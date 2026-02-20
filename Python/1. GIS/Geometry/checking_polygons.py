"""
Merge and validate multiple GeoPackage files
Author: Robin Benabid Jegaden
Date: 2025-11-13
Purpose: Combine ward boundary files and validate complete dataset

VALIDATION CHECKS PERFORMED:
    - Valid geometries: Checks topology validity using is_valid
    - Error details: Provides specific error messages via explain_validity
    - Overlaps: Performs pairwise comparison to detect overlapping polygons
    - Gaps: Calculates coverage gaps using convex hull analysis
    - NULL geometries: Identifies and removes empty/missing geometries
    - Auto-fix: Attempts to repair invalid geometries using buffer(0)
    - Dissolve: Groups polygons with same source_file into multi-polygons
    - Export problems: Saves invalid geometries and overlaps to separate files
    - Detailed report: Generates console output and CSV reports with source traceability

"""

import geopandas as gpd
from shapely.validation import explain_validity
from pathlib import Path
import pandas as pd
import os

# Define paths
input_dir = Path(r"D:\LoGRI Dropbox\Robin Benabid Jegaden\LoGRI\Sierra_Leone\data\2_Build\new_boundaries\Freetown")
output_dir = Path(r"D:\LoGRI Dropbox\Robin Benabid Jegaden\LoGRI\Sierra_Leone\data\3_Final\new_boundaries\Freetown")

# Create output directory if it doesn't exist
os.makedirs(output_dir, exist_ok=True)

print("=" * 60)
print("MERGE AND VALIDATION WORKFLOW")
print("=" * 60)
print(f"\nInput directory:  {input_dir}")
print(f"Output directory: {output_dir}")

# ========================================
# STEP 1: MERGE ALL GPKG FILES
# ========================================
print("\n" + "=" * 60)
print("STEP 1: MERGING GEOPACKAGE FILES")
print("=" * 60)

# Find all .gpkg files
gpkg_files = list(input_dir.glob("*.gpkg"))
print(f"\nFound {len(gpkg_files)} GeoPackage file(s):")
for f in gpkg_files:
    print(f"  - {f.name}")

# Read and merge all files
gdfs = []
for gpkg_file in gpkg_files:
    try:
        gdf = gpd.read_file(gpkg_file)
        gdf['source_file'] = gpkg_file.stem  # Track source file
        gdfs.append(gdf)
        print(f"  ✓ Loaded {gpkg_file.name}: {len(gdf)} features")
    except Exception as e:
        print(f"  ✗ Error loading {gpkg_file.name}: {str(e)}")

# Concatenate all dataframes
if gdfs:
    merged_gdf = gpd.GeoDataFrame(pd.concat(gdfs, ignore_index=True))
    print(f"\n✓ Total features after merge: {len(merged_gdf)}")
    print(f"✓ CRS: {merged_gdf.crs}")
    
    # Save merged file to output directory
    merged_output = output_dir / "revised_STA_boundaries_merged.gpkg"
    merged_gdf.to_file(merged_output, driver="GPKG")
    print(f"✓ Merged file saved to: {merged_output}")
else:
    print("\n✗ No files to merge!")
    exit()

# ========================================
# STEP 2: CHECK FOR NULL GEOMETRIES (DETAILED)
# ========================================
print("\n" + "=" * 60)
print("STEP 2: CHECKING FOR NULL GEOMETRIES")
print("=" * 60)

# Check for null/None geometries
merged_gdf['is_null'] = merged_gdf.geometry.isna()
null_count = merged_gdf['is_null'].sum()

print(f"\n✓ Non-null geometries: {(~merged_gdf['is_null']).sum()}")
print(f"✗ Null geometries: {null_count}")

if null_count > 0:
    print("\n" + "=" * 60)
    print("⚠️  DETAILED NULL GEOMETRY REPORT")
    print("=" * 60)
    
    null_gdf = merged_gdf[merged_gdf['is_null']].copy()
    
    for idx, row in null_gdf.iterrows():
        print(f"\n🔍 NULL Geometry #{idx + 1}")
        print(f"   Source file: {row['source_file']}.gpkg")
        print(f"   Row index in merged data: {idx}")
        print(f"\n   All attributes:")
        
        # Print ALL columns except geometry, is_null, and source_file
        for col in merged_gdf.columns:
            if col not in ['geometry', 'is_null', 'source_file']:
                value = row[col]
                # Check if value is empty/null
                if pd.isna(value) or value == '' or value == ' ':
                    print(f"      {col}: (empty)")
                else:
                    print(f"      {col}: {value}")
        
        print(f"\n   📊 Assessment:")
        # Check if ALL attributes are empty
        non_geom_cols = [col for col in merged_gdf.columns 
                        if col not in ['geometry', 'is_null', 'source_file']]
        all_empty = all(pd.isna(row[col]) or row[col] == '' or row[col] == ' ' 
                       for col in non_geom_cols)
        
        if all_empty:
            print(f"      → Completely EMPTY row (likely technical error)")
            print(f"      → SAFE to remove ✅")
        else:
            print(f"      → Row has attribute data but NO geometry")
            print(f"      → ⚠️  WARNING: Could be legitimate ward missing geometry!")
            print(f"      → ⚠️  REVIEW before removal!")
    
    # Save NULL details to CSV for review
    null_csv = output_dir / "null_geometries_report.csv"
    null_gdf.drop(columns=['geometry']).to_csv(null_csv, index=False)
    print(f"\n📄 Full NULL geometry report saved to: {null_csv}")
    
    # Ask for confirmation before removing
    print("\n" + "=" * 60)
    print("⚠️  REMOVAL DECISION")
    print("=" * 60)
    print(f"The script will now remove {null_count} NULL geometry(ies).")
    print("Review the details above to ensure this is safe.")
    print("\nPress Enter to continue with removal, or Ctrl+C to abort...")
    try:
        input()
    except KeyboardInterrupt:
        print("\n\n❌ Script aborted by user")
        exit()
    
    # Remove null geometries
    print(f"\n⚠️ Removing {null_count} null geometries from dataset...")
    merged_gdf = merged_gdf[~merged_gdf['is_null']].copy()
    print(f"✓ Remaining features: {len(merged_gdf)}")
    
else:
    print("\n✅ No null geometries!")

# ========================================
# STEP 3: VALIDATE GEOMETRIES (BEFORE DISSOLVE)
# ========================================
print("\n" + "=" * 60)
print("STEP 3: VALIDATING GEOMETRIES")
print("=" * 60)

# Check if geometries are valid
merged_gdf['is_valid'] = merged_gdf.geometry.is_valid
invalid_count = (~merged_gdf['is_valid']).sum()

print(f"\n✓ Valid geometries: {merged_gdf['is_valid'].sum()}")
print(f"✗ Invalid geometries: {invalid_count}")

# If there are invalid geometries, explain why
if invalid_count > 0:
    print("\nInvalid geometry details:")
    
    # Safe validity check with explicit null handling
    def safe_explain_validity(geom):
        if geom is None:
            return "NULL geometry"
        elif not geom.is_valid:
            return explain_validity(geom)
        else:
            return None
    
    merged_gdf['validity_error'] = merged_gdf.geometry.apply(safe_explain_validity)
    
    invalid_gdf = merged_gdf[~merged_gdf['is_valid']].copy()
    for idx, row in invalid_gdf.iterrows():
        print(f"  Feature {idx} (from {row['source_file']}): {row['validity_error']}")
    
    # Save invalid geometries
    invalid_output = output_dir / "invalid_geometries.gpkg"
    invalid_gdf.to_file(invalid_output, driver="GPKG")
    print(f"\n→ Invalid geometries saved to: {invalid_output}")
    
    # Try to fix invalid geometries using buffer(0)
    print("\nAttempting to fix invalid geometries...")
    merged_gdf.loc[~merged_gdf['is_valid'], 'geometry'] = merged_gdf.loc[~merged_gdf['is_valid'], 'geometry'].buffer(0)
    merged_gdf['is_valid'] = merged_gdf.geometry.is_valid
    fixed_count = merged_gdf['is_valid'].sum()
    remaining_invalid = (~merged_gdf['is_valid']).sum()
    print(f"✓ Valid geometries after fix: {fixed_count}/{len(merged_gdf)}")
    if remaining_invalid > 0:
        print(f"⚠️ Still {remaining_invalid} invalid geometries that couldn't be auto-fixed")
else:
    print("\n✅ All geometries are valid!")

# ========================================
# STEP 4: CHECK FOR OVERLAPS (BEFORE DISSOLVE)
# ========================================
print("\n" + "=" * 60)
print("STEP 4: CHECKING FOR OVERLAPS")
print("=" * 60)

# Only check overlaps on valid geometries
valid_gdf_predissolve = merged_gdf[merged_gdf['is_valid']].copy().reset_index(drop=True)

overlaps = []
total_comparisons = (len(valid_gdf_predissolve) * (len(valid_gdf_predissolve) - 1)) // 2
print(f"\nPerforming {total_comparisons} pairwise comparisons on {len(valid_gdf_predissolve)} valid features...")

# Compare each polygon with all others
for i in range(len(valid_gdf_predissolve)):
    if i % 10 == 0:  # Progress indicator
        print(f"  Progress: {i}/{len(valid_gdf_predissolve)}", end='\r')
    
    for j in range(i + 1, len(valid_gdf_predissolve)):
        geom_i = valid_gdf_predissolve.iloc[i].geometry
        geom_j = valid_gdf_predissolve.iloc[j].geometry
        
        # Skip if either geometry is None (extra safety)
        if geom_i is None or geom_j is None:
            continue
        
        # Check if geometries overlap (not just touch)
        try:
            if geom_i.overlaps(geom_j):
                overlap_area = geom_i.intersection(geom_j).area
                overlaps.append({
                    'feature_1_index': i,
                    'feature_2_index': j,
                    'feature_1_source': valid_gdf_predissolve.iloc[i]['source_file'],
                    'feature_2_source': valid_gdf_predissolve.iloc[j]['source_file'],
                    'overlap_area': overlap_area
                })
        except Exception as e:
            print(f"\n⚠️ Error checking overlap between features {i} and {j}: {str(e)}")

print(f"\n\n✓ Overlap checks completed")
print(f"✗ Number of overlapping pairs: {len(overlaps)}")

if overlaps:
    print("\nOverlapping features:")
    overlap_df = pd.DataFrame(overlaps)
    print(overlap_df.to_string(index=False))
    
    # Save overlap report
    overlap_csv = output_dir / "overlap_report.csv"
    overlap_df.to_csv(overlap_csv, index=False)
    print(f"\n→ Overlap report saved to: {overlap_csv}")
    
    # Create geometries of overlap areas
    overlap_geoms = []
    for overlap in overlaps:
        geom_i = valid_gdf_predissolve.iloc[overlap['feature_1_index']].geometry
        geom_j = valid_gdf_predissolve.iloc[overlap['feature_2_index']].geometry
        intersection = geom_i.intersection(geom_j)
        overlap_geoms.append({
            'geometry': intersection,
            'feature_1_source': overlap['feature_1_source'],
            'feature_2_source': overlap['feature_2_source'],
            'area': overlap['overlap_area']
        })
    
    overlap_gdf = gpd.GeoDataFrame(overlap_geoms, crs=valid_gdf_predissolve.crs)
    overlap_output = output_dir / "overlap_areas.gpkg"
    overlap_gdf.to_file(overlap_output, driver="GPKG")
    print(f"→ Overlap areas saved to: {overlap_output}")
else:
    print("\n✅ No overlaps detected!")

# ========================================
# STEP 5: CHECK FOR GAPS (BEFORE DISSOLVE)
# ========================================
print("\n" + "=" * 60)
print("STEP 5: CHECKING FOR GAPS")
print("=" * 60)

# Create union of all valid polygons
union = valid_gdf_predissolve.unary_union

# Get convex hull
convex_hull = union.convex_hull

# Calculate gap area
gap_area = convex_hull.area - union.area
gap_percentage = (gap_area / convex_hull.area) * 100

print(f"\nTotal ward area: {union.area:.10f} square degrees")
print(f"Convex hull area: {convex_hull.area:.10f} square degrees")
print(f"Gap area: {gap_area:.10f} square degrees ({gap_percentage:.2f}%)")

if gap_percentage > 1:  # More than 1% gap
    print("\n⚠️ Significant gaps detected between wards")
    
    # Save gap geometry
    gap_geom = convex_hull.difference(union)
    gap_gdf = gpd.GeoDataFrame([{'geometry': gap_geom}], crs=valid_gdf_predissolve.crs)
    gap_output = output_dir / "gap_areas.gpkg"
    gap_gdf.to_file(gap_output, driver="GPKG")
    print(f"→ Gap areas saved to: {gap_output}")
else:
    print("\n✅ No significant gaps detected")

# ========================================
# STEP 6: SAVE CLEANED VERSION (BEFORE DISSOLVE)
# ========================================
print("\n" + "=" * 60)
print("STEP 6: SAVING CLEANED DATA (PRE-DISSOLVE)")
print("=" * 60)

# Save cleaned version with all individual polygons
cleaned_output = output_dir / "revised_STA_boundaries_cleaned.gpkg"
valid_gdf_predissolve.drop(columns=['is_valid', 'is_null'], errors='ignore').to_file(cleaned_output, driver="GPKG")
print(f"✓ Cleaned file saved to: {cleaned_output}")
print(f"  Features: {len(valid_gdf_predissolve)} (individual polygons)")

# ========================================
# STEP 7: DISSOLVE BY SOURCE_FILE
# ========================================
print("\n" + "=" * 60)
print("STEP 7: DISSOLVING POLYGONS BY SOURCE FILE")
print("=" * 60)

# Show which source files have multiple polygons
source_counts = valid_gdf_predissolve['source_file'].value_counts()
multi_polygon_sources = source_counts[source_counts > 1]

print(f"\nSource files with multiple polygons:")
if len(multi_polygon_sources) > 0:
    print(f"⚠️ {len(multi_polygon_sources)} file(s) contain multiple polygons:")
    for source, count in multi_polygon_sources.items():
        print(f"  - {source}: {count} polygons → will be merged into 1 multi-polygon")
else:
    print("✓ Each source file has only one polygon")

print(f"\nBefore dissolve: {len(valid_gdf_predissolve)} features")
print(f"After dissolve: {valid_gdf_predissolve['source_file'].nunique()} features (expected)")

# Dissolve: group by source_file and combine geometries
print(f"\nDissolving geometries by 'source_file'...")
dissolved_gdf = valid_gdf_predissolve.dissolve(by='source_file', as_index=False)

print(f"✓ Features after dissolve: {len(dissolved_gdf)}")
print(f"✓ Unique source files: {dissolved_gdf['source_file'].nunique()}")

# Check geometry types after dissolve
geom_types = dissolved_gdf.geometry.geom_type.value_counts()
print(f"\nGeometry types after dissolve:")
for geom_type, count in geom_types.items():
    print(f"  - {geom_type}: {count}")

# Save dissolved file
dissolved_output = output_dir / "revised_STA_boundaries.gpkg"
dissolved_gdf.to_file(dissolved_output, driver="GPKG")
print(f"\n✓ Dissolved file saved to: {dissolved_output}")
print(f"  Features: {len(dissolved_gdf)} (one per source file)")

# ========================================
# FINAL SUMMARY
# ========================================
print("\n" + "=" * 60)
print("VALIDATION SUMMARY")
print("=" * 60)
print(f"📁 Input files: {len(gpkg_files)}")
print(f"📊 Total features (original): {len(merged_gdf) + null_count}")
print(f"✗ Null geometries removed: {null_count}")
print(f"📊 Features after cleaning: {len(valid_gdf_predissolve)}")
print(f"📊 Features after dissolve: {len(dissolved_gdf)}")
print(f"✓ Valid geometries: {len(valid_gdf_predissolve)}/{len(valid_gdf_predissolve)}")
print(f"✗ Invalid geometries: {invalid_count}")
print(f"✗ Overlapping pairs: {len(overlaps)}")
print(f"⚠️ Gap percentage: {gap_percentage:.2f}%")
print(f"\n📄 Output files (in {output_dir}):")
print(f"  - Merged (raw): {merged_output.name} ({len(merged_gdf)} features)")
print(f"  - Cleaned: {cleaned_output.name} ({len(valid_gdf_predissolve)} features) ✅")
print(f"  - Dissolved: {dissolved_output.name} ({len(dissolved_gdf)} features)")
if null_count > 0:
    print(f"  - NULL report: null_geometries_report.csv")
print("=" * 60)
