import pandas as pd

# Fichiers à comparer
raw_file = r"D:\LoGRI Dropbox\LoGRI Master Folder\2. Projects\2. Country Projects\9. Sierra Leone\12. Data\1. Raw\map_update\Freetown\FCC_layers_properties_04_02_2026.csv"
build_file = r"D:\LoGRI Dropbox\LoGRI Master Folder\2. Projects\2. Country Projects\9. Sierra Leone\12. Data\2. Build\map_update\Freetown\FCC_layers_properties_05_02_2026.csv"
output_dir = r"D:\LoGRI Dropbox\LoGRI Master Folder\2. Projects\2. Country Projects\9. Sierra Leone\12. Data\3. Final\map_update\Freetown"

print(f"\n{'='*60}")
print(f"Vérification: Freetown properties")
print('='*60)

# Lire les fichiers - sélectionner uniquement les colonnes nécessaires
raw = pd.read_csv(raw_file)[['property_code_assigned', 'layer_name', 'label']]
build = pd.read_csv(build_file)[['property_code_assigned', 'layer_name', 'label']]

# Convertir label en format texte pour les deux fichiers
raw['label'] = raw['label'].astype(str)
build['label'] = build['label'].astype(str)

# Merger sur property_code_assigned ET layer_name
merged = raw.merge(build, on=['property_code_assigned', 'layer_name'], suffixes=('_pre', '_post'), how='outer')

# Remplacer NaN par "missing"
merged['label_pre'] = merged['label_pre'].fillna('missing')
merged['label_post'] = merged['label_post'].fillna('missing')

# Identifier UNIQUEMENT les différences réelles
diff = merged[merged['label_pre'] != merged['label_post']].copy()

# Afficher les résultats
if len(diff) > 0:
    print(f"\n{len(diff)} lignes avec des labels différents")
    
    # Restructurer : une ligne par property_code_assigned
    restructured = []
    for prop_code in diff['property_code_assigned'].unique():
        prop_data = diff[diff['property_code_assigned'] == prop_code].reset_index(drop=True)
        row = {'property_code_assigned': prop_code}
        
        for idx, row_data in prop_data.iterrows():
            suffix = f"_{idx+1}" if idx > 0 else ""
            row[f'layer_name{suffix}'] = row_data['layer_name']
            row[f'label_pre{suffix}'] = row_data['label_pre']
            row[f'label_post{suffix}'] = row_data['label_post']
        
        restructured.append(row)
    
    result = pd.DataFrame(restructured)
    
    print(f"\n{len(result)} property codes uniques avec des labels différents:\n")
    print(result)
    
    # Exporter en CSV
    output_path = f"{output_dir}\\FCC_property_layer_differences.csv"
    result.to_csv(output_path, index=False)
    print(f"\nFichier 'FCC_property_layer_differences.csv' créé dans Final.")
    
    # Compter les UUID uniques
    print(f"\nNombre d'UUID uniques (property_code_assigned): {len(result)}")
else:
    print("\nAucune différence détectée. Tous les labels correspondent.")

print(f"\n{'='*60}")
print("Vérification terminée.")
print('='*60)