"""
Convert GeoPackage to Zipped Shapefile
Author: Robin Benabid Jegaden
Date: 2025-11-13
Purpose: Export GeoPackage to zipped Shapefile (EPSG:4326, selected columns only)
"""

import geopandas as gpd
from pathlib import Path
import zipfile
import os

# Define paths
input_file = Path(r"D:\LoGRI Dropbox\Robin Benabid Jegaden\LoGRI\Sierra_Leone\data\3_Final\new_boundaries\Freetown\revised_STA_boundaries.gpkg")
output_dir = input_file.parent
output_name = input_file.stem

print("=" * 60)
print("GEOPACKAGE TO ZIPPED SHAPEFILE CONVERSION")
print("=" * 60)

# Read the GeoPackage
print(f"\nReading: {input_file.name}")
gdf = gpd.read_file(input_file)

print(f"✓ Loaded successfully")
print(f"  Features: {len(gdf)}")
print(f"  Original CRS: {gdf.crs}")
print(f"  Columns: {list(gdf.columns)}")

# Check if required columns exist
required_cols = ['fid', 'source_file']
missing_cols = [col for col in required_cols if col not in gdf.columns]

if missing_cols:
    print(f"\n⚠️ Warning: Missing columns: {missing_cols}")
    print("Available columns:", list(gdf.columns))
    
    # If 'fid' is missing, create it
    if 'fid' in missing_cols:
        print("Creating 'fid' column with sequential numbers...")
        gdf['fid'] = range(1, len(gdf) + 1)
        missing_cols.remove('fid')
    
    if missing_cols:
        print(f"\n❌ Cannot proceed: {missing_cols} column(s) still missing")
        exit()

# Select only fid, source_file, and geometry
print(f"\n✓ Selecting columns: fid, source_file, geometry")
gdf_subset = gdf[['fid', 'source_file', 'geometry']].copy()

# Reproject to EPSG:4326 if needed
target_crs = "EPSG:4326"
if gdf_subset.crs != target_crs:
    print(f"\n🔄 Reprojecting from {gdf_subset.crs} to {target_crs}")
    gdf_subset = gdf_subset.to_crs(target_crs)
    print(f"✓ Reprojected to {target_crs}")
else:
    print(f"\n✓ Already in {target_crs}")

# Create temporary directory for shapefile components
temp_dir = output_dir / "temp_shp"
temp_dir.mkdir(exist_ok=True)

# Export to Shapefile
temp_shp = temp_dir / f"{output_name}.shp"
print(f"\nExporting to temporary shapefile...")
gdf_subset.to_file(temp_shp, driver="ESRI Shapefile")
print(f"✓ Shapefile created")

# Create zipped shapefile
zip_path = output_dir / f"{output_name}.zip"
print(f"\n📦 Creating zipped shapefile: {zip_path.name}")

with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
    # Add all shapefile components
    for ext in ['.shp', '.shx', '.dbf', '.prj', '.cpg']:
        file_path = temp_dir / f"{output_name}{ext}"
        if file_path.exists():
            zipf.write(file_path, file_path.name)
            print(f"  ✓ Added: {file_path.name}")

# Clean up temporary directory
print(f"\n🧹 Cleaning up temporary files...")
for file in temp_dir.glob(f"{output_name}.*"):
    file.unlink()
temp_dir.rmdir()

print(f"\n✅ SUCCESS!")
print("=" * 60)
print(f"📦 Zipped shapefile: {zip_path.name}")
print(f"📂 Location: {output_dir}")
print(f"📊 Features: {len(gdf_subset)}")
print(f"🗺️  CRS: {target_crs}")
print(f"📋 Columns: fid, source_file")
print("=" * 60)


