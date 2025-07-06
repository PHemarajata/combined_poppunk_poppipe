process POPPUNK_ASSIGN {
    tag          "poppunk_assign on \$(wc -l < ${valid_list}) samples"
    publishDir   "${params.resultsDir}/poppunk_assign", mode: 'copy'

    input:
    path db_dir
    path valid_list
    path fasta_files

    output:
    path 'full_assign.csv'

    script:
    // The method is toKilo(), not toKB()
    def mem_kb = task.memory.toKilo()

    """
    # Create a staged file list for all valid FASTA files.
    # This assumes valid_list is a two-column TSV: sample_name\tpath/to/file.fasta
    > staged_all_files.list
    while IFS=\$'\\t' read -r sample_name file_path; do
        basename_file=\$(basename "\$file_path")
        if [ -f "\$basename_file" ]; then
            echo -e "\$sample_name\\t\$basename_file" >> staged_all_files.list
        else
            echo "WARNING: Staged file not found for sample '\$sample_name': \$basename_file"
        fi
    done < "${valid_list}"

    echo "Assigning \$(wc -l < staged_all_files.list) genomes to PopPUNK clusters..."

    # SEGFAULT PREVENTION: Set resource limits
    echo "Setting resource limits..."
    ulimit -v ${mem_kb}  # Virtual memory limit in KB
    ulimit -m ${mem_kb}  # Physical memory limit in KB
    ulimit -s 8192       # 8MB stack limit
    ulimit -c 0          # Disable core dumps
    echo "Memory limits set: Virtual/Physical=${task.memory}"
    echo "Using ${task.cpus} threads."

    # Run PopPUNK assignment with fallbacks. The --no-plot flag has been removed as it is invalid.
    if poppunk_assign --db "${db_dir}" --query staged_all_files.list --output poppunk_full --threads ${task.cpus} ${params.poppunk_retain_failures ? '--retain-failures' : ''}; then
        echo "✅ PopPUNK assignment completed successfully."
    elif poppunk_assign --db "${db_dir}" --query staged_all_files.list --output poppunk_full --threads 2 ${params.poppunk_retain_failures ? '--retain-failures' : ''}; then
        echo "✅ PopPUNK assignment completed with reduced threads."
    elif poppunk_assign --db "${db_dir}" --query staged_all_files.list --output poppunk_full --threads 1 ${params.poppunk_retain_failures ? '--retain-failures' : ''}; then
        echo "✅ PopPUNK assignment completed with minimal settings."
    else
        echo "❌ All PopPUNK assignment attempts failed."
        exit 1
    fi

    # Locate the definitive output cluster file and copy it
    ASSIGN_CSV="poppunk_full/poppunk_full_clusters.csv"
    if [ -f "\$ASSIGN_CSV" ]; then
        cp "\$ASSIGN_CSV" full_assign.csv
        echo "Final assignment file 'full_assign.csv' created."
    else
        echo "ERROR: PopPUNK assignment finished, but the output file (\$ASSIGN_CSV) was not found."
        # Create a minimal file to prevent the pipeline from crashing, but log the error
        echo "sample,cluster" > full_assign.csv
        echo "no_sample,assignment_failed" >> full_assign.csv
        exit 1
    fi

    # Cluster distribution analysis
    echo "--- Cluster Distribution Analysis ---"
    total_samples=\$(tail -n +2 full_assign.csv | wc -l)
    unique_clusters=\$(tail -n +2 full_assign.csv | cut -d',' -f2 | sort -u | wc -l)
    echo "Total samples assigned: \$total_samples"
    echo "Number of unique clusters: \$unique_clusters"
    echo "Top 10 largest clusters:"
    tail -n +2 full_assign.csv | cut -d',' -f2 | sort | uniq -c | sort -nr | head -10

    if [ "\$unique_clusters" -eq 1 ] && [ "\$total_samples" -gt 1 ]; then
        echo "⚠️  WARNING: All samples were assigned to a single cluster."
    else
        echo "✅ Cluster diversity looks good."
    fi
    """
}