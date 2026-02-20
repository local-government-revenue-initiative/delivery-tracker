"""
Clean, rename, and merge GeoPackage layers
Author: Robin Benabid Jegaden
Date: 2025-11-13
Purpose: Process individual ward boundary layers with renaming and merging
"""

import geopandas as gpd
import pandas as pd
from pathlib import Path
import os

# Define paths
input_dir = Path(r"D:\LoGRI Dropbox\Robin Benabid Jegaden\LoGRI\Sierra_Leone\data\1_Raw\new_boundaries\Freetown\Revised_GIS Layers FCC\Revised_GIS_layers")
output_dir = Path(r"D:\LoGRI Dropbox\Robin Benabid Jegaden\LoGRI\Sierra_Leone\data\3_Final\new_boundaries\Freetown")

# Create output directory if it doesn't exist
os.makedirs(output_dir, exist_ok=True)

print("=" * 60)
print("LAYER CLEANING, RENAMING, AND MERGING WORKFLOW")
print("=" * 60)

# ========================================
# A. LAYER NAME MAPPINGS
# ========================================
layer_name_mapping = {
    "Dock and Industrial Area": "Dock Industrial Area",
    "CBD – f": "Central Business District",
    "Wellington Industrial Estate": "Wellington Industrial Area",
    "Aberdeen_Lumley_Tourist_District — Commercial Corridor": "Aberdeen Lumley Tourist District",
    "Juba_Levuma_Tourist_District": "Juba Levuma Tourist District",
    "Buffered Commercial Corridors": "Commercial Corridors"
}

# ========================================
# B. ENTITY CONFIGURATION BY LAYER
# ========================================

# Commercial Corridors entities (to validate/preserve)
commercial_corridors_entities = [
    "Congo Cross – Lumley",
    "Sanders - Campbell Streets",
    "Kissy Road– Bai Bureh Roads",
    "Bai Bureh Road (Allen Town section)",
    "Kroo Town Road",
    "Fourah Bay Road"
]

# Hazardous Zones entities
hazardous_zones_entities = [
    "Kingtom Dumpsite Zone",
    "Ferry junction Dumpsite Zone"
]

# Informal Settlements entities
informal_settlements_entities = [
    "Back of Kissy Brook",
    "Bobo Kombo - Kroo Bay",
    "Susan's Bay - Big Wharf",
    "Congo Valley - Back of Stadium"
]

# ========================================
# C. LAYERS TO MERGE
# ========================================
merge_groups = {
    "Industrial Areas": [
        "Dock Industrial Area",
        "Wellington Industrial Area",
        "Kissy Industrial Area",
        "Kissy Texaco Terminal Area",
        "Grassfield Industrial Area"
    ],
    "Tourist Districts": [
        "Aberdeen Lumley Tourist District",
        "Juba Levuma Tourist District"
    ]
}

# ========================================
# STEP 1: LOAD AND RENAME LAYERS
# ========================================
print("\n" + "=" * 60)
print("STEP 1: LOADING AND RENAMING LAYERS")
print("=" * 60)

# Find all .gpkg files
gpkg_files = list(input_dir.glob("*.gpkg"))
print(f"\nFound {len(gpkg_files)} GeoPackage file(s)")

# Dictionary to store loaded layers
layers = {}

for gpkg_file in gpkg_files:
    original_name = gpkg_file.stem
    
    # Apply layer name mapping
    new_name = layer_name_mapping.get(original_name, original_name)
    
    print(f"\n📁 Processing: {original_name}")
    if new_name != original_name:
        print(f"   → Renamed to: {new_name}")
    
    # Read the layer
    try:
        gdf = gpd.read_file(gpkg_file)
        print(f"   ✓ Loaded: {len(gdf)} features")
        print(f"   CRS: {gdf.crs}")
        print(f"   Columns: {list(gdf.columns)}")
        
        # Remove NULL geometries
        null_count = gdf.geometry.isna().sum()
        if null_count > 0:
            print(f"   ⚠️ Removing {null_count} NULL geometries")
            gdf = gdf[~gdf.geometry.isna()].copy()
        
        # Validate geometries
        gdf['is_valid'] = gdf.geometry.is_valid
        invalid_count = (~gdf['is_valid']).sum()
        
        if invalid_count > 0:
            print(f"   ⚠️ Found {invalid_count} invalid geometries, fixing...")
            gdf['geometry'] = gdf.geometry.buffer(0)
            gdf['is_valid'] = gdf.geometry.is_valid
            print(f"   ✓ Fixed geometries")
        
        # Remove is_valid column
        gdf = gdf.drop(columns=['is_valid'])
        
        # Store with new name
        layers[new_name] = gdf
        
    except Exception as e:
        print(f"   ✗ Error: {str(e)}")

# ========================================
# STEP 2: PROCESS COMMERCIAL CORRIDORS
# ========================================
print("\n" + "=" * 60)
print("STEP 2: PROCESSING COMMERCIAL CORRIDORS")
print("=" * 60)

if "Commercial Corridors" in layers:
    print("\n📋 Commercial Corridors")
    gdf = layers["Commercial Corridors"].copy()
    
    # Rename Street → Corridor
    if "Street" in gdf.columns:
        gdf = gdf.rename(columns={"Street": "Corridor"})
        print(f"   ✓ Renamed column: Street → Corridor")
    else:
        print(f"   ⚠️ Column 'Street' not found. Available: {list(gdf.columns)}")
    
    # Add id column
    gdf['id'] = range(1, len(gdf) + 1)
    print(f"   ✓ Added column: id")
    
    # Display current entities
    if "Corridor" in gdf.columns:
        print(f"\n   Current corridors in data:")
        for idx, value in enumerate(gdf['Corridor'], 1):
            print(f"      {idx}. {value}")
    
    layers["Commercial Corridors"] = gdf
    print(f"   ✓ Final columns: {list(gdf.columns)}")

# ========================================
# STEP 3: PROCESS HAZARDOUS ZONES
# ========================================
print("\n" + "=" * 60)
print("STEP 3: PROCESSING HAZARDOUS ZONES")
print("=" * 60)

# Try to find Hazardous Zones layer (might have different name)
hazardous_layer_name = None
for name in layers.keys():
    if "hazard" in name.lower() or "dumpsite" in name.lower() or "buffer" in name.lower():
        hazardous_layer_name = name
        break

if hazardous_layer_name:
    print(f"\n📋 Found: {hazardous_layer_name}")
    gdf = layers[hazardous_layer_name].copy()
    
    print(f"   Current columns: {list(gdf.columns)}")
    print(f"   Features: {len(gdf)}")
    
    # Create Zone column with entity names
    if len(gdf) == len(hazardous_zones_entities):
        gdf['Zone'] = hazardous_zones_entities
        print(f"   ✓ Created column: Zone")
        for idx, zone in enumerate(hazardous_zones_entities, 1):
            print(f"      {idx}. {zone}")
    else:
        print(f"   ⚠️ Expected {len(hazardous_zones_entities)} features, found {len(gdf)}")
        gdf['Zone'] = None
    
    # Add id column
    gdf['id'] = range(1, len(gdf) + 1)
    print(f"   ✓ Added column: id")
    
    # Rename layer to standard name
    layers["Hazardous Zones"] = gdf
    if hazardous_layer_name != "Hazardous Zones":
        del layers[hazardous_layer_name]
        print(f"   ✓ Renamed layer to: Hazardous Zones")
    
    print(f"   ✓ Final columns: {list(gdf.columns)}")
else:
    print("   ⚠️ Hazardous Zones layer not found")

# ========================================
# STEP 4: PROCESS INFORMAL SETTLEMENTS
# ========================================
print("\n" + "=" * 60)
print("STEP 4: PROCESSING INFORMAL SETTLEMENTS")
print("=" * 60)

# Try to find Informal Settlements layer
informal_layer_name = None
for name in layers.keys():
    if "informal" in name.lower() or "settlement" in name.lower():
        informal_layer_name = name
        break

if informal_layer_name:
    print(f"\n📋 Found: {informal_layer_name}")
    gdf = layers[informal_layer_name].copy()
    
    print(f"   Current columns: {list(gdf.columns)}")
    print(f"   Features: {len(gdf)}")
    
    # Create Settlement column with entity names
    if len(gdf) == len(informal_settlements_entities):
        gdf['Settlement'] = informal_settlements_entities
        print(f"   ✓ Created column: Settlement")
        for idx, settlement in enumerate(informal_settlements_entities, 1):
            print(f"      {idx}. {settlement}")
    else:
        print(f"   ⚠️ Expected {len(informal_settlements_entities)} features, found {len(gdf)}")
        gdf['Settlement'] = None
    
    # Add id column
    gdf['id'] = range(1, len(gdf) + 1)
    print(f"   ✓ Added column: id")
    
    # Rename layer to standard name
    layers["Informal Settlements"] = gdf
    if informal_layer_name != "Informal Settlements":
        del layers[informal_layer_name]
        print(f"   ✓ Renamed layer to: Informal Settlements")
    
    print(f"   ✓ Final columns: {list(gdf.columns)}")
else:
    print("   ⚠️ Informal Settlements layer not found")

# ========================================
# STEP 5: MERGE LAYERS
# ========================================
print("\n" + "=" * 60)
print("STEP 5: MERGING LAYERS")
print("=" * 60)

merged_layers = {}

for merged_name, layer_list in merge_groups.items():
    print(f"\n🔗 Merging: {merged_name}")
    
    gdfs_to_merge = []
    found_layers = []
    
    for layer_name in layer_list:
        if layer_name in layers:
            gdf = layers[layer_name].copy()
            gdf['source_layer'] = layer_name
            gdfs_to_merge.append(gdf)
            found_layers.append(layer_name)
            print(f"   ✓ Added: {layer_name} ({len(gdf)} features)")
        else:
            print(f"   ⚠️ Not found: {layer_name}")
    
    if gdfs_to_merge:
        # Merge all dataframes
        merged_gdf = gpd.GeoDataFrame(
            pd.concat(gdfs_to_merge, ignore_index=True),
            crs=gdfs_to_merge[0].crs
        )
        
        # Add merged id
        merged_gdf['id'] = range(1, len(merged_gdf) + 1)
        
        merged_layers[merged_name] = merged_gdf
        print(f"   ✓ Merged: {len(merged_gdf)} total features")
        print(f"   ✓ Columns: {list(merged_gdf.columns)}")
        
        # Remove original layers from output (they're now merged)
        for layer_name in found_layers:
            del layers[layer_name]
            print(f"   ✓ Removed original: {layer_name}")
    else:
        print(f"   ✗ No layers found to merge for {merged_name}")

# Add merged layers to layers dictionary
layers.update(merged_layers)

# ========================================
# STEP 6: REPROJECT AND SAVE ALL LAYERS
# ========================================
print("\n" + "=" * 60)
print("STEP 6: REPROJECTING AND SAVING LAYERS")
print("=" * 60)

for layer_name, gdf in layers.items():
    print(f"\n📍 {layer_name}")
    
    # Ensure CRS is EPSG:4326
    if gdf.crs is None:
        print(f"   ⚠️ No CRS defined, assuming EPSG:4326")
        gdf.crs = "EPSG:4326"
    elif str(gdf.crs) != "EPSG:4326":
        print(f"   🔄 Reprojecting from {gdf.crs} to EPSG:4326")
        gdf = gdf.to_crs("EPSG:4326")
    else:
        print(f"   ✓ Already in EPSG:4326")
    
    # Create safe filename
    safe_name = layer_name.replace(" ", "_").replace("–", "-").replace("—", "-")
    output_file = output_dir / f"{safe_name}.gpkg"
    
    # Save
    gdf.to_file(output_file, driver="GPKG")
    print(f"   ✓ Saved: {output_file.name}")
    print(f"   Features: {len(gdf)}")
    print(f"   Columns: {list(gdf.columns)}")

# ========================================
# FINAL SUMMARY
# ========================================
print("\n" + "=" * 60)
print("FINAL SUMMARY")
print("=" * 60)
print(f"📁 Input files processed: {len(gpkg_files)}")
print(f"📄 Output layers created: {len(layers)}")
print(f"\n📂 Output location: {output_dir}")
print("\n✅ Output layers:")
for i, layer_name in enumerate(sorted(layers.keys()), 1):
    feature_count = len(layers[layer_name])
    columns = list(layers[layer_name].columns)
    print(f"\n  {i}. {layer_name}")
    print(f"     Features: {feature_count}")
    print(f"     Columns: {columns}")

print("\n" + "=" * 60)
print("PROCESS COMPLETE!")
print("=" * 60)