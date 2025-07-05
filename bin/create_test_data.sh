#!/bin/bash

# Create test data for the combined PopPUNK + PopPIPE pipeline
# This script generates synthetic FASTA files for testing

set -e

echo "Creating test data for combined PopPUNK + PopPIPE pipeline..."

# Create test data directory
mkdir -p test_data

# Function to generate a random DNA sequence
generate_sequence() {
    local length=$1
    local bases=("A" "T" "G" "C")
    local sequence=""
    
    for ((i=0; i<length; i++)); do
        sequence+="${bases[$RANDOM % 4]}"
    done
    
    echo "$sequence"
}

# Function to introduce mutations
mutate_sequence() {
    local sequence=$1
    local mutation_rate=$2
    local length=${#sequence}
    local mutated=""
    
    for ((i=0; i<length; i++)); do
        if (( RANDOM % 100 < mutation_rate )); then
            # Introduce mutation
            local bases=("A" "T" "G" "C")
            mutated+="${bases[$RANDOM % 4]}"
        else
            mutated+="${sequence:$i:1}"
        fi
    done
    
    echo "$mutated"
}

# Generate base sequence (simulating a bacterial genome)
echo "Generating base sequence..."
BASE_SEQUENCE=$(generate_sequence 50000)  # 50kb for testing

# Create test genomes with different levels of similarity
echo "Creating test genomes..."

# Cluster 1: Highly similar genomes (1-2% divergence)
for i in {1..8}; do
    echo "Creating genome_cluster1_${i}.fasta..."
    mutated_seq=$(mutate_sequence "$BASE_SEQUENCE" 2)
    cat > "test_data/genome_cluster1_${i}.fasta" << EOF
>genome_cluster1_${i}
$mutated_seq
EOF
done

# Cluster 2: Moderately similar genomes (3-5% divergence)
CLUSTER2_BASE=$(mutate_sequence "$BASE_SEQUENCE" 10)
for i in {1..6}; do
    echo "Creating genome_cluster2_${i}.fasta..."
    mutated_seq=$(mutate_sequence "$CLUSTER2_BASE" 5)
    cat > "test_data/genome_cluster2_${i}.fasta" << EOF
>genome_cluster2_${i}
$mutated_seq
EOF
done

# Cluster 3: Distantly related genomes (8-10% divergence)
CLUSTER3_BASE=$(mutate_sequence "$BASE_SEQUENCE" 20)
for i in {1..4}; do
    echo "Creating genome_cluster3_${i}.fasta..."
    mutated_seq=$(mutate_sequence "$CLUSTER3_BASE" 10)
    cat > "test_data/genome_cluster3_${i}.fasta" << EOF
>genome_cluster3_${i}
$mutated_seq
EOF
done

# Create a few outlier genomes
for i in {1..3}; do
    echo "Creating outlier_${i}.fasta..."
    outlier_seq=$(generate_sequence 45000)  # Different length and sequence
    cat > "test_data/outlier_${i}.fasta" << EOF
>outlier_${i}
$outlier_seq
EOF
done

echo "Test data creation completed!"
echo "Created $(ls test_data/*.fasta | wc -l) test genomes in test_data/"
echo ""
echo "Genome distribution:"
echo "- Cluster 1: 8 genomes (highly similar)"
echo "- Cluster 2: 6 genomes (moderately similar)" 
echo "- Cluster 3: 4 genomes (distantly related)"
echo "- Outliers: 3 genomes (unrelated)"
echo ""
echo "To run the test pipeline:"
echo "nextflow run main.nf -c conf/test.config"