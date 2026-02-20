# -*- coding: utf-8 -*-
"""
Created on Fri Nov 14 17:14:10 2025

@author: robin
"""

"""
Rename layer names inside GeoPackage files
Author: Robin Benabid Jegaden
Date: 2025-11-13
Purpose: Change internal layer names in GeoPackage files
"""

import geopandas as gpd
from pathlib import Path
import os
import sqlite3

# Define paths
data_dir = Path(r"D:\LoGRI Dropbox\Robin Benabid Jegaden\LoGRI\Sierra_Leone\data\2_Build\new_boundaries\Freetown")

print("=" * 80)
print("LAYER NAME MODIFICATION (INTERNAL LAYER NAMES)")
print("=" * 80)

def rename_layer_in_gpkg(gpkg_path, new_layer_name):
    """
    Rename the internal layer name in a GeoPackage file
    """
    # Read the data
    gdf = gpd.read_file(gpkg_path)
    
    # Delete the original file
    gpkg_path.unlink()
    
    # Save with new layer name
    gdf.to_file(gpkg_path, layer=new_layer_name, driver="GPKG")
    
    return len(gdf)

# ========================================
# 1. Aberdeen Lumley Tourist District
# ========================================
print("\n1. Processing: Aberdeen Lumley Tourist District.gpkg")
file_path = data_dir / "Aberdeen Lumley Tourist District.gpkg"

if file_path.exists():
    count = rename_layer_in_gpkg(file_path, "Aberdeen Lumley Tourist District")
    print(f"   ✓ Layer renamed to: Aberdeen Lumley Tourist District")
    print(f"   Features: {count}")
else:
    print("   ⚠️ File not found")

# ========================================
# 2. Dock Industrial Area
# ========================================
print("\n2. Processing: Dock Industrial Area.gpkg")
file_path = data_dir / "Dock Industrial Area.gpkg"

if file_path.exists():
    count = rename_layer_in_gpkg(file_path, "Dock Industrial Area")
    print(f"   ✓ Layer renamed to: Dock Industrial Area")
    print(f"   Features: {count}")
else:
    print("   ⚠️ File not found")

# ========================================
# 3. Juba Levuma Tourist District
# ========================================
print("\n3. Processing: Juba Levuma Tourist District.gpkg")
file_path = data_dir / "Juba Levuma Tourist District.gpkg"

if file_path.exists():
    count = rename_layer_in_gpkg(file_path, "Juba Levuma Tourist District")
    print(f"   ✓ Layer renamed to: Juba Levuma Tourist District")
    print(f"   Features: {count}")
else:
    print("   ⚠️ File not found")

# ========================================
# 4. Central Business District
# ========================================
print("\n4. Processing: Central Business District.gpkg")
file_path = data_dir / "Central Business District.gpkg"

if file_path.exists():
    count = rename_layer_in_gpkg(file_path, "Central Business District")
    print(f"   ✓ Layer renamed to: Central Business District")
    print(f"   Features: {count}")
else:
    print("   ⚠️ File not found")

# ========================================
# SUMMARY
# ========================================
print("\n" + "=" * 80)
print("LAYER NAME MODIFICATIONS COMPLETE")
print("=" * 80)
print("\nInternal layer names changed:")
print("  1. ✓ Aberdeen Lumley Tourist District")
print("  2. ✓ Dock Industrial Area")
print("  3. ✓ Juba Levuma Tourist District")
print("  4. ✓ Central Business District")
print("\n📝 Note: Layer names are now clean (without underscores or hyphens)")
print("=" * 80)