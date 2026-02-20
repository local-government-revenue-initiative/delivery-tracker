import pandas as pd

# Charger les fichiers
differences = pd.read_csv(r"D:\LoGRI Dropbox\LoGRI Master Folder\2. Projects\2. Country Projects\9. Sierra Leone\12. Data\3. Final\map_update\Freetown\FCC_properties_differences.csv")
valuation = pd.read_csv(r"D:\LoGRI Dropbox\LoGRI Master Folder\2. Projects\2. Country Projects\9. Sierra Leone\12. Data\1. Raw\map_update\Freetown\valuation_and_rate_book_2026.csv")

# Dédupliquer valuation sur property_code_assigned (garder la première occurrence)
valuation_unique = valuation[['property_code_assigned', 'Status']].drop_duplicates(subset='property_code_assigned', keep='first')

# Merger pour ajouter la colonne Status
result = differences.merge(
    valuation_unique, 
    on='property_code_assigned', 
    how='left'
)

# Sauvegarder le résultat
result.to_csv(r"D:\LoGRI Dropbox\LoGRI Master Folder\2. Projects\2. Country Projects\9. Sierra Leone\12. Data\3. Final\map_update\Freetown\FCC_properties_differences.csv", index=False)

# Afficher le résumé
print(f"Total propriétés: {len(result)}")
print(f"Status trouvé: {result['Status'].notna().sum()}")
print(f"Status manquant: {result['Status'].isna().sum()}")
print(f"\nValeurs de Status:\n{result['Status'].value_counts(dropna=False)}")