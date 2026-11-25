<h1 align="center">registration diffmetrics2anat</h1>

<p align="center">
  Registers a NODDI scalar map (NDI, ISOVF or ODI) to a T1w or T2w anatomical image with ANTs (translation, rigid, affine or SyN) and reslices it onto the anatomical grid, with QC figures.
</p>

<p align="center">
  <a href="https://github.com/brainlife/abcd-spec"><img src="https://img.shields.io/badge/ABCD_Spec-v1.1-green.svg" alt="ABCD Spec v1.1"></a>
  <a href="https://doi.org/10.25663/brainlife.app.980"><img src="https://img.shields.io/badge/Brainlife-brainlife.app.980-blue.svg" alt="Run on brainlife.io"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-see_LICENSE-lightgrey.svg" alt="License"></a>
</p>

## At a glance

<!-- brainlife-app:begin (generated from the App manifest; edit the manifest, not this block) -->

> **Registers a NODDI scalar map (NDI, ISOVF or ODI) to a T1w or T2w anatomical image with ANTs (translation, rigid, affine or SyN) and reslices it onto the anatomical grid, with QC figures.**

Runs antsRegistration with configurable stages and pyramid depth, then antsApplyTransforms to reslice the moving map onto the anatomical image; outputs the transforms, the resliced map and before/after edge-overlay QC images. Use it to bring diffusion scalar maps onto the anatomical field of view, for example so that tract profiles of an anatomically constrained tractogram do not fall outside the diffusion grid. Only one map is registered: the first available of ndi, isovf, odi; apply the transform to the other maps with app-apply-ants-transform. Not for vector fields such as NODDI dir.

| | |
|---|---|
| **Inputs** | `neuro/noddi` · `neuro/anat/t1w` (optional) · `neuro/anat/t2w` (optional) |
| **Outputs** | `neuro/transform/nifti` · `neuro/noddi` · `generic/images` |
| **Container** | `gamorosino/tract_align:v1.1` |
| **Resources** | 1 CPUs · 1 h walltime |
| **Run it** | [doi.org/10.25663/brainlife.app.980](https://doi.org/10.25663/brainlife.app.980) |

#### Inputs

| Input | Datatype | Required | Description |
|---|---|---|---|
| `noddi_moving` | `neuro/noddi` | yes | NODDI scalar maps; the first available map (ndi, isovf, odi) is used as the moving image. 3D scalar volumes. |
| `t1_fixed` | `neuro/anat/t1w` | no | T1-weighted anatomical reference (fixed image). Used if present. |
| `t2_fixed` | `neuro/anat/t2w` | no | T2-weighted anatomical reference, used only when no T1w is given. At least one of t1_fixed or t2_fixed is required. |

#### Outputs

| Output | Datatype | Description |
|---|---|---|
| `transformations` | `neuro/transform/nifti` | Affine + optional warp/inverse-warp computed by ANTs registration. |
| `transformed` | `neuro/noddi` | The registered NODDI scalar map, resliced onto the anatomical grid. |
| `figures` | `generic/images` | Registration QC: edge-overlay before/after, orthoview + per-plane. |

<details>
<summary><b>Parameters</b> (2)</summary>

| Parameter | Type | Default | Description |
|---|---|---|---|
| `transformation` | enum | `rigid` | Stages to run: translation only, +rigid, +affine, or +nonlinear (SyN). Options: `translation`, `rigid`, `affine`, `nonlinear`. |
| `settings` | enum | `1` | Depth of the multiresolution (pyramidal) registration strategy. Higher = more levels, finer correspondence, slower. Options: `1`, `2`, `3`, `4`. |

</details>

<!-- brainlife-app:end -->

## Versions on brainlife.io

This repository hosts several Apps, each built from its own branch.

| App | Branch | Run it | Status |
|---|---|---|---|
| NODDI-to-Anatomical MRI Registration | [`main`](https://github.com/gamorosino/app-registration-diffmetrics2anat/tree/main) | [doi:10.25663/brainlife.app.980](https://doi.org/10.25663/brainlife.app.980) | current |
| DTI Metrics-to-Anatomical Registration | [`main`](https://github.com/gamorosino/app-registration-diffmetrics2anat/tree/main) | [doi:10.25663/brainlife.app.978](https://doi.org/10.25663/brainlife.app.978) | available |

## Running the App

### On brainlife.io

Open the App at [doi.org/10.25663/brainlife.app.980](https://doi.org/10.25663/brainlife.app.980), choose `neuro/noddi`, `neuro/anat/t1w`, `neuro/anat/t2w` from your project, set the parameters and press **Execute**. The results are saved to your project as `neuro/transform/nifti`, `neuro/noddi`, `generic/images`.

### Locally

You need [Singularity/Apptainer](https://apptainer.org/) (the App runs in `gamorosino/tract_align:v1.1`), [`jq`](https://jqlang.github.io/jq/).

1. Clone this repository and check out the App's branch (`git checkout main`).
2. Create `config.json` with the paths to your inputs and the parameters:

   ```json
   {
       "ndi": "/path/to/noddi_moving/ndi",
       "isovf": "/path/to/noddi_moving/isovf",
       "odi": "/path/to/noddi_moving/odi",
       "t1": "/path/to/t1_fixed/t1",
       "t2": "/path/to/t2_fixed/t2",
       "transformation": "rigid",
       "settings": "1"
   }
   ```

3. Run `./main`.

## Troubleshooting

- **Error: No valid anatomical reference found in config.json**: Provide a T1w or T2w input.
- **Error: no moving diffusion metric provided (fa/md/rd/ad/ndi/isovf/odi/moving)**: Provide an input containing at least one scalar map.

## Citing

If you use this App, please cite it, the software it builds on and brainlife.io:

- NODDI-to-Anatomical MRI Registration. brainlife.io App. [doi:10.25663/brainlife.app.980](https://doi.org/10.25663/brainlife.app.980)
- Avants et al. A reproducible evaluation of ANTs similarity metric performance in brain image registration. *NeuroImage* 54:2033-2044 (2011). [doi:10.1016/j.neuroimage.2010.09.025](https://doi.org/10.1016/j.neuroimage.2010.09.025)
- Zhang et al. NODDI: Practical in vivo neurite orientation dispersion and density imaging of the human brain. *NeuroImage* 61:1000-1016 (2012). [doi:10.1016/j.neuroimage.2012.03.072](https://doi.org/10.1016/j.neuroimage.2012.03.072)
- Hayashi S, Caron BA, Heinsfeld AS, et al. brainlife.io: a decentralized and open-source cloud platform to support neuroscience research. *Nature Methods* 21:809–813 (2024). [doi:10.1038/s41592-024-02237-2](https://doi.org/10.1038/s41592-024-02237-2)
- Avesani P, McPherson B, Hayashi S, et al. The open diffusion data derivatives, brain data upcycling via integrated publishing of derivatives and reproducible open cloud services. *Scientific Data* 6:69 (2019). [doi:10.1038/s41597-019-0073-y](https://doi.org/10.1038/s41597-019-0073-y)

## Authors

**Gabriele Amorosino**
(email:

---

## License

See [LICENSE](LICENSE).
