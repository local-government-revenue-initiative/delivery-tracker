"""
Field Data Review Toolbox Generator
====================================

Filters field data observations based on defined criteria:
1. Delivered On missing
2. Distance greater than 50 meters
3. Is Property At Correct Location is False
4. Not Delivered Reason is not missing (BL) OR Is Property Served is not true (Property)
5. Proof of Delivery Path or Signature Path are missing (RDN image was removed from criteria)
6. Delivery Type mismatch (RDN ≠ Property Rates OR BUSINESS ≠ License Fees)
Note: Three productivity checks (delivery count outside min-max range & mean gap > 15min & break > 1h30 between consecutive deliveries) 

Creates an interactive HTML interface to review problematic observations by date.

Author: Robin Benabid Jégaden
Date: 2026-02-10
"""

import subprocess
import sys

try:
    import pandas as pd
except ImportError:
    print("Installing pandas...")
    subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'pandas', '--break-system-packages'])
    import pandas as pd
from datetime import datetime
import os
import json


def parse_date(date_string):
    """Parse date string to date object."""
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


def filter_problematic_observations(df):
    """Filtre les observations problématiques basé sur les critères définis.
    
    Retourne un DataFrame avec seulement les observations ayant au moins un problème.
    """
    print("\nIdentification des observations problématiques...")
    
    conditions = []
    
    # 1. Created On missing
    print("  - Checking: Created On missing")
    df['Created_Date'] = df['Created On'].apply(parse_date)
    c1 = df['Created_Date'].isna()
    conditions.append(c1)
    print(f"    Found: {c1.sum()}")
    
    # 2. Updated On missing
    print("  - Checking: Updated On missing")
    df['Updated_Date'] = df['Updated On'].apply(parse_date)
    c2 = df['Updated_Date'].isna()
    conditions.append(c2)
    print(f"    Found: {c2.sum()}")
    
    # 3. Delivered On missing
    print("  - Checking: Delivered On missing")
    df['Delivered_Date'] = df['Delivered On'].apply(parse_date)
    c3 = df['Delivered_Date'].isna()
    conditions.append(c3)
    print(f"    Found: {c3.sum()}")
    
    # 4. Distance > 50m
    print("  - Checking: Distance > 50m")
    df['Distance_numeric'] = pd.to_numeric(df['Distance'], errors='coerce')
    c4 = df['Distance_numeric'] > 50
    conditions.append(c4)
    print(f"    Found: {c4.sum()}")
    
    # 5. Is Property At Correct Location = False
    print("  - Checking: Is Property At Correct Location = False")
    c5 = df['Is Property At Correct Location'].astype(str).str.lower() == 'false'
    conditions.append(c5)
    print(f"    Found: {c5.sum()}")
    
    # 6. Not Delivered Reason is not missing OR Is Property Served != true
    print("  - Checking: Not Delivered Reason present OR Is Property Served != true")
    c6 = ((df['Not Delivered Reason'].notna() & (df['Not Delivered Reason'] != '')) |
          (df['Is Property Served'].astype(str).str.lower() != 'true'))
    conditions.append(c6)
    print(f"    Found: {c6.sum()}")
    
    # 7. Missing file paths
    print("  - Checking: Missing file paths")
    c7 = ((df['Proof Of Delivery Path'].isna() | (df['Proof Of Delivery Path'] == '')) |
           (df['Signature Path'].isna() | (df['Signature Path'] == '')))
    conditions.append(c7)
    print(f"    Found: {c7.sum()}")
    
    # 8. Delivery Type mismatch
    print("  - Checking: Delivery Type mismatch")
    c8 = ((df['Delivery Type'] == 'RDN') & (df['Delivery Type.1'] != 'Property Rates')) | \
          ((df['Delivery Type'] == 'BUSINESS') & (df['Delivery Type.1'] != 'License Fees'))
    conditions.append(c8)
    print(f"    Found: {c8.sum()}")
    
    # Note: Gap > 1h30 is now tracked in productivity section, not as a data quality issue
    # We still calculate gap information for reference but don't use it as a filter criterion
    print("  - Note: Breaks > 1h30 are now tracked in productivity monitoring, not as data quality issues")
    df['Delivered_DateTime'] = df['Delivered On'].apply(parse_datetime)
    df['Gap_Minutes'] = 0
    df['Gap_Start'] = ''
    df['Gap_End'] = ''
    
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
                    
                    if time_diff_hours > 1.5:
                        df.loc[curr_idx, 'Gap_Minutes'] = time_diff_minutes
                        df.loc[curr_idx, 'Gap_Start'] = prev_dt.strftime('%H:%M')
                        df.loc[curr_idx, 'Gap_End'] = curr_dt.strftime('%H:%M')
    
    # Combiner toutes les conditions (OR logic) - excluding gap criterion
    final_mask = conditions[0]
    for condition in conditions[1:]:
        final_mask = final_mask | condition
    
    filtered_df = df[final_mask].copy()
    
    print(f"\n✓ Total problematic observations: {len(filtered_df)} / {len(df)} ({len(filtered_df)/len(df)*100:.1f}%)")
    
    return filtered_df


def calculate_delivery_statistics(df):
    """Calculate delivery statistics by enumerator and date with Business/Property split and average distance.
    
    Args:
        df: DataFrame with all delivery data (RAW)
        
    Returns:
        list: List of dicts with delivery statistics
    """
    delivery_stats = []
    
    # Parse dates
    df['Delivered_Date_temp'] = df['Delivered On'].apply(parse_date)
    
    # Convert Distance to numeric for calculations
    df['Distance_numeric_temp'] = pd.to_numeric(df['Distance'], errors='coerce')
    
    # Group by Full name and Date
    for name, name_group in df.groupby('Full name'):
        for date_val, day_group in name_group.groupby('Delivered_Date_temp'):
            if pd.notna(date_val):
                # Extract team from User Name
                user_name = str(day_group['User Name'].iloc[0]) if 'User Name' in day_group.columns else ''
                team = user_name[:2] if len(user_name) >= 2 else user_name
                
                # Count deliveries by type
                business_count = len(day_group[day_group['Delivery Type'] == 'BUSINESS'])
                rdn_count = len(day_group[day_group['Delivery Type'] == 'RDN'])
                total_count = len(day_group)
                
                # Calculate average distance
                avg_distance = day_group['Distance_numeric_temp'].mean()
                
                delivery_stats.append({
                    'full_name': name,
                    'user_name': user_name,
                    'date': date_val.strftime('%Y-%m-%d'),
                    'team': team,
                    'business': int(business_count),
                    'rdn': int(rdn_count),
                    'total': int(total_count),
                    'avg_distance': float(avg_distance) if pd.notna(avg_distance) else 0.0
                })
    
    # Clean up temporary columns
    df.drop(columns=['Delivered_Date_temp', 'Distance_numeric_temp'], inplace=True, errors='ignore')
    
    return delivery_stats


def identify_issues(row):
    """Identify all issues for a given observation."""
    issues = []
    
    # Parse dates
    created_date = parse_date(row.get('Created On'))
    updated_date = parse_date(row.get('Updated On'))
    delivered_date = parse_date(row.get('Delivered On'))
    
    # Check each criterion
    if pd.isna(row.get('Created On')) or row.get('Created On') == '':
        issues.append("Created On missing")
    
    if pd.isna(row.get('Updated On')) or row.get('Updated On') == '':
        issues.append("Updated On missing")
    
    if pd.isna(row.get('Delivered On')) or row.get('Delivered On') == '':
        issues.append("Delivered On missing")
    
    distance = pd.to_numeric(row.get('Distance'), errors='coerce')
    if pd.notna(distance) and distance > 50:
        issues.append(f"Distance > 50m ({distance:.1f}m)")
    
    if str(row.get('Is Property At Correct Location')).lower() == 'false':
        issues.append("Wrong location")
    
    if ((pd.notna(row.get('Not Delivered Reason')) and row.get('Not Delivered Reason') != '') or
        (str(row.get('Is Property Served')).lower() != 'true')):
        issues.append("Not Delivered")
    
    if (pd.isna(row.get('Proof Of Delivery Path')) or row.get('Proof Of Delivery Path') == '' or
        pd.isna(row.get('Signature Path')) or row.get('Signature Path') == ''):
        issues.append("Missing files")
    
    delivery_type = row.get('Delivery Type')
    delivery_type_1 = row.get('Delivery Type.1')
    if delivery_type == 'RDN' and delivery_type_1 != 'Property Rates':
        issues.append("Type mismatch (Property)")
    if delivery_type == 'BUSINESS' and delivery_type_1 != 'License Fees':
        issues.append("Type mismatch (BUSINESS)")
    
    # Note: Break > 1h30 is now tracked in the productivity section, not here
    
    return " • ".join(issues) if issues else "No issues"


def calculate_productivity_flagged_enumerators(df, min_deliveries=50, max_deliveries=80, max_mean_gap=15):
    """Get enumerators flagged for productivity issues (low or too high).
    
    Calculates productivity flags directly from raw data.
    
    Args:
        df: DataFrame with delivery data
        min_deliveries: Minimum expected deliveries per day
        max_deliveries: Maximum expected deliveries per day
        max_mean_gap: Maximum mean gap in minutes
        
    Returns:
        list: List of dicts with flagged enumerators info
    """
    import numpy as np
    
    flagged_enumerators = []
    
    # Parse datetime for grouping
    df['Delivered_DateTime_temp'] = df['Delivered On'].apply(lambda x: parse_datetime(x) if pd.notna(x) else None)
    df['Delivered_Date_temp'] = df['Delivered_DateTime_temp'].apply(lambda x: x.date() if pd.notna(x) else None)
    
    # Group by Full name and date to get unique enumerator×day combinations
    for name, group in df.groupby('Full name'):
        for date_val, day_group in group.groupby('Delivered_Date_temp'):
            if pd.notna(date_val) and len(day_group) > 2:  # Only include if more than 2 deliveries
                delivery_count = len(day_group)
                
                # Calculate mean gap and detect long breaks
                enum_sorted = day_group.sort_values('Delivered_DateTime_temp')
                gaps = []
                long_breaks = []  # Store breaks > 1h30
                
                for i in range(1, len(enum_sorted)):
                    prev_dt = enum_sorted.iloc[i-1]['Delivered_DateTime_temp']
                    curr_dt = enum_sorted.iloc[i]['Delivered_DateTime_temp']
                    
                    if pd.notna(prev_dt) and pd.notna(curr_dt):
                        gap_minutes = (curr_dt - prev_dt).total_seconds() / 60
                        gaps.append(gap_minutes)
                        
                        # Check if this is a long break (> 1.5 hours = 90 minutes)
                        if gap_minutes > 90:
                            long_breaks.append({
                                'start': prev_dt.strftime('%H:%M'),
                                'end': curr_dt.strftime('%H:%M'),
                                'duration_minutes': gap_minutes
                            })
                
                if len(gaps) > 0:
                    mean_gap = np.mean(gaps)
                    
                    # Determine flags
                    has_low_count_flag = delivery_count < min_deliveries
                    has_high_count_flag = delivery_count > max_deliveries
                    has_pace_flag = mean_gap > max_mean_gap
                    has_long_break_flag = len(long_breaks) > 0
                    
                    # Only add if flagged
                    if has_low_count_flag or has_high_count_flag or has_pace_flag or has_long_break_flag:
                        # Extract team from User Name
                        user_name = str(day_group['User Name'].iloc[0]) if 'User Name' in day_group.columns else ''
                        team = user_name[:2] if len(user_name) >= 2 else user_name
                        
                        flagged_enumerators.append({
                            'name': name,
                            'date': date_val.strftime('%Y-%m-%d'),
                            'team': team,
                            'deliveries': int(delivery_count),
                            'has_low_count_flag': bool(has_low_count_flag),
                            'has_high_count_flag': bool(has_high_count_flag),
                            'has_pace_flag': bool(has_pace_flag),
                            'has_long_break_flag': bool(has_long_break_flag),
                            'mean_gap': float(mean_gap),
                            'long_breaks': long_breaks  # List of breaks > 1h30
                        })
    
    # Clean up temporary columns
    df.drop(columns=['Delivered_DateTime_temp', 'Delivered_Date_temp'], inplace=True, errors='ignore')
    
    return flagged_enumerators


def generate_html_toolbox(df_raw, output_file, city, min_deliveries=50, max_deliveries=80, max_mean_gap=15):
    """Generate interactive HTML toolbox directly from RAW data.
    
    Args:
        df_raw: DataFrame with all delivery data (RAW)
        output_file: Path to output HTML file
        city: City name
        min_deliveries: Minimum expected deliveries per day
        max_deliveries: Maximum expected deliveries per day
        max_mean_gap: Maximum mean gap between deliveries in minutes
    """
    
    # Filter problematic observations
    df_filtered = filter_problematic_observations(df_raw.copy())
    
    # Calculate productivity flagged enumerators (use raw data)
    print("\nCalculating productivity flags...")
    productivity_enumerators = calculate_productivity_flagged_enumerators(
        df_raw.copy(), min_deliveries, max_deliveries, max_mean_gap
    )
    print(f"✓ Found {len(productivity_enumerators)} enumerator-days with productivity flags")
    
    # Calculate delivery statistics for all enumerators (use raw data)
    print("\nCalculating delivery statistics...")
    delivery_statistics = calculate_delivery_statistics(df_raw.copy())
    print(f"✓ Calculated statistics for {len(delivery_statistics)} enumerator-days")
    
    # Prepare data for problems section (use filtered data)
    print("\nPreparing problematic observations data...")
    records = []
    for _, row in df_filtered.iterrows():
        delivered_date = parse_date(row.get('Delivered On'))
        if delivered_date:
            delivery_type = row.get('Delivery Type')
            code = row.get('Property Code') if delivery_type == 'RDN' else row.get('License Code')
            user_name = str(row.get('User Name', ''))
            team = user_name[:2] if len(user_name) >= 2 else user_name
            
            records.append({
                'date': delivered_date.strftime('%Y-%m-%d'),
                'team': team,
                'full_name': row.get('Full name', ''),
                'user_name': user_name,
                'code': code if pd.notna(code) else '',
                'delivery_type': delivery_type,
                'issues': identify_issues(row)
            })
    
    # Sort by team, then by user_name
    records.sort(key=lambda x: (x['team'], x['user_name']))
    
    # Get unique dates sorted
    dates = sorted(list(set([r['date'] for r in records])), reverse=True)
    
    # Get unique teams sorted
    teams = sorted(list(set([r['team'] for r in records])))
    
    # Get unique dates, teams, and full names for delivery statistics section
    stats_dates = sorted(list(set([s['date'] for s in delivery_statistics])), reverse=True)
    stats_teams = sorted(list(set([s['team'] for s in delivery_statistics])))
    stats_names = sorted(list(set([s['full_name'] for s in delivery_statistics])))
    
    print(f"✓ Prepared {len(records)} problematic observations for display")
    
    # Generate HTML
    print("\nGenerating HTML interface...")
    html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{city} Delivery Data - Daily Tracker Box</title>
    <style>
        /* === SCREEN STYLES === */
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{ font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #f5f5f5; padding: 20px; }}
        .container {{ max-width: 1400px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }}
        h1 {{ color: #2c3e50; margin-bottom: 8px; font-size: 24px; }}
        .subtitle {{ color: #7f8c8d; margin-bottom: 15px; font-size: 13px; }}
        .active-filters {{
            background: #e3f2fd;
            padding: 10px 15px;
            border-radius: 4px;
            margin-bottom: 15px;
            font-size: 13px;
            color: #1565c0;
            font-weight: 600;
            border-left: 4px solid #2196f3;
        }}
        .verification-info {{ 
            background: #ecf0f1; 
            padding: 12px; 
            border-radius: 4px; 
            margin-bottom: 12px; 
            font-size: 12px; 
            color: #34495e; 
            line-height: 1.5;
        }}
        .productivity-info {{
            background: #fff3cd;
            padding: 12px;
            border-radius: 4px;
            margin-bottom: 20px;
            font-size: 12px;
            color: #856404;
            line-height: 1.5;
            border-left: 4px solid #ffc107;
        }}
        .print-button {{
            position: fixed;
            bottom: 30px;
            right: 30px;
            background: #3498db;
            color: white;
            border: none;
            border-radius: 50%;
            width: 60px;
            height: 60px;
            font-size: 24px;
            cursor: pointer;
            box-shadow: 0 4px 8px rgba(0,0,0,0.2);
            transition: all 0.3s;
            z-index: 1000;
        }}
        .print-button:hover {{
            background: #2980b9;
            transform: scale(1.1);
        }}
        .productivity-section {{
            background: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 15px;
            margin-bottom: 20px;
            border-radius: 4px;
        }}
        .productivity-section h2 {{
            color: #856404;
            margin-bottom: 10px;
            font-size: 16px;
        }}
        .productivity-list {{
            list-style: none;
            padding: 0;
        }}
        .productivity-item {{
            background: white;
            padding: 10px;
            margin-bottom: 8px;
            border-radius: 4px;
            border-left: 3px solid #ff9800;
        }}
        .productivity-name {{
            font-weight: bold;
            color: #d84315;
            font-size: 13px;
        }}
        .productivity-stats {{
            color: #616161;
            font-size: 12px;
            margin-top: 4px;
        }}
        .controls {{ margin-bottom: 20px; display: flex; gap: 15px; align-items: center; flex-wrap: wrap; }}
        .control-group {{ display: flex; gap: 8px; align-items: center; }}
        select {{ padding: 8px 12px; font-size: 14px; border: 2px solid #ddd; border-radius: 4px; cursor: pointer; }}
        select:focus {{ outline: none; border-color: #3498db; }}
        .stats {{ display: flex; gap: 15px; margin-bottom: 15px; }}
        .stat-box {{ flex: 1; padding: 12px; background: #ecf0f1; border-radius: 4px; }}
        .stat-value {{ font-size: 28px; font-weight: bold; color: #e74c3c; }}
        .stat-label {{ color: #7f8c8d; margin-top: 4px; font-size: 12px; }}
        table {{ width: 100%; border-collapse: collapse; margin-top: 15px; font-size: 12px; }}
        th {{ background: #34495e; color: white; padding: 8px; text-align: left; font-weight: 600; font-size: 12px; }}
        td {{ padding: 8px; border-bottom: 1px solid #ddd; }}
        tr:hover {{ background: #f8f9fa; }}
        .code {{ font-family: 'Courier New', monospace; font-weight: bold; color: #2c3e50; font-size: 11px; }}
        .issues {{ color: #e74c3c; font-size: 11px; }}
        .no-data {{ text-align: center; padding: 30px; color: #95a5a6; font-size: 14px; }}
        .team-badge {{ display: inline-block; padding: 3px 6px; background: #3498db; color: white; border-radius: 3px; font-weight: bold; font-size: 11px; }}
        .delivery-stats-container {{ margin-top: 30px; padding: 15px; background: #f0f4f8; border-radius: 8px; border: 2px solid #6c757d; }}
        .delivery-stats-container h2 {{ color: #495057; margin-bottom: 8px; font-size: 16px; }}
        .delivery-stats-container p {{ margin-bottom: 15px; color: #6c757d; font-size: 12px; }}
        
        /* === PRINT STYLES === */
        @media print {{
            @page {{
                size: A4;
                margin: 10mm 8mm 10mm 8mm;
            }}
            
            body {{
                background: white;
                padding: 0;
                font-size: 10pt;
            }}
            
            .container {{
                max-width: 100%;
                padding: 0;
                box-shadow: none;
                border-radius: 0;
            }}
            
            h1 {{
                font-size: 18pt;
                margin-bottom: 4pt;
                page-break-after: avoid;
            }}
            
            .subtitle {{
                font-size: 10pt;
                margin-bottom: 8pt;
                page-break-after: avoid;
            }}
            
            .active-filters {{
                display: block !important;
                background: #e3f2fd !important;
                padding: 8pt;
                margin-bottom: 10pt;
                font-size: 11pt;
                border: 1pt solid #2196f3;
                page-break-after: avoid;
                -webkit-print-color-adjust: exact;
                print-color-adjust: exact;
            }}
            
            .verification-info,
            .productivity-info {{
                padding: 6pt;
                margin-bottom: 8pt;
                font-size: 9pt;
                line-height: 1.3;
                border-radius: 2pt;
                page-break-inside: avoid;
            }}
            
            .print-button {{
                display: none !important;
            }}
            
            .controls {{
                display: none !important;
            }}
            
            .stats {{
                display: flex;
                gap: 10pt;
                margin-bottom: 10pt;
                page-break-inside: avoid;
            }}
            
            .stat-box {{
                padding: 8pt;
                border: 1pt solid #ddd;
            }}
            
            .stat-value {{
                font-size: 20pt;
            }}
            
            .stat-label {{
                font-size: 9pt;
            }}
            
            .productivity-section {{
                padding: 10pt;
                margin-bottom: 15pt;
                border: 1pt solid #ffc107;
                page-break-inside: avoid;
            }}
            
            .productivity-section h2 {{
                font-size: 13pt;
                margin-bottom: 6pt;
                page-break-after: avoid;
            }}
            
            .productivity-item {{
                padding: 6pt;
                margin-bottom: 4pt;
                border: 1pt solid #ff9800;
                page-break-inside: avoid;
            }}
            
            .productivity-name {{
                font-size: 10pt;
            }}
            
            .productivity-stats {{
                font-size: 9pt;
                margin-top: 2pt;
            }}
            
            table {{
                margin-top: 10pt;
                font-size: 9pt;
                page-break-inside: auto;
            }}
            
            thead {{
                display: table-header-group;
            }}
            
            tr {{
                page-break-inside: avoid;
                page-break-after: auto;
            }}
            
            th {{
                padding: 5pt;
                font-size: 9pt;
                background: #34495e !important;
                -webkit-print-color-adjust: exact;
                print-color-adjust: exact;
            }}
            
            td {{
                padding: 5pt;
                border-bottom: 0.5pt solid #ddd;
            }}
            
            .code {{
                font-size: 9pt;
            }}
            
            .issues {{
                font-size: 9pt;
            }}
            
            .team-badge {{
                padding: 2pt 4pt;
                font-size: 9pt;
                background: #3498db !important;
                -webkit-print-color-adjust: exact;
                print-color-adjust: exact;
            }}
            
            .delivery-stats-container {{
                margin-top: 20pt;
                padding: 10pt;
                border: 1pt solid #6c757d;
                page-break-before: auto;
                page-break-inside: avoid;
            }}
            
            .delivery-stats-container h2 {{
                font-size: 13pt;
                margin-bottom: 6pt;
                page-break-after: avoid;
            }}
            
            .delivery-stats-container p {{
                font-size: 9pt;
                margin-bottom: 10pt;
            }}
            
            /* Force background colors for key elements */
            .verification-info {{
                background: #ecf0f1 !important;
                -webkit-print-color-adjust: exact;
                print-color-adjust: exact;
            }}
            
            .productivity-info {{
                background: #fff3cd !important;
                -webkit-print-color-adjust: exact;
                print-color-adjust: exact;
            }}
            
            .productivity-section {{
                background: #fff3cd !important;
                -webkit-print-color-adjust: exact;
                print-color-adjust: exact;
            }}
            
            .productivity-item {{
                background: white !important;
                -webkit-print-color-adjust: exact;
                print-color-adjust: exact;
            }}
            
            .stat-box {{
                background: #ecf0f1 !important;
                -webkit-print-color-adjust: exact;
                print-color-adjust: exact;
            }}
            
            .delivery-stats-container {{
                background: #f0f4f8 !important;
                -webkit-print-color-adjust: exact;
                print-color-adjust: exact;
            }}
            
            /* Optimize spacing for compact A4 */
            * {{
                line-height: 1.3 !important;
            }}
        }}
    </style>
</head>
<body>
    <div class="container">
        <h1>{city} Delivery Data - Daily Tracker Box</h1>
        <div class="subtitle">Review problematic observations by delivery date and team</div>
        
        <div class="active-filters" id="activeFilters" style="display: none;"></div>
        
        <div class="verification-info">
            <strong>Verified issues:</strong> Created On/Updated On/Delivered On missing • Distance > 50m • Wrong location • Not Delivered • Missing files • Delivery type mismatch
        </div>
        
        <div class="productivity-info">
            <strong>Productivity monitoring:</strong> Enumerators flagged if &lt;{min_deliveries} deliveries OR &gt;{max_deliveries} deliveries OR mean gap between deliveries &gt;{max_mean_gap} minutes OR break &gt; 1.5 hours
        </div>
        
        <div class="controls">
            <div class="control-group">
                <label for="dateSelect"><strong>Delivery Date:</strong></label>
                <select id="dateSelect" onchange="applyFilters()">
                    <option value="">-- All dates --</option>
                    {''.join([f'<option value="{date}">{date}</option>' for date in dates])}
                </select>
            </div>
            <div class="control-group">
                <label for="teamSelect"><strong>Team:</strong></label>
                <select id="teamSelect" onchange="applyFilters()">
                    <option value="">-- All teams --</option>
                    {''.join([f'<option value="{team}">{team}</option>' for team in teams])}
                </select>
            </div>
        </div>
        
        <div class="stats" id="stats" style="display: none;">
            <div class="stat-box">
                <div class="stat-value" id="totalIssues">0</div>
                <div class="stat-label">Issues Found</div>
            </div>
            <div class="stat-box">
                <div class="stat-value" id="uniqueAgents">0</div>
                <div class="stat-label">Field Agents</div>
            </div>
            <div class="stat-box">
                <div class="stat-value" id="uniqueTeams">0</div>
                <div class="stat-label">Teams</div>
            </div>
        </div>
        
        <div id="results"></div>
        
        <div class="productivity-section" id="productivitySection" style="display: none;">
            <h2>⚠️ Enumerators facing potential difficulties</h2>
            <p style="margin-bottom: 15px; color: #856404; font-size: 14px;">Flagged for low productivity (&lt;{min_deliveries} deliveries) or too high productivity (&gt;{max_deliveries} deliveries) or slow pace (mean gap &gt;{max_mean_gap} minutes) or break &gt; 1.5 hours</p>
            <ul class="productivity-list" id="productivityList"></ul>
        </div>
        
        <!-- NEW SECTION: Delivery Statistics -->
        <div class="delivery-stats-container" style="margin-top: 40px; padding: 20px; background: #f0f4f8; border-radius: 8px; border: 2px solid #6c757d;">
            <h2 style="color: #495057; margin-bottom: 10px;">📊 Delivery Statistics by Enumerator</h2>
            <p style="margin-bottom: 20px; color: #6c757d; font-size: 14px;">View total deliveries (Business and Property) for each enumerator by date and team</p>
            
            <div class="controls" style="margin-bottom: 20px;">
                <div class="control-group">
                    <label for="statsDateSelect"><strong>Date:</strong></label>
                    <select id="statsDateSelect" onchange="applyStatsFilters()">
                        <option value="">-- All dates --</option>
                        {''.join([f'<option value="{date}">{date}</option>' for date in stats_dates])}
                    </select>
                </div>
                <div class="control-group">
                    <label for="statsTeamSelect"><strong>Team:</strong></label>
                    <select id="statsTeamSelect" onchange="applyStatsFilters()">
                        <option value="">-- All teams --</option>
                        {''.join([f'<option value="{team}">{team}</option>' for team in stats_teams])}
                    </select>
                </div>
                <div class="control-group">
                    <label for="statsNameSelect"><strong>Full Name:</strong></label>
                    <select id="statsNameSelect" onchange="applyStatsFilters()">
                        <option value="">-- All enumerators --</option>
                        {''.join([f'<option value="{name}">{name}</option>' for name in stats_names])}
                    </select>
                </div>
            </div>
            
            <div id="statsResults"></div>
        </div>
    </div>
    
    <button class="print-button" onclick="window.print()" title="Print or save as PDF">🖨️</button>

    <script>
        const data = {json.dumps(records)};
        const productivityEnumerators = {json.dumps(productivity_enumerators)};
        
        function applyFilters() {{
            const selectedDate = document.getElementById('dateSelect').value;
            const selectedTeam = document.getElementById('teamSelect').value;
            const resultsDiv = document.getElementById('results');
            const statsDiv = document.getElementById('stats');
            const productivitySection = document.getElementById('productivitySection');
            
            // Update active filters display
            const activeFiltersDiv = document.getElementById('activeFilters');
            let filterText = 'Active filters: ';
            let filters = [];
            
            if (selectedDate) {{
                filters.push(`Date: ${{selectedDate}}`);
            }}
            
            if (selectedTeam) {{
                filters.push(`Team: ${{selectedTeam}}`);
            }}
            
            if (filters.length > 0) {{
                filterText += filters.join(' | ');
                activeFiltersDiv.textContent = filterText;
                activeFiltersDiv.style.display = 'block';
            }} else {{
                activeFiltersDiv.style.display = 'none';
            }}
            
            // Filter data
            let filtered = data;
            
            if (selectedDate) {{
                filtered = filtered.filter(r => r.date === selectedDate);
            }}
            
            if (selectedTeam) {{
                filtered = filtered.filter(r => r.team === selectedTeam);
            }}
            
            // If no filters applied
            if (!selectedDate && !selectedTeam) {{
                resultsDiv.innerHTML = '<div class="no-data">Please select a date and/or team to view results</div>';
                statsDiv.style.display = 'none';
                productivitySection.style.display = 'none';
                return;
            }}
            
            if (filtered.length === 0) {{
                resultsDiv.innerHTML = '<div class="no-data">No problematic observations found for selected filters</div>';
                statsDiv.style.display = 'none';
                productivitySection.style.display = 'none';
                return;
            }}
            
            // Calculate stats
            const uniqueAgents = new Set(filtered.map(r => r.user_name)).size;
            const uniqueTeams = new Set(filtered.map(r => r.team)).size;
            document.getElementById('totalIssues').textContent = filtered.length;
            document.getElementById('uniqueAgents').textContent = uniqueAgents;
            document.getElementById('uniqueTeams').textContent = uniqueTeams;
            statsDiv.style.display = 'flex';
            
            // Filter productivity enumerators based on selected date/team
            let filteredProductivity = productivityEnumerators.filter(enum_data => {{
                let matchDate = !selectedDate || enum_data.date === selectedDate;
                let matchTeam = !selectedTeam || enum_data.team === selectedTeam;
                return matchDate && matchTeam;
            }});
            
            // Display productivity enumerators section if any found
            if (filteredProductivity.length > 0) {{
                productivitySection.style.display = 'block';
                const list = document.getElementById('productivityList');
                list.innerHTML = '';
                
                filteredProductivity.forEach(enum_data => {{
                    const li = document.createElement('li');
                    li.className = 'productivity-item';
                    
                    // Build the display string - show only what's flagged
                    let parts = [];
                    
                    // Add delivery count if flagged (low)
                    if (enum_data.has_low_count_flag) {{
                        parts.push(`${{enum_data.deliveries}} deliveries (Low productivity)`);
                    }}
                    
                    // Add delivery count if flagged (too high)
                    if (enum_data.has_high_count_flag) {{
                        parts.push(`${{enum_data.deliveries}} deliveries (Too high productivity)`);
                    }}
                    
                    // Add mean gap if flagged
                    if (enum_data.has_pace_flag) {{
                        parts.push(`Mean gap: ${{enum_data.mean_gap.toFixed(1)}} min (Slow pace)`);
                    }}
                    
                    // Add long breaks if flagged
                    if (enum_data.has_long_break_flag && enum_data.long_breaks) {{
                        const breakTexts = enum_data.long_breaks.map(brk => 
                            `${{brk.start}}-${{brk.end}} (${{Math.round(brk.duration_minutes)}}min)`
                        );
                        parts.push(`Break > 1.5h: ${{breakTexts.join(', ')}}`);
                    }}
                    
                    // Join with separator
                    let displayText = parts.join(' | ');
                    
                    li.innerHTML = `
                        <div class="productivity-name">${{enum_data.name}}</div>
                        <div class="productivity-stats">${{displayText}}</div>
                    `;
                    list.appendChild(li);
                }});
            }} else {{
                productivitySection.style.display = 'none';
            }}
            
            // Generate table
            let html = '<table><thead><tr>';
            html += '<th>Team</th>';
            html += '<th>Full Name</th>';
            html += '<th>User Name</th>';
            html += '<th>Code</th>';
            html += '<th>Issues</th>';
            html += '</tr></thead><tbody>';
            
            filtered.forEach(record => {{
                html += '<tr>';
                html += `<td><span class="team-badge">${{record.team}}</span></td>`;
                html += `<td>${{record.full_name}}</td>`;
                html += `<td>${{record.user_name}}</td>`;
                html += `<td class="code">${{record.code}}</td>`;
                html += `<td class="issues">${{record.issues}}</td>`;
                html += '</tr>';
            }});
            
            html += '</tbody></table>';
            resultsDiv.innerHTML = html;
        }}
        
        // Delivery Statistics Section
        const deliveryStats = {json.dumps(delivery_statistics)};
        
        function applyStatsFilters() {{
            const selectedDate = document.getElementById('statsDateSelect').value;
            const selectedTeam = document.getElementById('statsTeamSelect').value;
            const selectedName = document.getElementById('statsNameSelect').value;
            const statsResultsDiv = document.getElementById('statsResults');
            
            // Filter data
            let filtered = deliveryStats;
            
            if (selectedDate) {{
                filtered = filtered.filter(s => s.date === selectedDate);
            }}
            
            if (selectedTeam) {{
                filtered = filtered.filter(s => s.team === selectedTeam);
            }}
            
            if (selectedName) {{
                filtered = filtered.filter(s => s.full_name === selectedName);
            }}
            
            // If no filters applied
            if (!selectedDate && !selectedTeam && !selectedName) {{
                statsResultsDiv.innerHTML = '<div class="no-data">Please select at least one filter to view delivery statistics</div>';
                return;
            }}
            
            if (filtered.length === 0) {{
                statsResultsDiv.innerHTML = '<div class="no-data">No data found for selected filters</div>';
                return;
            }}
            
            // Sort by date (descending), then by full name
            filtered.sort((a, b) => {{
                if (a.date !== b.date) return b.date.localeCompare(a.date);
                return a.full_name.localeCompare(b.full_name);
            }});
            
            // Calculate total deliveries
            const totalDeliveries = filtered.reduce((sum, s) => sum + s.total, 0);
            const totalBusiness = filtered.reduce((sum, s) => sum + s.business, 0);
            const totalRDN = filtered.reduce((sum, s) => sum + s.rdn, 0);
            const avgDistanceOverall = filtered.length > 0 
                ? (filtered.reduce((sum, s) => sum + s.avg_distance, 0) / filtered.length).toFixed(1)
                : 0;
            
            // Generate table
            let html = `<div style="margin-bottom: 15px; padding: 10px; background: #fff; border-radius: 4px; border-left: 4px solid #6c757d;">
                <strong>Total Deliveries: ${{totalDeliveries}}</strong> 
                (Business: ${{totalBusiness}} | Property: ${{totalRDN}}) | 
                <strong>Avg Distance: ${{avgDistanceOverall}}m</strong> | 
                <strong>Records: ${{filtered.length}}</strong>
            </div>`;
            
            html += '<table><thead><tr>';
            html += '<th>Date</th>';
            html += '<th>Team</th>';
            html += '<th>Full Name</th>';
            html += '<th>Business</th>';
            html += '<th>Property</th>';
            html += '<th>Total</th>';
            html += '<th>Avg Distance (m)</th>';
            html += '</tr></thead><tbody>';
            
            filtered.forEach(stat => {{
                html += '<tr>';
                html += `<td>${{stat.date}}</td>`;
                html += `<td><span class="team-badge">${{stat.team}}</span></td>`;
                html += `<td>${{stat.full_name}}</td>`;
                html += `<td style="font-weight: bold; color: #27ae60; text-align: center;">${{stat.business}}</td>`;
                html += `<td style="font-weight: bold; color: #e74c3c; text-align: center;">${{stat.rdn}}</td>`;
                html += `<td style="font-weight: bold; color: #2c3e50; text-align: center; background: #e8f4f8;">${{stat.total}}</td>`;
                html += `<td style="font-weight: bold; color: #2c3e50; text-align: center;">${{stat.avg_distance.toFixed(1)}}</td>`;
                html += '</tr>';
            }});
            
            html += '</tbody></table>';
            statsResultsDiv.innerHTML = html;
        }}
    </script>
</body>
</html>"""
    
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(html_content)
    
    print(f"\n✓ Interactive toolbox created: {output_file}")
    print(f"  - Total problematic observations: {len(records)}")
    print(f"  - Date range: {dates[-1] if dates else 'N/A'} to {dates[0] if dates else 'N/A'}")


def run_toolbox(raw_file, output_file, city, min_deliveries=50, max_deliveries=80, max_mean_gap=15):
    """Main function to be called from master.py.
    
    All configuration comes from the master script.
    
    Args:
        raw_file: Path to raw input CSV file (all observations)
        output_file: Path to output HTML file
        city: City name
        min_deliveries: Minimum expected deliveries per day
        max_deliveries: Maximum expected deliveries per day
        max_mean_gap: Maximum mean gap between deliveries in minutes
    """
    # Create output directory if needed
    output_dir = os.path.dirname(output_file)
    os.makedirs(output_dir, exist_ok=True)
    
    # Check file exists
    if not os.path.exists(raw_file):
        raise FileNotFoundError(f"Raw file not found: {raw_file}")
    
    # Read raw data
    print(f"Reading raw data: {raw_file}")
    df_raw = pd.read_csv(raw_file)
    print(f"Loaded {len(df_raw)} total observations")
    
    # Generate HTML toolbox
    generate_html_toolbox(df_raw, output_file, city, min_deliveries, max_deliveries, max_mean_gap)


if __name__ == "__main__":
    print("="*70)
    print("This script should be run from delivery_tracker_master.py")
    print("All configuration is centralized in the master script.")
    print("="*70)