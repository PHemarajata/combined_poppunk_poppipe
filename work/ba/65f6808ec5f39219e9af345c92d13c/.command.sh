#!/bin/bash -ue
# Create file list with staged filenames (not absolute paths)
ls *.fasta > all_files.list

# Check if we have any files to process
if [ ! -s all_files.list ]; then
    echo "ERROR: No valid FASTA files found for sketching"
    exit 1
fi

echo "Sketching $(wc -l < all_files.list) valid FASTA files..."
echo "First few files to be processed:"
head -5 all_files.list

echo "All files verified. Starting MASH sketching..."

mash sketch -p 12 -k 21 -s 1000 \
    -o mash.msh -l all_files.list

echo "MASH sketching completed successfully!"
