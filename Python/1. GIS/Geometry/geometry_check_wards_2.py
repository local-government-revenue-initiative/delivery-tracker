"""
Fix invalid ward geometries and save corrected version
Author: Robin Benabid Jegaden
Date: 2025-11-18
"""

import geopandas as gpd
from shapely.validation import explain_validity

# Paths
input_path = r"D:\LoGRI Dropbox\Robin Benabid Jegaden\LoGRI\Sierra_Leone\data\1_Raw\new_boundaries\Freetown\western_urban_wards.gpkg"
output_path = r"D:\LoGRI Dropbox\Robin Benabid Jegaden\LoGRI\Sierra_Leone\data\1_Raw\new_boundaries\Freetown\western_urban_wards_fixed.gpkg"

# Load wards
print("Loading ward boundaries...")
wards = gpd.read_file(input_path)
print(f"Loaded {len(wards)} wards in {wards.crs}\n")

# Identify invalid geometries
print("Checking geometries...")
invalid_before = []
for idx, row in wards.iterrows():
    if not row.geometry.is_valid:
        invalid_before.append(idx)
        print(f"Ward {idx}: INVALID - {explain_validity(row.geometry)}")

print(f"\n{len(invalid_before)} invalid geometries found")

# Fix invalid geometries using buffer(0) technique
if len(invalid_before) > 0:
    print("\nFixing invalid geometries using buffer(0)...")
    wards['geometry'] = wards['geometry'].buffer(0)
    
    # Verify fix
    print("\nVerifying fixes...")
    invalid_after = []
    for idx, row in wards.iterrows():
        if not row.geometry.is_valid:
            invalid_after.append(idx)
            print(f"Ward {idx}: STILL INVALID - {explain_validity(row.geometry)}")
    
    if len(invalid_after) == 0:
        print("✓ All geometries successfully fixed!")
    else:
        print(f"✗ {len(invalid_after)} geometries still invalid")
else:
    print("\n✓ No invalid geometries to fix")

# Save corrected version
print(f"\nSaving corrected version to:\n{output_path}")
wards.to_file(output_path, driver="GPKG")
print("✓ Saved successfully")

# Final validation
print("\n" + "=" * 60)
print("FINAL VALIDATION")
print("=" * 60)
print(f"Total wards: {len(wards)}")
print(f"Invalid geometries: {len([g for g in wards.geometry if not g.is_valid])}")
print(f"CRS: {wards.crs}")

