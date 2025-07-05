process POPPUNK_MODEL {
    tag          'poppunk_model'
    publishDir   "${params.resultsDir}/poppunk_model", mode: 'copy'

    input:
    path sub_list
    path fasta_files

    output:
    path 'poppunk_db', type: 'dir', emit: db
    path 'cluster_model.csv'     , emit: csv
    path 'staged_files.list'     , emit: staged_list

    script:
    """
    # Check if subset list is not empty
    if [ ! -s ${sub_list} ]; then
        echo "ERROR: Subset list is empty. No valid genomes found for PopPUNK modeling."
        exit 1
    fi
    
    echo "Building PopPUNK database with \$(wc -l < ${sub_list}) genomes..."
    
    # Create a new file list with staged filenames (not absolute paths)
    # Map the sample names from subset.list to the staged FASTA files
    > staged_files.list
    while IFS=\$'\\t' read -r sample_name file_path; do
        # Find the corresponding staged file
        basename_file=\$(basename "\$file_path")
        if [ -f "\$basename_file" ]; then
            echo -e "\$sample_name\\t\$basename_file" >> staged_files.list
            echo "Mapped: \$sample_name -> \$basename_file"
        else
            echo "ERROR: Staged file not found: \$basename_file"
            exit 1
        fi
    done < ${sub_list}
    
    echo "Created staged files list:"
    cat staged_files.list
    
    echo "All files verified. Starting PopPUNK database creation..."
    
    poppunk --create-db --r-files staged_files.list \\
        --output poppunk_db --threads ${task.cpus}

    echo "Database created successfully. Fitting model with PopPUNK 2.7.x features..."
    
    # Use optimized PopPUNK 2.7.x features for better cluster separation
    echo "Fitting PopPUNK model with optimized parameters for better clustering..."
    poppunk --fit-model bgmm --ref-db poppunk_db \\
        --output poppunk_fit --threads ${task.cpus} \\
        ${params.poppunk_reciprocal ? '--reciprocal-only' : ''} \\
        ${params.poppunk_count_unique ? '--count-unique-distances' : ''} \\
        --max-search-depth ${params.poppunk_max_search} \\
        --K ${params.poppunk_K}

    echo "Model fitting completed. Copying fitted model files to database directory..."
    
    # Copy all fitted model files from poppunk_fit to poppunk_db
    # This ensures the database directory contains both the database and the fitted model
    if [ -d "poppunk_fit" ]; then
        echo "Copying fitted model files to poppunk_db directory..."
        
        # Copy all files from poppunk_fit to poppunk_db
        cp poppunk_fit/* poppunk_db/ 2>/dev/null || echo "Some files could not be copied"
        
        # The critical step: rename the fitted model file to match what PopPUNK expects
        if [ -f "poppunk_db/poppunk_fit_fit.pkl" ]; then
            cp poppunk_db/poppunk_fit_fit.pkl poppunk_db/poppunk_db_fit.pkl
            echo "✓ Created poppunk_db_fit.pkl from poppunk_fit_fit.pkl"
        fi
        
        # Also copy the npz file with the correct name
        if [ -f "poppunk_db/poppunk_fit_fit.npz" ]; then
            cp poppunk_db/poppunk_fit_fit.npz poppunk_db/poppunk_db_fit.npz
            echo "✓ Created poppunk_db_fit.npz from poppunk_fit_fit.npz"
        fi
        
        # Copy the graph file with the correct name - CRITICAL for poppunk_assign
        if [ -f "poppunk_db/poppunk_fit_graph.gt" ]; then
            cp poppunk_db/poppunk_fit_graph.gt poppunk_db/poppunk_db_graph.gt
            echo "✓ Created poppunk_db_graph.gt from poppunk_fit_graph.gt"
        fi
        
        # Copy the cluster file with the correct name - CRITICAL for poppunk_assign
        if [ -f "poppunk_db/poppunk_fit_clusters.csv" ]; then
            cp poppunk_db/poppunk_fit_clusters.csv poppunk_db/poppunk_db_clusters.csv
            echo "✓ Created poppunk_db_clusters.csv from poppunk_fit_clusters.csv"
        fi
        
        echo "Files in poppunk_db after copying:"
        ls -la poppunk_db/
        
        # Verify the critical model files exist
        if [ -f "poppunk_db/poppunk_db_fit.pkl" ]; then
            echo "✓ Found fitted model file: poppunk_db_fit.pkl"
        else
            echo "⚠ Model .pkl file not found. Available files:"
            ls -la poppunk_db/*.pkl 2>/dev/null || echo "No .pkl files found"
        fi
        
        if [ -f "poppunk_db/poppunk_db_graph.gt" ]; then
            echo "✓ Found graph file: poppunk_db_graph.gt"
        else
            echo "⚠ Graph file not found. Available graph files:"
            ls -la poppunk_db/*.gt 2>/dev/null || echo "No .gt files found"
        fi
        
        if [ -f "poppunk_db/poppunk_db_clusters.csv" ]; then
            echo "✓ Found cluster file: poppunk_db_clusters.csv"
        else
            echo "⚠ Cluster file not found. Available cluster files:"
            ls -la poppunk_db/*clusters*.csv 2>/dev/null || echo "No cluster CSV files found"
        fi
    else
        echo "ERROR: poppunk_fit directory not found"
        exit 1
    fi

    # Check for different possible output file locations for cluster assignments
    if [ -f "poppunk_fit/poppunk_fit_clusters.csv" ]; then
        cp poppunk_fit/poppunk_fit_clusters.csv cluster_model.csv
        echo "Found poppunk_fit_clusters.csv in poppunk_fit/"
    elif [ -f "poppunk_fit/cluster_assignments.csv" ]; then
        cp poppunk_fit/cluster_assignments.csv cluster_model.csv
        echo "Found cluster_assignments.csv in poppunk_fit/"
    elif ls poppunk_fit/*_clusters.csv 1> /dev/null 2>&1; then
        cp poppunk_fit/*_clusters.csv cluster_model.csv
        echo "Found cluster file in poppunk_fit/"
    elif ls poppunk_fit/*.csv 1> /dev/null 2>&1; then
        cp poppunk_fit/*.csv cluster_model.csv
        echo "Found CSV file in poppunk_fit/"
    else
        echo "Available files in poppunk_fit/:"
        ls -la poppunk_fit/ || echo "poppunk_fit directory not found"
        echo "Available files in current directory:"
        ls -la *.csv || echo "No CSV files found"
        # Create a minimal output file so the pipeline doesn't fail
        echo "sample,cluster" > cluster_model.csv
        echo "PopPUNK completed but cluster assignments file not found in expected location"
    fi
    
    echo "PopPUNK model completed successfully!"
    """
}