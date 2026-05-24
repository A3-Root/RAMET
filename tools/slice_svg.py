"""Slice a monolithic ocap-renderterrain SVG into per-class layer SVGs.

Keys on the documented colorMainRoads / colorSea / colorForest / etc palette.
Each output keeps the original <svg> wrapper (so viewBox + transforms stay)
and contains only the elements whose computed colour matches that class.
"""

from __future__ import annotations

import argparse
import gzip
import re
from pathlib import Path

try:
    from lxml import etree
except ImportError:  # pragma: no cover
    etree = None  # type: ignore

# Color palette pulled from ocap-renderterrain renderer defaults.
# Hex values are matched case-insensitively against both `fill` / `stroke`
# attributes and inline CSS within `style="..."`.
PALETTE = {
    "roads_main": ["#dbab37", "#d4a72c", "#caa648"],
    "roads":      ["#ffffff", "#fefefe"],
    "tracks":     ["#a0a0a0", "#9c9c9c", "#8e8e8e"],
    "trails":     ["#888888", "#808080"],
    "water":      ["#80b9ce", "#7fb6cb", "#a4c8d8"],
    "forest":     ["#85b66f", "#7da963", "#a5cf8f"],
    "rocks":      ["#5e5e5e", "#666666"],
    "rails":      ["#202020", "#1c1c1c"],
    "land":       ["#f2eedb", "#efe9d3"],
}

CLASS_LABEL = {
    "roads_main": "Main Roads",
    "roads": "Roads",
    "tracks": "Tracks",
    "trails": "Trails",
    "water": "Water",
    "forest": "Forest",
    "rocks": "Rocks",
    "rails": "Rails",
    "land": "Land",
}

COLOR_RE = re.compile(r"#[0-9A-Fa-f]{6}|#[0-9A-Fa-f]{3}")


def _normalise(hex_str: str) -> str:
    h = hex_str.lower().lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    return "#" + h


def _element_colors(el) -> set[str]:
    colors: set[str] = set()
    for attr in ("fill", "stroke"):
        v = el.get(attr)
        if v and v != "none":
            for m in COLOR_RE.findall(v):
                colors.add(_normalise(m))
    style = el.get("style")
    if style:
        for m in COLOR_RE.findall(style):
            colors.add(_normalise(m))
    return colors


def slice_svg(svg_path: Path, out_dir: Path) -> dict:
    if etree is None:
        raise RuntimeError("lxml not installed; install lxml to run slice_svg")
    out_dir.mkdir(parents=True, exist_ok=True)

    if svg_path.suffix == ".gz":
        with gzip.open(svg_path, "rb") as fp:
            tree = etree.parse(fp)
    else:
        tree = etree.parse(str(svg_path))

    root = tree.getroot()
    nsmap = root.nsmap.copy()
    default_ns = nsmap.get(None, "http://www.w3.org/2000/svg")

    palette_norm = {cls: [_normalise(h) for h in hexes] for cls, hexes in PALETTE.items()}

    results: dict[str, dict] = {}
    for cls, allowed in palette_norm.items():
        allowed_set = set(allowed)
        # build a copy and prune
        new_root = etree.fromstring(etree.tostring(root))
        # walk depth-first, drop visual leaves that don't match
        drops = []
        for el in new_root.iter():
            tag = etree.QName(el).localname
            if tag in {"svg", "g", "defs", "metadata", "title", "desc", "style"}:
                continue
            if not _element_colors(el).intersection(allowed_set):
                drops.append(el)
        for el in drops:
            parent = el.getparent()
            if parent is not None:
                parent.remove(el)

        # gzip output
        out_path = out_dir / f"{cls}.svg.gz"
        data = etree.tostring(new_root, xml_declaration=True, encoding="utf-8")
        with gzip.open(out_path, "wb") as fp:
            fp.write(data)
        results[cls] = {
            "path": str(out_path.relative_to(out_dir.parent.parent)) if out_dir.parent.parent in out_path.parents else str(out_path),
            "label": CLASS_LABEL[cls],
            "bytes": out_path.stat().st_size,
        }
    return results


def main() -> int:
    ap = argparse.ArgumentParser(description="Slice ocap-rt SVG by colour palette")
    ap.add_argument("--in", dest="svg", required=True, help="input SVG (may be .gz)")
    ap.add_argument("--out", dest="out", required=True, help="output dir for layer SVGs")
    args = ap.parse_args()
    results = slice_svg(Path(args.svg), Path(args.out))
    for cls, meta in results.items():
        print(f"  {cls:12s} {meta['bytes']/1024:8.1f} KiB  {meta['path']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
