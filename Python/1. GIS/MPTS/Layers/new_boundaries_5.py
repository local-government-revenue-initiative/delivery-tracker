"""
Convert all GeoPackage files to Shapefiles
Author: Robin Benabid Jegaden
Date: 2025-11-13
Purpose: Batch convert .gpkg to .shp format
"""

import geopandas as gpd
from pathlib import Path
import os

# Define paths
input_dir = Path(r"D:\LoGRI Dropbox\Robin Benabid Jegaden\LoGRI\Sierra_Leone\data\2_Build\new_boundaries\Freetown\final")
output_dir = Path(r"D:\LoGRI Dropbox\Robin Benabid Jegaden\LoGRI\Sierra_Leone\data\3_Final\new_boundaries\Freetown")

# Create output directory if it doesn't exist
os.makedirs(output_dir, exist_ok=True)

print("=" * 80)
print("GEOPACKAGE TO SHAPEFILE CONVERSION")
print("=" * 80)
print(f"\nInput directory:  {input_dir}")
print(f"Output directory: {output_dir}")

# Find all .gpkg files
gpkg_files = list(input_dir.glob("*.gpkg"))
print(f"\nFound {len(gpkg_files)} GeoPackage file(s) to convert")

# Track statistics
stats = {
    'total': len(gpkg_files),
    'success': 0,
    'failed': 0
}

# Convert each file
for idx, gpkg_file in enumerate(gpkg_files, 1):
    
    layer_name = gpkg_file.stem
    
    print(f"\n[{idx}/{len(gpkg_files)}] Processing: {layer_name}")
    
    try:
        # Read GeoPackage
        gdf = gpd.read_file(gpkg_file)
        print(f"   ✓ Loaded: {len(gdf)} features")
        print(f"   CRS: {gdf.crs}")
        
        # Ensure CRS is EPSG:4326
        if gdf.crs != "EPSG:4326":
            print(f"   🔄 Reprojecting to EPSG:4326")
            gdf = gdf.to_crs("EPSG:4326")
        
        # Create output path
        output_shp = output_dir / f"{layer_name}.shp"
        
        # Export to Shapefile
        gdf.to_file(output_shp, driver="ESRI Shapefile")
        
        print(f"   ✓ Saved: {layer_name}.shp")
        print(f"   Files created:")
        print(f"      - {layer_name}.shp")
        print(f"      - {layer_name}.shx")
        print(f"      - {layer_name}.dbf")
        print(f"      - {layer_name}.prj")
        
        stats['success'] += 1
        
    except Exception as e:
        print(f"   ✗ Error: {str(e)}")
        stats['failed'] += 1

# ========================================
# SUMMARY
# ========================================
print("\n" + "=" * 80)
print("CONVERSION SUMMARY")
print("=" * 80)
print(f"📁 Total files: {stats['total']}")
print(f"✓ Successfully converted: {stats['success']}")
print(f"✗ Failed: {stats['failed']}")
print(f"\n📂 Shapefiles saved to: {output_dir}")
print("=" * 80)