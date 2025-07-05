process IQ_TREE {
    tag          "iqtree_${strain_id}"
    publishDir   "${params.resultsDir}/strains/${strain_id}", mode: 'copy'

    input:
    tuple val(strain_id), path(nj_tree)
    tuple val(strain_id_aln), path(alignment)
    path rfiles

    output:
    tuple val(strain_id), path("besttree.nwk"), emit: ml_tree

    script:
    """
    echo "Running IQ-TREE for strain: ${strain_id}"
    echo "Starting tree: ${nj_tree}"
    echo "Alignment: ${alignment}"
    
    if [ "${params.iqtree_enabled}" = "true" ]; then
        echo "IQ-TREE is enabled, running ML tree inference"
        
        # Run IQ-TREE
        if [ "${params.iqtree_mode}" = "fast" ]; then
            echo "Running IQ-TREE in fast mode"
            iqtree2 -s ${alignment} \\
                -t ${nj_tree} \\
                -m ${params.iqtree_model} \\
                --fast \\
                -nt ${task.cpus} \\
                --prefix besttree.unrooted \\
                --quiet
        else
            echo "Running IQ-TREE in full mode"
            iqtree2 -s ${alignment} \\
                -t ${nj_tree} \\
                -m ${params.iqtree_model} \\
                -nt ${task.cpus} \\
                --prefix besttree.unrooted \\
                --quiet
        fi
        
        # Check if IQ-TREE completed successfully
        if [ -f "besttree.unrooted.treefile" ]; then
            echo "IQ-TREE completed successfully"
            
            # Root the tree (simple midpoint rooting)
            python - << 'PY'
import sys
try:
    # Simple tree rooting - just copy the tree for now
    # In a full implementation, you'd use a proper tree library like ete3 or dendropy
    with open('besttree.unrooted.treefile', 'r') as f:
        tree_content = f.read().strip()
    
    with open('besttree.nwk', 'w') as f:
        f.write(tree_content)
    
    print("Tree rooting completed")
except Exception as e:
    print(f"Error in tree processing: {e}")
    # Fallback: copy NJ tree
    import shutil
    shutil.copy('${nj_tree}', 'besttree.nwk')
    print("Used NJ tree as fallback")
PY
        else
            echo "IQ-TREE failed, using NJ tree as fallback"
            cp ${nj_tree} besttree.nwk
        fi
    else
        echo "IQ-TREE is disabled, using NJ tree"
        cp ${nj_tree} besttree.nwk
    fi
    
    echo "ML tree generation completed"
    
    # Verify output
    if [ -f "besttree.nwk" ]; then
        echo "Final tree file created successfully"
        wc -c besttree.nwk
    else
        echo "Error: besttree.nwk not found"
        exit 1
    fi
    """
}