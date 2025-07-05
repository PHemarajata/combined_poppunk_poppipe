process GUBBINS {
    tag          "gubbins_${strain_id}"
    publishDir   "${params.resultsDir}/strains/${strain_id}", mode: 'copy'

    input:
    tuple val(strain_id), path(mapping_aln)
    tuple val(strain_id_tree), path(ml_tree)

    output:
    tuple val(strain_id), path("${params.gubbins_prefix}.final_tree.tre"), emit: gubbins_tree

    script:
    """
    echo "Running Gubbins for strain: ${strain_id}"
    echo "Mapping alignment: ${mapping_aln}"
    echo "Starting tree: ${ml_tree}"
    
    # Run Gubbins
    run_gubbins.py ${mapping_aln} \\
        --prefix ${params.gubbins_prefix} \\
        --starting-tree ${ml_tree} \\
        --tree-builder ${params.gubbins_tree_builder} \\
        --min-snps ${params.gubbins_min_snps} \\
        --min-window-size ${params.gubbins_min_window_size} \\
        --max-window-size ${params.gubbins_max_window_size} \\
        --iterations ${params.gubbins_iterations} \\
        --threads ${task.cpus}
    
    echo "Gubbins completed"
    
    # Check if Gubbins completed successfully
    if [ -f "${params.gubbins_prefix}.final_tree.tre" ]; then
        echo "Gubbins tree created successfully"
        wc -c ${params.gubbins_prefix}.final_tree.tre
    else
        echo "Gubbins failed, using ML tree as fallback"
        cp ${ml_tree} ${params.gubbins_prefix}.final_tree.tre
    fi
    
    # List all output files
    echo "Gubbins output files:"
    ls -la ${params.gubbins_prefix}.*
    """
}