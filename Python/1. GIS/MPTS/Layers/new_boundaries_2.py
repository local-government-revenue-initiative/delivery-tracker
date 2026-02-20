"""
Rename and modify GeoPackage files
Author: Robin Benabid Jegaden
Date: 2025-11-13
Purpose: Apply specific renaming and column modifications to individual files
"""

import geopandas as gpd
from pathlib import Path
import os

# Define paths
data_dir = Path(r"D:\LoGRI Dropbox\Robin Benabid Jegaden\LoGRI\Sierra_Leone\data\2_Build\new_boundaries\Freetown")

print("=" * 80)
print("LAYER RENAMING AND MODIFICATION")
print("=" * 80)

# ========================================
# 1. Aberdeen_Lumley_Tourist_District.gpkg
# ========================================
print("\n1. Processing: Aberdeen_Lumley_Tourist_District.gpkg")
old_file = data_dir / "Aberdeen_Lumley_Tourist_District.gpkg"
new_file = data_dir / "Aberdeen Lumley Tourist District.gpkg"

if old_file.exists():
    os.rename(old_file, new_file)
    print("   ✓ Renamed to: Aberdeen Lumley Tourist District.gpkg")
else:
    print("   ⚠️ File not found")

# ========================================
# 2. Buffered Commercial Corridors.gpkg
# ========================================
print("\n2. Processing: Buffered Commercial Corridors.gpkg")
old_file = data_dir / "Buffered Commercial Corridors.gpkg"
new_file = data_dir / "Commercial Corridors.gpkg"

if old_file.exists():
    # Read file
    gdf = gpd.read_file(old_file)
    print(f"   ✓ Loaded: {len(gdf)} features")
    print(f"   Current columns: {list(gdf.columns)}")
    
    # Rename column Street → Corridor
    if "Street" in gdf.columns:
        gdf = gdf.rename(columns={"Street": "Corridor"})
        print("   ✓ Renamed column: Street → Corridor")
    elif "street" in gdf.columns:
        gdf = gdf.rename(columns={"street": "Corridor"})
        print("   ✓ Renamed column: street → Corridor")
    
    # Delete id column if exists
    if "id" in gdf.columns:
        gdf = gdf.drop(columns=["id"])
        print("   ✓ Deleted column: id")
    
    # Assign specific corridor names to fid 1-6
    corridor_names = [
        "Congo Cross - Lumley",
        "Sanders - Campbell Streets",
        "Kissy Road - Bai Bureh Roads",
        "Bai Bureh Road (Allen Town section)",
        "Kroo Town Road",
        "Fourah Bay Road"
    ]
    
    if len(gdf) == 6:
        # Sort by fid to ensure correct assignment
        if "fid" in gdf.columns:
            gdf = gdf.sort_values("fid").reset_index(drop=True)
        gdf['Corridor'] = corridor_names
        print("   ✓ Assigned corridor names to features 1-6")
        for i, name in enumerate(corridor_names, 1):
            print(f"      {i}. {name}")
    else:
        print(f"   ⚠️ Expected 6 features, found {len(gdf)}")
    
    # Save with new name
    gdf.to_file(new_file, driver="GPKG")
    print(f"   ✓ Saved as: Commercial Corridors.gpkg")
    
    # Delete old file
    old_file.unlink()
    print("   ✓ Deleted old file")
else:
    print("   ⚠️ File not found")

# ========================================
# 3. CBD.gpkg
# ========================================
print("\n3. Processing: CBD.gpkg")
old_file = data_dir / "CBD.gpkg"
new_file = data_dir / "Central Business District.gpkg"

if old_file.exists():
    os.rename(old_file, new_file)
    print("   ✓ Renamed to: Central Business District.gpkg")
else:
    print("   ⚠️ File not found")

# ========================================
# 4. Dock and Industrial area.gpkg
# ========================================
print("\n4. Processing: Dock and Industrial area.gpkg")
old_file = data_dir / "Dock and Industrial area.gpkg"
new_file = data_dir / "Dock Industrial Area.gpkg"

if old_file.exists():
    os.rename(old_file, new_file)
    print("   ✓ Renamed to: Dock Industrial Area.gpkg")
else:
    print("   ⚠️ File not found")

# ========================================
# 5. Juba_Levuma_Tourist_District.gpkg
# ========================================
print("\n5. Processing: Juba_Levuma_Tourist_District.gpkg")
old_file = data_dir / "Juba_Levuma_Tourist_District.gpkg"
new_file = data_dir / "Juba Levuma Tourist District.gpkg"

if old_file.exists():
    os.rename(old_file, new_file)
    print("   ✓ Renamed to: Juba Levuma Tourist District.gpkg")
else:
    print("   ⚠️ File not found")

# ========================================
# 6. Hazardeous Zones.gpkg
# ========================================
print("\n6. Processing: Hazardeous Zones.gpkg")
hazard_file = data_dir / "Hazardeous Zones.gpkg"

if hazard_file.exists():
    gdf = gpd.read_file(hazard_file)
    print(f"   ✓ Loaded: {len(gdf)} features")
    print(f"   Current columns: {list(gdf.columns)}")
    
    # Create Zone column with entity names
    zone_names = [
        "Kingtom Dumpsite Zone",
        "Ferry junction Dumpsite Zone"
    ]
    
    if len(gdf) == 2:
        # Sort by fid to ensure correct assignment
        if "fid" in gdf.columns:
            gdf = gdf.sort_values("fid").reset_index(drop=True)
        gdf['Zone'] = zone_names
        print("   ✓ Created column: Zone")
        print("   ✓ Assigned zone names:")
        for i, name in enumerate(zone_names, 1):
            print(f"      {i}. {name}")
    else:
        print(f"   ⚠️ Expected 2 features, found {len(gdf)}")
        gdf['Zone'] = None
    
    # Save
    gdf.to_file(hazard_file, driver="GPKG")
    print("   ✓ Saved changes")
else:
    print("   ⚠️ File not found")

# ========================================
# 7. Informal Settlements.gpkg
# ========================================
print("\n7. Processing: Informal Settlements.gpkg")
informal_file = data_dir / "Informal Settlements.gpkg"

if informal_file.exists():
    gdf = gpd.read_file(informal_file)
    print(f"   ✓ Loaded: {len(gdf)} features")
    print(f"   Current columns: {list(gdf.columns)}")
    
    # Create Settlement column with entity names
    settlement_names = [
        "Back of Kissy Brook",
        "Bobo Kombo - Kroo Bay",
        "Susan's Bay - Big Wharf",
        "Congo Valley - Back of Stadium"
    ]
    
    if len(gdf) == 4:
        # Sort by fid to ensure correct assignment
        if "fid" in gdf.columns:
            gdf = gdf.sort_values("fid").reset_index(drop=True)
        gdf['Settlement'] = settlement_names
        print("   ✓ Created column: Settlement")
        print("   ✓ Assigned settlement names:")
        for i, name in enumerate(settlement_names, 1):
            print(f"      {i}. {name}")
    else:
        print(f"   ⚠️ Expected 4 features, found {len(gdf)}")
        gdf['Settlement'] = None
    
    # Save
    gdf.to_file(informal_file, driver="GPKG")
    print("   ✓ Saved changes")
else:
    print("   ⚠️ File not found")

# ========================================
# SUMMARY
# ========================================
print("\n" + "=" * 80)
print("MODIFICATIONS COMPLETE")
print("=" * 80)
print("\nFiles modified:")
print("  1. ✓ Aberdeen Lumley Tourist District.gpkg")
print("  2. ✓ Commercial Corridors.gpkg")
print("     - Street → Corridor")
print("     - Deleted column: id")
print("     - Assigned 6 corridor names")
print("  3. ✓ Central Business District.gpkg")
print("  4. ✓ Dock Industrial Area.gpkg")
print("  5. ✓ Juba Levuma Tourist District.gpkg")
print("  6. ✓ Hazardeous Zones.gpkg")
print("     - Created column: Zone")
print("     - Assigned 2 zone names")
print("  7. ✓ Informal Settlements.gpkg")
print("     - Created column: Settlement")
print("     - Assigned 4 settlement names")
print("=" * 80)