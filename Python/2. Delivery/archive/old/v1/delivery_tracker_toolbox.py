"""
Field Data Review Toolbox Generator
====================================

Creates an interactive HTML interface to review problematic observations by date.

Author: Robin Benabid Jégaden
Date: 2026-01-16
"""

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


def calculate_delivery_statistics(df):
    """Calculate delivery statistics by enumerator and date with Business/Property split and average distance.
    
    Args:
        df: DataFrame with all delivery data (not just filtered)
        
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
    
    if pd.notna(row.get('Not Delivered Reason')) and row.get('Not Delivered Reason') != '':
        issues.append("Not Delivered")
    
    if (pd.isna(row.get('Proof Of Delivery Path')) or row.get('Proof Of Delivery Path') == '' or
        pd.isna(row.get('Rdn Image Path')) or row.get('Rdn Image Path') == '' or
        pd.isna(row.get('Signature Path')) or row.get('Signature Path') == ''):
        issues.append("Missing files")
    
    delivery_type = row.get('Delivery Type')
    delivery_type_1 = row.get('Delivery Type.1')
    if delivery_type == 'RDN' and delivery_type_1 != 'Property Rates':
        issues.append("Type mismatch (Property)")
    if delivery_type == 'BUSINESS' and delivery_type_1 != 'License Fees':
        issues.append("Type mismatch (BUSINESS)")
    
    # Check for gap > 2 hours
    gap_minutes = row.get('Gap_Minutes', 0)
    if gap_minutes > 0:
        gap_start = row.get('Gap_Start', '')
        gap_end = row.get('Gap_End', '')
        if gap_start and gap_end:
            issues.append(f"Break > 2h ({gap_start}-{gap_end})")
        else:
            issues.append(f"Break > 2h ({int(gap_minutes)}min)")
    
    # Note: Productivity flags are shown in separate section, not in Issues column
    
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
                
                # Calculate mean gap
                enum_sorted = day_group.sort_values('Delivered_DateTime_temp')
                gaps = []
                
                for i in range(1, len(enum_sorted)):
                    prev_dt = enum_sorted.iloc[i-1]['Delivered_DateTime_temp']
                    curr_dt = enum_sorted.iloc[i]['Delivered_DateTime_temp']
                    
                    if pd.notna(prev_dt) and pd.notna(curr_dt):
                        gap_minutes = (curr_dt - prev_dt).total_seconds() / 60
                        gaps.append(gap_minutes)
                
                if len(gaps) > 0:
                    mean_gap = np.mean(gaps)
                    
                    # Determine flags
                    has_low_count_flag = delivery_count < min_deliveries
                    has_high_count_flag = delivery_count > max_deliveries
                    has_pace_flag = mean_gap > max_mean_gap
                    
                    # Only add if flagged
                    if has_low_count_flag or has_high_count_flag or has_pace_flag:
                        # Extract team from User Name
                        user_name = str(day_group['User Name'].iloc[0]) if 'User Name' in day_group.columns else ''
                        team = user_name[:2] if len(user_name) >= 2 else user_name
                        
                        flagged_enumerators.append({
                            'name': name,
                            'date': date_val.strftime('%Y-%m-%d'),
                            'team': team,
                            'deliveries': int(delivery_count),
                            'has_low_count_flag': bool(has_low_count_flag),  # Convert numpy bool to Python bool
                            'has_high_count_flag': bool(has_high_count_flag),  # Convert numpy bool to Python bool
                            'has_pace_flag': bool(has_pace_flag),  # Convert numpy bool to Python bool
                            'mean_gap': float(mean_gap)  # Convert numpy float to Python float
                        })
    
    # Clean up temporary columns
    df.drop(columns=['Delivered_DateTime_temp', 'Delivered_Date_temp'], inplace=True, errors='ignore')
    
    return flagged_enumerators


def generate_html_toolbox(df_filtered, df_raw, output_file, city, min_deliveries=50, max_deliveries=80, max_mean_gap=15):
    """Generate interactive HTML toolbox.
    
    Args:
        df_filtered: DataFrame with filtered delivery data (observations with issues)
        df_raw: DataFrame with all delivery data (for statistics)
        output_file: Path to output HTML file
        city: City name
        min_deliveries: Minimum expected deliveries per day
        max_deliveries: Maximum expected deliveries per day
        max_mean_gap: Maximum mean gap between deliveries in minutes
    """
    
    # Calculate productivity flagged enumerators (use raw data to get complete picture)
    productivity_enumerators = calculate_productivity_flagged_enumerators(
        df_raw, min_deliveries, max_deliveries, max_mean_gap
    )
    
    # Calculate delivery statistics for all enumerators (use raw data)
    delivery_statistics = calculate_delivery_statistics(df_raw)
    
    # Prepare data for problems section (use filtered data)
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
    
    # Generate HTML
    html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{city} Delivery Data - Daily Tracker Box</title>
    <style>
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{ font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #f5f5f5; padding: 20px; }}
        .container {{ max-width: 1400px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }}
        h1 {{ color: #2c3e50; margin-bottom: 10px; }}
        .subtitle {{ color: #7f8c8d; margin-bottom: 20px; }}
        .verification-info {{ 
            background: #ecf0f1; 
            padding: 15px; 
            border-radius: 4px; 
            margin-bottom: 15px; 
            font-size: 14px; 
            color: #34495e; 
            line-height: 1.6;
        }}
        .productivity-info {{
            background: #fff3cd;
            padding: 15px;
            border-radius: 4px;
            margin-bottom: 30px;
            font-size: 14px;
            color: #856404;
            line-height: 1.6;
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
        }}
        .print-button:hover {{
            background: #2980b9;
            transform: scale(1.1);
        }}
        @media print {{
            .print-button {{ display: none; }}
            .controls {{ display: none; }}
        }}
        .productivity-section {{
            background: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 20px;
            margin-bottom: 30px;
            border-radius: 4px;
        }}
        .productivity-section h2 {{
            color: #856404;
            margin-bottom: 15px;
            font-size: 18px;
        }}
        .productivity-list {{
            list-style: none;
            padding: 0;
        }}
        .productivity-item {{
            background: white;
            padding: 12px;
            margin-bottom: 10px;
            border-radius: 4px;
            border-left: 3px solid #ff9800;
        }}
        .productivity-name {{
            font-weight: bold;
            color: #d84315;
        }}
        .productivity-stats {{
            color: #616161;
            font-size: 13px;
            margin-top: 5px;
        }}
        .controls {{ margin-bottom: 30px; display: flex; gap: 20px; align-items: center; flex-wrap: wrap; }}
        .control-group {{ display: flex; gap: 10px; align-items: center; }}
        select {{ padding: 10px 15px; font-size: 16px; border: 2px solid #ddd; border-radius: 4px; cursor: pointer; }}
        select:focus {{ outline: none; border-color: #3498db; }}
        .stats {{ display: flex; gap: 20px; margin-bottom: 20px; }}
        .stat-box {{ flex: 1; padding: 15px; background: #ecf0f1; border-radius: 4px; }}
        .stat-value {{ font-size: 32px; font-weight: bold; color: #e74c3c; }}
        .stat-label {{ color: #7f8c8d; margin-top: 5px; }}
        table {{ width: 100%; border-collapse: collapse; margin-top: 20px; }}
        th {{ background: #34495e; color: white; padding: 12px; text-align: left; font-weight: 600; }}
        td {{ padding: 12px; border-bottom: 1px solid #ddd; }}
        tr:hover {{ background: #f8f9fa; }}
        .code {{ font-family: 'Courier New', monospace; font-weight: bold; color: #2c3e50; }}
        .issues {{ color: #e74c3c; font-size: 14px; }}
        .no-data {{ text-align: center; padding: 40px; color: #95a5a6; }}
        .team-badge {{ display: inline-block; padding: 4px 8px; background: #3498db; color: white; border-radius: 3px; font-weight: bold; }}
    </style>
</head>
<body>
    <div class="container">
        <h1>{city} Delivery Data - Daily Tracker Box</h1>
        <div class="subtitle">Review problematic observations by delivery date and team</div>
        
        <div class="verification-info">
            <strong>Verified issues:</strong> Created On/Updated On/Delivered On missing • Distance > 50m • Wrong location • Not Delivered • Missing files • Delivery type mismatch • Break > 2h
        </div>
        
        <div class="productivity-info">
            <strong>Productivity monitoring:</strong> Enumerators flagged if &lt;{min_deliveries} deliveries OR &gt;{max_deliveries} deliveries OR mean gap between deliveries &gt;{max_mean_gap} minutes
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
            <p style="margin-bottom: 15px; color: #856404; font-size: 14px;">Flagged for low productivity (&lt;{min_deliveries} deliveries) or too high productivity (&gt;{max_deliveries} deliveries) or slow pace (mean gap &gt;{max_mean_gap} minutes)</p>
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
    
    print(f"Interactive toolbox created: {output_file}")
    print(f"Total problematic observations: {len(records)}")
    print(f"Date range: {dates[-1] if dates else 'N/A'} to {dates[0] if dates else 'N/A'}")


def run_toolbox(filtered_file, raw_file, output_file, city, min_deliveries=50, max_deliveries=80, max_mean_gap=15):
    """Main function to be called from master.py.
    
    All configuration comes from the master script.
    
    Args:
        filtered_file: Path to filtered (BUILD) CSV file (observations with issues)
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
    
    # Check files exist
    if not os.path.exists(filtered_file):
        raise FileNotFoundError(f"Filtered file not found: {filtered_file}")
    if not os.path.exists(raw_file):
        raise FileNotFoundError(f"Raw file not found: {raw_file}")
    
    # Read filtered data (for problems section)
    print(f"\nReading filtered data: {filtered_file}")
    df_filtered = pd.read_csv(filtered_file)
    print(f"Loaded {len(df_filtered)} problematic observations")
    
    # Read raw data (for statistics section)
    print(f"Reading raw data: {raw_file}")
    df_raw = pd.read_csv(raw_file)
    print(f"Loaded {len(df_raw)} total observations")
    
    # Generate HTML toolbox
    generate_html_toolbox(df_filtered, df_raw, output_file, city, min_deliveries, max_deliveries, max_mean_gap)


# Standalone execution removed - use master.py for all runs
if __name__ == "__main__":
    print("="*70)
    print("This script should be run from delivery_tracker_master.py")
    print("All configuration is centralized in the master script.")
    print("="*70)