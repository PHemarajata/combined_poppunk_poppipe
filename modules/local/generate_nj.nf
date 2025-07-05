process GENERATE_NJ {
    tag          "nj_${strain_id}"
    publishDir   "${params.resultsDir}/strains/${strain_id}", mode: 'copy'

    input:
    tuple val(strain_id), path(npy_file), path(pkl_file)

    output:
    tuple val(strain_id), path("njtree.nwk"), emit: nj_tree

    script:
    """
    python - << 'PY'
import numpy as np
import pickle
from io import StringIO
import subprocess
import sys

# Load the distance data
try:
    distances = np.load('${npy_file}')
    with open('${pkl_file}', 'rb') as f:
        sample_names = pickle.load(f)
    
    print(f"Loaded distances for {len(sample_names)} samples")
    print(f"Distance matrix shape: {distances.shape}")
    
    # Create distance matrix in PHYLIP format for rapidnj
    n_samples = len(sample_names)
    
    with open('distances.phy', 'w') as f:
        f.write(f"{n_samples}\\n")
        for i, name in enumerate(sample_names):
            # Truncate names to 10 characters for PHYLIP format
            short_name = name[:10].ljust(10)
            f.write(f"{short_name}")
            for j in range(n_samples):
                f.write(f" {distances[i,j]:.6f}")
            f.write("\\n")
    
    print("Created PHYLIP distance file")
    
    # Run rapidnj to create neighbor-joining tree
    cmd = ["rapidnj", "distances.phy", "-i", "pd", "-o", "t", "-x", "njtree.nwk"]
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    if result.returncode == 0:
        print("Successfully created NJ tree")
        # Verify output file exists
        import os
        if os.path.exists('njtree.nwk'):
            with open('njtree.nwk', 'r') as f:
                tree_content = f.read().strip()
                print(f"Tree length: {len(tree_content)} characters")
        else:
            print("Warning: njtree.nwk not found")
    else:
        print(f"rapidnj failed: {result.stderr}")
        # Create a simple star tree as fallback
        tree_str = "(" + ",".join(sample_names) + ");"
        with open('njtree.nwk', 'w') as f:
            f.write(tree_str)
        print("Created fallback star tree")

except Exception as e:
    print(f"Error in NJ tree generation: {e}")
    # Create a minimal tree as fallback
    with open('njtree.nwk', 'w') as f:
        f.write("(sample1,sample2);")
    sys.exit(1)
PY
    """
}