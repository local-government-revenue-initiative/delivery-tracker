"""
Merge layers into new GeoPackage files
Author: Robin Benabid Jegaden
Date: 2025-11-13
Purpose: Create Industrial Areas and Tourist Districts merged files
"""

import geopandas as gpd
import pandas as pd
from pathlib import Path

# Define paths
data_dir = Path(r"D:\LoGRI Dropbox\Robin Benabid Jegaden\LoGRI\Sierra_Leone\data\2_Build\new_boundaries\Freetown")

print("=" * 80)
print("MERGING LAYERS")
print("=" * 80)

# ========================================
# 1. INDUSTRIAL AREAS
# ========================================
print("\n1. Creating: Industrial Areas.gpkg")

industrial_layers = [
    "Dock Industrial Area",
    "Wellington Industrial Estate",
    "Kissy Industrial Area",
    "Kissy Texaco Terminal Area",
    "Grassfield Industrial Area"
]

gdfs_industrial = []
for layer_name in industrial_layers:
    file_path = data_dir / f"{layer_name}.gpkg"
    if file_path.exists():
        gdf = gpd.read_file(file_path)
        gdf['source_layer'] = layer_name
        gdfs_industrial.append(gdf)
        print(f"   ✓ Added: {layer_name} ({len(gdf)} features)")
    else:
        print(f"   ⚠️ Not found: {layer_name}")

if gdfs_industrial:
    # Merge all
    merged_industrial = gpd.GeoDataFrame(
        pd.concat(gdfs_industrial, ignore_index=True),
        crs=gdfs_industrial[0].crs
    )
    
    # Add id
    merged_industrial['id'] = range(1, len(merged_industrial) + 1)
    
    # Save
    output_file = data_dir / "Industrial Areas.gpkg"
    merged_industrial.to_file(output_file, layer="Industrial Areas", driver="GPKG")
    
    print(f"\n   ✓ Created: Industrial Areas.gpkg")
    print(f"   Total features: {len(merged_industrial)}")
    print(f"   Columns: {list(merged_industrial.columns)}")
else:
    print("\n   ✗ No layers found to merge")

# ========================================
# 2. TOURIST DISTRICTS
# ========================================
print("\n2. Creating: Tourist Districts.gpkg")

tourist_layers = [
    "Aberdeen Lumley Tourist District",
    "Juba Levuma Tourist District"
]

gdfs_tourist = []
for layer_name in tourist_layers:
    file_path = data_dir / f"{layer_name}.gpkg"
    if file_path.exists():
        gdf = gpd.read_file(file_path)
        gdf['source_layer'] = layer_name
        gdfs_tourist.append(gdf)
        print(f"   ✓ Added: {layer_name} ({len(gdf)} features)")
    else:
        print(f"   ⚠️ Not found: {layer_name}")

if gdfs_tourist:
    # Merge all
    merged_tourist = gpd.GeoDataFrame(
        pd.concat(gdfs_tourist, ignore_index=True),
        crs=gdfs_tourist[0].crs
    )
    
    # Add id
    merged_tourist['id'] = range(1, len(merged_tourist) + 1)
    
    # Save
    output_file = data_dir / "Tourist Districts.gpkg"
    merged_tourist.to_file(output_file, layer="Tourist Districts", driver="GPKG")
    
    print(f"\n   ✓ Created: Tourist Districts.gpkg")
    print(f"   Total features: {len(merged_tourist)}")
    print(f"   Columns: {list(merged_tourist.columns)}")
else:
    print("\n   ✗ No layers found to merge")

# ========================================
# SUMMARY
# ========================================
print("\n" + "=" * 80)
print("MERGE COMPLETE")
print("=" * 80)
print("\nNew files created:")
print("  1. ✓ Industrial Areas.gpkg")
print("     - 5 industrial areas merged")
print("     - Added columns: source_layer, id")
print("\n  2. ✓ Tourist Districts.gpkg")
print("     - 2 tourist districts merged")
print("     - Added columns: source_layer, id")
print("=" * 80)
