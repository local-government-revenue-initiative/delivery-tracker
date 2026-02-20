"""
Validate individual GeoPackage files
Author: Robin Benabid Jegaden
Date: 2025-11-13
Purpose: Apply comprehensive validation checks to each .gpkg file separately

VALIDATION CHECKS PERFORMED:
    - Valid geometries: Checks topology validity using is_valid
    - Error details: Provides specific error messages via explain_validity
    - Overlaps: Performs pairwise comparison to detect overlapping polygons
    - Gaps: Calculates coverage gaps using convex hull analysis (report only)
    - NULL geometries: Identifies and removes empty/missing geometries
    - Auto-fix: Attempts to repair invalid geometries using buffer(0)
    - Export problems: Saves invalid geometries and overlaps to separate files
    - Detailed report: Generates console output and CSV reports with source traceability
"""

import geopandas as gpd
from shapely.validation import explain_validity
from pathlib import Path
import pandas as pd
import os

# Define paths
input_dir = Path(r"D:\LoGRI Dropbox\Robin Benabid Jegaden\LoGRI\Sierra_Leone\data\1_Raw\new_boundaries\Freetown\Revised_GIS Layers FCC")
output_dir = Path(r"D:\LoGRI Dropbox\Robin Benabid Jegaden\LoGRI\Sierra_Leone\data\2_Build\new_boundaries\Freetown")

# Create output directory if it doesn't exist
os.makedirs(output_dir, exist_ok=True)

print("=" * 80)
print("INDIVIDUAL LAYER VALIDATION WORKFLOW")
print("=" * 80)
print(f"\nInput directory:  {input_dir}")
print(f"Output directory: {output_dir}")

# Find all .gpkg files
gpkg_files = list(input_dir.glob("*.gpkg"))
print(f"\nFound {len(gpkg_files)} GeoPackage file(s) to validate")

# Track overall statistics
overall_stats = {
    'total_files': len(gpkg_files),
    'files_processed': 0,
    'files_with_nulls': 0,
    'files_with_invalids': 0,
    'files_with_overlaps': 0,
    'files_with_gaps': 0
}

# Process each file individually
for file_idx, gpkg_file in enumerate(gpkg_files, 1):
    
    layer_name = gpkg_file.stem
    
    print("\n" + "=" * 80)
    print(f"PROCESSING FILE {file_idx}/{len(gpkg_files)}: {layer_name}")
    print("=" * 80)
    
    # ========================================
    # STEP 1: LOAD FILE
    # ========================================
    print("\n" + "-" * 80)
    print("STEP 1: LOADING FILE")
    print("-" * 80)
    
    try:
        gdf = gpd.read_file(gpkg_file)
        print(f"✓ Loaded: {len(gdf)} features")
        print(f"  CRS: {gdf.crs}")
        print(f"  Columns: {list(gdf.columns)}")
        original_count = len(gdf)
    except Exception as e:
        print(f"✗ Error loading file: {str(e)}")
        continue
    
    # ========================================
    # STEP 2: CHECK FOR NULL GEOMETRIES
    # ========================================
    print("\n" + "-" * 80)
    print("STEP 2: CHECKING FOR NULL GEOMETRIES")
    print("-" * 80)
    
    gdf['is_null'] = gdf.geometry.isna()
    null_count = gdf['is_null'].sum()
    
    print(f"✓ Non-null geometries: {(~gdf['is_null']).sum()}")
    print(f"✗ Null geometries: {null_count}")
    
    if null_count > 0:
        overall_stats['files_with_nulls'] += 1
        null_gdf = gdf[gdf['is_null']].copy()
        
        # Save NULL report
        null_csv = output_dir / f"{layer_name}_null_report.csv"
        null_gdf.drop(columns=['geometry']).to_csv(null_csv, index=False)
        print(f"→ NULL report saved: {null_csv.name}")
        
        # Remove null geometries
        gdf = gdf[~gdf['is_null']].copy()
        print(f"✓ Removed {null_count} null geometries")
    
    gdf = gdf.drop(columns=['is_null'], errors='ignore')
    
    # ========================================
    # STEP 3: VALIDATE GEOMETRIES
    # ========================================
    print("\n" + "-" * 80)
    print("STEP 3: VALIDATING GEOMETRIES")
    print("-" * 80)
    
    gdf['is_valid'] = gdf.geometry.is_valid
    invalid_count = (~gdf['is_valid']).sum()
    
    print(f"✓ Valid geometries: {gdf['is_valid'].sum()}")
    print(f"✗ Invalid geometries: {invalid_count}")
    
    if invalid_count > 0:
        overall_stats['files_with_invalids'] += 1
        
        # Explain validity errors
        def safe_explain_validity(geom):
            if geom is None:
                return "NULL geometry"
            elif not geom.is_valid:
                return explain_validity(geom)
            else:
                return None
        
        gdf['validity_error'] = gdf.geometry.apply(safe_explain_validity)
        
        invalid_gdf = gdf[~gdf['is_valid']].copy()
        print("\nInvalid geometry details:")
        for idx, row in invalid_gdf.iterrows():
            print(f"  Feature {idx}: {row['validity_error']}")
        
        # Save invalid geometries
        invalid_output = output_dir / f"{layer_name}_invalid_geometries.gpkg"
        invalid_gdf.to_file(invalid_output, driver="GPKG")
        print(f"→ Invalid geometries saved: {invalid_output.name}")
        
        # Try to fix
        print("\nAttempting to fix invalid geometries...")
        gdf.loc[~gdf['is_valid'], 'geometry'] = gdf.loc[~gdf['is_valid'], 'geometry'].buffer(0)
        gdf['is_valid'] = gdf.geometry.is_valid
        fixed_count = gdf['is_valid'].sum()
        remaining_invalid = (~gdf['is_valid']).sum()
        print(f"✓ Valid after fix: {fixed_count}/{len(gdf)}")
        if remaining_invalid > 0:
            print(f"⚠️ Still {remaining_invalid} invalid geometries")
    
    gdf = gdf.drop(columns=['validity_error'], errors='ignore')
    
    # ========================================
    # STEP 4: CHECK FOR OVERLAPS
    # ========================================
    print("\n" + "-" * 80)
    print("STEP 4: CHECKING FOR OVERLAPS")
    print("-" * 80)
    
    valid_gdf = gdf[gdf['is_valid']].copy().reset_index(drop=True)
    
    overlaps = []
    total_comparisons = (len(valid_gdf) * (len(valid_gdf) - 1)) // 2
    
    if len(valid_gdf) > 1:
        print(f"Performing {total_comparisons} pairwise comparisons...")
        
        for i in range(len(valid_gdf)):
            if i % 10 == 0:
                print(f"  Progress: {i}/{len(valid_gdf)}", end='\r')
            
            for j in range(i + 1, len(valid_gdf)):
                geom_i = valid_gdf.iloc[i].geometry
                geom_j = valid_gdf.iloc[j].geometry
                
                if geom_i is None or geom_j is None:
                    continue
                
                try:
                    if geom_i.overlaps(geom_j):
                        overlap_area = geom_i.intersection(geom_j).area
                        overlaps.append({
                            'feature_1_index': i,
                            'feature_2_index': j,
                            'overlap_area': overlap_area
                        })
                except Exception as e:
                    print(f"\n⚠️ Error checking overlap between {i} and {j}: {str(e)}")
        
        print(f"\n✓ Overlap checks completed")
        print(f"✗ Overlapping pairs: {len(overlaps)}")
        
        if overlaps:
            overall_stats['files_with_overlaps'] += 1
            
            # Save overlap report
            overlap_df = pd.DataFrame(overlaps)
            overlap_csv = output_dir / f"{layer_name}_overlap_report.csv"
            overlap_df.to_csv(overlap_csv, index=False)
            print(f"→ Overlap report saved: {overlap_csv.name}")
            
            # Save overlap geometries
            overlap_geoms = []
            for overlap in overlaps:
                geom_i = valid_gdf.iloc[overlap['feature_1_index']].geometry
                geom_j = valid_gdf.iloc[overlap['feature_2_index']].geometry
                intersection = geom_i.intersection(geom_j)
                overlap_geoms.append({
                    'geometry': intersection,
                    'feature_1': overlap['feature_1_index'],
                    'feature_2': overlap['feature_2_index'],
                    'area': overlap['overlap_area']
                })
            
            overlap_gdf = gpd.GeoDataFrame(overlap_geoms, crs=valid_gdf.crs)
            overlap_output = output_dir / f"{layer_name}_overlap_areas.gpkg"
            overlap_gdf.to_file(overlap_output, driver="GPKG")
            print(f"→ Overlap areas saved: {overlap_output.name}")
        else:
            print("✅ No overlaps detected")
    else:
        print("⚠️ Only 1 feature, skipping overlap check")
    
    # ========================================
    # STEP 5: CHECK FOR GAPS (REPORT ONLY)
    # ========================================
    print("\n" + "-" * 80)
    print("STEP 5: CHECKING FOR GAPS")
    print("-" * 80)
    
    if len(valid_gdf) > 0:
        union = valid_gdf.unary_union
        convex_hull = union.convex_hull
        
        gap_area = convex_hull.area - union.area
        gap_percentage = (gap_area / convex_hull.area) * 100
        
        print(f"Total area: {union.area:.10f} square degrees")
        print(f"Convex hull area: {convex_hull.area:.10f} square degrees")
        print(f"Gap area: {gap_area:.10f} square degrees ({gap_percentage:.2f}%)")
        
        if gap_percentage > 1:
            overall_stats['files_with_gaps'] += 1
            print("⚠️ Significant gaps detected (>1%)")
        else:
            print("✅ No significant gaps (<1%)")
    
    # ========================================
    # STEP 6: REPROJECT TO EPSG:4326
    # ========================================
    print("\n" + "-" * 80)
    print("STEP 6: REPROJECTING TO EPSG:4326")
    print("-" * 80)
    
    if valid_gdf.crs != "EPSG:4326":
        print(f"🔄 Reprojecting from {valid_gdf.crs} to EPSG:4326")
        valid_gdf = valid_gdf.to_crs("EPSG:4326")
    else:
        print("✓ Already in EPSG:4326")
    
    # ========================================
    # STEP 7: SAVE CLEANED FILE
    # ========================================
    print("\n" + "-" * 80)
    print("STEP 7: SAVING CLEANED FILE")
    print("-" * 80)
    
    # Remove validation columns
    valid_gdf = valid_gdf.drop(columns=['is_valid'], errors='ignore')
    
    # Save cleaned file
    output_file = output_dir / f"{layer_name}.gpkg"
    valid_gdf.to_file(output_file, driver="GPKG")
    
    print(f"✓ Saved: {output_file.name}")
    print(f"  Original features: {original_count}")
    print(f"  Final features: {len(valid_gdf)}")
    print(f"  Features removed: {original_count - len(valid_gdf)}")
    
    overall_stats['files_processed'] += 1

# ========================================
# OVERALL SUMMARY
# ========================================
print("\n" + "=" * 80)
print("OVERALL VALIDATION SUMMARY")
print("=" * 80)
print(f"📁 Total files: {overall_stats['total_files']}")
print(f"✓ Files processed: {overall_stats['files_processed']}")
print(f"✗ Files with NULL geometries: {overall_stats['files_with_nulls']}")
print(f"✗ Files with invalid geometries: {overall_stats['files_with_invalids']}")
print(f"✗ Files with overlaps: {overall_stats['files_with_overlaps']}")
print(f"⚠️ Files with gaps (>1%): {overall_stats['files_with_gaps']}")
print(f"\n📂 All cleaned files saved to: {output_dir}")
