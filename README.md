# Combined PopPUNK + PopPIPE Pipeline

A comprehensive Nextflow pipeline that combines bacterial genome clustering with downstream phylogenetic analysis and visualization.

## Overview

This pipeline integrates two powerful tools:

1. **PopPUNK (Phase 1)** - Population Partitioning Using Nucleotide K-mers
   - Intelligent subsampling for large datasets
   - MASH pre-clustering for efficiency
   - PopPUNK clustering and assignment

2. **PopPIPE (Phase 2)** - Population analysis Pipeline
   - Strain-specific phylogenetic analysis
   - SKA-based alignments
   - IQ-TREE maximum likelihood trees
   - Gubbins recombination removal
   - fastbaps subclustering

## Pipeline Workflow

### Phase 1: PopPUNK Clustering
1. **VALIDATE_FASTA** - Quality control of input FASTA files
2. **MASH_SKETCH** - K-mer sketching of genomes
3. **MASH_DIST** - Pairwise distance calculation
4. **BIN_SUBSAMPLE** - Intelligent subsampling for model building
5. **POPPUNK_MODEL** - PopPUNK database and model creation
6. **POPPUNK_ASSIGN** - Assignment of all genomes to clusters
7. **SUMMARY_REPORT** - PopPUNK clustering summary

### Phase 2: PopPIPE Analysis
8. **SPLIT_STRAINS** - Separate genomes by PopPUNK clusters
9. **SKETCHLIB_DISTS** - Extract within-cluster distances
10. **GENERATE_NJ** - Create neighbor-joining trees
11. **SKA_BUILD** - Build SKA k-mer files
12. **SKA_ALIGN** - Generate variant alignments
13. **SKA_MAP** - Create reference-based mappings
14. **IQ_TREE** - Maximum likelihood phylogeny
15. **GUBBINS** - Remove recombination
16. **FASTBAPS** - Hierarchical subclustering
17. **CLUSTER_SUMMARY** - Final analysis summary

## Quick Start

### 1. Prepare Input Data

Create a directory with your FASTA files:
```bash
mkdir input_genomes
cp /path/to/your/*.fasta input_genomes/
```

### 2. Run Pipeline

```bash
# Run the complete pipeline
./bin/run_pipeline.sh -i input_genomes -o results

# Or run with test data
./bin/run_pipeline.sh --test

# Run with custom configuration
./bin/run_pipeline.sh -i input_genomes -o results -c custom.config
```

## Configuration Parameters

### Input/Output
- `input`: Directory containing FASTA files (*.fasta)
- `resultsDir`: Output directory for all results

### Resource Settings
- `threads`: Number of CPU threads (default: 8)
- `ram`: Memory allocation (default: '32 GB')

### PopPUNK Parameters
- `mash_k`: K-mer size for MASH (default: 21)
- `mash_s`: Sketch size for MASH (default: 1000)
- `mash_thresh`: Distance threshold for pre-clustering (default: 0.001)
- `poppunk_K`: Number of mixture components (default: 3)

### PopPIPE Parameters
- `min_cluster_size`: Minimum cluster size for analysis (default: 6)
- `ska_kmer`: K-mer size for SKA (default: 31)
- `iqtree_enabled`: Enable IQ-TREE analysis (default: true)
- `iqtree_model`: Substitution model (default: 'GTR+F+R6')
- `fastbaps_levels`: Hierarchical clustering levels (default: 3)

## Output Structure

```
results/
├── validation/                 # Input validation results
│   ├── valid_files.list
│   └── validation_report.txt
├── poppunk_model/             # PopPUNK database and model
│   ├── poppunk_db/
│   ├── cluster_model.csv
│   └── staged_files.list
├── poppunk_full/              # Full cluster assignments
│   └── full_assign.csv
├── summary/                   # PopPUNK summary
│   └── pipeline_summary.txt
├── strains/                   # Per-strain analysis
│   ├── 1/                     # Strain 1 results
│   │   ├── dists.npy
│   │   ├── njtree.nwk
│   │   ├── split_kmers.skf
│   │   ├── align_variants.aln
│   │   ├── besttree.nwk
│   │   ├── gubbins.final_tree.tre
│   │   └── fastbaps_clusters.txt
│   └── 2/                     # Strain 2 results
└── output/                    # Final summary
    └── all_clusters.txt
```

## Key Output Files

### PopPUNK Results
- `full_assign.csv`: Cluster assignments for all genomes
- `pipeline_summary.txt`: Clustering statistics and validation report
- `poppunk_db/`: Complete PopPUNK database for future queries

### PopPIPE Results
- `all_clusters.txt`: Comprehensive subclustering summary
- `strains/*/fastbaps_clusters.txt`: Hierarchical clusters per strain
- `strains/*/besttree.nwk`: Maximum likelihood phylogenies
- `strains/*/gubbins.final_tree.tre`: Recombination-free trees

## Advanced Usage

### Execution Profiles

```bash
# Run on SLURM cluster
./bin/run_pipeline.sh -i genomes -o results -p slurm

# Run with Singularity
./bin/run_pipeline.sh -i genomes -o results -p singularity

# Run locally with custom resources
./bin/run_pipeline.sh -i genomes -o results -t 16 -m "64 GB"
```

### Resume Failed Runs

```bash
# Resume from last checkpoint
./bin/run_pipeline.sh -i genomes -o results --resume
```

## Troubleshooting

### Common Issues

1. **Segmentation Faults in PopPUNK**
   - Reduce thread count: `--threads 4`
   - Increase memory: `--ram '64 GB'`

2. **Insufficient Memory**
   - Monitor with: `nextflow log`
   - Increase memory allocation in config

3. **Missing Dependencies**
   - Ensure Docker is running
   - Pull containers manually: `docker pull staphb/poppunk:2.7.5`

### Performance Optimization

- **Large datasets (>500 genomes)**: Increase `mash_thresh` to 0.005
- **High diversity datasets**: Decrease `min_cluster_size` to 3
- **Memory constraints**: Enable `singularity` instead of `docker`

## Requirements

### Software
- **Nextflow** ≥ 21.04.0
- **Docker** or **Singularity**

### Hardware
- **Minimum**: 8 GB RAM, 4 CPUs
- **Recommended**: 32 GB RAM, 8 CPUs
- **Large datasets**: 64+ GB RAM, 16+ CPUs

### Containers Used
- `staphb/poppunk:2.7.5` - PopPUNK clustering
- `quay.io/biocontainers/mash:2.3--hb105d93_9` - MASH sketching
- `poppunk/poppipe:latest` - PopPIPE analysis tools
- `python:3.9` - Data processing scripts

## Citation

If you use this pipeline, please cite:

**PopPUNK:**
- Lees, J. A., et al. (2019). Fast and flexible bacterial genomic epidemiology with PopPUNK. *Genome Research*, 29(2), 304-316.

**PopPIPE:**
- McHugh, M. P., et al. (2025). Integrated population clustering and genomic epidemiology with PopPIPE. *Microbial Genomics*, 11(4), 001404.

**Supporting Tools:**
- Ondov, B. D., et al. (2016). Mash: fast genome and metagenome distance estimation using MinHash. *Genome Biology*, 17(1), 132.
- Nguyen, L. T., et al. (2015). IQ-TREE: a fast and effective stochastic algorithm for estimating maximum-likelihood phylogenies. *Molecular Biology and Evolution*, 32(1), 268-274.

## Support

For issues and questions:
- **Pipeline issues**: Create an issue in this repository
- **PopPUNK questions**: https://github.com/bacpop/PopPUNK
- **PopPIPE questions**: https://github.com/bacpop/PopPIPE

## License

This pipeline is released under the MIT License. See individual tool licenses for their respective terms.

---

**Version**: 1.0.0  
**Last Updated**: 2024-07-05  
**Compatibility**: Nextflow DSL2, PopPUNK 2.7.5, PopPIPE latest