process SUMMARY_REPORT {
    tag          'summary_report'
    publishDir   "${params.resultsDir}/summary", mode: 'copy'

    input:
    path cluster_csv
    path validation_report

    output:
    path 'pipeline_summary.txt'

    script:
    """
    export PIP_CACHE_DIR=/tmp/pip-cache
    export PYTHONUSERBASE=/tmp/python-user
    pip install --user --quiet pandas
    python - << 'PY'
import pandas as pd
from collections import Counter

# Read cluster assignments
try:
    df = pd.read_csv('${cluster_csv}')
    print(f"Successfully read cluster assignments: {len(df)} samples")
    
    # Count clusters
    if 'Cluster' in df.columns:
        cluster_col = 'Cluster'
    elif 'cluster' in df.columns:
        cluster_col = 'cluster'
    else:
        cluster_col = df.columns[1]  # Assume second column is cluster
    
    cluster_counts = df[cluster_col].value_counts().sort_index()
    total_samples = len(df)
    num_clusters = len(cluster_counts)
    
    # Read validation report
    with open('${validation_report}', 'r') as f:
        validation_content = f.read()
    
    # Generate summary
    with open('pipeline_summary.txt', 'w') as f:
        f.write("="*60 + "\\n")
        f.write("PopPUNK Pipeline Summary Report\\n")
        f.write("="*60 + "\\n\\n")
        
        f.write("VALIDATION RESULTS:\\n")
        f.write("-"*20 + "\\n")
        f.write(validation_content + "\\n\\n")
        
        f.write("CLUSTERING RESULTS:\\n")
        f.write("-"*20 + "\\n")
        f.write(f"Total samples processed: {total_samples}\\n")
        f.write(f"Number of clusters found: {num_clusters}\\n\\n")
        
        f.write("Cluster distribution:\\n")
        for cluster, count in cluster_counts.items():
            percentage = (count / total_samples) * 100
            f.write(f"  Cluster {cluster}: {count} samples ({percentage:.1f}%)\\n")
        
        f.write("\\n" + "="*60 + "\\n")
        
        # Also print to stdout
        print(f"\\n{'='*60}")
        print("PopPUNK Pipeline Summary")
        print(f"{'='*60}")
        print(f"Total samples processed: {total_samples}")
        print(f"Number of clusters found: {num_clusters}")
        print("\\nCluster distribution:")
        for cluster, count in cluster_counts.items():
            percentage = (count / total_samples) * 100
            print(f"  Cluster {cluster}: {count} samples ({percentage:.1f}%)")
        print(f"{'='*60}")

except Exception as e:
    print(f"Error processing results: {e}")
    with open('pipeline_summary.txt', 'w') as f:
        f.write(f"Error generating summary: {e}\\n")
        f.write("Please check the cluster assignment file format.\\n")
PY
    """
}