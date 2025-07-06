# PopPUNK Segmentation Fault Fixes and Local Profile Guide

## Overview
This document describes the segmentation fault prevention measures implemented in the Combined PopPUNK + PopPIPE pipeline and how to use the optimized local profile for systems with 22 CPUs and 64GB RAM.

## Segmentation Fault Issues
PopPUNK version 2.7.5 is known to experience segmentation faults under certain conditions:
- High thread counts (>16 threads)
- Large datasets (>1000 genomes)
- Insufficient memory allocation
- Use of `--stable` flag with large datasets
- Memory fragmentation in long-running processes

## Implemented Fixes

### 1. Resource Management
- **Conservative CPU allocation**: Limited to 12 CPUs for model building, 8 CPUs for assignment
- **Generous memory allocation**: Up to 48GB for PopPUNK processes
- **Memory limits**: Set ulimit constraints to prevent memory overconsumption
- **Stack size limits**: 8MB stack limit to prevent stack overflow

### 2. PopPUNK Parameter Optimization
- **Disabled `--stable` flag**: Known to cause segfaults with large datasets
- **Reduced search depth**: `--max-search-depth` limited to 15 (from default 20)
- **Simplified mixture components**: `--K` reduced to 2 for stability
- **Disabled plotting**: `--no-plot` to reduce memory usage
- **Conservative QC settings**: Increased tolerance for edge cases

### 3. Fallback Strategies
- **Multi-tier retry logic**: Progressive reduction of resources if initial attempt fails
- **Single-threaded fallback**: Ultimate fallback to single-threaded execution
- **Minimal parameter fallback**: Stripped-down parameter set for problematic datasets

### 4. Container Optimizations
- **Shared memory**: `--shm-size=8g` for better memory management
- **Memory locking**: `--ulimit memlock=-1:-1` to prevent memory swapping
- **File descriptor limits**: `--ulimit nofile=65536:65536` for large datasets
- **Core dump prevention**: `--ulimit core=0` to prevent disk space issues

## Local Profile Usage

### System Requirements
- 22 CPUs, 64GB RAM (leaves 2 CPUs and 8GB for system overhead)
- Docker installed and running
- Sufficient disk space (recommend 100GB+ free)

### Running with Local Profile
```bash
# Standard run with local profile
nextflow run main.nf -profile local --input /path/to/genomes --resultsDir ./results

# Test run with segfault debugging
nextflow run main.nf -profile test_segfault --input ./test_data

# Resume a failed run
nextflow run main.nf -profile local -resume --input /path/to/genomes
```

### Profile Configurations

#### Local Profile (`-profile local`)
- **Max CPUs**: 20 (leaves 2 for system)
- **Max Memory**: 56GB (leaves 8GB for system)
- **PopPUNK threads**: 16 (conservative)
- **PopPUNK memory**: 48GB (generous allocation)
- **Retry strategy**: 3 attempts with progressive resource reduction

#### Test Segfault Profile (`-profile test_segfault`)
- **Ultra-conservative**: Single-threaded execution
- **Minimal memory**: 8GB maximum
- **Immediate termination**: Stops on first error for debugging
- **Enhanced logging**: Detailed resource usage tracking

## Troubleshooting Segmentation Faults

### 1. Check System Resources
```bash
# Monitor memory usage during run
watch -n 5 'free -h && docker stats --no-stream'

# Check disk space
df -h

# Monitor CPU usage
htop
```

### 2. Review Logs
```bash
# Check Nextflow trace
cat results/reports/trace_local.txt

# Check process-specific logs
ls -la work/*/*/.command.log
```

### 3. Progressive Debugging
1. Start with `test_segfault` profile on small dataset
2. Gradually increase dataset size
3. Monitor resource usage patterns
4. Adjust parameters based on observations

### 4. Common Solutions
- **Reduce thread count**: Edit `conf/local.config` to lower CPU allocation
- **Increase memory**: Adjust memory limits in local profile
- **Disable features**: Set `poppunk_count_unique = false` in parameters
- **Use fallback mode**: Let the pipeline automatically retry with reduced resources

## Parameter Tuning

### For Large Datasets (>500 genomes)
```groovy
params {
    threads = 8                    // Reduce threads
    poppunk_max_search = 10        // Reduce search depth
    poppunk_K = 2                  // Minimal mixture components
    poppunk_count_unique = false   // Disable memory-intensive feature
}
```

### For Memory-Constrained Systems
```groovy
params {
    ram = '32 GB'                  // Reduce memory allocation
    threads = 4                    // Minimal threads
    mash_s = 500                   // Reduce sketch size
}
```

### For Speed Optimization (if no segfaults)
```groovy
params {
    threads = 16                   // Increase threads
    poppunk_max_search = 20        // Increase search depth
    poppunk_count_unique = true    // Enable advanced features
}
```

## Monitoring and Alerts

### Resource Usage Monitoring
The local profile includes enhanced reporting:
- **Execution report**: `results/reports/execution_report_local.html`
- **Timeline**: `results/reports/timeline_local.html`
- **Resource trace**: `results/reports/trace_local.txt`

### Warning Signs
Watch for these indicators of potential segfaults:
- Memory usage >90% of allocated
- Processes killed with exit code 139 (segfault)
- Sudden process termination without error messages
- Docker containers being killed by OOM killer

## Performance Optimization

### Disk I/O Optimization
```bash
# Use SSD storage for work directory
export NXF_WORK=/path/to/ssd/work

# Increase Docker disk space if needed
docker system prune -a
```

### Memory Optimization
```bash
# Clear system caches before run
sudo sync && sudo sysctl vm.drop_caches=3

# Monitor swap usage
watch -n 5 'cat /proc/meminfo | grep -E "MemTotal|MemFree|SwapTotal|SwapFree"'
```

## Support and Debugging

### Collecting Debug Information
```bash
# System information
uname -a
free -h
df -h
docker --version

# Pipeline logs
tar -czf debug_logs.tar.gz work/ results/reports/ .nextflow.log
```

### Common Error Patterns
1. **Exit code 139**: Segmentation fault - use more conservative settings
2. **Exit code 137**: Out of memory - increase memory allocation
3. **Exit code 1**: General error - check process logs for details

### Getting Help
1. Check this documentation first
2. Review the execution report and trace files
3. Try the `test_segfault` profile to isolate issues
4. Collect debug information as shown above
5. Report issues with full system specifications and error logs

## Version Compatibility
- **PopPUNK**: 2.7.5 (with segfault fixes)
- **Nextflow**: 22.04.0 or later
- **Docker**: 20.10.0 or later
- **System**: Linux x86_64 (tested on Ubuntu 20.04+)