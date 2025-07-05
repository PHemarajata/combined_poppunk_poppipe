process CLUSTER_SUMMARY {
    tag          'cluster_summary'
    publishDir   "${params.resultsDir}/output", mode: 'copy'

    input:
    path fastbaps_files

    output:
    path 'all_clusters.txt'

    script:
    """
    echo "Creating cluster summary from fastbaps results"
    echo "Input files: ${fastbaps_files}"
    
    export PIP_CACHE_DIR=/tmp/pip-cache
    export PYTHONUSERBASE=/tmp/python-user
    pip install --user --quiet pandas
    
    python - << 'PY'
import os
import pandas as pd
from pathlib import Path

# Initialize summary data
all_clusters = []
strain_summaries = []

# Process each fastbaps file
fastbaps_files = '${fastbaps_files}'.split()
print(f"Processing {len(fastbaps_files)} fastbaps files")

for file_path in fastbaps_files:
    if not os.path.exists(file_path):
        print(f"Warning: File not found: {file_path}")
        continue
    
    try:
        # Extract strain ID from file path
        strain_id = "unknown"
        path_parts = Path(file_path).parts
        for part in path_parts:
            if part.startswith("strain") or part.isdigit():
                strain_id = part
                break
        
        print(f"Processing strain {strain_id}: {file_path}")
        
        # Read fastbaps results
        df = pd.read_csv(file_path, sep='\\t', index_col=0)
        
        if df.empty:
            print(f"Warning: Empty file {file_path}")
            continue
        
        # Count clusters at each level
        level_counts = {}
        for col in df.columns:
            if col.startswith('Level'):
                unique_clusters = df[col].nunique()
                level_counts[col] = unique_clusters
                print(f"  {col}: {unique_clusters} clusters")
        
        # Add strain info to summary
        strain_info = {
            'strain_id': strain_id,
            'n_samples': len(df),
            **level_counts
        }
        strain_summaries.append(strain_info)
        
        # Add individual sample cluster assignments
        for sample_name, row in df.iterrows():
            sample_info = {
                'strain_id': strain_id,
                'sample_id': sample_name,
                **{col: row[col] for col in df.columns}
            }
            all_clusters.append(sample_info)
            
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        continue

# Create summary output
with open('all_clusters.txt', 'w') as f:
    f.write("PopPIPE Cluster Summary\\n")
    f.write("=" * 50 + "\\n\\n")
    
    if strain_summaries:
        f.write("STRAIN SUMMARY:\\n")
        f.write("-" * 20 + "\\n")
        
        total_samples = 0
        total_strains = len(strain_summaries)
        
        for strain in strain_summaries:
            f.write(f"Strain {strain['strain_id']}: {strain['n_samples']} samples\\n")
            total_samples += strain['n_samples']
            
            for level_col in [col for col in strain.keys() if col.startswith('Level')]:
                f.write(f"  {level_col}: {strain[level_col]} clusters\\n")
            f.write("\\n")
        
        f.write(f"\\nTOTAL SUMMARY:\\n")
        f.write(f"Total strains processed: {total_strains}\\n")
        f.write(f"Total samples processed: {total_samples}\\n")
        
        # Calculate average clusters per level
        if strain_summaries:
            for level in ['Level.1', 'Level.2', 'Level.3']:
                if level in strain_summaries[0]:
                    avg_clusters = sum(s.get(level, 0) for s in strain_summaries) / len(strain_summaries)
                    f.write(f"Average {level} clusters per strain: {avg_clusters:.1f}\\n")
    else:
        f.write("No strain data processed\\n")
    
    f.write("\\n" + "=" * 50 + "\\n")

print(f"Cluster summary completed. Processed {len(strain_summaries)} strains with {len(all_clusters)} total samples.")
PY
    
    echo "Cluster summary generation completed"
    
    # Verify output
    if [ -f "all_clusters.txt" ]; then
        echo "Summary file created successfully"
        wc -l all_clusters.txt
        echo "Content preview:"
        head -20 all_clusters.txt
    else
        echo "Error: all_clusters.txt not created"
        echo "PopPIPE Cluster Summary - No data processed" > all_clusters.txt
    fi
    """
}