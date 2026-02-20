import pandas as pd

# Charger les données
excel_path = r"D:\LoGRI Dropbox\LoGRI Master Folder\2. Projects\2. Country Projects\9. Sierra Leone\12. Data\3. Final\map_update\Freetown\FCC_property_layer_differences.xlsx"
csv_path = r"D:\LoGRI Dropbox\LoGRI Master Folder\2. Projects\2. Country Projects\9. Sierra Leone\12. Data\1. Raw\map_update\Freetown\business_license_payments_2026.csv"
output_path = r"D:\LoGRI Dropbox\LoGRI Master Folder\2. Projects\2. Country Projects\9. Sierra Leone\12. Data\3. Final\map_update\Freetown\FCC_BL_internal.xlsx"

# Lire les fichiers
df_excel = pd.read_excel(excel_path, sheet_name=2)
df_csv = pd.read_csv(csv_path)

# Filtrer le CSV pour dates > 15/12/2025
df_csv['Payment Date'] = pd.to_datetime(df_csv['Payment Date'], format='mixed', dayfirst=True, errors='coerce')
df_csv = df_csv[df_csv['Payment Date'] > '2025-12-14']

# Comparer les property_code_assigned
excel_codes = set(df_excel['property_code_assigned'].dropna())
csv_codes = set(df_csv['property_code_assigned'].dropna())
codes_communs = excel_codes & csv_codes

# Filtrer Excel pour codes communs uniquement
df_output = df_excel[df_excel['property_code_assigned'].isin(codes_communs)]

# Exporter
df_output.to_excel(output_path, index=False)

print(f"Total codes dans Excel: {len(excel_codes)}")
print(f"Total codes dans CSV (après filtrage): {len(csv_codes)}")
print(f"Codes présents dans les deux: {len(codes_communs)}")
print(f"\nFichier exporté: {output_path}")
print(f"Nombre de lignes exportées: {len(df_output)}")