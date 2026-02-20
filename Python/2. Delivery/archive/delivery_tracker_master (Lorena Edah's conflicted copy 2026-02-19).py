"""
Delivery Tracker Master Script
===============================

Centralized script to run the delivery tracker data pipeline:
1. Clean and filter field data (delivery_tracker_toolbox.py)
2. Generate interactive review toolbox (delivery_tracker_toolbox.py)

Author: Robin Benabid Jégaden
Date: 2026-02-10
"""

import os
import sys
from datetime import datetime
import glob

# ============================================================================
# USER CONFIGURATION
# ============================================================================

# SELECT YOUR NAME - Each user changes only this line
CURRENT_USER = 'Lorena'  # Change to your name when you use the script

# User-specific Dropbox root paths
USER_PATHS = {
    'Robin': r'D:\LoGRI Dropbox',
    'Lorena': r'C:\Users\Loren\LoGRI Dropbox',
    'Ibrahim': r'C:\Users\Ibrahim\LoGRI Dropbox',
    'Evan': r'C:\Users\edtro\LoGRI Dropbox',
    # Add your Dropbox root path here
}

# ============================================================================
# CONFIGURATION - CITY SELECTION
# ============================================================================

# SELECT CITY: 'Freetown', 'Kenema', or 'Makeni'
CITY = 'Kenema'  # <-- CHANGE THIS TO SWITCH CITIES

# ============================================================================
# CONFIGURATION - PRODUCTIVITY THRESHOLDS BY CITY
# ============================================================================

# Delivery count thresholds per city (min, max)
# Low productivity: < min_deliveries
# High productivity: > max_deliveries
PRODUCTIVITY_THRESHOLDS = {
    'Freetown': {'min_deliveries': 55, 'max_deliveries': 80},
    'Kenema': {'min_deliveries': 45, 'max_deliveries': 55},
    'Makeni': {'min_deliveries': 40, 'max_deliveries': 50}
}

# Mean gap threshold (applies to all cities)
MAX_MEAN_GAP = 15  # minutes

# ============================================================================
# CONFIGURATION - PATHS (AUTOMATIC)
# ============================================================================

# Get user's root path
if CURRENT_USER not in USER_PATHS:
    print(f"ERROR: User '{CURRENT_USER}' not found in USER_PATHS dictionary.")
    print(f"Available users: {', '.join(USER_PATHS.keys())}")
    print("\nPlease either:")
    print("1. Change CURRENT_USER to match an existing user, or")
    print("2. Add your name and path to the USER_PATHS dictionary")
    sys.exit(1)

USER_ROOT_PATH = USER_PATHS[CURRENT_USER]

# Common path structure (same for everyone)
COMMON_PATH = r'LoGRI Master Folder\2. Projects\2. Country Projects\9. Sierra Leone'

# Build complete base path
BASE_PATH = os.path.join(USER_ROOT_PATH, COMMON_PATH)
CODE_PATH = os.path.join(BASE_PATH, r'11. Code\Python\2. Delivery')

# Input data path
RAW_DATA_PATH = os.path.join(BASE_PATH, r'12. Data\1. Raw\delivery_tracker', CITY)

# Output path (uses CITY variable)
OUTPUT_PATH = os.path.join(BASE_PATH, r'13. Output\delivery_tracker', CITY)


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def get_most_recent_csv(directory):
    """Get the most recently modified CSV file in a directory.
    
    Args:
        directory: Path to directory to search
        
    Returns:
        Path to most recent CSV file, or None if no CSV found
    """
    # Get all CSV files in directory
    csv_files = glob.glob(os.path.join(directory, '*.csv'))
    
    if not csv_files:
        return None
    
    # Sort by modification time (most recent first)
    csv_files.sort(key=os.path.getmtime, reverse=True)
    
    return csv_files[0]


# ============================================================================
# AUTO-DETECT MOST RECENT FILE
# ============================================================================

# Find most recent input file (RAW)
INPUT_FILE = get_most_recent_csv(RAW_DATA_PATH)

if INPUT_FILE is None:
    print(f"ERROR: No CSV file found in {RAW_DATA_PATH}")
    sys.exit(1)

# HTML output file
TOOLBOX_HTML_FILE = os.path.join(OUTPUT_PATH, f'{CITY}_Delivery data - daily tracker box.html')


# ============================================================================
# FUNCTIONS
# ============================================================================

def check_prerequisites():
    """Check that input file exists and create output directories."""
    print("Checking prerequisites...")
    
    # Display current configuration
    print(f"\nCurrent user: {CURRENT_USER}")
    print(f"User root path: {USER_ROOT_PATH}")
    print(f"Selected city: {CITY}")
    
    # Display selected RAW file info
    if INPUT_FILE:
        file_modified = datetime.fromtimestamp(os.path.getmtime(INPUT_FILE))
        print(f"\n✓ Most recent RAW CSV file found:")
        print(f"  File: {os.path.basename(INPUT_FILE)}")
        print(f"  Modified: {file_modified.strftime('%Y-%m-%d %H:%M:%S')}")
    
    # Check input file exists
    if not os.path.exists(INPUT_FILE):
        print(f"\nERROR: Input file not found: {INPUT_FILE}")
        return False
    
    # Create output directory
    os.makedirs(OUTPUT_PATH, exist_ok=True)
    
    print(f"✓ Output directory ready")
    return True


def run_toolbox_generation():
    """Run delivery_tracker_toolbox.py to generate HTML review interface."""
    print("\n" + "="*70)
    print("GENERATING TOOLBOX FROM RAW DATA")
    print("="*70)
    
    try:
        # Get productivity thresholds for selected city
        thresholds = PRODUCTIVITY_THRESHOLDS.get(CITY)
        if not thresholds:
            print(f"WARNING: No productivity thresholds defined for {CITY}, using defaults")
            thresholds = {'min_deliveries': 50, 'max_deliveries': 80}
        
        # Add code directory to Python path
        sys.path.insert(0, CODE_PATH)
        
        # Import and run the toolbox script
        import delivery_tracker_toolbox
        delivery_tracker_toolbox.run_toolbox(
            INPUT_FILE,         # Raw data only
            TOOLBOX_HTML_FILE, 
            CITY,
            min_deliveries=thresholds['min_deliveries'],
            max_deliveries=thresholds['max_deliveries'],
            max_mean_gap=MAX_MEAN_GAP
        )
        
        print(f"\n✓ Toolbox generated: {TOOLBOX_HTML_FILE}")
        return True
        
    except Exception as e:
        print(f"\n✗ ERROR in toolbox generation: {str(e)}")
        import traceback
        traceback.print_exc()
        return False


def main():
    """Main execution function."""
    print("="*70)
    print("DELIVERY TRACKER - SIMPLIFIED PIPELINE")
    print("="*70)
    print(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"User: {CURRENT_USER}")
    print(f"City: {CITY}")
    print("="*70)
    
    # Check prerequisites
    if not check_prerequisites():
        sys.exit(1)
    
    # Generate toolbox directly from RAW data
    if not run_toolbox_generation():
        print("\n✗ Pipeline failed")
        sys.exit(1)
    
    # Success
    print("\n" + "="*70)
    print("✓ PIPELINE COMPLETED SUCCESSFULLY")
    print("="*70)
    print(f"\nOpen the toolbox in your browser:")
    print(f"{TOOLBOX_HTML_FILE}")


if __name__ == "__main__":
    main()