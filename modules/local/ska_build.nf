process SKA_BUILD {
    tag          "ska_build_${strain_id}"
    publishDir   "${params.resultsDir}/strains/${strain_id}", mode: 'copy'

    input:
    tuple val(strain_id), path(rfile)
    path fasta_files

    output:
    tuple val(strain_id), path("split_kmers.skf"), emit: ska_file

    script:
    """
    echo "Building SKA file for strain: ${strain_id}"
    echo "R-file: ${rfile}"
    
    # Debug: Show contents of rfile
    echo "Contents of rfile:"
    cat ${rfile}
    
    # Debug: Show files in working directory
    echo "Files in working directory:"
    ls -la
    
    python - << 'PY'
import subprocess
import sys
import os
from pathlib import Path

# Read the rfile to get sample names and their original paths
samples_from_rfile = []
with open('${rfile}', 'r') as f:
    for line in f:
        parts = line.strip().split('\\t')
        if len(parts) >= 2:
            sample_name = parts[0]
            original_path = parts[1]
            samples_from_rfile.append((sample_name, original_path))

print(f"Found {len(samples_from_rfile)} samples in rfile")

if len(samples_from_rfile) == 0:
    print("Error: No samples found in rfile")
    sys.exit(1)

# Get list of staged FASTA files in working directory
staged_files = []
for f in os.listdir('.'):
    if f.endswith(('.fasta', '.fa', '.fas')) and f != '${rfile}':
        staged_files.append(f)

print(f"Found {len(staged_files)} staged FASTA files: {staged_files}")

# Create mapping from original filenames to staged filenames
file_mapping = {}
for sample_name, original_path in samples_from_rfile:
    original_filename = os.path.basename(original_path)
    
    # Try to find the corresponding staged file
    staged_file = None
    
    # First, try exact filename match
    if original_filename in staged_files:
        staged_file = original_filename
    else:
        # Try to match by sample name
        for sf in staged_files:
            if sample_name in sf or sf.startswith(sample_name):
                staged_file = sf
                break
        
        # If still not found, try matching by removing extensions and comparing
        if not staged_file:
            original_base = os.path.splitext(original_filename)[0]
            for sf in staged_files:
                staged_base = os.path.splitext(sf)[0]
                if original_base == staged_base:
                    staged_file = sf
                    break
    
    if staged_file:
        file_mapping[sample_name] = staged_file
        print(f"  ✓ {sample_name}: {original_filename} -> {staged_file}")
    else:
        print(f"  ✗ {sample_name}: {original_filename} -> NOT FOUND")

if len(file_mapping) == 0:
    print("Error: No staged files could be mapped to samples")
    print("Available staged files:", staged_files)
    print("Expected samples:", [s[0] for s in samples_from_rfile])
    sys.exit(1)

print(f"Successfully mapped {len(file_mapping)} files for SKA build")

# Create a file list for SKA using the staged filenames
# SKA expects either just filenames (if files are in current directory) 
# or full paths, and each line should be clean without extra whitespace
with open('ska_files.txt', 'w') as f:
    for sample_name, staged_file in file_mapping.items():
        # Ensure the file exists and get its full path
        if os.path.exists(staged_file):
            # Use absolute path to be safe
            full_path = os.path.abspath(staged_file)
            f.write(f"{full_path}\\n")
            print(f"  Added to file list: {full_path}")
        else:
            print(f"  WARNING: File not found: {staged_file}")

print("Created file list for SKA")
print("Contents of ska_files.txt:")
with open('ska_files.txt', 'r') as f:
    content = f.read()
    print(repr(content))  # Use repr to see any hidden characters
    print("Actual content:")
    print(content)

# Validate that all files in the list actually exist
print("Validating files in ska_files.txt:")
with open('ska_files.txt', 'r') as f:
    for line_num, line in enumerate(f, 1):
        filepath = line.strip()
        if filepath:  # Skip empty lines
            if os.path.exists(filepath):
                file_size = os.path.getsize(filepath)
                print(f"  Line {line_num}: ✓ {filepath} ({file_size} bytes)")
            else:
                print(f"  Line {line_num}: ✗ {filepath} (NOT FOUND)")
                
# Also try creating a simpler file list with just filenames (relative paths)
print("Creating alternative file list with relative paths...")
with open('ska_files_relative.txt', 'w') as f:
    for sample_name, staged_file in file_mapping.items():
        if os.path.exists(staged_file):
            f.write(f"{staged_file}\\n")

print("Contents of ska_files_relative.txt:")
with open('ska_files_relative.txt', 'r') as f:
    print(f.read())

# Try SKA build with different approaches
ska_success = False

# First try with relative paths (simpler, often works better)
cmd_relative = [
    "ska", "build",
    "-o", "split_kmers",
    "-k", str(${params.ska_kmer}),
    "-f", "ska_files_relative.txt"
]

# Add optional parameters
if ${params.ska_single_strand ? 'True' : 'False'}:
    cmd_relative.append("--single-strand")

print(f"Trying SKA command with relative paths: {' '.join(cmd_relative)}")

try:
    result = subprocess.run(cmd_relative, capture_output=True, text=True, check=True)
    print("SKA build completed successfully with relative paths")
    print(f"stdout: {result.stdout}")
    ska_success = True
    
except subprocess.CalledProcessError as e:
    print(f"SKA build with relative paths failed: {e}")
    print(f"stdout: {e.stdout}")
    print(f"stderr: {e.stderr}")
    
    # Try with absolute paths
    cmd_absolute = [
        "ska", "build",
        "-o", "split_kmers",
        "-k", str(${params.ska_kmer}),
        "-f", "ska_files.txt"
    ]
    
    if ${params.ska_single_strand ? 'True' : 'False'}:
        cmd_absolute.append("--single-strand")
    
    print(f"Trying SKA command with absolute paths: {' '.join(cmd_absolute)}")
    
    try:
        result = subprocess.run(cmd_absolute, capture_output=True, text=True, check=True)
        print("SKA build completed successfully with absolute paths")
        print(f"stdout: {result.stdout}")
        ska_success = True
        
    except subprocess.CalledProcessError as e2:
        print(f"SKA build with absolute paths also failed: {e2}")
        print(f"stdout: {e2.stdout}")
        print(f"stderr: {e2.stderr}")
        
        # Try individual files approach (without file list)
        print("Trying individual files approach...")
        cmd_individual = [
            "ska", "build",
            "-o", "split_kmers",
            "-k", str(${params.ska_kmer})
        ]
        
        if ${params.ska_single_strand ? 'True' : 'False'}:
            cmd_individual.append("--single-strand")
            
        # Add individual files
        for sample_name, staged_file in file_mapping.items():
            if os.path.exists(staged_file):
                cmd_individual.append(staged_file)
        
        print(f"Trying SKA command with individual files: {' '.join(cmd_individual)}")
        
        try:
            result = subprocess.run(cmd_individual, capture_output=True, text=True, check=True)
            print("SKA build completed successfully with individual files")
            print(f"stdout: {result.stdout}")
            ska_success = True
            
        except subprocess.CalledProcessError as e3:
            print(f"All SKA build approaches failed. Last error: {e3}")
            print(f"stdout: {e3.stdout}")
            print(f"stderr: {e3.stderr}")

if ska_success:
    # Verify output file exists
    if os.path.exists('split_kmers.skf'):
        file_size = os.path.getsize('split_kmers.skf')
        print(f"Created split_kmers.skf ({file_size} bytes)")
    else:
        print("Warning: split_kmers.skf not found despite successful command")
        ska_success = False

if not ska_success:
    print("Creating dummy SKA file as fallback...")
    # Create a dummy file to prevent pipeline failure
    with open('split_kmers.skf', 'w') as f:
        f.write("# Dummy SKA file - build failed\\n")
    
    sys.exit(1)
PY
    """
}