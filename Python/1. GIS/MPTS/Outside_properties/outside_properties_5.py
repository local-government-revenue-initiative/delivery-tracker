import pandas as pd

# Chemin du fichier
file_path = r"D:\LoGRI Dropbox\Robin Benabid Jegaden\LoGRI\Sierra_Leone\data\1_Raw\new_boundaries\Freetown\properties_outside_wards_with_values.csv"

# Lire le fichier CSV
df = pd.read_csv(file_path)

# Afficher les types de propriétés uniques pour vérification
print("Types de propriétés dans le fichier:")
print(df['property_type'].value_counts())
print("\n" + "="*50 + "\n")

# Filtrer selon les critères
# Commercial: >= 5000
# Domestic ou Institutional: >= 8000

commercial_filter = (df['property_type'] == 'Commercial') & (df['assessed_annual_value_dynamic'] >= 5000)
domestic_filter = (df['property_type'] == 'Domestic') & (df['assessed_annual_value_dynamic'] >= 8000)
institutional_filter = (df['property_type'] == 'Institutional') & (df['assessed_annual_value_dynamic'] >= 8000)

# Combiner les filtres
df_filtered = df[commercial_filter | domestic_filter | institutional_filter]

# Trier par valeur décroissante
df_filtered = df_filtered.sort_values('assessed_annual_value_dynamic', ascending=False)

# Afficher les résultats
print(f"Nombre total de propriétés hors wards: {len(df)}")
print(f"Nombre de propriétés répondant aux critères: {len(df_filtered)}")
print("\nRépartition par type:")
print(df_filtered['property_type'].value_counts())
print("\n" + "="*50 + "\n")

# Afficher les propriétés
print("Liste des propriétés:")
print(df_filtered[['property', 'property_type', 'assessed_annual_value_dynamic']].to_string(index=False))

# Sauvegarder la liste filtrée
output_path = file_path.replace('.csv', '_high_value.csv')
df_filtered.to_csv(output_path, index=False)

print(f"\n\nFichier sauvegardé: {output_path}")

# Statistiques supplémentaires
print("\n" + "="*50)
print("STATISTIQUES:")
print(f"Valeur totale: {df_filtered['assessed_annual_value_dynamic'].sum():,.2f}")
print(f"Valeur moyenne: {df_filtered['assessed_annual_value_dynamic'].mean():,.2f}")
print(f"Valeur médiane: {df_filtered['assessed_annual_value_dynamic'].median():,.2f}")
print(f"Valeur max: {df_filtered['assessed_annual_value_dynamic'].max():,.2f}")
print(f"Valeur min: {df_filtered['assessed_annual_value_dynamic'].min():,.2f}")

