process SKA_BUILD {
    tag          "ska_build_${strain_id}"
    publishDir   "${params.resultsDir}/strains/${strain_id}", mode: 'copy'

    input:
    tuple val(strain_id), path(rfile)

    output:
    tuple val(strain_id), path("split_kmers.skf"), emit: ska_file

    script:
    """
    echo "Building SKA file for strain: ${strain_id}"
    echo "R-file: ${rfile}"
    
    python - << 'PY'
import subprocess
import sys
import os

# Read the rfile to get sample files
samples = []
with open('${rfile}', 'r') as f:
    for line in f:
        parts = line.strip().split('\\t')
        if len(parts) >= 2:
            sample_name = parts[0]
            file_path = parts[1]
            samples.append((sample_name, file_path))

print(f"Found {len(samples)} samples for SKA build")

if len(samples) == 0:
    print("Error: No samples found in rfile")
    sys.exit(1)

# Create a temporary file list for ska
with open('ska_files.txt', 'w') as f:
    for sample_name, file_path in samples:
        f.write(f"{file_path}\\n")

print("Created file list for SKA")

# Build SKA command
cmd = [
    "ska", "build",
    "-o", "split_kmers",
    "-k", str(${params.ska_kmer}),
    "-f", "ska_files.txt"
]

# Add optional parameters
if ${params.ska_single_strand}:
    cmd.append("--single-strand")

print(f"Running SKA command: {' '.join(cmd)}")

try:
    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    print("SKA build completed successfully")
    print(f"stdout: {result.stdout}")
    
    # Verify output file exists
    if os.path.exists('split_kmers.skf'):
        file_size = os.path.getsize('split_kmers.skf')
        print(f"Created split_kmers.skf ({file_size} bytes)")
    else:
        print("Warning: split_kmers.skf not found")
        
except subprocess.CalledProcessError as e:
    print(f"SKA build failed: {e}")
    print(f"stdout: {e.stdout}")
    print(f"stderr: {e.stderr}")
    
    # Create a dummy file to prevent pipeline failure
    with open('split_kmers.skf', 'w') as f:
        f.write("# Dummy SKA file - build failed\\n")
    
    sys.exit(1)
PY
    """
}