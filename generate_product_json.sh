#!/usr/bin/env bash
# generate_product_json.sh
#
# Usage:
#   bash generate_product_json.sh [--compress] <image_dir> <output_product_json>
#
# Behavior:
#   - Default: embeds PNGs as full base64
#   - --compress: tries to keep final product.json under 1 MB by
#       resizing PNGs proportionally based on image count, then
#       iteratively shrinking further if needed.
#
# Requirements for --compress:
#   - ImageMagick via apptainer/singularity (docker://brainlife/imagemagick:latest)
#
set -euo pipefail

MAX_JSON_SIZE=$((1024 * 1024))   # 1 MB
TMPDIR_LOCAL="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT

compress=false

usage() {
    cat <<EOF
Usage: $0 [--compress] <image_dir> <output_product_json>

Options:
  --compress   Resize images before base64 embedding so product.json
               tries to stay under 1 MB.
EOF
}

# ── parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --compress) compress=true; shift ;;
        -h|--help)  usage; exit 0 ;;
        --)         shift; break ;;
        -*) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
        *)  break ;;
    esac
done

image_dir="${1:?Usage: $0 [--compress] <image_dir> <product_json>}"
product_json="${2:?Usage: $0 [--compress] <image_dir> <product_json>}"

metrics_json="null"
metrics_file="${image_dir}/metrics.json"
[[ -f "$metrics_file" ]] && metrics_json="$(cat "$metrics_file")"

mapfile -d '' images < <(
    find "${image_dir}" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) -print0 | sort -z
)
num_images="${#images[@]}"

if [[ "$num_images" -eq 0 ]]; then
    cat > "${product_json}" <<EOF
{
  "datatype_tags": [],
  "brainlife": [{"type":"error","msg":"No QC images were generated."}],
  "metrics": ${metrics_json}
}
EOF
    echo "product.json written to ${product_json} (no images found)"
    exit 0
fi

# ── image conversion helper ───────────────────────────────────────────────────
IMG_CONTAINER="${IMG_CONTAINER:-docker://brainlife/imagemagick:latest}"

img_to_png() {
    local input="$1" output="$2" percent="$3"
    local resize_args=()
    [[ "$percent" -lt 100 ]] && resize_args=(-resize "${percent}%")
    if command -v apptainer >/dev/null 2>&1; then
        apptainer exec "$IMG_CONTAINER" convert "$input" "${resize_args[@]}" PNG:"$output"
    elif command -v singularity >/dev/null 2>&1; then
        singularity exec "$IMG_CONTAINER" convert "$input" "${resize_args[@]}" PNG:"$output"
    else
        echo "Error: --compress requires apptainer or singularity." >&2; exit 1
    fi
}

# ── build product.json at a given scale ──────────────────────────────────────
build_product_json() {
    local scale_percent="$1" out_json="$2"
    local qa_entries=() idx=0

    for image in "${images[@]}"; do
        local filename base ext
        filename="$(basename "$image")"
        base="${filename%.*}"
        ext="${filename##*.}"; ext="${ext,,}"

        local working_image="${TMPDIR_LOCAL}/img_${idx}.png"

        if [[ "$compress" == true ]]; then
            img_to_png "$image" "$working_image" "$scale_percent"
        else
            if [[ "$ext" == "png" ]]; then
                working_image="$image"
            else
                img_to_png "$image" "$working_image" 100
            fi
        fi

        local b64
        b64="$(base64 -w 0 "$working_image")"
        qa_entries+=("$(printf '{"type":"image/png","name":"%s","base64":"%s"}' "$base" "$b64")")
        idx=$((idx + 1))
    done

    local brainlife_array
    brainlife_array="[$(printf '%s,' "${qa_entries[@]}" | sed 's/,$//')]"

    cat > "${out_json}" <<EOF
{
  "datatype_tags": [],
  "brainlife": ${brainlife_array},
  "metrics": ${metrics_json}
}
EOF
}

# ── no-compress path ──────────────────────────────────────────────────────────
if [[ "$compress" == false ]]; then
    build_product_json 100 "${product_json}"
    final_size=$(wc -c < "${product_json}")
    echo "product.json written to ${product_json} (${final_size} bytes)"
    exit 0
fi

# ── compress path: estimate initial scale, then iterate ──────────────────────
reserved_overhead=16384
available_for_images=$((MAX_JSON_SIZE - reserved_overhead))

total_original_size=0
for image in "${images[@]}"; do
    sz=$(wc -c < "$image")
    total_original_size=$((total_original_size + sz))
done
avg_original_size=$((total_original_size / num_images))
target_binary_per_image=$((available_for_images * 3 / 4 / num_images))

scale_percent=100
if [[ "$avg_original_size" -gt 0 && "$target_binary_per_image" -lt "$avg_original_size" ]]; then
    scale_percent=$(python3 - <<PY
import math
ratio = max($target_binary_per_image / $avg_original_size, 0.01)
print(int(max(5, min(100, math.sqrt(ratio) * 100))))
PY
)
fi

candidate_json="${TMPDIR_LOCAL}/product.json"
attempt=1

while :; do
    rm -f "${TMPDIR_LOCAL}"/img_*.png "$candidate_json" 2>/dev/null || true
    build_product_json "$scale_percent" "$candidate_json"
    current_size=$(wc -c < "$candidate_json")

    if [[ "$current_size" -le "$MAX_JSON_SIZE" ]] || [[ "$scale_percent" -le 5 ]]; then
        cp "$candidate_json" "$product_json"
        echo "product.json written to ${product_json} (${current_size} bytes, scale=${scale_percent}%)"
        [[ "$current_size" -gt "$MAX_JSON_SIZE" ]] && echo "Warning: still above 1 MB at minimum scale." >&2
        exit 0
    fi

    next_scale=$(python3 - <<PY
import math
ratio = $MAX_JSON_SIZE / $current_size
next_scale = math.sqrt(ratio) * $scale_percent * 0.92
print(int(max(5, min($scale_percent - 1, next_scale))))
PY
)
    [[ "$next_scale" -ge "$scale_percent" ]] && next_scale=$((scale_percent - 5))
    [[ "$next_scale" -lt 5 ]] && next_scale=5
    scale_percent="$next_scale"
    attempt=$((attempt + 1))

    if [[ "$attempt" -gt 12 ]]; then
        cp "$candidate_json" "$product_json"
        echo "Warning: reached max compression attempts." >&2
        echo "product.json written to ${product_json} (${current_size} bytes, scale=${scale_percent}%)"
        exit 0
    fi
done
