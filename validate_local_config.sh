#!/bin/bash

# Validation script for local profile configuration
# This script checks system resources and validates the local profile setup

echo "=== PopPUNK Pipeline Local Profile Validation ==="
echo "Date: $(date)"
echo ""

# Check system resources
echo "1. SYSTEM RESOURCES:"
echo "   CPUs available: $(nproc)"
echo "   Memory total: $(free -h | grep '^Mem:' | awk '{print $2}')"
echo "   Memory available: $(free -h | grep '^Mem:' | awk '{print $7}')"
echo "   Disk space (current dir): $(df -h . | tail -1 | awk '{print $4}' | sed 's/G/ GB/')"
echo ""

# Check Docker
echo "2. DOCKER STATUS:"
if command -v docker &> /dev/null; then
    echo "   Docker version: $(docker --version)"
    if docker info &> /dev/null; then
        echo "   Docker daemon: Running ✓"
        echo "   Docker memory limit: $(docker info 2>/dev/null | grep 'Total Memory' | awk '{print $3 $4}')"
    else
        echo "   Docker daemon: Not running ✗"
        echo "   Please start Docker daemon before running the pipeline"
    fi
else
    echo "   Docker: Not installed ✗"
    echo "   Please install Docker before running the pipeline"
fi
echo ""

# Check Nextflow
echo "3. NEXTFLOW STATUS:"
if command -v nextflow &> /dev/null; then
    echo "   Nextflow version: $(nextflow -version 2>&1 | head -1)"
    echo "   Nextflow: Available ✓"
else
    echo "   Nextflow: Not found ✗"
    echo "   Please install Nextflow before running the pipeline"
fi
echo ""

# Validate local profile configuration
echo "4. LOCAL PROFILE VALIDATION:"
if [ -f "conf/local.config" ]; then
    echo "   Local config file: Found ✓"
    
    # Extract key parameters
    max_cpus=$(grep -E "max_cpus.*=" conf/local.config | head -1 | sed 's/.*= *//' | sed 's/ .*//')
    max_memory=$(grep -E "max_memory.*=" conf/local.config | head -1 | sed 's/.*= *//' | sed "s/'//g")
    threads=$(grep -E "threads.*=" conf/local.config | head -1 | sed 's/.*= *//')
    
    echo "   Configured max CPUs: $max_cpus"
    echo "   Configured max memory: $max_memory"
    echo "   Configured threads: $threads"
    
    # Check if configuration is reasonable for system
    system_cpus=$(nproc)
    if [ "$max_cpus" -le "$system_cpus" ]; then
        echo "   CPU configuration: Appropriate ✓"
    else
        echo "   CPU configuration: May be too high ⚠"
    fi
    
else
    echo "   Local config file: Not found ✗"
    echo "   Please ensure conf/local.config exists"
fi
echo ""

# Check for required directories
echo "5. DIRECTORY STRUCTURE:"
required_dirs=("conf" "modules" "modules/local")
for dir in "${required_dirs[@]}"; do
    if [ -d "$dir" ]; then
        echo "   $dir/: Found ✓"
    else
        echo "   $dir/: Missing ✗"
    fi
done
echo ""

# Check for key files
echo "6. KEY FILES:"
key_files=("main.nf" "nextflow.config" "conf/profiles.config" "conf/local.config")
for file in "${key_files[@]}"; do
    if [ -f "$file" ]; then
        echo "   $file: Found ✓"
    else
        echo "   $file: Missing ✗"
    fi
done
echo ""

# Memory recommendations
echo "7. RECOMMENDATIONS:"
system_mem_gb=$(free -g | grep '^Mem:' | awk '{print $2}')
if [ "$system_mem_gb" -ge 64 ]; then
    echo "   ✓ System has sufficient memory (${system_mem_gb}GB) for large datasets"
elif [ "$system_mem_gb" -ge 32 ]; then
    echo "   ⚠ System has moderate memory (${system_mem_gb}GB) - consider smaller datasets"
    echo "     or reduce memory allocation in conf/local.config"
else
    echo "   ✗ System has limited memory (${system_mem_gb}GB) - may need significant tuning"
    echo "     Consider using test_segfault profile for small datasets only"
fi

system_cpu_count=$(nproc)
if [ "$system_cpu_count" -ge 20 ]; then
    echo "   ✓ System has sufficient CPUs (${system_cpu_count}) for parallel processing"
elif [ "$system_cpu_count" -ge 8 ]; then
    echo "   ⚠ System has moderate CPUs (${system_cpu_count}) - pipeline will work but slower"
else
    echo "   ✗ System has limited CPUs (${system_cpu_count}) - consider single-threaded execution"
fi
echo ""

# Test command suggestions
echo "8. SUGGESTED TEST COMMANDS:"
echo "   # Quick validation with test profile:"
echo "   nextflow run main.nf -profile test_segfault --input ./test_data"
echo ""
echo "   # Full run with local profile:"
echo "   nextflow run main.nf -profile local --input /path/to/genomes --resultsDir ./results"
echo ""
echo "   # Resume a failed run:"
echo "   nextflow run main.nf -profile local -resume"
echo ""

echo "=== Validation Complete ==="
echo "Review any ✗ or ⚠ items above before running the pipeline."