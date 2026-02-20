"""
Script to check the Coordinate Reference System (CRS) of a GeoPackage (.gpkg) file.

- Reads the GeoPackage using GeoPandas
- Prints the detected CRS
- Provides additional details (full CRS name and EPSG code) if available
"""

import geopandas as gpd

# 🔁 Replace with the path to your file
gpkg_path = r"D:\Dropbox\LoGRI\Sierra_Leone\data\GIS\Kenema\kenema_roftops_2025_mapping.gpkg"

# Read the GeoPackage
gdf = gpd.read_file(gpkg_path)

# Print the CRS
print("Detected CRS:", gdf.crs)

# Print more detailed information if available
if gdf.crs:
    print("Full name:", gdf.crs.to_string())
    print("EPSG code:", gdf.crs.to_epsg())
else:
    print("⚠️ No CRS defined in this file")



