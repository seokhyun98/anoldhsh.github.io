#!/usr/bin/env bash
set -euo pipefail

# Unified media conversion:
# - GIF → MP4/WebM + JPG poster (idempotent)
# - JPG/PNG → WebP/AVIF (idempotent)
#
# Requirements (macOS via Homebrew):
#   brew install ffmpeg
#   brew install webp
#   brew install libavif
#
# Usage:
#   bash scripts/convert_media.sh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMG_DIR="${ROOT_DIR}/images"

echo "Media conversion started in: ${IMG_DIR}"

have_gifs=false
have_rasters=false

shopt -s nullglob
pushd "$IMG_DIR" >/dev/null

# Detect targets
gif_list=(*.gif)
jpgpng_list=(*.jpg *.JPG *.jpeg *.JPEG *.png *.PNG)

if (( ${#gif_list[@]} > 0 )); then
  have_gifs=true
fi
if (( ${#jpgpng_list[@]} > 0 )); then
  have_rasters=true
fi

# Tool checks only when needed
if [[ "$have_gifs" == true ]]; then
  command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg not found. Install with: brew install ffmpeg" >&2; exit 1; }
fi
if [[ "$have_rasters" == true ]]; then
  command -v cwebp >/dev/null 2>&1 || { echo "cwebp not found. Install with: brew install webp" >&2; exit 1; }
  command -v avifenc >/dev/null 2>&1 || { echo "avifenc not found. Install with: brew install libavif" >&2; exit 1; }
fi

convert_gif() {
  local gif="$1"
  local base="${gif%.*}"
  local mp4="${base}.mp4"
  local webm="${base}.webm"
  local jpg="${base}.jpg"

  local need_any=false

  if [[ ! -f "$mp4" || "$gif" -nt "$mp4" ]]; then
    echo "→ MP4: $gif -> $mp4"
    ffmpeg -y -i "$gif" \
      -movflags +faststart \
      -pix_fmt yuv420p \
      -vf "fps=30,scale=trunc(iw/2)*2:trunc(ih/2)*2" \
      -c:v libx264 -preset medium -crf 23 \
      "$mp4"
    need_any=true
  fi

  if [[ ! -f "$webm" || "$gif" -nt "$webm" ]]; then
    echo "→ WebM: $gif -> $webm"
    ffmpeg -y -i "$gif" \
      -pix_fmt yuv420p \
      -vf "fps=30,scale=trunc(iw/2)*2:trunc(ih/2)*2" \
      -c:v libvpx-vp9 -b:v 0 -crf 32 \
      "$webm"
    need_any=true
  fi

  if [[ ! -f "$jpg" || "$gif" -nt "$jpg" ]]; then
    echo "→ Poster JPG: $gif -> $jpg"
    ffmpeg -y -i "$gif" -frames:v 1 "$jpg"
    need_any=true
  fi

  if [[ "$need_any" == false ]]; then
    echo "✓ Skip (up-to-date): $gif"
  fi
}

convert_raster() {
  local file="$1"
  local base="${file%.*}"
  local webp="${base}.webp"
  local avif="${base}.avif"

  local did=false

  if [[ ! -f "$webp" || "$file" -nt "$webp" ]]; then
    echo "→ WebP: $file -> $webp"
    cwebp -quiet -q 82 "$file" -o "$webp"
    did=true
  fi
  if [[ ! -f "$avif" || "$file" -nt "$avif" ]]; then
    echo "→ AVIF: $file -> $avif"
    # Use broadly compatible flags; fallback to defaults if unsupported
    if ! avifenc -q 28 --speed 6 --jobs 4 "$file" "$avif" >/dev/null 2>&1; then
      avifenc "$file" "$avif" >/dev/null
    fi
    did=true
  fi

  if [[ "$did" == false ]]; then
    echo "✓ Skip (up-to-date): $file"
  fi
}

echo "Converting GIF animations (if any)..."
for gif in "${gif_list[@]}"; do
  convert_gif "$gif"
done

echo "Converting JPG/PNG images to WebP/AVIF (if any)..."
for file in "${jpgpng_list[@]}"; do
  convert_raster "$file"
done

popd >/dev/null
echo "Media conversion completed."

