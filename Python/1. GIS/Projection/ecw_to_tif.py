import subprocess
import os

def convert_ecw_to_tiff_lossless(input_ecw, output_tiff):
    """
    Convertit un fichier ECW en TIFF sans compression (qualité maximale)
    
    Args:
        input_ecw: Chemin complet du fichier ECW
        output_tiff: Chemin complet du fichier TIFF de sortie
    """
    
    # Script Python pour QGIS
    script_content = '''# -*- coding: utf-8 -*-
from osgeo import gdal
gdal.UseExceptions()

input_ecw = r"{input}"
output_tiff = r"{output}"

try:
    # Conversion SANS compression pour qualité maximale
    result = gdal.Translate(
        output_tiff, 
        input_ecw, 
        format='GTiff', 
        creationOptions=['TILED=YES', 'BIGTIFF=YES']  # Pas de COMPRESS
    )
    if result:
        print("Conversion reussie (sans perte) : " + output_tiff)
    else:
        print("Erreur lors de la conversion")
except Exception as e:
    print("Erreur : " + str(e))
'''.format(input=input_ecw.replace('\\', '\\\\'), 
           output=output_tiff.replace('\\', '\\\\'))
    
    # Sauvegarder le script temporaire
    script_path = r"C:\Users\robin\temp_convert_ecw_lossless.py"
    with open(script_path, "w", encoding="utf-8") as f:
        f.write(script_content)
    
    # Exécuter avec Python de QGIS
    python_qgis = r"D:\Logiciels\QGIS 3.40\bin\python-qgis.bat"
    
    print(f"Conversion SANS PERTE de : {os.path.basename(input_ecw)}")
    print("Patientez... (fichier sera plus volumineux)")
    
    result = subprocess.run(
        [python_qgis, script_path], 
        capture_output=True, 
        text=True, 
        encoding='utf-8'
    )
    
    print(result.stdout)
    
    # Vérifier le fichier créé
    if os.path.exists(output_tiff):
        size_mb = os.path.getsize(output_tiff) / (1024 * 1024)
        print(f"\n✓ Fichier créé : {size_mb:.2f} MB")
    
    # Nettoyer
    os.remove(script_path)


# UTILISATION
input_ecw = r"D:\Dropbox\LoGRI\Sierra_Leone\data\1_Raw\geopackage_polygons\Kenema\Kenema LiDar Image\240144_Sierra_Leone_Kenema_1-5_compression_ratio.ecw"
output_tiff = r"D:\Dropbox\LoGRI\Sierra_Leone\data\2_Build\geopackage_polygons\Kenema\240144_Sierra_Leone_Kenema.tiff"  # Extension .tiff

convert_ecw_to_tiff_lossless(input_ecw, output_tiff)