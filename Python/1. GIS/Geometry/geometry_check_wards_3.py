import geopandas as gpd

# Lire
gdf = gpd.read_file(r"D:\Divers\Western Urban Wards.gpkg")

# Combler les gaps
gdf['geometry'] = gdf.geometry.buffer(0.00001).buffer(0)

# Exporter
gdf.to_file(r"D:\Divers\Western Urban Wards_1.gpkg", driver='GPKG')

print("✓ Fait !")