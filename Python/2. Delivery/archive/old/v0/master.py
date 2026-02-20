"""
Delivery Tracker Master Script
===============================

Centralized script to run the delivery tracker data pipeline:
1. Clean and filter field data (delivery_tracker_cleaning.py)
2. Generate interactive review toolbox (delivery_tracker_toolbox.py)

Author: Robin Benabid Jégaden
Date: 2026-01-15
"""

import os
import sys
from datetime import datetime
import glob

# ============================================================================
# USER CONFIGURATION
# ============================================================================

# SELECT YOUR NAME - Each user changes only this line
CURRENT_USER = 'Robin'  # Change to your name when you use the script

# User-specific Dropbox root paths
USER_PATHS = {
    'Robin': r'D:\LoGRI Dropbox',
    'Lorena': r'C:\Users\John\Dropbox\LoGRI Dropbox',
    'Zoe': r'C:\Users\Zoe\LoGRI Dropbox',
    # Add your Dropbox root path here
}

# ============================================================================
# CONFIGURATION - CITY SELECTION
# ============================================================================

# SELECT CITY: 'Freetown', 'Kenema', or 'Makeni'
CITY = 'Kenema'  # <-- CHANGE THIS TO SWITCH CITIES

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

# Output paths (uses CITY variable)
BUILD_PATH = os.path.join(BASE_PATH, r'12. Data\2. Build\delivery_tracker', CITY)
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
# AUTO-DETECT MOST RECENT FILES
# ============================================================================

# Find most recent input file (RAW)
INPUT_FILE = get_most_recent_csv(RAW_DATA_PATH)

if INPUT_FILE is None:
    print(f"ERROR: No CSV file found in {RAW_DATA_PATH}")
    sys.exit(1)

# Extract date from input filename for output naming
import re
date_match = re.search(r'(\d{4}-\d{2}-\d{2})', INPUT_FILE)
FILE_DATE = date_match.group(1) if date_match else datetime.now().strftime('%Y-%m-%d')

# Output file for Step 1 (will be created)
FILTERED_DATA_FILE = os.path.join(BUILD_PATH, f'delivery_build_tracker_{FILE_DATE}.csv')

# HTML output file
TOOLBOX_HTML_FILE = os.path.join(OUTPUT_PATH, 'Delivery data - daily tracker box.html')


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
    
    # Create output directories
    os.makedirs(BUILD_PATH, exist_ok=True)
    os.makedirs(OUTPUT_PATH, exist_ok=True)
    
    print(f"✓ Output directories ready")
    return True


def run_data_cleaning():
    """Run delivery_tracker_cleaning.py to filter field data."""
    print("\n" + "="*70)
    print("STEP 1: DATA CLEANING AND FILTERING")
    print("="*70)
    
    try:
        # Add code directory to Python path
        sys.path.insert(0, CODE_PATH)
        
        # Import and run the cleaning script
        import delivery_tracker_cleaning
        delivery_tracker_cleaning.run_filter(INPUT_FILE, FILTERED_DATA_FILE)
        
        print(f"\n✓ Filtered data saved: {FILTERED_DATA_FILE}")
        return True
        
    except Exception as e:
        print(f"\n✗ ERROR in data cleaning: {str(e)}")
        import traceback
        traceback.print_exc()
        return False


def run_toolbox_generation():
    """Run delivery_tracker_toolbox.py to generate HTML review interface."""
    print("\n" + "="*70)
    print("STEP 2: TOOLBOX GENERATION")
    print("="*70)
    
    try:
        # Get most recent BUILD file
        most_recent_build = get_most_recent_csv(BUILD_PATH)
        
        if most_recent_build is None:
            print(f"ERROR: No BUILD file found in {BUILD_PATH}")
            return False
        
        # Display which BUILD file is being used
        build_modified = datetime.fromtimestamp(os.path.getmtime(most_recent_build))
        print(f"\n✓ Most recent BUILD CSV file found:")
        print(f"  File: {os.path.basename(most_recent_build)}")
        print(f"  Modified: {build_modified.strftime('%Y-%m-%d %H:%M:%S')}")
        
        # Import and run the toolbox script
        import delivery_tracker_toolbox
        delivery_tracker_toolbox.run_toolbox(most_recent_build, TOOLBOX_HTML_FILE)
        
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
    print("DELIVERY TRACKER PIPELINE")
    print("="*70)
    print(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"User: {CURRENT_USER}")
    print(f"City: {CITY}")
    print("="*70)
    
    # Check prerequisites
    if not check_prerequisites():
        sys.exit(1)
    
    # Step 1: Clean and filter data
    if not run_data_cleaning():
        print("\n✗ Pipeline failed at Step 1: Data Cleaning")
        sys.exit(1)
    
    # Step 2: Generate toolbox
    if not run_toolbox_generation():
        print("\n✗ Pipeline failed at Step 2: Toolbox Generation")
        sys.exit(1)
    
    # Success
    print("\n" + "="*70)
    print("✓ PIPELINE COMPLETED SUCCESSFULLY")
    print("="*70)
    print(f"\nOpen the toolbox in your browser:")
    print(f"{TOOLBOX_HTML_FILE}")


if __name__ == "__main__":
    main()