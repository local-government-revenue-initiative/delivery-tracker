"""
Reproject all GeoPackage files to EPSG:4326
Author: Robin Benabid Jegaden
Date: 2025-11-13
Purpose: Batch reproject .gpkg files from raw to build directory
"""

import os
from pathlib import Path
import geopandas as gpd

# Define paths
input_dir = r"D:\LoGRI Dropbox\Robin Benabid Jegaden\LoGRI\Sierra_Leone\data\1_Raw\new_boundaries\Freetown\Revised_GIS Layers FCC\Revised_GIS_layers"
output_dir = r"D:\LoGRI Dropbox\Robin Benabid Jegaden\LoGRI\Sierra_Leone\data\2_Build\new_boundaries\Freetown"

# Create output directory if it doesn't exist
os.makedirs(output_dir, exist_ok=True)

# Target CRS
target_crs = "EPSG:4326"

# Find all .gpkg files
gpkg_files = list(Path(input_dir).glob("*.gpkg"))

print(f"Found {len(gpkg_files)} GeoPackage file(s) to process\n")

# Process each file
for gpkg_file in gpkg_files:
    try:
        print(f"Processing: {gpkg_file.name}")
        
        # Read the GeoPackage
        gdf = gpd.read_file(gpkg_file)
        
        # Get original CRS
        original_crs = gdf.crs
        print(f"  Original CRS: {original_crs}")
        
        # Check if reprojection is needed
        if gdf.crs != target_crs:
            # Reproject to EPSG:4326
            gdf = gdf.to_crs(target_crs)
            print(f"  Reprojected to: {target_crs}")
        else:
            print(f"  Already in {target_crs}, no reprojection needed")
        
        # Define output path
        output_path = Path(output_dir) / gpkg_file.name
        
        # Save reprojected file
        gdf.to_file(output_path, driver="GPKG")
        print(f"  Saved to: {output_path}")
        print(f"  Features: {len(gdf)}\n")
        
    except Exception as e:
        print(f"  ERROR processing {gpkg_file.name}: {str(e)}\n")

print("Processing complete!")