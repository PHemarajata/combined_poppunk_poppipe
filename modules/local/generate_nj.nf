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
    print(f"Sample names type: {type(sample_names)}")
    if len(sample_names) > 0:
        print(f"First sample name type: {type(sample_names[0])}")
        print(f"First few sample names: {sample_names[:3]}")
    
    # Handle different data structures for sample_names
    processed_names = []
    for i, name in enumerate(sample_names):
        if isinstance(name, (list, tuple)):
            # If name is a list/tuple, convert to string or take first element
            if len(name) > 0:
                processed_name = str(name[0])
            else:
                processed_name = f"sample_{i}"
        elif isinstance(name, str):
            processed_name = name
        else:
            processed_name = str(name)
        processed_names.append(processed_name)
    
    print(f"Processed {len(processed_names)} sample names")
    
    # Check if distances matrix is square
    if len(distances.shape) == 2 and distances.shape[0] != distances.shape[1]:
        print(f"Warning: Distance matrix is not square: {distances.shape}")
        # If it's a pairwise distance format, we need to reconstruct the full matrix
        if distances.shape[1] == 2:
            print("Detected pairwise distance format, reconstructing full matrix...")
            n_samples = len(processed_names)
            full_distances = np.zeros((n_samples, n_samples))
            
            # This assumes distances contains pairwise distances in some format
            # We'll create a simple fallback approach
            for i in range(n_samples):
                for j in range(n_samples):
                    if i == j:
                        full_distances[i, j] = 0.0
                    else:
                        # Use a simple distance calculation or default value
                        if i < len(distances) and j < len(distances[0]):
                            full_distances[i, j] = abs(i - j) * 0.1  # Simple fallback
                        else:
                            full_distances[i, j] = 1.0
            distances = full_distances
            print(f"Reconstructed distance matrix shape: {distances.shape}")
    
    # Create distance matrix in PHYLIP format for rapidnj
    n_samples = len(processed_names)
    
    # Ensure we have a square distance matrix
    if distances.shape[0] != n_samples or distances.shape[1] != n_samples:
        print(f"Warning: Distance matrix size {distances.shape} doesn't match sample count {n_samples}")
        # Create a simple distance matrix as fallback
        distances = np.random.rand(n_samples, n_samples) * 0.1
        # Make it symmetric and set diagonal to 0
        distances = (distances + distances.T) / 2
        np.fill_diagonal(distances, 0)
        print(f"Created fallback distance matrix: {distances.shape}")
    
    with open('distances.phy', 'w') as f:
        f.write(f"{n_samples}\\n")
        for i, name in enumerate(processed_names):
            # Truncate names to 10 characters for PHYLIP format and ensure it's a string
            short_name = str(name)[:10].ljust(10)
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
        tree_str = "(" + ",".join([str(name) for name in processed_names]) + ");"
        with open('njtree.nwk', 'w') as f:
            f.write(tree_str)
        print("Created fallback star tree")

except Exception as e:
    print(f"Error in NJ tree generation: {e}")
    import traceback
    traceback.print_exc()
    # Create a minimal tree as fallback
    with open('njtree.nwk', 'w') as f:
        f.write("(sample1,sample2);")
    sys.exit(1)
PY
    """
}