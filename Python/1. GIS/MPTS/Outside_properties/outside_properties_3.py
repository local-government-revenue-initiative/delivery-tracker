import pandas as pd

# Chemin du fichier
file_path = r"D:\LoGRI Dropbox\Robin Benabid Jegaden\LoGRI\Sierra_Leone\data\1_Raw\new_boundaries\Freetown\freetown_prd_property_assessed_values_08_09_2025 1(in).csv"

# Lire le fichier CSV
df = pd.read_csv(file_path)

# Ajouter "FCC" avec padding de zéros pour obtenir 10 caractères
df['property'] = df['property'].apply(lambda x: f"FCC{str(x).zfill(7)}")

# Sauvegarder le fichier modifié
output_path = file_path.replace(".csv", "_modified.csv")
df.to_csv(output_path, index=False)

print(f"Fichier modifié sauvegardé: {output_path}")
print(f"Exemple de valeurs: {df['property'].head().tolist()}")

