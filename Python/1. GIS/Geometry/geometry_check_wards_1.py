"""
Validate ward geometries: check validity, gaps, and overlaps
Author: Robin Benabid Jegaden
Date: 2025-11-18
"""

import geopandas as gpd
from shapely.validation import explain_validity
from shapely.ops import unary_union

# Load ward boundaries
input_path = r"D:\LoGRI Dropbox\Robin Benabid Jegaden\LoGRI\Sierra_Leone\data\1_Raw\new_boundaries\Freetown\western_urban_wards.gpkg"
wards = gpd.read_file(input_path)

print(f"Loaded {len(wards)} wards\n")
print("=" * 60)

# 1. Check individual geometry validity
print("\n1. GEOMETRY VALIDITY CHECK")
print("-" * 60)
invalid_count = 0
for idx, row in wards.iterrows():
    if not row.geometry.is_valid:
        invalid_count += 1
        print(f"Ward {idx}: INVALID - {explain_validity(row.geometry)}")

if invalid_count == 0:
    print("✓ All geometries are valid")
else:
    print(f"✗ {invalid_count} invalid geometries found")

# 2. Check for overlaps between wards
print("\n2. OVERLAP CHECK")
print("-" * 60)
overlaps_found = False
for i in range(len(wards)):
    for j in range(i + 1, len(wards)):
        intersection = wards.geometry.iloc[i].intersection(wards.geometry.iloc[j])
        if not intersection.is_empty and intersection.area > 1e-6:  # Tolerance for floating point
            overlaps_found = True
            print(f"Overlap between ward {i} and ward {j}: {intersection.area:.2f} sq units")

if not overlaps_found:
    print("✓ No overlaps detected")

# 3. Check for gaps
print("\n3. GAP CHECK")
print("-" * 60)
# Create dissolved boundary
dissolved = unary_union(wards.geometry)
total_ward_area = wards.geometry.area.sum()
dissolved_area = dissolved.area

# Check if dissolved area equals sum of individual areas (no gaps)
area_difference = abs(dissolved_area - total_ward_area)
if area_difference < 1e-3:  # Small tolerance
    print(f"✓ No gaps detected (area difference: {area_difference:.6f})")
else:
    print(f"⚠ Potential gaps detected (area difference: {area_difference:.2f})")

# Summary statistics
print("\n" + "=" * 60)
print("SUMMARY")
print("=" * 60)
print(f"Total wards: {len(wards)}")
print(f"CRS: {wards.crs}")
print(f"Total area: {total_ward_area:.2f} sq units")
print(f"Bounding box: {wards.total_bounds}")

