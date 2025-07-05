process SPLIT_STRAINS {
    tag          'split_strains'
    publishDir   "${params.resultsDir}/strains", mode: 'copy'

    input:
    path rfile
    path clusters_csv
    val strain_ids

    output:
    path 'strains/*/rfile.txt', emit: strain_data
    path 'strains/*/names.txt', emit: strain_names

    script:
    """
    export PIP_CACHE_DIR=/tmp/pip-cache
    export PYTHONUSERBASE=/tmp/python-user
    pip install --user --quiet pandas
    python - << 'PY'
import pandas as pd
import os
from pathlib import Path

# Read the rfile (sample to file mapping)
samples = pd.read_table('${rfile}', header=None, index_col=0, names=['file'])

# Read clusters
clusters = pd.read_csv('${clusters_csv}', dtype={'Cluster': str})
if 'Cluster' not in clusters.columns and 'cluster' in clusters.columns:
    clusters = clusters.rename(columns={'cluster': 'Cluster'})

# Set index to sample name
if 'Taxon' in clusters.columns:
    clusters = clusters.set_index('Taxon')
elif 'sample' in clusters.columns:
    clusters = clusters.set_index('sample')
else:
    clusters = clusters.set_index(clusters.columns[0])

# Get strain IDs that meet minimum cluster size
strain_ids = ${strain_ids}
print(f"Processing {len(strain_ids)} strains that meet minimum size requirement")

# Create output directory
os.makedirs('strains', exist_ok=True)

for strain_id in strain_ids:
    strain_id = str(strain_id).strip()
    print(f"Processing strain: {strain_id}")
    
    # Get samples for this strain
    strain_samples = clusters[clusters['Cluster'].astype(str).str.strip() == strain_id]
    
    if len(strain_samples) == 0:
        print(f"Warning: No samples found for strain {strain_id}")
        continue
    
    # Get the corresponding file paths
    sample_subset = samples.loc[strain_samples.index.intersection(samples.index)]
    
    if len(sample_subset) > 1:
        # Create strain directory
        strain_dir = f'strains/{strain_id}'
        os.makedirs(strain_dir, exist_ok=True)
        
        # Write rfile for this strain
        rfile_path = f'{strain_dir}/rfile.txt'
        sample_subset.to_csv(rfile_path, sep='\\t', header=False)
        
        # Write names file for this strain
        names_path = f'{strain_dir}/names.txt'
        sample_subset.index.to_series().to_csv(names_path, sep='\\t', header=False, index=False)
        
        print(f"Created files for strain {strain_id}: {len(sample_subset)} samples")
    else:
        print(f"Skipping strain {strain_id}: only {len(sample_subset)} samples")

print("Strain splitting completed")
PY
    """
}