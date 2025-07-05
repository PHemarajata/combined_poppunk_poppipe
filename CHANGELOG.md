# Changelog

All notable changes to the Combined PopPUNK + PopPIPE Pipeline will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-07-05

### Added
- **Initial release** of the combined PopPUNK + PopPIPE pipeline
- **Phase 1 (PopPUNK)**: Complete bacterial genome clustering workflow
  - FASTA validation with quality control
  - MASH sketching and distance calculation
  - Intelligent subsampling for large datasets
  - PopPUNK database creation and model fitting
  - Genome assignment to clusters with segfault prevention
  - Comprehensive summary reporting
- **Phase 2 (PopPIPE)**: Downstream phylogenetic analysis
  - Strain separation based on PopPUNK clusters
  - Within-cluster distance extraction using pp-sketchlib
  - Neighbor-joining tree generation with RapidNJ
  - SKA-based k-mer alignments (both reference-free and reference-based)
  - Maximum likelihood phylogeny with IQ-TREE
  - Recombination removal using Gubbins
  - Hierarchical subclustering with fastbaps
  - Comprehensive cluster summary generation

### Features
- **Multi-profile execution**: Docker, Singularity, local, cluster (SLURM/PBS)
- **Intelligent resource management**: Automatic scaling and segfault prevention
- **Comprehensive validation**: Input file quality control and pipeline validation
- **Test framework**: Synthetic data generation and test configurations
- **Helper scripts**: Easy-to-use pipeline runner and setup validation
- **Flexible configuration**: Multiple execution profiles and parameter customization
- **Container support**: Pre-configured Docker and Singularity containers
- **Cluster compatibility**: SLURM and PBS job scheduler support

### Technical Details
- **Nextflow DSL2**: Modern workflow definition language
- **PopPUNK 2.7.5**: Latest stable version with segfault fixes
- **Container orchestration**: Docker and Singularity support
- **Resource optimization**: Memory and CPU scaling for different dataset sizes
- **Error handling**: Robust error recovery and resume functionality

### Documentation
- Comprehensive README with usage examples
- Configuration templates for different environments
- Troubleshooting guide with common issues
- Performance optimization recommendations
- Citation guidelines for academic use

### Validation
- Automated setup validation script
- Test data generation for pipeline verification
- Multiple execution profile testing
- Container availability checking
- Dependency validation

## [Unreleased]

### Planned Features
- **Microreact integration**: Automatic visualization generation
- **Transmission analysis**: BactDating and TransPhylo integration
- **Advanced visualization**: Interactive plots and reports
- **Cloud deployment**: AWS Batch and Google Cloud support
- **Performance monitoring**: Resource usage tracking and optimization
- **Extended format support**: Additional input file formats
- **Quality metrics**: Enhanced QC reporting and statistics

---

## Version Compatibility

| Pipeline Version | PopPUNK Version | PopPIPE Version | Nextflow Version |
|------------------|-----------------|-----------------|------------------|
| 1.0.0            | 2.7.5          | latest          | ≥21.04.0         |

## Migration Guide

This is the initial release, so no migration is required.

## Support

For issues, questions, or contributions:
- **Issues**: Create an issue in the repository
- **Discussions**: Use GitHub Discussions for questions
- **Contributions**: Submit pull requests with improvements

## Acknowledgments

This pipeline combines and extends the functionality of:
- **PopPUNK**: Lees et al. (2019) - Population clustering
- **PopPIPE**: McHugh et al. (2025) - Downstream analysis
- **Nextflow**: Di Tommaso et al. (2017) - Workflow management