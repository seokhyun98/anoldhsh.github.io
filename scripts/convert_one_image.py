import argparse
import os
from pathlib import Path


def _needs_update(src: Path, dst: Path) -> bool:
    if not dst.exists():
        return True
    return src.stat().st_mtime > dst.stat().st_mtime


def main() -> int:
    parser = argparse.ArgumentParser(description="Convert one image to WebP and AVIF (idempotent).")
    parser.add_argument("src", help="Source image path (jpg/png/jpeg).")
    parser.add_argument("--webp-quality", type=int, default=82)
    parser.add_argument("--avif-quality", type=int, default=45)
    args = parser.parse_args()

    src = Path(args.src)
    if not src.exists():
        raise FileNotFoundError(f"Source not found: {src}")

    # Register AVIF support for Pillow (provided by pillow-avif-plugin).
    try:
        import pillow_avif  # noqa: F401
    except Exception as e:
        raise RuntimeError(
            "AVIF support is not available. Install pillow-avif-plugin in this environment."
        ) from e

    from PIL import Image

    base = src.with_suffix("")
    webp = base.with_suffix(".webp")
    avif = base.with_suffix(".avif")

    with Image.open(src) as im:
        im = im.convert("RGB")

        if _needs_update(src, webp):
            webp.parent.mkdir(parents=True, exist_ok=True)
            im.save(webp, format="WEBP", quality=int(args.webp_quality), method=6)
            print(f"Wrote: {webp}")
        else:
            print(f"Up-to-date: {webp}")

        if _needs_update(src, avif):
            avif.parent.mkdir(parents=True, exist_ok=True)
            # pillow-avif-plugin uses 'quality' 0-100.
            im.save(avif, format="AVIF", quality=int(args.avif_quality), speed=6)
            print(f"Wrote: {avif}")
        else:
            print(f"Up-to-date: {avif}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

