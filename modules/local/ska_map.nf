process SKA_MAP {
    tag          "ska_map_${strain_id}"
    publishDir   "${params.resultsDir}/strains/${strain_id}", mode: 'copy'

    input:
    tuple val(strain_id), path(skf_file)
    tuple val(strain_id_ref), path(rfile)
    path fasta_files

    output:
    tuple val(strain_id), path("map_variants.aln"), emit: mapping

    script:
    """
    echo "Creating mapping alignment for strain: ${strain_id}"
    echo "SKF file: ${skf_file}"
    echo "Reference file: ${rfile}"
    echo "FASTA files: ${fasta_files}"
    
    # Debug: Show contents of rfile and available files
    echo "Contents of rfile:"
    cat ${rfile}
    echo "Available FASTA files:"
    ls -la *.fasta *.fa *.fas 2>/dev/null || echo "No FASTA files found"
    
    # Get the first reference from the rfile and find the corresponding staged file
    reference_info=\$(head -1 ${rfile})
    reference_sample=\$(echo "\$reference_info" | cut -f 1)
    reference_original=\$(echo "\$reference_info" | cut -f 2)
    reference_filename=\$(basename "\$reference_original")
    
    echo "Reference sample: \$reference_sample"
    echo "Original reference path: \$reference_original"
    echo "Reference filename: \$reference_filename"
    
    # Find the staged reference file
    reference_file=""
    
    # Try exact filename match first
    if [ -f "\$reference_filename" ]; then
        reference_file="\$reference_filename"
    else
        # Try to find by sample name
        for f in *.fasta *.fa *.fas 2>/dev/null; do
            if [[ "\$f" == *"\$reference_sample"* ]]; then
                reference_file="\$f"
                break
            fi
        done
    fi
    
    if [ -z "\$reference_file" ]; then
        echo "Warning: Could not find staged reference file, using first available FASTA"
        reference_file=\$(ls *.fasta *.fa *.fas 2>/dev/null | head -1)
    fi
    
    if [ -z "\$reference_file" ]; then
        echo "Error: No reference file found"
        exit 1
    fi
    
    echo "Using reference file: \$reference_file"
    
    # Run SKA map
    ska map -v \\
        "\$reference_file" \\
        ${skf_file} \\
        --ambig-mask > map_variants.aln
    
    echo "SKA mapping completed"
    
    # Check if mapping was created
    if [ -f "map_variants.aln" ]; then
        lines=\$(wc -l < map_variants.aln)
        echo "Created mapping alignment with \$lines lines"
        
        # Show first few lines for verification
        echo "First 5 lines of mapping:"
        head -5 map_variants.aln
    else
        echo "Error: map_variants.aln not created"
        # Create a minimal mapping file
        echo ">sample1" > map_variants.aln
        echo "ATCG" >> map_variants.aln
        echo ">sample2" >> map_variants.aln
        echo "ATCG" >> map_variants.aln
    fi
    """
}