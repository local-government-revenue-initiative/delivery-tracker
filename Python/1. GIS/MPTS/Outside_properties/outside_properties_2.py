"""
Assign properties outside wards to their nearest ward
Author: Robin Benabid Jegaden
Date: 2025-11-18
"""

import geopandas as gpd

# Paths
base_path = r"D:\LoGRI Dropbox\Robin Benabid Jegaden\LoGRI\Sierra_Leone\data\1_Raw\new_boundaries\Freetown"
wards_path = f"{base_path}\\western_urban_wards_fixed.gpkg"
outside_props_path = f"{base_path}\\properties_outside_wards.gpkg"
all_props_path = f"{base_path}\\fcc_prop_locations.gpkg"
output_path = f"{base_path}\\fcc_prop_locations_with_wards.gpkg"

# Load data
print("Loading data...")
wards = gpd.read_file(wards_path)
outside_props = gpd.read_file(outside_props_path)
all_props = gpd.read_file(all_props_path)

# Get ward identifier column
ward_id_col = 'ward_id' if 'ward_id' in wards.columns else wards.columns[0]
print(f"Using ward identifier: {ward_id_col}")
print(f"Properties outside wards: {len(outside_props)}\n")

# Ensure same CRS
if wards.crs != outside_props.crs:
    outside_props = outside_props.to_crs(wards.crs)
if wards.crs != all_props.crs:
    all_props = all_props.to_crs(wards.crs)

# Assign nearest ward to each outside property
print("Assigning outside properties to nearest ward...")
nearest_wards = []

for idx, prop in outside_props.iterrows():
    point = prop.geometry
    
    # Calculate distance to all wards
    distances = wards.geometry.distance(point)
    nearest_ward_idx = distances.idxmin()
    nearest_ward_id = wards.loc[nearest_ward_idx, ward_id_col]
    
    nearest_wards.append(nearest_ward_id)

outside_props[ward_id_col] = nearest_wards
print(f"✓ Assigned {len(outside_props)} properties to nearest ward")

# Now assign wards to ALL properties (inside + outside corrected)
print("\nAssigning wards to all properties...")
all_props_with_wards = gpd.sjoin(all_props, wards[[ward_id_col, 'geometry']], 
                                   how='left', predicate='within')

# Add assignment method column
all_props_with_wards['assignment_method'] = 'within'

# Replace NaN with assignments from outside_props
# Create a dictionary for faster lookup
outside_dict = {}
for oidx, row in outside_props.iterrows():
    geom_wkt = row.geometry.wkt
    outside_dict[geom_wkt] = row[ward_id_col]

# Assign nearest ward to properties without ward
nan_indices = all_props_with_wards[all_props_with_wards[ward_id_col].isna()].index
for idx in nan_indices:
    geom_wkt = all_props_with_wards.loc[idx, 'geometry'].wkt
    if geom_wkt in outside_dict:
        all_props_with_wards.loc[idx, ward_id_col] = outside_dict[geom_wkt]
        all_props_with_wards.loc[idx, 'assignment_method'] = 'nearest'

# Clean up
if 'index_right' in all_props_with_wards.columns:
    all_props_with_wards = all_props_with_wards.drop(columns=['index_right'])

# Export
print(f"\nExporting to:\n{output_path}")
all_props_with_wards.to_file(output_path, driver="GPKG")

# Summary
print("\n" + "=" * 60)
print("SUMMARY")
print("=" * 60)
print(f"Total properties: {len(all_props_with_wards)}")
print(f"Properties with ward: {all_props_with_wards[ward_id_col].notna().sum()}")
print(f"Properties without ward: {all_props_with_wards[ward_id_col].isna().sum()}")
print("\nAssignment method breakdown:")
print(all_props_with_wards['assignment_method'].value_counts())
print(f"\nPercentage assigned by proximity: {(all_props_with_wards['assignment_method']=='nearest').sum() / len(all_props_with_wards) * 100:.2f}%")