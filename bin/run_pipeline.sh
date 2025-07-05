#!/bin/bash

# Combined PopPUNK + PopPIPE Pipeline Runner
# This script provides an easy interface to run the pipeline with different configurations

set -e

# Default values
PROFILE="standard"
INPUT_DIR=""
OUTPUT_DIR="./results"
CONFIG_FILE=""
RESUME=false
HELP=false
TEST=false
THREADS=8
MEMORY="32 GB"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}$1${NC}"
}

# Help function
show_help() {
    cat << EOF
Combined PopPUNK + PopPIPE Pipeline Runner

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -i, --input DIR         Input directory containing FASTA files (required)
    -o, --output DIR        Output directory (default: ./results)
    -p, --profile PROFILE   Execution profile (default: standard)
                           Available: standard, docker, singularity, test, local, slurm, pbs
    -c, --config FILE       Custom configuration file
    -t, --threads INT       Number of threads (default: 8)
    -m, --memory SIZE       Memory allocation (default: 32 GB)
    -r, --resume            Resume previous run
    --test                  Run with test data and configuration
    -h, --help              Show this help message

PROFILES:
    standard    - Default Docker execution
    docker      - Docker containers
    singularity - Singularity containers
    test        - Quick test with reduced resources
    local       - Local execution
    slurm       - SLURM cluster execution
    pbs         - PBS cluster execution

EXAMPLES:
    # Basic run with Docker
    $0 -i ./genomes -o ./results

    # Run on SLURM cluster
    $0 -i ./genomes -o ./results -p slurm

    # Test run with synthetic data
    $0 --test

    # Resume previous run
    $0 -i ./genomes -o ./results --resume

    # Custom configuration
    $0 -i ./genomes -o ./results -c custom.config

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--input)
            INPUT_DIR="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -p|--profile)
            PROFILE="$2"
            shift 2
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -t|--threads)
            THREADS="$2"
            shift 2
            ;;
        -m|--memory)
            MEMORY="$2"
            shift 2
            ;;
        -r|--resume)
            RESUME=true
            shift
            ;;
        --test)
            TEST=true
            shift
            ;;
        -h|--help)
            HELP=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Show help if requested
if [[ "$HELP" == true ]]; then
    show_help
    exit 0
fi

# Header
print_header "╔══════════════════════════════════════════════════════════════════════════════╗"
print_header "║                    COMBINED POPPUNK + POPPIPE PIPELINE                       ║"
print_header "║                          Bacterial Genome Analysis                           ║"
print_header "╚══════════════════════════════════════════════════════════════════════════════╝"
echo

# Check if running test
if [[ "$TEST" == true ]]; then
    print_status "Running in TEST mode"
    
    # Create test data if it doesn't exist
    if [[ ! -d "test_data" ]]; then
        print_status "Creating test data..."
        ./bin/create_test_data.sh
    fi
    
    INPUT_DIR="./test_data"
    OUTPUT_DIR="./test_results"
    PROFILE="test"
    print_status "Test data: $INPUT_DIR"
    print_status "Test results: $OUTPUT_DIR"
fi

# Validate required parameters
if [[ -z "$INPUT_DIR" ]]; then
    print_error "Input directory is required. Use -i/--input to specify."
    show_help
    exit 1
fi

if [[ ! -d "$INPUT_DIR" ]]; then
    print_error "Input directory does not exist: $INPUT_DIR"
    exit 1
fi

# Check for FASTA files
FASTA_COUNT=$(find "$INPUT_DIR" -name "*.fasta" -o -name "*.fa" -o -name "*.fas" | wc -l)
if [[ $FASTA_COUNT -eq 0 ]]; then
    print_error "No FASTA files found in input directory: $INPUT_DIR"
    print_error "Expected files with extensions: .fasta, .fa, .fas"
    exit 1
fi

# Check Nextflow installation
if ! command -v nextflow &> /dev/null; then
    print_error "Nextflow is not installed or not in PATH"
    print_error "Please install Nextflow: https://www.nextflow.io/docs/latest/getstarted.html"
    exit 1
fi

# Check Docker/Singularity based on profile
if [[ "$PROFILE" == "docker" || "$PROFILE" == "standard" ]]; then
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        print_error "Please install Docker or use -p singularity"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running"
        print_error "Please start Docker daemon"
        exit 1
    fi
fi

if [[ "$PROFILE" == "singularity" ]]; then
    if ! command -v singularity &> /dev/null; then
        print_error "Singularity is not installed or not in PATH"
        print_error "Please install Singularity or use -p docker"
        exit 1
    fi
fi

# Display configuration
print_status "Configuration:"
echo "  Input directory: $INPUT_DIR"
echo "  Output directory: $OUTPUT_DIR"
echo "  Execution profile: $PROFILE"
echo "  FASTA files found: $FASTA_COUNT"
echo "  Threads: $THREADS"
echo "  Memory: $MEMORY"
if [[ -n "$CONFIG_FILE" ]]; then
    echo "  Custom config: $CONFIG_FILE"
fi
if [[ "$RESUME" == true ]]; then
    echo "  Resume: enabled"
fi
echo

# Build Nextflow command
NF_CMD="nextflow run main.nf"
NF_CMD="$NF_CMD --input $INPUT_DIR"
NF_CMD="$NF_CMD --resultsDir $OUTPUT_DIR"
NF_CMD="$NF_CMD --threads $THREADS"
NF_CMD="$NF_CMD --ram '$MEMORY'"
NF_CMD="$NF_CMD -profile $PROFILE"

if [[ -n "$CONFIG_FILE" ]]; then
    NF_CMD="$NF_CMD -c $CONFIG_FILE"
fi

if [[ "$RESUME" == true ]]; then
    NF_CMD="$NF_CMD -resume"
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

print_status "Starting pipeline execution..."
print_status "Command: $NF_CMD"
echo

# Execute pipeline
if eval $NF_CMD; then
    echo
    print_header "╔══════════════════════════════════════════════════════════════════════════════╗"
    print_header "║                            PIPELINE COMPLETED                                ║"
    print_header "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo
    print_status "Results are available in: $OUTPUT_DIR"
    print_status "Key output files:"
    echo "  - PopPUNK clusters: $OUTPUT_DIR/poppunk_full/full_assign.csv"
    echo "  - PopPIPE subclusters: $OUTPUT_DIR/output/all_clusters.txt"
    echo "  - Summary report: $OUTPUT_DIR/summary/pipeline_summary.txt"
    echo "  - Execution report: $OUTPUT_DIR/reports/execution_report.html"
    echo
else
    echo
    print_error "Pipeline execution failed!"
    print_error "Check the error messages above for details."
    print_error "You can resume the pipeline with: $0 -i $INPUT_DIR -o $OUTPUT_DIR --resume"
    exit 1
fi