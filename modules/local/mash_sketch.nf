process MASH_SKETCH {
    tag         'mash_sketch'

    input:
    path fasta_files

    output:
    path 'mash.msh'      , emit: msh
    path 'all_files.list', emit: list

    script:
    """
    # Create file list with staged filenames (not absolute paths)
    ls *.fasta > all_files.list
    
    # Check if we have any files to process
    if [ ! -s all_files.list ]; then
        echo "ERROR: No valid FASTA files found for sketching"
        exit 1
    fi
    
    echo "Sketching \$(wc -l < all_files.list) valid FASTA files..."
    echo "First few files to be processed:"
    head -5 all_files.list
    
    echo "All files verified. Starting MASH sketching..."
    
    mash sketch -p ${task.cpus} -k ${params.mash_k} -s ${params.mash_s} \\
        -o mash.msh -l all_files.list
        
    echo "MASH sketching completed successfully!"
    """
}