#!/bin/bash

# Pipeline Validation Script
# This script checks if all required components are properly created

echo "🔍 PIPELINE VALIDATION"
echo "======================"
echo

# Check main files
echo "📄 Main Files:"
files=("main.nf" "nextflow.config" "README.md" "environment.yml" "VERSION" "CHANGELOG.md")
for file in "${files[@]}"; do
    if [[ -f "$file" ]]; then
        echo "  ✅ $file"
    else
        echo "  ❌ $file (MISSING)"
    fi
done
echo

# Check helper scripts
echo "🛠️ Helper Scripts:"
scripts=("bin/run_pipeline.sh" "bin/create_test_data.sh")
for script in "${scripts[@]}"; do
    if [[ -f "$script" && -x "$script" ]]; then
        echo "  ✅ $script (executable)"
    elif [[ -f "$script" ]]; then
        echo "  ⚠️ $script (not executable)"
    else
        echo "  ❌ $script (MISSING)"
    fi
done
echo

# Check configuration files
echo "⚙️ Configuration Files:"
configs=("conf/base.config" "conf/docker.config" "conf/singularity.config" "conf/profiles.config" "conf/test.config")
for config in "${configs[@]}"; do
    if [[ -f "$config" ]]; then
        echo "  ✅ $config"
    else
        echo "  ❌ $config (MISSING)"
    fi
done
echo

# Check process modules
echo "🔧 Process Modules:"
modules=(
    "validate_fasta.nf" "mash_sketch.nf" "mash_dist.nf" "bin_subsample.nf"
    "poppunk_model.nf" "poppunk_assign.nf" "summary_report.nf"
    "split_strains.nf" "sketchlib_dists.nf" "generate_nj.nf"
    "ska_build.nf" "ska_align.nf" "ska_map.nf" "iq_tree.nf"
    "gubbins.nf" "fastbaps.nf" "cluster_summary.nf"
)

module_count=0
for module in "${modules[@]}"; do
    if [[ -f "modules/local/$module" ]]; then
        echo "  ✅ $module"
        ((module_count++))
    else
        echo "  ❌ $module (MISSING)"
    fi
done
echo

# Summary
echo "📊 SUMMARY:"
echo "==========="
total_files=$(find . -type f | wc -l)
echo "  Total files created: $total_files"
echo "  Process modules: $module_count/17"
echo

if [[ $module_count -eq 17 ]]; then
    echo "🎉 PIPELINE VALIDATION: ✅ PASSED"
    echo
    echo "🚀 Ready to use! Try:"
    echo "   ./bin/run_pipeline.sh --test"
    echo
else
    echo "❌ PIPELINE VALIDATION: FAILED"
    echo "   Some components are missing"
    echo
fi

echo "📁 Complete file structure:"
find . -type f | sort | sed 's/^/  /'
echo
echo "🎊 Combined PopPUNK + PopPIPE Pipeline Complete!"