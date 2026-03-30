# Delivery Data Review Toolbox 📦

This repository provides an automated solution for quality control and productivity monitoring of field delivery operations. It generates both an **interactive HTML interface** for anomaly filtering and statistics by team/date as well as **individual detailed PDF reports** for field agents.

## 🚀 Getting Started

To update the tracking data and generate new reports, follow these steps:

1. **Data Extraction:**
   * Log in to the dashboard: [Production Mobile Monitor](https://analytics-ftn.moptax.com/dashboard/11-production-mobile-monitor)
   * Download the raw data in **CSV** format.
   * Place the downloaded file into the `data/[CITY]/` folder of your local repository (replace `[CITY]` with the relevant city name).

2. **Execution in Python:**
   * Open the `delivery_tracker_master.py` script.
   * **Required:** Modify **Line 23** to specify the target city (e.g., `CITY = "Freetown"`).
   * Run the script.

3. **Reviewing Results:**
   * **Interactive Interface:** Open the generated `.html` file at the root of the directory to filter observations by date and/or team.
   * **Individual Reports:** Navigate to the `stats_enum/` folder to find detailed PDF performance sheets for each agent.

---

## 🛠️ System Features

The toolbox (`delivery_tracker_toolbox.py`) automatically evaluates observations based on the following criteria:

### 1. Data Quality Control
The system flags observations with the following issues:
* **Missing Data:** "Created On", "Updated On", or "Delivered On" fields are empty.
* **Geolocation:** Distance from target exceeds **50 meters** or "Property At Correct Location" is marked False.
* **Evidence of Delivery:** Missing "Proof of Delivery" image or "Signature Path".
* **Type Mismatch:** Discrepancies between Delivery Type (RDN/Business) and specific fee categories.

### 2. Productivity Monitoring
The script identifies potential field difficulties based on predefined thresholds:
* **Volume:** Total daily deliveries outside the expected range (**City Specific: Freetown = 50-90**).
* **Pace:** An average gap between deliveries exceeding **15 minutes**.
* **Breaks:** Any inactivity period longer than **1 hour and 30 minutes** between consecutive deliveries.

---

## 📋 Prerequisites
* Python 3.x (Anaconda / Spyder environment recommended).
* Required Libraries: `pandas`, `xhtml2pdf` (automatically installed by the script if missing).

**Author:** Robin Benabid Jégaden  