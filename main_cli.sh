#! /bin/bash

#########################################################################################################################
#########################################################################################################################
###################                                                                                   ###################
###################     title:             Local launcher — build config.json and run main            ###################
###################                                                                                   ###################
###################     usage:             main_cli.sh --moving <path> --t1w <path> [--t2w <path>]    ###################
###################                        [--transformation <type>] [--settings <1-4>]               ###################
###################                                                                                   ###################
###################     moving:            a diffusion-derived scalar map: tensor (fa/md/rd/ad) or    ###################
###################                        NODDI (ndi/isovf/odi). Vector fields (e.g. NODDI "dir")    ###################
###################                        are not supported — they need orientation-aware            ###################
###################                        reorientation (e.g. FSL vecreg), not a plain reslice.       ###################
###################                                                                                   ###################
###################     transformation:    translation | rigid | affine | nonlinear  (def: rigid)     ###################
###################     settings:          1 | 2 | 3 | 4                             (def: 1)         ###################
###################                                                                                   ###################
###################     autor: gamorosino                                                             ###################
#########################################################################################################################
#########################################################################################################################

SCRIPT=$(realpath -s "$0")
SCRIPT_DIR=$(dirname "$SCRIPT")

usage() {
    echo "Usage: $(basename $0) --moving <path> ( --t1w <path> | --t2w <path> )"
    echo "                       [--transformation translation|rigid|affine|nonlinear]"
    echo "                       [--settings 1|2|3|4]"
    exit 1
}

# ── defaults ──────────────────────────────────────────────────────────────────
moving=""
t1w="null"
t2w="null"
transformation="rigid"
settings=1

# ── parse arguments ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --moving)         moving=$(realpath "$2");        shift 2 ;;
        --t1w)            t1w=$(realpath "$2");            shift 2 ;;
        --t2w)            t2w=$(realpath "$2");            shift 2 ;;
        --transformation) transformation=$2;              shift 2 ;;
        --settings)       settings=$2;                    shift 2 ;;
        -h|--help)        usage ;;
        *) echo "Unknown argument: $1"; usage ;;
    esac
done

# ── validate required fields ──────────────────────────────────────────────────
errors=0

if [ -z "$moving" ]; then
    echo "Error: --moving is required" >&2
    errors=1
elif [ ! -f "$moving" ]; then
    echo "Error: --moving file not found: $moving" >&2
    errors=1
fi

if [ "$t1w" = "null" ] && [ "$t2w" = "null" ]; then
    echo "Error: at least one anatomical reference is required (--t1w or --t2w)" >&2
    errors=1
fi

case "$transformation" in
    translation|rigid|affine|nonlinear) ;;
    *) echo "Error: --transformation must be one of: translation rigid affine nonlinear" >&2; errors=1 ;;
esac

case "$settings" in
    1|2|3|4) ;;
    *) echo "Error: --settings must be one of: 1 2 3 4" >&2; errors=1 ;;
esac

[ $errors -ne 0 ] && exit 1

# ── helper: quote a path or emit JSON null ─────────────────────────────────────
json_val() {
    local v="$1"
    if [ "$v" = "null" ]; then
        echo "null"
    else
        jq -n --arg v "$v" '$v'
    fi
}

# ── write config.json ─────────────────────────────────────────────────────────
cat > config.json <<EOF
{
  "moving":         $(json_val "$moving"),
  "t1":             $(json_val "$t1w"),
  "t2":             $(json_val "$t2w"),
  "transformation": "$(echo $transformation)",
  "settings":       "$(echo $settings)"
}
EOF

echo "config.json written:"
cat config.json

# ── run main ──────────────────────────────────────────────────────────────────
echo ""
echo "Running: bash ${SCRIPT_DIR}/main"
bash "${SCRIPT_DIR}/main"
