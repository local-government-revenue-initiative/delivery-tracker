import subprocess
import os

def convert_and_merge_lossless(input_ecw, input_tiff, output_file):
    """
    Convertit un ECW en TIFF puis fusionne avec un autre TIFF sans compression
    
    Args:
        input_ecw: Fichier ECW source
        input_tiff: Fichier TIFF existant
        output_file: Fichier TIFF de sortie fusionné
    """
    
    print("="*60)
    print("ETAPE 1 : CONVERSION ECW → TIFF (SANS COMPRESSION)")
    print("="*60)
    
    # Fichier TIFF temporaire depuis ECW
    temp_tiff = r"D:\Dropbox\LoGRI\Sierra_Leone\data\2_Build\geopackage_polygons\Kenema\240144_temp_uncompressed.tiff"
    
    # Script de conversion SANS compression
    convert_script = '''# -*- coding: utf-8 -*-
from osgeo import gdal
gdal.UseExceptions()

input_ecw = r"{input}"
output_tiff = r"{output}"

print("Conversion ECW en TIFF non compresse...")

try:
    result = gdal.Translate(
        output_tiff, 
        input_ecw, 
        format='GTiff', 
        creationOptions=[
            'TILED=YES',      # Organisation en tuiles (performance)
            'BIGTIFF=YES'     # Support fichiers > 4GB
            # PAS DE COMPRESS = qualité maximale
        ]
    )
    if result:
        print("✓ Conversion reussie")
    else:
        print("✗ Erreur conversion")
except Exception as e:
    print("Erreur : " + str(e))
'''.format(input=input_ecw.replace('\\', '\\\\'), 
           output=temp_tiff.replace('\\', '\\\\'))
    
    script_path = r"C:\Users\robin\temp_convert.py"
    with open(script_path, "w", encoding="utf-8") as f:
        f.write(convert_script)
    
    python_qgis = r"D:\Logiciels\QGIS 3.40\bin\python-qgis.bat"
    
    print("Patientez... (peut prendre 5-10 minutes)")
    result = subprocess.run([python_qgis, script_path], capture_output=True, text=True, encoding='utf-8')
    print(result.stdout)
    
    os.remove(script_path)
    
    if not os.path.exists(temp_tiff):
        print("✗ Erreur : fichier temporaire non créé")
        return
    
    size_mb = os.path.getsize(temp_tiff) / (1024 * 1024)
    print(f"✓ Fichier temporaire créé : {size_mb:.2f} MB")
    
    print("\n" + "="*60)
    print("ETAPE 2 : FUSION DES DEUX TIFF (SANS COMPRESSION)")
    print("="*60)
    
    # Créer le dossier de sortie
    output_dir = os.path.dirname(output_file)
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
        print(f"✓ Dossier créé : {output_dir}")
    
    # Script de fusion SANS compression
    merge_script = '''# -*- coding: utf-8 -*-
from osgeo import gdal
gdal.UseExceptions()

input_files = {input_files}
output_file = r"{output}"

print("Fusion des TIFF sans compression...")
print(f"Fichier 1 : {{input_files[0]}}")
print(f"Fichier 2 : {{input_files[1]}}")

try:
    # Créer un VRT (Virtual Raster)
    vrt = gdal.BuildVRT("", input_files)
    
    # Convertir le VRT en TIFF SANS compression
    translate_options = gdal.TranslateOptions(
        format='GTiff',
        creationOptions=[
            'TILED=YES',
            'BIGTIFF=YES'
            # PAS DE COMPRESS = qualité maximale
        ]
    )
    
    result = gdal.Translate(output_file, vrt, options=translate_options)
    
    if result:
        print("✓ Fusion reussie")
    else:
        print("✗ Erreur fusion")
        
except Exception as e:
    print("Erreur : " + str(e))
'''.format(
        input_files=str([temp_tiff.replace('\\', '\\\\'), input_tiff.replace('\\', '\\\\')]),
        output=output_file.replace('\\', '\\\\')
    )
    
    script_path = r"C:\Users\robin\temp_merge.py"
    with open(script_path, "w", encoding="utf-8") as f:
        f.write(merge_script)
    
    print("Patientez... (peut prendre 10-20 minutes)")
    result = subprocess.run([python_qgis, script_path], capture_output=True, text=True, encoding='utf-8')
    print(result.stdout)
    
    os.remove(script_path)
    
    if os.path.exists(output_file):
        size_mb = os.path.getsize(output_file) / (1024 * 1024)
        size_gb = size_mb / 1024
        print(f"\n✓ FICHIER FINAL CRÉÉ")
        print(f"  Emplacement : {output_file}")
        print(f"  Taille : {size_gb:.2f} GB")
        print(f"  Qualité : MAXIMALE (non compressé)")
        
        # Nettoyer le fichier temporaire
        if os.path.exists(temp_tiff):
            os.remove(temp_tiff)
            print(f"  Fichier temporaire supprimé")
    else:
        print("\n✗ Erreur : fichier final non créé")


# UTILISATION
input_ecw = r"D:\Dropbox\LoGRI\Sierra_Leone\data\1_Raw\geopackage_polygons\Kenema\Kenema LiDar Image\240144_Sierra_Leone_Kenema_1-5_compression_ratio.ecw"
input_tiff = r"D:\Dropbox\LoGRI\Sierra_Leone\data\1_Raw\geopackage_polygons\Kenema\Kenema_remaining_section.tiff"
output_file = r"D:\Dropbox\LoGRI\Sierra_Leone\data\3_Final\geopackage_polygons\kenema_match_2025.tiff"

convert_and_merge_lossless(input_ecw, input_tiff, output_file)