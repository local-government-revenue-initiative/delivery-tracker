"""
Convert /FreetownKenema rooftop CSV (EWKB hex in 'geom') to GeoPackage (.gpkg).

Defaults (change if needed):
- input : D:\LoGRI Dropbox\Robin Benabid Jegaden\LoGRI\Sierra_Leone\data\1_Raw\map_update\Freetown\freetown_polygons_04_02_2026.csv
- output: D:\LoGRI Dropbox\Robin Benabid Jegaden\LoGRI\Sierra_Leone\data\2_Build\map_update\Freetown\freetown_polygons_04_02_2026.gpkg
- layer : rooftops_kenema
"""

import argparse
from pathlib import Path
import pandas as pd
import geopandas as gpd
from shapely import wkb, wkt
from shapely.errors import ShapelyError

# --- Defaults for your setup ---
DEFAULT_INPUT = r"D:\LoGRI Dropbox\LoGRI Master Folder\2. Projects\2. Country Projects\9. Sierra Leone\12. Data\1. Raw\map_update\Freetown\freetown_polygons_04_02_2026.csv"
DEFAULT_OUTPUT = r"D:\LoGRI Dropbox\LoGRI Master Folder\2. Projects\2. Country Projects\9. Sierra Leone\12. Data\2. Build\map_update\Freetown\freetown_polygons_04_02_2026.gpkg"
DEFAULT_LAYER = "rooftops_freetown"

def parse_geom(val: str):
    """Parse geometry that may be EWKB/WKB hex (e.g. 0106000020E610...) or WKT."""
    if not isinstance(val, str):
        return None
    s = val.strip()

    # Try hex WKB/EWKB
    try:
        if all(c in "0123456789ABCDEFabcdef" for c in s) and len(s) >= 10 and s[:2] in ("01", "00"):
            return wkb.loads(s, hex=True)
    except (ShapelyError, ValueError):
        pass

    # Fallback to WKT
    try:
        return wkt.loads(s)
    except (ShapelyError, ValueError):
        return None

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", "-i", default=DEFAULT_INPUT, help="Path to input CSV")
    ap.add_argument("--output", "-o", default=DEFAULT_OUTPUT, help="Path to output GPKG")
    ap.add_argument("--layer", "-l", default=DEFAULT_LAYER, help="Layer name inside the GPKG")
    args = ap.parse_args()

    in_path = Path(args.input)
    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    print(f"Reading CSV: {in_path}")
    # Let pandas infer delimiter; handles comma or tab
    df = pd.read_csv(in_path, sep=None, engine="python")

    if "geom" not in df.columns:
        raise SystemExit("ERROR: 'geom' column not found in the CSV.")

    print("Parsing geometries from 'geom'…")
    geom = df["geom"].apply(parse_geom)

    print("Building GeoDataFrame with EPSG:4326…")
    gdf = gpd.GeoDataFrame(df.drop(columns=["geom"]), geometry=geom, crs="EPSG:4326")

    if "area" in gdf.columns:
        gdf["area"] = pd.to_numeric(gdf["area"], errors="coerce")

    # Drop rows with invalid geometry
    bad_mask = gdf.geometry.isna()
    if bad_mask.any():
        dropped_all = df.loc[bad_mask].copy()
        print(f"Note: dropping {bad_mask.sum()} rows with invalid geometry.")

        # Fichier CSV complet (toutes colonnes)
        dropped_csv = out_path.with_name(out_path.stem + "_dropped.csv")
        dropped_all.to_csv(dropped_csv, index=False)
        print(f"❗ Dropped rows saved to: {dropped_csv}")

    # Keep only valid geometries
    gdf = gdf[~bad_mask].copy()

    # Optional repair for invalid polygons/multipolygons
    gdf["geometry"] = gdf.geometry.buffer(0)

    if gdf.empty:
        raise SystemExit("ERROR: No valid geometries parsed from 'geom'.")

    print(f"Writing {len(gdf)} features to: {out_path} (layer: {args.layer})")
    gdf.to_file(out_path, layer=args.layer, driver="GPKG")
    print("✅ Done.")

if __name__ == "__main__":
    main()