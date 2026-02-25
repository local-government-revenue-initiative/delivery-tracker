"""
Field Data Filter Script
========================

Filters field data observations based on defined criteria:
1. Created On missing
2. Updated On missing
3. Delivered On missing
4. Distance greater than 40 meters
5. Is Property At Correct Location is False
6. Not Delivered Reason is not missing
7. Proof of Delivery Path, RDN Image Path, or Signature Path are missing
8. Delivery Type mismatch (RDN ≠ Property Rates OR BUSINESS ≠ License Fees)
9. Gap > 2 hours between consecutive deliveries (same person, same day)

Note: Two productivity checks (delivery count < 50 and mean gap > 10min) are 
calculated for informational purposes but NOT used as filtering criteria.

Author: Robin Benabid Jégaden
Date: 2026-01-16
"""

import pandas as pd
from datetime import datetime
import sys
import os
import re


def parse_date(date_string):
    """Parse date string to date object (without time)."""
    if pd.isna(date_string) or date_string == '':
        return None
    try:
        dt = datetime.strptime(date_string, "%B %d, %Y, %H:%M")
        return dt.date()
    except (ValueError, AttributeError):
        return None


def parse_datetime(date_string):
    """Parse date string to datetime object (with time)."""
    if pd.isna(date_string) or date_string == '':
        return None
    try:
        return datetime.strptime(date_string, "%B %d, %Y, %H:%M")
    except (ValueError, AttributeError):
        return None


def calculate_productivity_flags(df, min_deliveries=50, max_mean_gap=10):
    """Calculate productivity flags based on fixed thresholds."""
    import numpy as np
    
    # Add columns
    df['Delivery_Count_Flag'] = ''
    df['Pace_Flag'] = ''
    df['Mean_Gap'] = 0.0
    df['Delivery_Count'] = 0
    df['Delivered_DateTime_temp'] = df['Delivered On'].apply(parse_datetime)
    df['Delivered_Date_temp'] = df['Delivered_DateTime_temp'].apply(lambda x: x.date() if pd.notna(x) else None)
    
    # Process day by day
    for date_val, day_df in df.groupby('Delivered_Date_temp'):
        if pd.isna(date_val):
            continue
        
        # Process each enumerator on this day
        for name, enum_group in day_df.groupby('Full name'):
            delivery_count = len(enum_group)
            
            if delivery_count > 2:
                enum_sorted = enum_group.sort_values('Delivered_DateTime_temp')
                
                gaps = []
                for i in range(1, len(enum_sorted)):
                    prev_dt = enum_sorted.iloc[i-1]['Delivered_DateTime_temp']
                    curr_dt = enum_sorted.iloc[i]['Delivered_DateTime_temp']
                    
                    if pd.notna(prev_dt) and pd.notna(curr_dt):
                        gap_minutes = (curr_dt - prev_dt).total_seconds() / 60
                        gaps.append(gap_minutes)
                
                if len(gaps) > 0:
                    mean_gap = np.mean(gaps)
                    count_flag = 'Low productivity' if delivery_count < min_deliveries else ''
                    pace_flag = 'Too slow' if mean_gap > max_mean_gap else ''
                    
                    for idx in enum_sorted.index:
                        df.loc[idx, 'Delivery_Count_Flag'] = count_flag
                        df.loc[idx, 'Pace_Flag'] = pace_flag
                        df.loc[idx, 'Mean_Gap'] = mean_gap
                        df.loc[idx, 'Delivery_Count'] = delivery_count
    
    df = df.drop(columns=['Delivered_DateTime_temp', 'Delivered_Date_temp'])
    return df


def filter_field_data(input_file, output_file):
    """Filter field data based on defined criteria."""
    print(f"Reading file: {input_file}")
    df = pd.read_csv(input_file)
    total_rows = len(df)
    print(f"Total observations: {total_rows}")
    
    conditions = []
    
    # 1. Created On missing
    print("\n1. Checking: Created On missing...")
    df['Created_Date'] = df['Created On'].apply(parse_date)
    c1 = df['Created_Date'].isna()
    conditions.append(c1)
    print(f"   Found: {c1.sum()}")
    
    # 2. Updated On missing
    print("\n2. Checking: Updated On missing...")
    df['Updated_Date'] = df['Updated On'].apply(parse_date)
    c2 = df['Updated_Date'].isna()
    conditions.append(c2)
    print(f"   Found: {c2.sum()}")
    
    # 3. Delivered On missing
    print("\n3. Checking: Delivered On missing...")
    df['Delivered_Date'] = df['Delivered On'].apply(parse_date)
    c3 = df['Delivered_Date'].isna()
    conditions.append(c3)
    print(f"   Found: {c3.sum()}")
    
    # 4. Distance > 40m
    print("\n4. Checking: Distance > 40m...")
    df['Distance_numeric'] = pd.to_numeric(df['Distance'], errors='coerce')
    c4 = df['Distance_numeric'] > 40
    conditions.append(c4)
    print(f"   Found: {c4.sum()}")
    
    # 5. Is Property At Correct Location = False
    print("\n5. Checking: Is Property At Correct Location = False...")
    c5 = df['Is Property At Correct Location'].astype(str).str.lower() == 'false'
    conditions.append(c5)
    print(f"   Found: {c5.sum()}")
    
    # 6. Not Delivered Reason is not missing
    print("\n6. Checking: Not Delivered Reason present...")
    c6 = df['Not Delivered Reason'].notna() & (df['Not Delivered Reason'] != '')
    conditions.append(c6)
    print(f"   Found: {c6.sum()}")
    
    # 7. Missing file paths
    print("\n7. Checking: Missing file paths...")
    c7 = ((df['Proof Of Delivery Path'].isna() | (df['Proof Of Delivery Path'] == '')) |
           (df['Rdn Image Path'].isna() | (df['Rdn Image Path'] == '')) |
           (df['Signature Path'].isna() | (df['Signature Path'] == '')))
    conditions.append(c7)
    print(f"   Found: {c7.sum()}")
    
    # 8. Delivery Type mismatch
    print("\n8. Checking: Delivery Type mismatch...")
    c8 = ((df['Delivery Type'] == 'RDN') & (df['Delivery Type.1'] != 'Property Rates')) | \
          ((df['Delivery Type'] == 'BUSINESS') & (df['Delivery Type.1'] != 'License Fees'))
    conditions.append(c8)
    print(f"   Found: {c8.sum()}")
    
    # 9. Gap > 2 hours between consecutive deliveries
    print("\n9. Checking: Gap > 2 hours between deliveries...")
    df['Delivered_DateTime'] = df['Delivered On'].apply(parse_datetime)
    df['Gap_Minutes'] = 0
    
    for name, group in df.groupby('Full name'):
        if len(group) > 1:
            group_sorted = group.sort_values('Delivered_DateTime')
            
            for i in range(1, len(group_sorted)):
                prev_idx = group_sorted.index[i-1]
                curr_idx = group_sorted.index[i]
                
                prev_dt = df.loc[prev_idx, 'Delivered_DateTime']
                curr_dt = df.loc[curr_idx, 'Delivered_DateTime']
                
                if pd.notna(prev_dt) and pd.notna(curr_dt) and prev_dt.date() == curr_dt.date():
                    time_diff_hours = (curr_dt - prev_dt).total_seconds() / 3600
                    time_diff_minutes = (curr_dt - prev_dt).total_seconds() / 60
                    
                    if time_diff_hours > 2:
                        df.loc[curr_idx, 'Gap_Minutes'] = time_diff_minutes
    
    c9 = df['Gap_Minutes'] > 0
    conditions.append(c9)
    print(f"   Found: {c9.sum()}")
    
    # 10. Calculate productivity flags
    print("\n10. Calculating productivity flags for information...")
    df = calculate_productivity_flags(df, min_deliveries=50, max_mean_gap=10)
    count_flagged = (df['Delivery_Count_Flag'] != '').sum()
    pace_flagged = (df['Pace_Flag'] != '').sum()
    print(f"   Found {count_flagged} observations with low productivity (<50 deliveries)")
    print(f"   Found {pace_flagged} observations with slow pace (>10min mean gap)")
    
    # Combine conditions
    print("\n" + "="*70)
    print("Combining conditions (OR logic)...")
    final_mask = conditions[0]
    for condition in conditions[1:]:
        final_mask = final_mask | condition
    
    filtered_df = df[final_mask]
    filtered_rows = len(filtered_df)
    
    # Remove temporary columns
    filtered_df = filtered_df.drop(columns=['Created_Date', 'Updated_Date', 'Delivered_Date', 
                                             'Distance_numeric', 'Delivered_DateTime'])
    
    # Save result
    filtered_df.to_csv(output_file, index=False)
    
    print(f"\nResults:")
    print(f"  - Filtered observations: {filtered_rows}")
    print(f"  - Percentage retained: {filtered_rows/total_rows*100:.2f}%")
    print(f"  - Output file created: {output_file}")
    
    return total_rows, filtered_rows


def run_filter(input_file, output_file):
    """Main function to be called from master.py.
    
    All configuration comes from the master script.
    """
    # Create output directory if needed
    output_dir = os.path.dirname(output_file)
    os.makedirs(output_dir, exist_ok=True)
    
    # Check input file exists
    if not os.path.exists(input_file):
        raise FileNotFoundError(f"Input file not found: {input_file}")
    
    # Execute filtering
    total, filtered = filter_field_data(input_file, output_file)
    return total, filtered


# Standalone execution removed - use master.py for all runs
if __name__ == "__main__":
    print("="*70)
    print("This script should be run from delivery_tracker_master.py")
    print("All configuration is centralized in the master script.")
    print("="*70)