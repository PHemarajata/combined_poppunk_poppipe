#!/bin/bash

# Combined PopPUNK + PopPIPE Pipeline Installation Script
# This script helps set up the pipeline environment

set -e

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

# Default values
INSTALL_NEXTFLOW=false
INSTALL_DOCKER=false
PULL_CONTAINERS=false
CREATE_TEST_DATA=false
VALIDATE_SETUP=false
CONDA_ENV=false

# Help function
show_help() {
    cat << EOF
Combined PopPUNK + PopPIPE Pipeline Installation Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --nextflow          Install Nextflow
    --docker            Install Docker (Linux only)
    --pull-containers   Pull required Docker containers
    --conda-env         Create conda environment
    --test-data         Create test data
    --validate          Validate pipeline setup
    --all               Perform all installation steps
    -h, --help          Show this help message

EXAMPLES:
    # Full installation
    $0 --all

    # Install only Nextflow and pull containers
    $0 --nextflow --pull-containers

    # Setup test environment
    $0 --test-data --validate

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --nextflow)
            INSTALL_NEXTFLOW=true
            shift
            ;;
        --docker)
            INSTALL_DOCKER=true
            shift
            ;;
        --pull-containers)
            PULL_CONTAINERS=true
            shift
            ;;
        --conda-env)
            CONDA_ENV=true
            shift
            ;;
        --test-data)
            CREATE_TEST_DATA=true
            shift
            ;;
        --validate)
            VALIDATE_SETUP=true
            shift
            ;;
        --all)
            INSTALL_NEXTFLOW=true
            PULL_CONTAINERS=true
            CREATE_TEST_DATA=true
            VALIDATE_SETUP=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Header
print_header "╔══════════════════════════════════════════════════════════════════════════════╗"
print_header "║                    PIPELINE INSTALLATION SCRIPT                              ║"
print_header "╚══════════════════════════════════════════════════════════════════════════════╝"
echo

# Install Nextflow
if [[ "$INSTALL_NEXTFLOW" == true ]]; then
    print_header "Installing Nextflow..."
    
    if command -v nextflow &> /dev/null; then
        print_status "Nextflow is already installed"
        nextflow -version
    else
        print_status "Downloading and installing Nextflow..."
        curl -s https://get.nextflow.io | bash
        
        # Move to a directory in PATH
        if [[ -w "/usr/local/bin" ]]; then
            sudo mv nextflow /usr/local/bin/
            print_status "Nextflow installed to /usr/local/bin/"
        else
            mkdir -p ~/bin
            mv nextflow ~/bin/
            print_status "Nextflow installed to ~/bin/"
            print_warning "Make sure ~/bin is in your PATH"
            echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
        fi
    fi
    echo
fi

# Install Docker (Linux only)
if [[ "$INSTALL_DOCKER" == true ]]; then
    print_header "Installing Docker..."
    
    if command -v docker &> /dev/null; then
        print_status "Docker is already installed"
        docker --version
    else
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            print_status "Installing Docker on Linux..."
            curl -fsSL https://get.docker.com -o get-docker.sh
            sudo sh get-docker.sh
            sudo usermod -aG docker $USER
            rm get-docker.sh
            print_status "Docker installed successfully"
            print_warning "Please log out and log back in for Docker group membership to take effect"
        else
            print_warning "Automatic Docker installation is only supported on Linux"
            print_warning "Please install Docker manually: https://docs.docker.com/get-docker/"
        fi
    fi
    echo
fi

# Pull Docker containers
if [[ "$PULL_CONTAINERS" == true ]]; then
    print_header "Pulling Docker containers..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Cannot pull containers."
    elif ! docker info &> /dev/null; then
        print_error "Docker daemon is not running. Cannot pull containers."
    else
        CONTAINERS=(
            "python:3.9"
            "staphb/poppunk:2.7.5"
            "quay.io/biocontainers/mash:2.3--hb105d93_9"
            "poppunk/poppipe:latest"
        )
        
        for container in "${CONTAINERS[@]}"; do
            print_status "Pulling container: $container"
            docker pull "$container"
        done
        
        print_status "All containers pulled successfully"
    fi
    echo
fi

# Create conda environment
if [[ "$CONDA_ENV" == true ]]; then
    print_header "Creating conda environment..."
    
    if command -v conda &> /dev/null; then
        if conda env list | grep -q "poppunk-poppipe"; then
            print_status "Conda environment 'poppunk-poppipe' already exists"
        else
            print_status "Creating conda environment from environment.yml..."
            conda env create -f environment.yml
            print_status "Conda environment created successfully"
            print_status "Activate with: conda activate poppunk-poppipe"
        fi
    else
        print_warning "Conda is not installed. Skipping conda environment creation."
        print_warning "Install conda/mamba: https://docs.conda.io/en/latest/miniconda.html"
    fi
    echo
fi

# Create test data
if [[ "$CREATE_TEST_DATA" == true ]]; then
    print_header "Creating test data..."
    
    if [[ -f "bin/create_test_data.sh" ]]; then
        ./bin/create_test_data.sh
        print_status "Test data created successfully"
    else
        print_error "Test data creation script not found: bin/create_test_data.sh"
    fi
    echo
fi

# Validate setup
if [[ "$VALIDATE_SETUP" == true ]]; then
    print_header "Validating pipeline setup..."
    
    if [[ -f "bin/validate_pipeline.sh" ]]; then
        ./bin/validate_pipeline.sh
    else
        print_error "Validation script not found: bin/validate_pipeline.sh"
    fi
    echo
fi

# Final message
print_header "╔══════════════════════════════════════════════════════════════════════════════╗"
print_header "║                          INSTALLATION COMPLETE                               ║"
print_header "╚══════════════════════════════════════════════════════════════════════════════╝"
echo

print_status "Installation completed successfully!"
echo
print_status "Next steps:"
echo "  1. Validate setup: ./bin/validate_pipeline.sh"
echo "  2. Run test pipeline: ./bin/run_pipeline.sh --test"
echo "  3. Run with your data: ./bin/run_pipeline.sh -i /path/to/genomes"
echo
print_status "For help: ./bin/run_pipeline.sh --help"
echo