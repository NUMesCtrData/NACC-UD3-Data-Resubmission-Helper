# NACC Data Resubmission Helper

This script supports the comparison and re-submission of NACC-formatted data from the Mesulam Center to NACC. It automates the extraction, comparison, and preparation of updated participant visit data using standardized form files. The script pulls metadata from REDCap, compares new data to original submissions, and outputs ready-to-upload CSV files for NACC.

---

## 📋 Purpose

This script helps data managers:
- Retrieve the data request folder name from REDCap using a data request ID
- Compare original and resubmitted NACC-formatted CSV files
- Identify new or updated visits based on key identifiers
- Generate a clean upload file for NACC
- Track which rows were modified or added
- Create structured folders and handle file paths across Mac and Windows

---

## 🔧 Requirements

**R packages:**

```r
library(tidyverse)
library(redcapAPI)
library(writexl)
library(readxl)
library(arsenal)
library(data.table)

⚠️ plyr and reshape are detached if loaded to avoid conflicts with dplyr and tidyverse.

REDCap Access:
An R script (redcap_api_info.R) stored on OneDrive should define dr_token and url to authenticate REDCap API requests.

## 🚀 Usage
Set your parameters:

dr_id: REDCap Data Request ID (e.g., "1027")

og_submit_date: Original NACC data submission date folder (e.g., "2025_05_20")

resubmit_date: Current data resubmission date folder (e.g., "2025_07_09")

Run the Script:

The script will:

Determine your OneDrive path based on OS

Retrieve the data request name from REDCap (or use one manually)

Create folder structure if not already created

Load all valid NACC-formatted CSVs, excluding known problem files (A4D, A3A, D2.csv, NP.csv)

Read and reformat files as needed

Compare old and new data using arsenal::comparedf

Identify new or changed rows by visit ID

Write a clean upload file and a test file

Log comparison details with variable names for QA

Manually upload A4D file separately!
The script will skip this file but reminds the user to upload it manually.

## 📂 Folder Structure
css
Copy
Edit
/OneDrive - Northwestern University/
├── MC Data Management/
│   └── Data Requests/
│       └── [data_request_name]/
│           └── Program/
│               ├── Input/
│               └── Output/
└── Uploading to Nacc/
    └── Program/
        ├── Past Uploaded NACC Data/
        └── Input/
            └── NACC_Variable_Lookup.csv
## 📄 Output Files
The following files are written to the resubmission folder:

nacc_upload_<date>.csv: Final file for upload to NACC

nacc_upload_test<date>.csv: Test version with the same content

(Optional) QA table if variable lookup exists

## 🧠 Notes
The D2.csv file is skipped and replaced by D2_reformatted.csv to avoid parsing issues with trailing commas.

Missing values are normalized to blank strings.

NACC ID (V5) is padded to 10 digits.

Visit numbers (V9) are padded to 3 digits unless already marked (e.g., m01).

& characters are discouraged and should be replaced with "AND".

## 🔍 Variable Lookup
A helper routine (run = T) is available to regenerate the NACC_Variable_Lookup.csv file from the UDS Excel file. This provides human-readable variable names for QA checks.

## 📢 Reminder
## 🔴 Don't forget to upload A4D separately.
It's excluded due to limitations in distinguishing multiple drug entries.

## 🧑‍💻 Authors
Mesulam Institute Data Management Core

Maintainer: Debby Zemlock
