process VALIDATE_FASTA {
    tag         'validate_fasta'
    publishDir  "${params.resultsDir}/validation", mode: 'copy'

    input:
    path fasta_files

    output:
    path 'valid_files.list', emit: valid_list
    path 'validation_report.txt', emit: report

    script:
    """
    python - << 'PY'
import os
from pathlib import Path

valid_files = []
invalid_files = []
total_files = 0

# Process each FASTA file
fasta_files = '${fasta_files}'.split()
for fasta_file in fasta_files:
    total_files += 1
    file_path = Path(fasta_file)
    
    # Get the absolute path for the file
    abs_path = file_path.resolve()
    
    if not file_path.exists():
        invalid_files.append(f"{fasta_file}: File does not exist")
        continue
    
    if file_path.stat().st_size == 0:
        invalid_files.append(f"{fasta_file}: File is empty (0 bytes)")
        continue
    
    # Check if file contains actual sequence data
    has_sequence = False
    sequence_length = 0
    
    try:
        with open(fasta_file, 'r') as f:
            lines = f.readlines()
            for line in lines:
                line = line.strip()
                if line and not line.startswith('>'):
                    sequence_length += len(line)
                    has_sequence = True
        
        if not has_sequence or sequence_length == 0:
            invalid_files.append(f"{fasta_file}: No sequence data found")
        elif sequence_length < 1000:  # Minimum sequence length threshold
            invalid_files.append(f"{fasta_file}: Sequence too short ({sequence_length} bp)")
        else:
            # Store the absolute path so MASH can find the files
            valid_files.append(str(abs_path))
            
    except Exception as e:
        invalid_files.append(f"{fasta_file}: Error reading file - {str(e)}")

# Write valid files list with sample names and absolute paths (TSV format)
with open('valid_files.list', 'w') as f:
    for valid_file in valid_files:
        # Extract sample name from filename (remove extension)
        sample_name = Path(valid_file).stem
        f.write(f"{sample_name}\\t{valid_file}\\n")

# Write validation report
with open('validation_report.txt', 'w') as f:
    f.write(f"FASTA Validation Report\\n")
    f.write(f"======================\\n")
    f.write(f"Total files processed: {total_files}\\n")
    f.write(f"Valid files: {len(valid_files)}\\n")
    f.write(f"Invalid files: {len(invalid_files)}\\n\\n")
    
    if valid_files:
        f.write("Valid files (sample_name -> absolute_path):\\n")
        for vf in valid_files:
            sample_name = Path(vf).stem
            f.write(f"  ✓ {sample_name} -> {vf}\\n")
        f.write("\\n")
    
    if invalid_files:
        f.write("Invalid files (excluded from analysis):\\n")
        for inf in invalid_files:
            f.write(f"  ✗ {inf}\\n")

print(f"Validation complete: {len(valid_files)} valid files out of {total_files} total files")
if len(valid_files) < 3:
    print("WARNING: Less than 3 valid files found. PopPUNK requires at least 3 genomes.")
    exit(1)
PY
    """
}