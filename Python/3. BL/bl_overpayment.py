"""
Business License Payment Analysis - Error Detection
LoGRI Project - Sierra Leone / Freetown
Author: Robin Benabid Jégaden
Date: 2026-01-20

Purpose: Identify businesses where total payments exceed total payables
"""

import pandas as pd
import numpy as np
from pathlib import Path
import sys

# ============================================================================
# CONFIGURATION
# ============================================================================

# Input file path
INPUT_FILE = r"D:\LoGRI Dropbox\LoGRI Master Folder\2. Projects\2. Country Projects\9. Sierra Leone\12. Data\1. Raw\business_error\Freetown\business_license_payments_2026-01-20T09_36_28.472965105Z.csv"

# Output directory
OUTPUT_DIR = r"D:\LoGRI Dropbox\LoGRI Master Folder\2. Projects\2. Country Projects\9. Sierra Leone\12. Data\2. Build\business_error\Freetown"

# Output filename
OUTPUT_FILE = "businesses_overpayment_errors.csv"

# Tolerance margin (do not flag if difference <= this amount)
TOLERANCE_MARGIN = 25

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def clean_currency(value):
    """
    Convert currency string to float.
    Handles various formats: '$1,234.56', '1234.56', etc.
    
    Args:
        value: String or numeric value
        
    Returns:
        float: Cleaned numeric value
    """
    if pd.isna(value):
        return 0.0
    
    if isinstance(value, (int, float)):
        return float(value)
    
    # Remove currency symbols, commas, and whitespace
    cleaned = str(value).replace('$', '').replace(',', '').strip()
    
    try:
        return float(cleaned)
    except ValueError:
        return 0.0


# ============================================================================
# MAIN ANALYSIS
# ============================================================================

def main():
    """Main analysis function"""
    
    print("="*80)
    print("Business License Payment Error Analysis")
    print("="*80)
    print()
    
    # ------------------------------------------------------------------------
    # 1. Load Data
    # ------------------------------------------------------------------------
    print("Step 1: Loading data...")
    try:
        df = pd.read_csv(INPUT_FILE, encoding='utf-8')
        print(f"   ✓ Successfully loaded {len(df):,} records")
        print(f"   ✓ Columns: {', '.join(df.columns)}")
        print()
    except FileNotFoundError:
        print(f"   ✗ ERROR: File not found at {INPUT_FILE}")
        sys.exit(1)
    except Exception as e:
        print(f"   ✗ ERROR loading file: {e}")
        sys.exit(1)
    
    # ------------------------------------------------------------------------
    # 2. Clean and Convert Currency Columns
    # ------------------------------------------------------------------------
    print("Step 2: Cleaning currency columns...")
    
    # Apply cleaning function to monetary columns
    df['Total_Payable_Clean'] = df['Total Payable'].apply(clean_currency)
    df['Payment_Amount_Clean'] = df['Payment  Amount'].apply(clean_currency)
    
    print(f"   ✓ Converted 'Total Payable' column")
    print(f"   ✓ Converted 'Payment Amount' column")
    print()
    
    # ------------------------------------------------------------------------
    # 3. Group by License Code and Calculate Sums
    # ------------------------------------------------------------------------
    print("Step 3: Aggregating by License Code...")
    
    # Group by License Code and sum the cleaned amounts
    grouped = df.groupby('License Code').agg({
        'Total_Payable_Clean': 'sum',
        'Payment_Amount_Clean': 'sum',
        'Business': 'first',  # Get business name (assuming one business per license)
        'License Type': 'first',
        'Business Category': 'first',
        'Business Sub Category': 'first'
    }).reset_index()
    
    # Rename columns for clarity
    grouped.columns = [
        'License_Code',
        'Sum_Total_Payable',
        'Sum_Payment_Amount',
        'Business_Name',
        'License_Type',
        'Business_Category',
        'Business_Sub_Category'
    ]
    
    print(f"   ✓ Aggregated {len(grouped):,} unique License Codes")
    print()
    
    # ------------------------------------------------------------------------
    # 4. Identify Overpayment Errors
    # ------------------------------------------------------------------------
    print("Step 4: Identifying overpayment errors...")
    print(f"   ℹ Using tolerance margin: ${TOLERANCE_MARGIN:.2f}")
    
    # Filter for cases where Payment Amount > Total Payable + TOLERANCE_MARGIN
    # Only flag if the overpayment exceeds the tolerance threshold
    errors = grouped[
        grouped['Sum_Payment_Amount'] > (grouped['Sum_Total_Payable'] + TOLERANCE_MARGIN)
    ].copy()
    
    # Calculate the difference (overpayment amount)
    errors['Overpayment_Amount'] = errors['Sum_Payment_Amount'] - errors['Sum_Total_Payable']
    
    # Calculate percentage overpayment
    errors['Overpayment_Percentage'] = (
        (errors['Overpayment_Amount'] / errors['Sum_Total_Payable']) * 100
    ).round(2)
    
    # Sort by overpayment amount (descending)
    errors = errors.sort_values('Overpayment_Amount', ascending=False)
    
    print(f"   ✓ Found {len(errors):,} businesses with overpayments")
    
    if len(errors) > 0:
        total_overpayment = errors['Overpayment_Amount'].sum()
        print(f"   ✓ Total overpayment amount: ${total_overpayment:,.2f}")
        print(f"   ✓ Average overpayment: ${errors['Overpayment_Amount'].mean():,.2f}")
        print(f"   ✓ Maximum overpayment: ${errors['Overpayment_Amount'].max():,.2f}")
    print()
    
    # ------------------------------------------------------------------------
    # 5. Export Results
    # ------------------------------------------------------------------------
    print("Step 5: Exporting results...")
    
    # Create output directory if it doesn't exist
    output_path = Path(OUTPUT_DIR)
    output_path.mkdir(parents=True, exist_ok=True)
    
    # Full output file path
    output_file_path = output_path / OUTPUT_FILE
    
    # Export to CSV
    errors.to_csv(output_file_path, index=False, encoding='utf-8')
    
    print(f"   ✓ Results exported to:")
    print(f"     {output_file_path}")
    print()
    
    # ------------------------------------------------------------------------
    # 6. Summary Statistics
    # ------------------------------------------------------------------------
    print("="*80)
    print("SUMMARY")
    print("="*80)
    print(f"Total records processed:        {len(df):,}")
    print(f"Unique License Codes:           {len(grouped):,}")
    print(f"Businesses with overpayments:   {len(errors):,}")
    print(f"Error rate:                     {(len(errors)/len(grouped)*100):.2f}%")
    print()
    
    if len(errors) > 0:
        print("Top 5 overpayments by amount:")
        print("-" * 80)
        top_5 = errors.head(5)[['License_Code', 'Business_Name', 'Overpayment_Amount', 'Overpayment_Percentage']]
        for idx, row in top_5.iterrows():
            print(f"  {row['License_Code']}: {row['Business_Name'][:40]}")
            print(f"    Overpayment: ${row['Overpayment_Amount']:,.2f} ({row['Overpayment_Percentage']:.1f}%)")
        print()
    
    print("="*80)
    print("Analysis complete!")
    print("="*80)


# ============================================================================
# SCRIPT EXECUTION
# ============================================================================

if __name__ == "__main__":
    main()