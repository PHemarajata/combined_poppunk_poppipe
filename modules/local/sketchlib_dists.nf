process SKETCHLIB_DISTS {
    tag          "sketchlib_${strain_id}"
    publishDir   "${params.resultsDir}/strains/${strain_id}", mode: 'copy'

    input:
    path database_dir
    tuple val(strain_id), path(names_file)

    output:
    tuple val(strain_id), path("dists.npy"), path("dists.pkl"), emit: distances

    script:
    """
    echo "Processing strain: ${strain_id}"
    echo "Database directory: ${database_dir}"
    echo "Names file: ${names_file}"
    
    # Debug: List all files in the database directory
    echo "Contents of database directory:"
    ls -la ${database_dir}/
    
    # Find the h5 database file in the directory with multiple approaches
    h5_file=""
    
    # Try direct path first (most common case)
    if [ -f "${database_dir}/poppunk_db.h5" ]; then
        h5_file="${database_dir}/poppunk_db.h5"
        echo "Found h5 file using direct path: \$h5_file"
    else
        # Try find command
        h5_file=\$(find ${database_dir} -name "*.h5" -type f | head -1)
        if [ -n "\$h5_file" ]; then
            echo "Found h5 file using find: \$h5_file"
        else
            # Try ls with wildcard
            h5_file=\$(ls ${database_dir}/*.h5 2>/dev/null | head -1)
            if [ -n "\$h5_file" ]; then
                echo "Found h5 file using ls: \$h5_file"
            fi
        fi
    fi
    
    if [ -z "\$h5_file" ]; then
        echo "ERROR: No .h5 database file found in ${database_dir}"
        echo "Available files:"
        find ${database_dir} -type f
        exit 1
    fi
    
    # Extract the database prefix (remove .h5 extension)
    db_prefix=\$(basename \$h5_file .h5)
    echo "Found database file: \$h5_file"
    echo "Database prefix: \$db_prefix"
    
    # Copy database files to working directory for sketchlib
    echo "Copying database files..."
    cp ${database_dir}/* . || {
        echo "Failed to copy database files, trying individual files..."
        cp "\$h5_file" .
        cp ${database_dir}/*.pkl . 2>/dev/null || true
        cp ${database_dir}/*.npz . 2>/dev/null || true
        cp ${database_dir}/*.gt . 2>/dev/null || true
    }
    
    # Verify files are copied
    echo "Files in working directory:"
    ls -la
    
    # Run sketchlib to extract distances
    echo "Running sketchlib query..."
    sketchlib query dist \$db_prefix \$db_prefix \\
        --subset ${names_file} \\
        -o dists \\
        --cpus ${task.cpus}
    
    echo "Sketchlib distances completed for strain ${strain_id}"
    ls -la dists.*
    """
}