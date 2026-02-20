import pandas as pd

# Chemins des fichiers
base_path = r"D:\LoGRI Dropbox\Robin Benabid Jegaden\LoGRI\Sierra_Leone\data\1_Raw\new_boundaries\Freetown"

# Lire les deux fichiers CSV
df_properties = pd.read_csv(f"{base_path}\\properties_outside_wards.csv")
df_values = pd.read_csv(f"{base_path}\\freetown_prd_property_assessed_values_08_09_2025 1(in)_modified.csv")

# Afficher les colonnes pour vérification
print("Colonnes dans properties_outside_wards:", df_properties.columns.tolist())
print("Colonnes dans le CSV des valeurs:", df_values.columns.tolist())
print(f"\nNombre de propriétés hors wards: {len(df_properties)}")
print(f"Nombre de propriétés dans CSV valeurs: {len(df_values)}")

# Joindre les données sur la colonne 'property'
df_merged = df_properties.merge(
    df_values[['property', 'assessed_annual_value_dynamic']], 
    on='property', 
    how='left'
)

# Statistiques de la jointure
print(f"\nNombre de propriétés après jointure: {len(df_merged)}")
print(f"Propriétés avec valeur non-nulle: {df_merged['assessed_annual_value_dynamic'].notna().sum()}")
print(f"Propriétés avec valeur nulle: {df_merged['assessed_annual_value_dynamic'].isna().sum()}")

# Sauvegarder le résultat
df_merged.to_csv(f"{base_path}\\properties_outside_wards_with_values.csv", index=False)

print(f"\nFichier sauvegardé: {base_path}\\properties_outside_wards_with_values.csv")
print("\nAperçu des premières lignes:")
print(df_merged[['property', 'assessed_annual_value_dynamic']].head(10))
