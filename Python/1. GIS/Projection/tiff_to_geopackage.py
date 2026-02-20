import subprocess
import os

def convert_tiff_to_geopackage(input_tiff, output_gpkg):
    """
    Convertit un fichier TIFF en GeoPackage SANS PERTE DE QUALITÉ
    
    Args:
        input_tiff: Chemin du fichier TIFF source
        output_gpkg: Chemin du fichier GeoPackage de sortie
    """
    
    print("=== CONVERSION TIFF → GEOPACKAGE (SANS PERTE) ===\n")
    
    # Vérifier que le fichier source existe
    if not os.path.exists(input_tiff):
        print(f"✗ Fichier non trouvé : {input_tiff}")
        return
    
    size_mb = os.path.getsize(input_tiff) / (1024 * 1024)
    print(f"✓ Fichier source : {os.path.basename(input_tiff)} ({size_mb:.2f} MB)")
    
    # Créer le dossier de sortie si nécessaire
    output_dir = os.path.dirname(output_gpkg)
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
        print(f"✓ Dossier créé : {output_dir}")
    
    # Script de conversion SANS PERTE
    script_content = '''# -*- coding: utf-8 -*-
from osgeo import gdal
gdal.UseExceptions()

input_tiff = r"{input}"
output_gpkg = r"{output}"

print("Conversion SANS PERTE en cours...")

try:
    # Conversion avec qualité maximale (PNG sans perte)
    translate_options = gdal.TranslateOptions(
        format='GPKG',
        creationOptions=[
            'RASTER_TABLE=imagery',      # Nom de la table raster
            'APPEND_SUBDATASET=YES',     # Permet d'ajouter d'autres couches
            'TILE_FORMAT=PNG',           # PNG = SANS PERTE (lossless)
            'QUALITY=100'                # Qualité maximale à 100%
        ]
    )
    
    result = gdal.Translate(output_gpkg, input_tiff, options=translate_options)
    
    if result:
        print("✓ Conversion reussie - Qualite preservee a 100%")
    else:
        print("✗ Erreur lors de la conversion")
        
except Exception as e:
    print("Erreur : " + str(e))
'''.format(
        input=input_tiff.replace('\\', '\\\\'),
        output=output_gpkg.replace('\\', '\\\\')
    )
    
    # Sauvegarder le script temporaire
    script_path = r"C:\Users\robin\temp_tiff_to_gpkg_lossless.py"
    with open(script_path, "w", encoding="utf-8") as f:
        f.write(script_content)
    
    print("\n🔒 QUALITÉ : 100% PRÉSERVÉE (PNG sans perte)")
    print("⏱️  Temps estimé : 15-30 minutes")
    print("💾 Taille : Le fichier sera plus volumineux que le TIFF\n")
    
    # Exécuter avec Python de QGIS
    python_qgis = r"D:\Logiciels\QGIS 3.40\bin\python-qgis.bat"
    
    result = subprocess.run(
        [python_qgis, script_path],
        capture_output=True,
        text=True,
        encoding='utf-8'
    )
    
    print(result.stdout)
    
    # Vérifier le résultat
    if os.path.exists(output_gpkg):
        size_mb = os.path.getsize(output_gpkg) / (1024 * 1024)
        size_gb = size_mb / 1024
        print(f"\n✓ CONVERSION RÉUSSIE (QUALITÉ 100%)")
        print(f"  Fichier : {output_gpkg}")
        if size_gb > 1:
            print(f"  Taille : {size_gb:.2f} GB")
        else:
            print(f"  Taille : {size_mb:.2f} MB")
        print(f"  Format tuiles : PNG (sans perte)")
    else:
        print("\n✗ Erreur : fichier GeoPackage non créé")
    
    # Nettoyer
    if os.path.exists(script_path):
        os.remove(script_path)


# UTILISATION
input_tiff = r"D:\Dropbox\LoGRI\Sierra_Leone\data\3_Final\geopackage_polygons\kenema_match_2025.tiff"
output_gpkg = r"D:\Dropbox\LoGRI\Sierra_Leone\data\3_Final\geopackage_polygons\kenema_match_2025.gpkg"

convert_tiff_to_geopackage(input_tiff, output_gpkg)