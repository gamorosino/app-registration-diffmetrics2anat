#!/usr/bin/env python3
"""Registration QC: edge-overlay of a diffusion-derived scalar map (tensor or
NODDI) on the anatomical reference, before and after registration.

Before: the original moving map is resampled onto the anatomical grid using
        the (mis)aligned world-space affines, purely for visual comparison.
After:  the moving map already warped onto the anatomical grid by
        antsApplyTransforms in the caller.
"""

import argparse
import os

import numpy as np
import nibabel as nib
import nibabel.orientations as nio
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from scipy.ndimage import sobel, gaussian_filter, center_of_mass, affine_transform


def normalize(v):
    valid = v[v > 0]
    if valid.size == 0:
        return np.zeros_like(v)
    p2, p98 = np.percentile(valid, [2, 98])
    return np.clip((v - p2) / (p98 - p2 + 1e-9), 0, 1)


def make_edges(v, edge_thr, sigma=1.5):
    s = gaussian_filter(v.astype(np.float32), sigma=sigma)
    mag = np.sqrt(sobel(s, 0) ** 2 + sobel(s, 1) ** 2 + sobel(s, 2) ** 2)
    valid = mag[mag > 0]
    if valid.size == 0:
        return np.zeros_like(mag)
    return (mag > np.percentile(valid, edge_thr * 100)).astype(np.float32)


def to_ras(data, affine):
    ornt = nio.io_orientation(affine)
    tgt = nio.axcodes2ornt(("R", "A", "S"))
    return nio.apply_orientation(data, nio.ornt_transform(ornt, tgt))


def show_slice(vol, axis, idx):
    s = vol[:, :, idx] if axis == 2 else (vol[:, idx, :] if axis == 1 else vol[idx, :, :])
    return np.flipud(s[::-1, :].T)


def render_panel(ax, fixed_ras, edges_vol, axis, idx):
    bg = show_slice(fixed_ras, axis, idx)
    fg = show_slice(edges_vol, axis, idx)
    ax.imshow(bg, cmap="gray", vmin=0, vmax=1, interpolation="bilinear")
    rgba = np.zeros((*fg.shape, 4), dtype=np.float32)
    rgba[..., 0] = 1.0
    rgba[..., 1] = 0.55
    rgba[..., 2] = 0.0
    rgba[..., 3] = fg * 0.85
    ax.imshow(rgba, interpolation="nearest")
    ax.axis("off")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--fixed", required=True, help="Anatomical reference (e.g. T1w)")
    p.add_argument("--moving-orig", required=True, help="Original diffusion metric map, native space")
    p.add_argument("--moving-warped", required=True, help="Metric map already resliced onto the anatomical grid")
    p.add_argument("--outdir", required=True)
    p.add_argument("--edge-thr", type=float, default=0.9)
    args = p.parse_args()

    os.makedirs(args.outdir, exist_ok=True)

    fixed_img = nib.load(args.fixed)
    fixed_data = fixed_img.get_fdata(dtype=np.float32)
    if fixed_data.ndim == 4:
        fixed_data = fixed_data[..., 0]

    warped_img = nib.load(args.moving_warped)
    warped_data = warped_img.get_fdata(dtype=np.float32)
    if warped_data.ndim == 4:
        warped_data = warped_data[..., 0]

    orig_img = nib.load(args.moving_orig)
    orig_data = orig_img.get_fdata(dtype=np.float32)
    if orig_data.ndim == 4:
        orig_data = orig_data[..., 0]

    # "Before": resample the original (native-space) map onto the fixed grid
    # using the raw world-space affines, so any pre-registration misalignment
    # is visible rather than corrected away.
    M = np.linalg.inv(orig_img.affine) @ fixed_img.affine
    before_r = affine_transform(orig_data, M[:3, :3], offset=M[:3, 3],
                                 output_shape=fixed_data.shape, order=1, cval=0.0)

    fn_ras = to_ras(normalize(fixed_data), fixed_img.affine)
    before_edges_ras = to_ras(make_edges(normalize(before_r), args.edge_thr), fixed_img.affine)
    after_edges_ras = to_ras(make_edges(normalize(warped_data), args.edge_thr), fixed_img.affine)
    after_ras = to_ras(warped_data, fixed_img.affine)

    cx, cy, cz = [int(round(c)) for c in
                  center_of_mass(after_ras > np.percentile(after_ras[after_ras > 0], 30))]
    cx = np.clip(cx, 0, fn_ras.shape[0] - 1)
    cy = np.clip(cy, 0, fn_ras.shape[1] - 1)
    cz = np.clip(cz, 0, fn_ras.shape[2] - 1)

    rows = [(before_edges_ras, "Before"), (after_edges_ras, "After")]

    # 1. orthoview summary (one slice per plane)
    view_labels = ["Axial", "Coronal", "Sagittal"]
    axes_idx = [2, 1, 0]
    slices_idx = [cz, cy, cx]

    fig, axs = plt.subplots(2, 3, figsize=(15, 10), facecolor="black")
    fig.suptitle("Registration QC — anatomical (grey) + diffusion metric edges (orange)",
                 color="white", fontsize=14)
    for col, (label, axis, idx) in enumerate(zip(view_labels, axes_idx, slices_idx)):
        for row, (edges_vol, row_label) in enumerate(rows):
            render_panel(axs[row, col], fn_ras, edges_vol, axis, idx)
            axs[row, col].set_title(f"{row_label} — {label}", color="white", fontsize=11)
    plt.tight_layout()
    plt.savefig(os.path.join(args.outdir, "orthoview_qc.png"), dpi=150,
                bbox_inches="tight", facecolor="black")
    plt.close()
    print("QC image saved to: orthoview_qc.png")

    # 2. per-plane multi-slice QC (5 slices at 25/35/50/65/75 %)
    fracs = [0.25, 0.35, 0.50, 0.65, 0.75]
    planes = [
        ("axial", 2, fn_ras.shape[2]),
        ("coronal", 1, fn_ras.shape[1]),
        ("sagittal", 0, fn_ras.shape[0]),
    ]

    for plane_name, axis, dim in planes:
        idxs = [int(round(f * (dim - 1))) for f in fracs]
        fig, axs = plt.subplots(2, len(idxs), figsize=(5 * len(idxs), 8), facecolor="black")
        fig.suptitle(f"Registration QC — {plane_name.capitalize()} slices — "
                     f"anatomical (grey) + diffusion metric edges (orange)",
                     color="white", fontsize=13)
        for col, idx in enumerate(idxs):
            for row, (edges_vol, row_label) in enumerate(rows):
                render_panel(axs[row, col], fn_ras, edges_vol, axis, idx)
                axs[row, col].set_title(f"{row_label} — slice {idx}", color="white", fontsize=10)
        plt.tight_layout()
        out = os.path.join(args.outdir, f"{plane_name}_qc.png")
        plt.savefig(out, dpi=150, bbox_inches="tight", facecolor="black")
        plt.close()
        print(f"QC image saved to: {plane_name}_qc.png")


if __name__ == "__main__":
    main()
