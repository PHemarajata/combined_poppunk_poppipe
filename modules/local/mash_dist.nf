process MASH_DIST {
    tag         'mash_dist'

    input:
    path msh

    output:
    path 'mash.dist'

    script:
    """
    echo "Computing pairwise distances for all genomes..."
    mash dist -p ${task.cpus} ${msh} ${msh} > mash.dist
    echo "Distance computation completed. Generated \$(wc -l < mash.dist) pairwise comparisons."
    """
}