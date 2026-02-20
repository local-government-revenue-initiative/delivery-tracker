"""
Script to reproject a GeoPackage (.gpkg) file to EPSG:3857 (Web Mercator).

- Reads the input GeoPackage
- Reprojects all geometries to EPSG:3857
- Saves the result as a new GeoPackage

⚠️ Note:
EPSG:3857 is primarily used for web map display (Google Maps, OSM tiles).
For accurate area or distance calculations, use a local projection such as EPSG:32629 (UTM Zone 29N for Sierra Leone).
"""

import geopandas as gpd

# Path to your input file
gpkg_path = r"D:\Dropbox\LoGRI\Sierra_Leone\data\GIS\Kenema\kenema_roftops_2025_mapping.gpkg"

# Read the GeoPackage
gdf = gpd.read_file(gpkg_path)

# Reproject to EPSG:3857 (Web Mercator)
# Change the number according to the local re-projection (32629)
gdf_3857 = gdf.to_crs(epsg=3857)

# Save to a new GeoPackage
# Change the number according to the local re-projection (32629)
output_path = r"D:\Dropbox\LoGRI\Sierra_Leone\data\GIS\Kenema\kenema_roftops_2025_mapping_3857.gpkg"
gdf_3857.to_file(output_path, driver="GPKG")

print("✅ Reprojection done. Saved to:", output_path)



