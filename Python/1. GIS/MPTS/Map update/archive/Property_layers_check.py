import pandas as pd

# Répertoires
raw_dir = r"D:\LoGRI Dropbox\LoGRI Master Folder\2. Projects\2. Country Projects\9. Sierra Leone\12. Data\1. Raw\map_update\Kenema"
build_dir = r"D:\LoGRI Dropbox\LoGRI Master Folder\2. Projects\2. Country Projects\9. Sierra Leone\12. Data\2. Build\map_update\Kenema"
output_dir = r"D:\LoGRI Dropbox\LoGRI Master Folder\2. Projects\2. Country Projects\9. Sierra Leone\12. Data\3. Final\map_update\Kenema"

# Fichiers à vérifier
files = [
    'Property_communities.csv',
    'Property_delivery_discovery.csv'
]

# Vérifier chaque fichier
for filename in files:
    print(f"\n{'='*60}")
    print(f"Vérification: {filename}")
    print('='*60)
    
    # Lire les fichiers
    raw = pd.read_csv(f"{raw_dir}\\{filename}")
    build = pd.read_csv(f"{build_dir}\\{filename}")
    
    # Merger sur property_code_assigned
    merged = raw.merge(build, on='property_code_assigned', suffixes=('_pre', '_post'))
    
    # Identifier les différences
    diff = merged[merged['label_pre'] != merged['label_post']]
    
    # Exclure z042-z043 pour Property_delivery_discovery
    if filename == 'Property_delivery_discovery.csv':
        diff = diff[~(
            ((diff['label_pre'] == 'z042') & (diff['label_post'] == 'z043')) |
            ((diff['label_pre'] == 'z043') & (diff['label_post'] == 'z042'))
        )]
    
    # Afficher les résultats
    if len(diff) > 0:
        print(f"\n{len(diff)} property codes avec des labels différents:\n")
        print(diff[['property_code_assigned', 'label_pre', 'label_post']])
        
        # Exporter en CSV dans le répertoire Final
        output_name = filename.replace('.csv', '_differences.csv')
        output_path = f"{output_dir}\\{output_name}"
        diff[['property_code_assigned', 'label_pre', 'label_post']].to_csv(output_path, index=False)
        print(f"\nFichier '{output_name}' créé dans Final.")
    else:
        print("\nAucune différence détectée. Tous les labels correspondent.")

print(f"\n{'='*60}")
print("Vérification terminée.")
print('='*60)