"""
Freetown Urbanization Analysis (2019-2025)
Calculating the difference in number of buildings per ward (Western Area Urban)
"""

import geopandas as gpd
import pandas as pd
from pathlib import Path
import warnings
warnings.filterwarnings('ignore')

# ============================================================================
# CONFIGURATION
# ============================================================================

BASE_DIR = Path(r"D:\LoGRI Dropbox\LoGRI Master Folder\2. Projects\2. Country Projects\9. Sierra Leone\12. Data\2. Build\map_update\Freetown")
FINAL_DIR = Path(r"D:\LoGRI Dropbox\LoGRI Master Folder\2. Projects\2. Country Projects\9. Sierra Leone\12. Data\3. Final\discovery")
OUTPUT_DIR = Path(r"D:\LoGRI Dropbox\LoGRI Master Folder\2. Projects\2. Country Projects\9. Sierra Leone\13. Output\discovery")

# Create folders if needed
FINAL_DIR.mkdir(parents=True, exist_ok=True)
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# Input files
BUILDINGS_2019 = BASE_DIR / "freetown_polygons_2026_01_22.gpkg"
BUILDINGS_2025 = BASE_DIR / "osm_buildings_freetown_2025.gpkg"
ZONES = BASE_DIR / "Western Area Urban Wards.shp"

# Output files
OUTPUT_CSV = OUTPUT_DIR / "wards_urbanization_2019_2025.csv"
OUTPUT_EXCEL = OUTPUT_DIR / "wards_urbanization_2019_2025.xlsx"

# Final data
FINAL_SHAPEFILE = FINAL_DIR / "wards_urbanization_2019_2025.shp"
FINAL_GEOJSON = FINAL_DIR / "wards_urbanization_2019_2025.geojson"


# ============================================================================
# MAIN SCRIPT
# ============================================================================

def main():
    print("\nFREETOWN URBANIZATION ANALYSIS (2019-2025)")
    print("Western Area Urban Wards")
    print("=" * 60)
    
    # 1. Load data
    print("\n1. Loading data...")
    buildings_2019 = gpd.read_file(BUILDINGS_2019)
    buildings_2025 = gpd.read_file(BUILDINGS_2025)
    zones = gpd.read_file(ZONES)
    print(f"   ✓ Buildings 2019: {len(buildings_2019):,}")
    print(f"   ✓ Buildings 2025: {len(buildings_2025):,}")
    print(f"   ✓ Wards: {len(zones):,}")
    
    # 2. Harmonize CRS
    print("\n2. CRS harmonization...")
    if buildings_2019.crs != zones.crs:
        buildings_2019 = buildings_2019.to_crs(zones.crs)
    if buildings_2025.crs != zones.crs:
        buildings_2025 = buildings_2025.to_crs(zones.crs)
    print(f"   ✓ CRS: {zones.crs}")
    
    # 3. Count buildings per zone (using centroids)
    print("\n3. Counting per ward (with centroids)...")
    
    # 2019 - Create centroids
    buildings_2019_centroids = buildings_2019.copy()
    buildings_2019_centroids['geometry'] = buildings_2019.centroid
    buildings_2019_centroids['building_id'] = range(len(buildings_2019_centroids))  # ID unique
    
    join_2019 = gpd.sjoin(buildings_2019_centroids, zones, how='left', predicate='within')
    
    # CRITICAL: Keep only first assignment per building (in case of overlapping wards)
    join_2019 = join_2019.drop_duplicates(subset='building_id', keep='first')
    
    # Identifier et exporter bâtiments non assignés
    unassigned_2019 = join_2019[join_2019['index_right'].isna()].copy()
    if len(unassigned_2019) > 0:
        print(f"   ⚠️  {len(unassigned_2019)} buildings 2019 outside wards")
        # Export
        unassigned_2019_export = unassigned_2019.drop(columns=['index_right', 'building_id'], errors='ignore')
        unassigned_2019_export.to_file(OUTPUT_DIR / "unassigned_buildings_2019_wards.geojson", driver='GeoJSON')
        print(f"   ✓ List exported: unassigned_buildings_2019_wards.geojson")
    
    # Compter bâtiments par zone
    counts_2019 = join_2019.groupby('index_right').size()
    zones['buildings_2019'] = 0
    zones.loc[counts_2019.index, 'buildings_2019'] = counts_2019.values
    print(f"   ✓ 2019: {zones['buildings_2019'].sum():,} buildings assigned")
    
    # 2025 - Create centroids
    buildings_2025_centroids = buildings_2025.copy()
    buildings_2025_centroids['geometry'] = buildings_2025.centroid
    buildings_2025_centroids['building_id'] = range(len(buildings_2025_centroids))  # ID unique
    
    join_2025 = gpd.sjoin(buildings_2025_centroids, zones, how='left', predicate='within')
    
    # CRITICAL: Keep only first assignment per building (in case of overlapping wards)
    join_2025 = join_2025.drop_duplicates(subset='building_id', keep='first')
    
    # Identifier et exporter bâtiments non assignés
    unassigned_2025 = join_2025[join_2025['index_right'].isna()].copy()
    if len(unassigned_2025) > 0:
        print(f"   ⚠️  {len(unassigned_2025)} buildings 2025 outside wards")
        # Export
        unassigned_2025_export = unassigned_2025.drop(columns=['index_right', 'building_id'], errors='ignore')
        unassigned_2025_export.to_file(OUTPUT_DIR / "unassigned_buildings_2025_wards.geojson", driver='GeoJSON')
        print(f"   ✓ List exported: unassigned_buildings_2025_wards.geojson")
    
    # Compter bâtiments par zone
    counts_2025 = join_2025.groupby('index_right').size()
    zones['buildings_2025'] = 0
    zones.loc[counts_2025.index, 'buildings_2025'] = counts_2025.values
    print(f"   ✓ 2025: {zones['buildings_2025'].sum():,} buildings assigned")
    
    # 4. Calculate difference
    print("\n4. Calculating differences...")
    zones['difference'] = zones['buildings_2025'] - zones['buildings_2019']
    
    print(f"   ✓ Total new buildings: {zones['difference'].sum():,}")
    print(f"   ✓ Growth rate: {zones['difference'].sum() / zones['buildings_2019'].sum() * 100:.1f}%")
    
    # 5. Top 10
    print("\n5. Top 10 wards:")
    top_10 = zones.nlargest(10, 'difference')
    for idx, row in enumerate(top_10.itertuples(), 1):
        name = getattr(row, 'Ward', getattr(row, 'ward', getattr(row, 'WARD', getattr(row, 'Name', getattr(row, 'name', f'Ward {row.Index}')))))
        print(f"   {idx:2d}. {name}: +{row.difference:,} ({row.buildings_2019:,} → {row.buildings_2025:,})")
    
    # 6. Export
    print("\n6. Exporting results...")
    
    # Shapefile (final data)
    zones_shp = zones.copy()
    zones_shp = zones_shp.rename(columns={
        'buildings_2019': 'bld_2019',
        'buildings_2025': 'bld_2025',
        'difference': 'diff'
    })
    zones_shp.to_file(FINAL_SHAPEFILE)
    print(f"   ✓ {FINAL_SHAPEFILE}")
    
    # GeoJSON (final data)
    zones.to_file(FINAL_GEOJSON, driver='GeoJSON')
    print(f"   ✓ {FINAL_GEOJSON}")
    
    # CSV (output)
    zones_csv = zones.drop(columns=['geometry'])
    zones_csv.to_csv(OUTPUT_CSV, index=False, encoding='utf-8-sig')
    print(f"   ✓ {OUTPUT_CSV}")
    
    # Excel (output)
    with pd.ExcelWriter(OUTPUT_EXCEL, engine='openpyxl') as writer:
        zones_csv.to_excel(writer, sheet_name='All wards', index=False)
        zones_csv.nlargest(20, 'difference').to_excel(writer, sheet_name='Top 20', index=False)
    print(f"   ✓ {OUTPUT_EXCEL}")
    
    print("\n" + "=" * 60)
    print("✅ COMPLETED")
    print("=" * 60)


if __name__ == "__main__":
    main()