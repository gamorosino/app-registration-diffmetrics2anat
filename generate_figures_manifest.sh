#!/usr/bin/env bash
# generate_figures_manifest.sh
#
# Usage:
#   bash generate_figures_manifest.sh <image_dir> <output_dir>
#
# Copies QC images into <output_dir>/figures/images/ and writes
# <output_dir>/figures/images.json with name/desc metadata.
#
# The "desc" field is derived from the filename:
#   orthoview_qc  → "Orthoview registration QC (Before/After, 3 planes)"
#   axial_qc      → "Axial slices registration QC (Before/After, 5 levels)"
#   coronal_qc    → "Coronal slices registration QC (Before/After, 5 levels)"
#   sagittal_qc   → "Sagittal slices registration QC (Before/After, 5 levels)"
#   *             → "QC figure"
#
set -euo pipefail

image_dir="$1"
output_dir="$2"

figures_dir="${output_dir}/figures"
images_dir="${figures_dir}/images"
mkdir -p "$images_dir"

IMG_CONTAINER="${IMG_CONTAINER:-docker://brainlife/imagemagick:latest}"

run_convert() {
    if command -v apptainer >/dev/null 2>&1; then
        apptainer exec "$IMG_CONTAINER" convert "$@"
    else
        singularity exec "$IMG_CONTAINER" convert "$@"
    fi
}

json_escape() {
    python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"
}

describe_figure() {
    local name="$1"
    case "$name" in
        orthoview_qc) echo "Orthoview registration QC — Before/After, axial/coronal/sagittal" ;;
        axial_qc)     echo "Axial slices registration QC — Before/After, 5 levels (25–75%)" ;;
        coronal_qc)   echo "Coronal slices registration QC — Before/After, 5 levels (25–75%)" ;;
        sagittal_qc)  echo "Sagittal slices registration QC — Before/After, 5 levels (25–75%)" ;;
        *)            echo "QC figure" ;;
    esac
}

entries=()

for img in "${image_dir}"/*.png "${image_dir}"/*.jpg "${image_dir}"/*.jpeg; do
    [[ -f "$img" ]] || continue

    base=$(basename "$img")
    name="${base%.*}"
    ext="${base##*.}"

    out="${images_dir}/${name}.png"

    if [[ "$ext" == "png" ]]; then
        cp "$img" "$out"
    else
        run_convert "$img" PNG:"$out"
    fi

    desc="$(describe_figure "$name")"

    entries+=(
        "$(printf '{"filename":%s,"name":%s,"desc":%s}' \
            "$(json_escape "images/${name}.png")" \
            "$(json_escape "$name")" \
            "$(json_escape "$desc")")"
    )
done

images_json="["
for i in "${!entries[@]}"; do
    [[ "$i" -gt 0 ]] && images_json+=","
    images_json+="${entries[$i]}"
done
images_json+="]"

cat > "${figures_dir}/images.json" <<EOF
{
  "images": ${images_json}
}
EOF

echo "Figures manifest written to ${figures_dir}/images.json (${#entries[@]} figures)"
