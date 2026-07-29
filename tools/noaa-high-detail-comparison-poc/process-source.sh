#!/usr/bin/env bash
#
# Build the isolated Southern Tampa Bay high-detail comparison tile layer.
#
# This processor is deliberately fixed to one approved NOAA source file,
# checksum, and 2 km x 2 km extent. GIS commands run only in the pinned GDAL
# container. The downloaded source and every intermediate stay in a temporary
# directory and are removed on exit.

set -euo pipefail
IFS=$'\n\t'

readonly GDAL_IMAGE='ghcr.io/osgeo/gdal@sha256:a0dcafba68b64c19a97b718767bcb3f245d1aac94714fea397201d6cdb763f8b'
readonly SOURCE_FILENAME='2021_339000e_3067000n_dem.tif'
readonly SOURCE_URL='https://noaa-nos-coastal-lidar-pds.s3.amazonaws.com/dem/NGS_South_TampBay_Topobathy_2021_9481/2021_339000e_3067000n_dem.tif'
readonly SOURCE_EXPECTED_SIZE='102303312'
readonly SOURCE_EXPECTED_SHA256='4d943093c0f88b72007d0f99e3e325395a8d0ec21c8be01baba1e7d87de43c90'
readonly EXPECTED_TILE_COUNT='102'

readonly WEST='339267'
readonly EAST='341267'
readonly SOUTH='3064121'
readonly NORTH='3066121'
readonly SOURCE_EPSG='EPSG:6346'
readonly ZOOM_RANGE='14-17'

SCRIPT_DIR=''
REPO_ROOT=''
OUTPUT_PARENT=''
OUTPUT_DIR=''
LOCK_DIR=''
WORK_DIR=''
STAGE_DIR=''
BACKUP_DIR=''
LOCK_HELD='0'
TEMP_PARENT=''

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "Required command is unavailable: $1"
}

safe_remove_tree() {
    local target_path="${1:-}"
    local allowed_parent="${2:-}"

    [ -n "$target_path" ] || return 0
    [ -n "$allowed_parent" ] || return 1
    [ "$target_path" != "$allowed_parent" ] || return 1
    case "$target_path" in
        "$allowed_parent"/*) ;;
        *) return 1 ;;
    esac
    [ ! -L "$target_path" ] || return 1
    if [ -d "$target_path" ]; then
        find "$target_path" -depth -delete
    fi
}

cleanup() {
    exit_status=$?
    trap - EXIT
    set +e

    if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ] && [ ! -e "$OUTPUT_DIR" ]; then
        mv "$BACKUP_DIR" "$OUTPUT_DIR"
        BACKUP_DIR=''
    fi
    if [ -n "$STAGE_DIR" ] && [ -d "$STAGE_DIR" ]; then
        safe_remove_tree "$STAGE_DIR" "$OUTPUT_PARENT"
    fi
    if [ -n "$WORK_DIR" ] && [ -d "$WORK_DIR" ]; then
        safe_remove_tree "$WORK_DIR" "$TEMP_PARENT"
    fi
    if [ "$LOCK_HELD" = '1' ] && [ -d "$LOCK_DIR" ]; then
        rmdir "$LOCK_DIR"
    fi

    exit "$exit_status"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

sha256_file() {
    input_path=$1
    if command -v shasum >/dev/null 2>&1; then
        checksum_line="$(shasum -a 256 "$input_path")"
    elif command -v sha256sum >/dev/null 2>&1; then
        checksum_line="$(sha256sum "$input_path")"
    else
        fail 'A SHA-256 utility (shasum or sha256sum) is required.'
    fi
    printf '%s\n' "${checksum_line%% *}"
}

epoch_seconds() {
    date +%s
}

run_gdal() {
    docker run --rm \
        --platform linux/arm64 \
        --network none \
        --user "$(id -u):$(id -g)" \
        --env HOME=/tmp \
        --env GDAL_CACHEMAX=512 \
        --volume "$WORK_DIR:/work" \
        --volume "$SCRIPT_DIR:/tool:ro" \
        --workdir /work \
        "$GDAL_IMAGE" \
        "$@"
}

validate_staged_public_output() {
    [ -d "$STAGE_DIR" ] || fail 'Public-output stage directory is missing.'
    [ ! -L "$STAGE_DIR" ] || fail 'Public-output stage must not be a symlink.'
    [ -f "$STAGE_DIR/manifest.json" ] || fail 'Generated manifest is missing.'
    [ ! -L "$STAGE_DIR/manifest.json" ] || fail 'Generated manifest must not be a symlink.'

    staged_symlink="$(find "$STAGE_DIR" -type l -print -quit)"
    [ -z "$staged_symlink" ] || fail "Generated output contains a symlink: $staged_symlink"

    unexpected_file="$(
        find "$STAGE_DIR" -type f \
            ! \( -name '*.png' -o -name 'manifest.json' \) \
            -print -quit
    )"
    [ -z "$unexpected_file" ] || fail "Generated output contains an unexpected file: $unexpected_file"

    for zoom in 14 15 16 17; do
        [ -d "$STAGE_DIR/$zoom" ] || fail "Generated output is missing zoom directory $zoom."
    done

    for top_level_path in "$STAGE_DIR"/*; do
        top_level_name="${top_level_path##*/}"
        case "$top_level_name" in
            14|15|16|17|manifest.json) ;;
            *) fail "Generated output has an unexpected top-level entry: $top_level_name" ;;
        esac
    done

    staged_tile_count="$(
        find "$STAGE_DIR" -type f -name '*.png' -print | wc -l | tr -d '[:space:]'
    )"
    [ "$staged_tile_count" = "$EXPECTED_TILE_COUNT" ] || \
        fail "Expected $EXPECTED_TILE_COUNT staged PNG tiles; found $staged_tile_count."

    staged_file_count="$(
        find "$STAGE_DIR" -type f -print | wc -l | tr -d '[:space:]'
    )"
    [ "$staged_file_count" = '103' ] || \
        fail "Expected 103 public files (102 PNG plus manifest); found $staged_file_count."
}

publish_output() {
    if [ -L "$OUTPUT_DIR" ]; then
        fail "Refusing to replace a symlinked output path: $OUTPUT_DIR"
    fi
    if [ -e "$OUTPUT_DIR" ] && [ ! -d "$OUTPUT_DIR" ]; then
        fail "Output path exists but is not a directory: $OUTPUT_DIR"
    fi

    if [ -d "$OUTPUT_DIR" ]; then
        [ -f "$OUTPUT_DIR/manifest.json" ] || \
            fail 'Existing output has no manifest; refusing to replace an unverified directory.'
        [ ! -L "$OUTPUT_DIR/manifest.json" ] || \
            fail 'Existing output manifest is a symlink; refusing replacement.'
        BACKUP_DIR="$OUTPUT_PARENT/.south-tampa-high-detail.previous.$$"
        [ ! -e "$BACKUP_DIR" ] || fail "Backup path unexpectedly exists: $BACKUP_DIR"
        mv "$OUTPUT_DIR" "$BACKUP_DIR"
    fi

    if ! mv "$STAGE_DIR" "$OUTPUT_DIR"; then
        if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ] && [ ! -e "$OUTPUT_DIR" ]; then
            mv "$BACKUP_DIR" "$OUTPUT_DIR"
            BACKUP_DIR=''
        fi
        fail 'Atomic publication of the generated POC output failed.'
    fi
    STAGE_DIR=''

    if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
        safe_remove_tree "$BACKUP_DIR" "$OUTPUT_PARENT" || \
            fail "New output is published, but old backup could not be removed: $BACKUP_DIR"
        BACKUP_DIR=''
    fi
}

if [ "$#" -ne 0 ]; then
    fail 'This fixed-scope processor accepts no arguments.'
fi

require_command curl
require_command date
require_command docker
require_command find
require_command id
require_command mv
require_command wc

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
OUTPUT_PARENT="$REPO_ROOT/assets/maps/poc"
OUTPUT_DIR="$OUTPUT_PARENT/south-tampa-high-detail"
LOCK_DIR="$OUTPUT_PARENT/.south-tampa-high-detail.lock"

[ -f "$SCRIPT_DIR/process-source.py" ] || \
    fail "Required helper is missing: $SCRIPT_DIR/process-source.py"
case "$SCRIPT_DIR" in
    "$REPO_ROOT"/tools/noaa-high-detail-comparison-poc) ;;
    *) fail "Processor is not running from the expected repository location: $SCRIPT_DIR" ;;
esac

mkdir -p "$OUTPUT_PARENT"
if ! mkdir "$LOCK_DIR"; then
    fail "Another processor run may be active (lock exists): $LOCK_DIR"
fi
LOCK_HELD='1'

TEMP_PARENT="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
WORK_DIR="$(mktemp -d "$TEMP_PARENT/fpw-noaa-high-detail.XXXXXX")"
[ -d "$WORK_DIR" ] || fail 'Could not create the temporary processing directory.'
[ ! -L "$WORK_DIR" ] || fail 'Temporary processing directory must not be a symlink.'

TOTAL_STARTED_AT="$(epoch_seconds)"
SOURCE_PATH="$WORK_DIR/$SOURCE_FILENAME"
SOURCE_PART="$SOURCE_PATH.part"
SOURCE_METADATA_PATH="$WORK_DIR/source-metadata.json"
CLIP_PATH="$WORK_DIR/south-tampa-clip-1m.tif"
CLIP_METADATA_PATH="$WORK_DIR/clip-metadata.json"
PALETTE_PATH="$WORK_DIR/bluetopo-nbs-elevation-palette.txt"
COLOR_PATH="$WORK_DIR/south-tampa-color-relief.tif"
HILLSHADE_PATH="$WORK_DIR/south-tampa-multidirectional-hillshade.tif"
COMBINED_PATH="$WORK_DIR/south-tampa-combined-relief.tif"
TILES_PATH="$WORK_DIR/tiles"
MANIFEST_PATH="$WORK_DIR/manifest.json"

printf 'Pinned GDAL image: %s\n' "$GDAL_IMAGE"
if ! docker image inspect "$GDAL_IMAGE" >/dev/null 2>&1; then
    printf 'Pinned GDAL image is not local; pulling its exact digest...\n'
    docker pull "$GDAL_IMAGE"
fi
GDAL_IMAGE_ID="$(docker image inspect --format '{{.Id}}' "$GDAL_IMAGE")"
GDAL_VERSION="$(run_gdal gdalinfo --version | tr -d '\r\n')"

printf 'Downloading the one approved NOAA source tile...\n'
DOWNLOAD_STARTED_AT="$(epoch_seconds)"
curl --fail --location --proto '=https' --tlsv1.2 \
    --retry 3 --retry-delay 2 --retry-connrefused \
    --output "$SOURCE_PART" \
    "$SOURCE_URL"
mv "$SOURCE_PART" "$SOURCE_PATH"
DOWNLOAD_SECONDS="$(( $(epoch_seconds) - DOWNLOAD_STARTED_AT ))"

SOURCE_SIZE_ACTUAL="$(wc -c < "$SOURCE_PATH" | tr -d '[:space:]')"
[ "$SOURCE_SIZE_ACTUAL" = "$SOURCE_EXPECTED_SIZE" ] || \
    fail "Source size mismatch: expected $SOURCE_EXPECTED_SIZE bytes, got $SOURCE_SIZE_ACTUAL."
SOURCE_SHA256_ACTUAL="$(sha256_file "$SOURCE_PATH")"
[ "$SOURCE_SHA256_ACTUAL" = "$SOURCE_EXPECTED_SHA256" ] || \
    fail "Source SHA-256 mismatch: expected $SOURCE_EXPECTED_SHA256, got $SOURCE_SHA256_ACTUAL."

printf 'Validating source metadata and approved coverage...\n'
SOURCE_VALIDATION_STARTED_AT="$(epoch_seconds)"
run_gdal python3 /tool/process-source.py inspect-source \
    --input "/work/$SOURCE_FILENAME" \
    --output /work/source-metadata.json
SOURCE_VALIDATION_SECONDS="$(( $(epoch_seconds) - SOURCE_VALIDATION_STARTED_AT ))"

printf 'Clipping exactly 2000 x 2000 native 1 m cells...\n'
CLIP_STARTED_AT="$(epoch_seconds)"
run_gdal gdal_translate \
    -projwin "$WEST" "$NORTH" "$EAST" "$SOUTH" \
    -projwin_srs "$SOURCE_EPSG" \
    -a_nodata -999999 \
    -co TILED=YES \
    -co BLOCKXSIZE=256 \
    -co BLOCKYSIZE=256 \
    -co COMPRESS=DEFLATE \
    -co PREDICTOR=3 \
    "/work/$SOURCE_FILENAME" \
    /work/south-tampa-clip-1m.tif
run_gdal python3 /tool/process-source.py inspect-clip \
    --input /work/south-tampa-clip-1m.tif \
    --output /work/clip-metadata.json
CLIP_SECONDS="$(( $(epoch_seconds) - CLIP_STARTED_AT ))"

printf 'Generating restrained color relief and multidirectional hillshade...\n'
RELIEF_STARTED_AT="$(epoch_seconds)"
run_gdal python3 /tool/process-source.py write-palette \
    --output /work/bluetopo-nbs-elevation-palette.txt
run_gdal gdaldem color-relief \
    /work/south-tampa-clip-1m.tif \
    /work/bluetopo-nbs-elevation-palette.txt \
    /work/south-tampa-color-relief.tif \
    -alpha \
    -co TILED=YES \
    -co BLOCKXSIZE=256 \
    -co BLOCKYSIZE=256 \
    -co COMPRESS=DEFLATE \
    -co PREDICTOR=2
run_gdal gdaldem hillshade \
    /work/south-tampa-clip-1m.tif \
    /work/south-tampa-multidirectional-hillshade.tif \
    -multidirectional \
    -compute_edges \
    -z 2.0 \
    -co TILED=YES \
    -co BLOCKXSIZE=256 \
    -co BLOCKYSIZE=256 \
    -co COMPRESS=DEFLATE
run_gdal python3 /tool/process-source.py combine \
    --color /work/south-tampa-color-relief.tif \
    --hillshade /work/south-tampa-multidirectional-hillshade.tif \
    --output /work/south-tampa-combined-relief.tif
run_gdal python3 /tool/process-source.py validate-combined \
    --input /work/south-tampa-combined-relief.tif
RELIEF_SECONDS="$(( $(epoch_seconds) - RELIEF_STARTED_AT ))"

printf 'Generating the limited XYZ PNG tile pyramid at zooms %s...\n' "$ZOOM_RANGE"
TILES_STARTED_AT="$(epoch_seconds)"
mkdir "$TILES_PATH"
run_gdal gdal2tiles.py \
    --profile=mercator \
    --zoom="$ZOOM_RANGE" \
    --xyz \
    --resampling=near \
    --tilesize=256 \
    --tiledriver=PNG \
    --exclude \
    --webviewer=none \
    --processes=4 \
    /work/south-tampa-combined-relief.tif \
    /work/tiles
TILES_SECONDS="$(( $(epoch_seconds) - TILES_STARTED_AT ))"

printf 'Validating every generated tile and writing the source manifest...\n'
VALIDATION_MANIFEST_STARTED_AT="$(epoch_seconds)"
GENERATED_AT_UTC="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
run_gdal python3 /tool/process-source.py build-manifest \
    --source-metadata /work/source-metadata.json \
    --clip-metadata /work/clip-metadata.json \
    --tiles-dir /work/tiles \
    --output /work/manifest.json \
    --source-size-bytes "$SOURCE_SIZE_ACTUAL" \
    --source-sha256 "$SOURCE_SHA256_ACTUAL" \
    --generated-at-utc "$GENERATED_AT_UTC" \
    --gdal-image "$GDAL_IMAGE" \
    --gdal-image-id "$GDAL_IMAGE_ID" \
    --gdal-version "$GDAL_VERSION" \
    --download-seconds "$DOWNLOAD_SECONDS" \
    --source-validation-seconds "$SOURCE_VALIDATION_SECONDS" \
    --clip-seconds "$CLIP_SECONDS" \
    --relief-seconds "$RELIEF_SECONDS" \
    --tiles-seconds "$TILES_SECONDS" \
    --processing-started-epoch "$TOTAL_STARTED_AT" \
    --validation-started-epoch "$VALIDATION_MANIFEST_STARTED_AT"
VALIDATION_MANIFEST_SECONDS="$(( $(epoch_seconds) - VALIDATION_MANIFEST_STARTED_AT ))"

STAGE_DIR="$(mktemp -d "$OUTPUT_PARENT/.south-tampa-high-detail.stage.XXXXXX")"
for zoom in 14 15 16 17; do
    cp -R "$TILES_PATH/$zoom" "$STAGE_DIR/$zoom"
done
cp "$MANIFEST_PATH" "$STAGE_DIR/manifest.json"
validate_staged_public_output
publish_output

TOTAL_SECONDS="$(( $(epoch_seconds) - TOTAL_STARTED_AT ))"
PUBLISHED_SIZE_KIB="$(du -sk "$OUTPUT_DIR" | tr '\t' ' ' | tr -s ' ' | cut -d ' ' -f 1)"

printf '\nPOC source processing completed successfully.\n'
printf 'Output: %s\n' "$OUTPUT_DIR"
printf 'Tiles: %s PNG files across zooms %s\n' "$EXPECTED_TILE_COUNT" "$ZOOM_RANGE"
printf 'Published size: %s KiB (filesystem allocation)\n' "$PUBLISHED_SIZE_KIB"
printf 'Source SHA-256: %s\n' "$SOURCE_SHA256_ACTUAL"
printf 'Validation/manifest stage: %s seconds\n' "$VALIDATION_MANIFEST_SECONDS"
printf 'Total elapsed before temporary cleanup: %s seconds\n' "$TOTAL_SECONDS"
printf 'Temporary source and intermediate rasters will now be removed.\n'
