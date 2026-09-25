# Diffusion Metrics-to-Anatomical Registration

A reproducible and automated pipeline to register a diffusion-derived scalar
map — tensor-based (FA, MD, RD, AD) or NODDI-based (NDI, ISOVF, ODI) — to an
anatomical MRI reference (e.g. T1-weighted), using configurable transformation
stages, and to reslice that map onto the anatomical grid.

This is a companion to
[`app-registration-dwi2anat`](https://github.com/gamorosino/app-registration-dwi2anat),
trimmed down for the case where you already have a scalar diffusion metric
map instead of a raw 4D DWI: no b=0 extraction step, and no DWI gradient
reorientation (there is nothing to reorient in a scalar map). The moving
image goes straight into ANTs.

Motivation: diffusion-derived scalar maps and the whole-brain tractogram
they're meant to be sampled against are not always reconstructed on the same
field of view. A tractogram built with anatomically-constrained tracking
(against a T1-derived tissue mask) can extend past the edges of the native
diffusion-reconstruction grid — most visibly at the inferior brainstem/
cerebellum boundary — and any downstream tool that indexes those scalar maps
by voxel coordinate (e.g. tract-profile extraction) can throw an
out-of-bounds error for streamline points that fall just outside that grid.
Registering (and reslicing) the scalar maps onto the anatomical's larger FOV
resolves this.

---

## Author

**Gabriele Amorosino**
(email: [gabriele.amorosino@utexas.edu](mailto:gabriele.amorosino@utexas.edu))

---

## Description

This pipeline registers a diffusion-derived scalar map to a selected
anatomical image using ANTs (`antsRegistration`, staged translation → rigid →
affine → nonlinear, configurable), then reslices that same map onto the
anatomical grid with `antsApplyTransforms`. The workflow is configured via a
`config.json` file and supports execution in containerized environments
(Singularity).

**Supported moving images:** `fa`, `md`, `rd`, `ad` (tensor), `ndi`, `isovf`,
`odi` (NODDI) — all plain 3D scalar volumes.

**Not supported:** NODDI's `dir` (a 3-vector orientation field). Reslicing
each of its components independently under anything beyond a pure
translation would rotate the underlying directions incorrectly. Reorienting
`dir` needs a vector-aware tool (e.g. FSL's `vecreg`) — out of scope here.

**Applying the resulting transform to other maps:** this app only computes
the transform and reslices the one map you register with. To apply that same
transform to additional scalar maps (e.g. register FA, then also reslice
MD/RD/AD/NDI/ISOVF/ODI with the transform already computed), use
[`app-apply-ants-transform`](https://github.com/gamorosino/app-apply-ants-transform)
with this app's `transformations/` output.

---

## Requirements

- [Singularity](https://sylabs.io/guides/latest/user-guide/)

---

## Usage

### Running on Brainlife.io

#### On Brainlife.io via Web UI

1. Navigate to the [Brainlife.io](https://brainlife.io) platform and locate the `app-registration-diffmetrics2anat` app.
2. Click the **Execute** tab.
3. Upload required inputs:
   - A diffusion-derived scalar map (`fa`/`md`/`rd`/`ad`/`ndi`/`isovf`/`odi`, `.nii.gz`)
   - An anatomical image (T1w or T2w)
4. Submit the job. Output will include the registered/resliced map and its transformation matrices/fields.

#### On Brainlife.io via CLI

1. Install the Brainlife CLI: https://brainlife.io/docs/cli/
2. Log in:
   ```bash
   bl login
   ```
3. Run the app:
   ```bash
   bl app run --id <app_id> --project <project_id> \
     --input fa:<fa_dataset_id> \
     --input t1:<t1_dataset_id>
   ```

Replace IDs with the appropriate dataset and project references.

---

### Running Locally

#### Option 1: Using a Configuration File

1. Clone the repository:
   ```bash
   git clone https://github.com/gamorosino/app-registration-diffmetrics2anat.git
   cd app-registration-diffmetrics2anat
   ```

2. Create a `config.json`:
   ```json
   {
       "fa": "sub-01_fa.nii.gz",
       "t1": "sub-01_T1w.nii.gz",
       "transformation": "rigid",
       "settings": "1"
   }
   ```
   (`moving` also works as an explicit generic key instead of `fa`/`md`/`rd`/`ad`/`ndi`/`isovf`/`odi`.)

3. Run the pipeline:
   ```bash
   bash ./main
   ```

#### Option 2: Using the CLI Wrapper

```bash
./main_cli.sh --moving sub-01_fa.nii.gz --t1w sub-01_T1w.nii.gz \
              --transformation rigid --settings 1
```

---

## Outputs

- `ANTs_outputs/` — ANTs registration outputs: affine matrix, warp fields
- `transformations/` — Final transformation files (formatted for Brainlife: `affine.txt`, `warp.nii.gz`, `inverse-warp.nii.gz`)
- `transformed/` — The registered/resliced scalar map, on the anatomical grid
- `QC/` — Edge-overlay registration QC figures (before/after, orthoview + per-plane)
