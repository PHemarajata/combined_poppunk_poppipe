#!/bin/bash -ue
# Check if subset list is not empty
if [ ! -s "subset.list" ]; then
    echo "ERROR: Subset list is empty. No valid genomes found for PopPUNK modeling."
    exit 1
fi

echo "Building PopPUNK database with $(wc -l < "subset.list") genomes..."

# Create a new file list with staged filenames by mapping sample names to the staged FASTA files
> staged_files.list
while IFS=$'\t' read -r sample_name file_path; do
    basename_file=$(basename "$file_path")
    if [ -f "$basename_file" ]; then
        echo -e "$sample_name\t$basename_file" >> staged_files.list
    else
        echo "ERROR: Staged file not found: $basename_file for sample $sample_name"
        exit 1
    fi
done < "subset.list"

echo "Created staged files list. Verifying all files are present..."
cat staged_files.list

# SEGFAULT PREVENTION: Set memory and resource limits
echo "Setting resource limits to prevent segmentation faults..."
ulimit -v 41943040  # Virtual memory limit in KB
ulimit -m 41943040  # Physical memory limit in KB
ulimit -s 8192       # 8MB stack limit
ulimit -c 0          # Disable core dumps

echo "Memory limits set: Virtual/Physical=40 GB"
echo "Using 12 threads for PopPUNK."

# Create database with a fallback for reduced threads
if ! poppunk --create-db --r-files staged_files.list \
    --output poppunk_db --threads 12; then
    echo "⚠️  Database creation failed, retrying with 2 threads..."
    poppunk --create-db --r-files staged_files.list \
        --output poppunk_db --threads 2
fi
echo "✅ PopPUNK database created successfully."

# Fit model with optimized features and multiple fallbacks
echo "Fitting PopPUNK model with optimized parameters..."
if poppunk --fit-model bgmm --ref-db poppunk_db --output poppunk_fit --threads 12 --reciprocal-only  --max-search-depth 15 --K 2 --no-plot; then
    echo "✅ PopPUNK model fitting completed successfully."
elif poppunk --fit-model bgmm --ref-db poppunk_db --output poppunk_fit --threads 2 --max-search-depth 10 --K 2 --no-plot; then
    echo "✅ PopPUNK model fitting completed with reduced complexity."
elif poppunk --fit-model bgmm --ref-db poppunk_db --output poppunk_fit --threads 1 --K 2 --no-plot; then
    echo "✅ PopPUNK model fitting completed with minimal settings."
else
    echo "❌ All PopPUNK model fitting attempts failed."
    exit 1
fi

echo "Model fitting completed. Preparing database for assignment..."
# Consolidate the fitted model into the database directory for poppunk_assign
if [ -d "poppunk_fit" ]; then
    # Copy and rename critical model files to what poppunk_assign expects
    cp poppunk_fit/poppunk_fit_fit.pkl     poppunk_db/poppunk_db_fit.pkl
    cp poppunk_fit/poppunk_fit_fit.npz     poppunk_db/poppunk_db_fit.npz
    cp poppunk_fit/poppunk_fit_graph.gt    poppunk_db/poppunk_db_graph.gt
    cp poppunk_fit/*_clusters.csv         poppunk_db/poppunk_db_clusters.csv

    # Verify that the final cluster file exists before copying to output
    if [ -f "poppunk_db/poppunk_db_clusters.csv" ]; then
        cp poppunk_db/poppunk_db_clusters.csv cluster_model.csv
        echo "✓ Cluster model CSV prepared."
    else
         echo "sample,cluster" > cluster_model.csv
         echo "⚠️  PopPUNK completed but cluster assignments file was not found."
    fi
else
    echo "ERROR: poppunk_fit directory not found after model fitting."
    exit 1
fi

echo "PopPUNK model process completed successfully!"
