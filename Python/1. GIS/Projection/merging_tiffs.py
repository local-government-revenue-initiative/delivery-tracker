import subprocess
import os

def merge_tiff_files_lossless(input_files, output_file):
    """
    Fusionne plusieurs fichiers TIFF sans compression (qualité maximale)
    """
    
    print("=== VERIFICATION DES FICHIERS ===")
    for f in input_files:
        if not os.path.exists(f):
            print(f"✗ Fichier non trouvé : {f}")
            return
        else:
            size_mb = os.path.getsize(f) / (1024 * 1024)
            print(f"✓ {os.path.basename(f)} ({size_mb:.2f} MB)")
    
    # Créer le dossier de sortie
    output_dir = os.path.dirname(output_file)
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    # Script Python pour la fusion
    script_content = '''# -*- coding: utf-8 -*-
from osgeo import gdal
gdal.UseExceptions()

input_files = {input_files}
output_file = r"{output}"

print("Fusion sans compression...")

try:
    vrt = gdal.BuildVRT("", input_files)
    
    # SANS COMPRESS pour qualité maximale
    translate_options = gdal.TranslateOptions(
        format='GTiff',
        creationOptions=['TILED=YES', 'BIGTIFF=YES']
    )
    
    result = gdal.Translate(output_file, vrt, options=translate_options)
    
    if result:
        print("Fusion reussie!")
    else:
        print("Erreur")
        
except Exception as e:
    print("Erreur : " + str(e))
'''.format(
        input_files=str([f.replace('\\', '\\\\') for f in input_files]),
        output=output_file.replace('\\', '\\\\')
    )
    
    script_path = r"C:\Users\robin\temp_merge_lossless.py"
    with open(script_path, "w", encoding="utf-8") as f:
        f.write(script_content)
    
    print("\n=== FUSION SANS PERTE ===")
    print("Patientez... (fichier final sera volumineux)")
    
    python_qgis = r"D:\Logiciels\QGIS 3.40\bin\python-qgis.bat"
    result = subprocess.run([python_qgis, script_path], capture_output=True, text=True, encoding='utf-8')
    
    print(result.stdout)
    
    if os.path.exists(output_file):
        size_mb = os.path.getsize(output_file) / (1024 * 1024)
        print(f"\n✓ Fichier créé : {size_mb:.2f} MB")
    
    os.remove(script_path)


# UTILISATION
input_files = [
    r"D:\Dropbox\LoGRI\Sierra_Leone\data\2_Build\geopackage_polygons\Kenema\240144_Sierra_Leone_Kenema.tiff",
    r"D:\Dropbox\LoGRI\Sierra_Leone\data\1_Raw\geopackage_polygons\Kenema\Kenema_remaining_section.tiff"
]

output_file = r"D:\Dropbox\LoGRI\Sierra_Leone\data\3_Final\geopackage_polygons\kenema_match_2025.tiff"  # Extension .tiff

merge_tiff_files_lossless(input_files, output_file)