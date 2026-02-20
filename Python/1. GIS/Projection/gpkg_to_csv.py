"""
Convert GeoPackage (.gpkg) back to CSV with WKB hex geometry in 'geom' column.
Defaults (change if needed):
- input : D:\LoGRI Dropbox\LoGRI Master Folder\2. Projects\2. Country Projects\9. Sierra Leone\12. Data\2. Build\map_update\Freetown\freetown_georeferenced_rooftops.gpkg
- output: D:\LoGRI Dropbox\LoGRI Master Folder\2. Projects\2. Country Projects\9. Sierra Leone\12. Data\3. Final\map_update\Freetown\freetown_georeferenced_rooftops.csv
- layer : rooftops_kenema
"""
import argparse
from pathlib import Path
import pandas as pd
import geopandas as gpd

# --- Defaults ---
DEFAULT_INPUT = r"D:\LoGRI Dropbox\LoGRI Master Folder\2. Projects\2. Country Projects\9. Sierra Leone\12. Data\2. Build\map_update\Freetown\freetown_polygons_04_02_2026_georef.gpkg"
DEFAULT_OUTPUT = r"D:\LoGRI Dropbox\LoGRI Master Folder\2. Projects\2. Country Projects\9. Sierra Leone\12. Data\3. Final\map_update\Freetown\freetown_polygons_04_02_2026_georef.csv"
DEFAULT_LAYER = "freetown_polygons_04_02_2026_modified"

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", "-i", default=DEFAULT_INPUT, help="Path to input GPKG")
    ap.add_argument("--output", "-o", default=DEFAULT_OUTPUT, help="Path to output CSV")
    ap.add_argument("--layer", "-l", default=DEFAULT_LAYER, help="Layer name to read from GPKG")
    args = ap.parse_args()
    
    in_path = Path(args.input)
    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    
    print(f"Reading GeoPackage: {in_path} (layer: {args.layer})")
    gdf = gpd.read_file(in_path, layer=args.layer)
    
    print("Converting geometries to WKB hex...")
    geom_hex = gdf.geometry.apply(lambda g: g.wkb_hex if g is not None else None)
    
    # Create DataFrame with 'geom' column
    df = pd.DataFrame(gdf.drop(columns='geometry'))
    df['geom'] = geom_hex
    
    print(f"Writing CSV: {out_path}")
    df.to_csv(out_path, index=False)
    
    print(f"✅ Done. Exported {len(df)} rows to CSV.")

if __name__ == "__main__":
    main()
