process SKETCHLIB_DISTS {
    tag          "sketchlib_${strain_id}"
    publishDir   "${params.resultsDir}/strains/${strain_id}", mode: 'copy'

    input:
    path database_h5
    tuple val(strain_id), path(names_file)

    output:
    tuple val(strain_id), path("dists.npy"), path("dists.pkl"), emit: distances

    script:
    // Extract database prefix from h5 file
    def db_prefix = database_h5.baseName
    """
    echo "Processing strain: ${strain_id}"
    echo "Database: ${database_h5}"
    echo "Names file: ${names_file}"
    
    # Extract the database prefix (remove .h5 extension)
    db_prefix=\$(basename ${database_h5} .h5)
    echo "Database prefix: \$db_prefix"
    
    # Run sketchlib to extract distances
    sketchlib query dist \$db_prefix \$db_prefix \\
        --subset ${names_file} \\
        -o dists \\
        --cpus ${task.cpus}
    
    echo "Sketchlib distances completed for strain ${strain_id}"
    ls -la dists.*
    """
}