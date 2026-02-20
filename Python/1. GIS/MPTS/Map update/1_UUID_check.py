import pandas as pd

# Load CSV files
georef = pd.read_csv(r"D:\LoGRI Dropbox\LoGRI Master Folder\2. Projects\2. Country Projects\9. Sierra Leone\12. Data\3. Final\map_update\Freetown\freetown_polygons_04_02_2026_georef.csv")
raw = pd.read_csv(r"D:\LoGRI Dropbox\LoGRI Master Folder\2. Projects\2. Country Projects\9. Sierra Leone\12. Data\1. Raw\map_update\Freetown\freetown_polygons_04_02_2026.csv")

# Get unique property codes
georef_codes = set(georef['property_code_assigned'].dropna())
raw_codes = set(raw['property_code_assigned'].dropna())

# Display results
print(f"Georef file: {len(georef_codes)} unique property codes")
print(f"Raw file: {len(raw_codes)} unique property codes")
print(f"\nCodes in georef but NOT in raw: {len(georef_codes - raw_codes)}")
print(f"Codes in raw but NOT in georef: {len(raw_codes - georef_codes)}")
print(f"Codes in BOTH files: {len(georef_codes & raw_codes)}")

# Optional: Show the differences
if len(georef_codes - raw_codes) > 0:
    print(f"\nSample codes only in georef (max 10): {list(georef_codes - raw_codes)[:10]}")
if len(raw_codes - georef_codes) > 0:
    print(f"Sample codes only in raw (max 10): {list(raw_codes - georef_codes)[:10]}")