"""
Identify property points outside ward boundaries
Author: Robin Benabid Jegaden
Date: 2025-11-18
"""

import geopandas as gpd

# Paths
base_path = r"D:\LoGRI Dropbox\Robin Benabid Jegaden\LoGRI\Sierra_Leone\data\1_Raw\new_boundaries\Freetown"
wards_path = f"{base_path}\\western_urban_wards_fixed.gpkg"
properties_path = f"{base_path}\\fcc_prop_locations.gpkg"

# Load data
print("Loading data...")
wards = gpd.read_file(wards_path)
properties = gpd.read_file(properties_path)

print(f"Wards: {len(wards)} polygons")
print(f"Properties: {len(properties)} points")
print(f"Ward CRS: {wards.crs}")
print(f"Property CRS: {properties.crs}\n")

# Ensure same CRS
if wards.crs != properties.crs:
    print(f"Reprojecting properties to {wards.crs}...")
    properties = properties.to_crs(wards.crs)

# Create dissolved ward boundary
ward_boundary = wards.unary_union

# Identify points outside wards
print("Checking spatial containment...")
properties['outside_wards'] = ~properties.geometry.within(ward_boundary)

# Results
outside = properties[properties['outside_wards'] == True]
inside = properties[properties['outside_wards'] == False]

print("\n" + "=" * 60)
print("RESULTS")
print("=" * 60)
print(f"Points inside wards: {len(inside)} ({len(inside)/len(properties)*100:.1f}%)")
print(f"Points outside wards: {len(outside)} ({len(outside)/len(properties)*100:.1f}%)")

# Export outside points if any
if len(outside) > 0:
    output_path = f"{base_path}\\properties_outside_wards.gpkg"
    outside.to_file(output_path, driver="GPKG")
    print(f"\n✓ Outside points exported to:\n{output_path}")
else:
    print("\n✓ All properties fall within ward boundaries")
