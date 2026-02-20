"""
Business License Categories Analysis - Error Detection
LoGRI Project - Sierra Leone / Freetown
Author: Robin Benabid Jégaden
Date: 2026-01-20

Purpose: Identify businesses where category has changed between 2025 and 2026
"""

import pandas as pd
from pathlib import Path

# Chemins
raw = Path(r'D:\LoGRI Dropbox\LoGRI Master Folder\2. Projects\2. Country Projects\9. Sierra Leone\12. Data\1. Raw\business_error\Freetown')
build = Path(r'D:\LoGRI Dropbox\LoGRI Master Folder\2. Projects\2. Country Projects\9. Sierra Leone\12. Data\2. Build\business_error\Freetown')
build.mkdir(parents=True, exist_ok=True)

# Charger et joindre les données sur Property Code ET Business Name
df = pd.read_csv(raw / 'business_list_book_2026-01-20T10_31_18.634017625Z.csv').merge(
    pd.read_excel(raw / 'business_rate_book_and_valuation_list_20-Jan-2026.xlsx', skiprows=1),
    left_on=['Associated Property', 'Business'], 
    right_on=['Property Code', 'Business Name'], 
    how='inner'
)[['License Code', 'Associated Property', 'Business', 'Business Category', 'Industry']].drop_duplicates()

# Nettoyer les espaces dans les colonnes texte
df['Business Category'] = df['Business Category'].str.strip()
df['Industry'] = df['Industry'].str.strip()

# Analyser et exporter avec exceptions Manufacturing/Materials et Unassigned
df['Match'] = (df['Business Category'] == df['Industry']) | \
              ((df['Business Category'] == 'Manufacturing, Industry and Services') & (df['Industry'] == 'Materials')) | \
              (df['Industry'] == 'Unassigned')
print(f"Concordance: {df['Match'].sum()}/{len(df)} ({df['Match'].mean()*100:.1f}%)")
manufacturing_materials = ((df['Business Category'] == 'Manufacturing, Industry and Services') & (df['Industry'] == 'Materials')).sum()
unassigned = (df['Industry'] == 'Unassigned').sum()
print(f"Cas Manufacturing/Materials traités comme Match: {manufacturing_materials}")
print(f"Cas Industry=Unassigned traités comme Match: {unassigned}")
df.to_csv(build / 'category_comparison.csv', index=False)
print(f"\nFichier exporté: {build / 'category_comparison.csv'}")
print(f"\nExemples de différences:\n{df[~df['Match']].head(10)}")