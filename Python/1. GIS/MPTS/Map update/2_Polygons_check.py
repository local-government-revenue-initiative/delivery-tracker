"""
Flag properties with different area, plus_code, point_lat, point_lng between two CSV files.
Outputs: CSV with flagged differences.
"""
import pandas as pd
from pathlib import Path

# --- File paths ---
CSV1 = r"D:\LoGRI Dropbox\LoGRI Master Folder\2. Projects\2. Country Projects\9. Sierra Leone\12. Data\1. Raw\map_update\Freetown\freetown_polygons_04_02_2026.csv"
CSV2 = r"D:\LoGRI Dropbox\LoGRI Master Folder\2. Projects\2. Country Projects\9. Sierra Leone\12. Data\3. Final\map_update\Freetown\freetown_polygons_04_02_2026_georef.csv"
OUTPUT = r"D:\LoGRI Dropbox\LoGRI Master Folder\2. Projects\2. Country Projects\9. Sierra Leone\12. Data\3. Final\map_update\Freetown\freetown_polygon_differences_flagged.csv"

# Columns to compare
COLS_TO_COMPARE = ['area', 'plus_code', 'point_lat', 'point_lng']

print("Reading CSV files...")
df1 = pd.read_csv(CSV1, sep=None, engine="python")
df2 = pd.read_csv(CSV2, sep=None, engine="python")

print("Merging on property_code_assigned...")
merged = df1.merge(df2, on='property_code_assigned', how='inner', suffixes=('_raw', '_final'))

print("Comparing columns...")
# Flag differences for each column
for col in COLS_TO_COMPARE:
    col1, col2 = f'{col}_raw', f'{col}_final'
    merged[f'{col}_diff'] = merged[col1] != merged[col2]

# Overall flag: any difference
merged['has_difference'] = merged[[f'{col}_diff' for col in COLS_TO_COMPARE]].any(axis=1)

# Filter to only rows with differences
flagged = merged[merged['has_difference']].copy()

print(f"\n✅ Found {len(flagged)} properties with differences out of {len(merged)} matched.")

# Save results
Path(OUTPUT).parent.mkdir(parents=True, exist_ok=True)
flagged.to_csv(OUTPUT, index=False)
print(f"📁 Saved to: {OUTPUT}")

# Summary
if len(flagged) > 0:
    print("\n📊 Differences by column:")
    for col in COLS_TO_COMPARE:
        diff_count = flagged[f'{col}_diff'].sum()
        print(f"  - {col}: {diff_count} different")