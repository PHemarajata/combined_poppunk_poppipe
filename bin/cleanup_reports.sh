#!/bin/bash

# Cleanup script to remove existing report files before running the pipeline
# This prevents the "file already exists" errors

if [ $# -eq 0 ]; then
    echo "Usage: $0 <results_directory>"
    echo "Example: $0 /path/to/results"
    exit 1
fi

RESULTS_DIR="$1"
REPORTS_DIR="${RESULTS_DIR}/reports"

echo "🧹 Cleaning up existing report files in: ${REPORTS_DIR}"

if [ -d "${REPORTS_DIR}" ]; then
    echo "Removing existing report files..."
    rm -f "${REPORTS_DIR}"/*.html
    rm -f "${REPORTS_DIR}"/*.txt
    echo "✅ Report files cleaned up"
else
    echo "📁 Creating reports directory: ${REPORTS_DIR}"
    mkdir -p "${REPORTS_DIR}"
fi

echo "🎯 Reports directory is ready for new pipeline run"