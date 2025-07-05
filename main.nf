#!/usr/bin/env nextflow
nextflow.enable.dsl=2

/* ----------------------------------------------------------
 * COMBINED POPPUNK + POPPIPE PIPELINE
 * 
 * This pipeline combines:
 * 1. localpoppunk - PopPUNK clustering workflow
 * 2. PopPIPE-bp - Downstream analysis and visualization
 * 
 * The output from localpoppunk feeds directly into PopPIPE-bp
 * ---------------------------------------------------------- */

println "▶ FASTA input directory:  ${params.input}"
println "▶ Results directory:      ${params.resultsDir}"
println "▶ Threads / RAM:          ${params.threads}  /  ${params.ram}"

// Include processes from localpoppunk
include { VALIDATE_FASTA } from './modules/local/validate_fasta'
include { MASH_SKETCH } from './modules/local/mash_sketch'
include { MASH_DIST } from './modules/local/mash_dist'
include { BIN_SUBSAMPLE } from './modules/local/bin_subsample'
include { POPPUNK_MODEL } from './modules/local/poppunk_model'
include { POPPUNK_ASSIGN } from './modules/local/poppunk_assign'
include { SUMMARY_REPORT } from './modules/local/summary_report'

// Include processes from PopPIPE-bp conversion
include { SPLIT_STRAINS } from './modules/local/split_strains'
include { SKETCHLIB_DISTS } from './modules/local/sketchlib_dists'
include { GENERATE_NJ } from './modules/local/generate_nj'
include { SKA_BUILD } from './modules/local/ska_build'
include { SKA_ALIGN } from './modules/local/ska_align'
include { SKA_MAP } from './modules/local/ska_map'
include { IQ_TREE } from './modules/local/iq_tree'
include { GUBBINS } from './modules/local/gubbins'
include { FASTBAPS } from './modules/local/fastbaps'
include { CLUSTER_SUMMARY } from './modules/local/cluster_summary'

/* ──────────────────────────────────────────────────────────
 * MAIN WORKFLOW
 * ────────────────────────────────────────────────────────── */
workflow {

    // ========================================
    // PHASE 1: POPPUNK CLUSTERING
    // ========================================
    
    ch_fasta = Channel.fromPath("${params.input}/*.fasta", checkIfExists: true)
    
    // Validate FASTA files first
    validation_out = VALIDATE_FASTA(ch_fasta.collect())
    
    // Display validation report
    validation_out.report.view { report -> 
        println "\n" + "="*50
        println "📋 FASTA VALIDATION REPORT"
        println "="*50
        println report.text
        println "="*50 + "\n"
    }
    
    // Filter the original FASTA files based on validation results
    valid_files_ch = validation_out.valid_list
        .splitText() { it.trim() }
        .map { file_path -> file(file_path) }
        .filter { it.exists() }
    
    // Collect valid files for use in multiple processes
    valid_files_collected = valid_files_ch.collect()
    
    // Run PopPUNK clustering pipeline
    sketch_out = MASH_SKETCH(valid_files_collected)
    dist_ch    = MASH_DIST(sketch_out.msh)
    subset_ch  = BIN_SUBSAMPLE(dist_ch)
    model_out  = POPPUNK_MODEL(subset_ch, valid_files_collected)
    final_csv  = POPPUNK_ASSIGN(model_out.db, validation_out.valid_list, valid_files_collected)

    // Generate PopPUNK summary report
    poppunk_summary = SUMMARY_REPORT(final_csv, validation_out.report)
    
    final_csv.view { p -> "✅ PopPUNK assignment completed: ${p}" }

    // ========================================
    // PHASE 2: POPPIPE DOWNSTREAM ANALYSIS
    // ========================================
    
    // Create the required input files for PopPIPE from PopPUNK outputs
    // PopPIPE needs: rfile, clusters CSV, and h5 database
    
    // The rfile is the staged_files.list from POPPUNK_MODEL
    ch_rfile = model_out.staged_list
    
    // The clusters CSV is the final assignment from POPPUNK_ASSIGN  
    ch_clusters = final_csv
    
    // The h5 database file should be in the poppunk_db directory
    ch_h5_db = model_out.db.map { db_dir -> 
        file("${db_dir}/poppunk_db.h5")
    }
    
    // Read clusters and filter by minimum cluster size
    ch_strain_ids = ch_clusters
        .splitCsv(header: true)
        .map { row -> row.Cluster ?: row.cluster }
        .groupTuple()
        .map { cluster_id, samples -> 
            [cluster_id, samples.size()]
        }
        .filter { cluster_id, size -> 
            size >= params.min_cluster_size 
        }
        .map { cluster_id, size -> cluster_id }
    
    // Split strains for each cluster that meets minimum size
    strain_files = SPLIT_STRAINS(
        ch_rfile,
        ch_clusters,
        ch_strain_ids.collect()
    )
    
    // Process each strain through the PopPIPE pipeline
    strain_files.strain_data
        .transpose()
        .set { ch_strain_processing }
    
    // Calculate distances for each strain
    strain_dists = SKETCHLIB_DISTS(
        ch_h5_db,
        ch_strain_processing
    )
    
    // Generate neighbor-joining trees
    nj_trees = GENERATE_NJ(strain_dists)
    
    // Build SKA files for alignment
    ska_files = SKA_BUILD(ch_strain_processing)
    
    // Create alignments
    alignments = SKA_ALIGN(ska_files)
    
    // Create mappings for Gubbins
    mappings = SKA_MAP(ska_files, ch_strain_processing)
    
    // Generate ML trees with IQ-TREE
    ml_trees = IQ_TREE(nj_trees, alignments, ch_rfile)
    
    // Run Gubbins for recombination removal
    gubbins_trees = GUBBINS(mappings, ml_trees)
    
    // Generate subclusters with fastbaps
    fastbaps_clusters = FASTBAPS(ml_trees, alignments)
    
    // Generate final cluster summary
    cluster_summary = CLUSTER_SUMMARY(fastbaps_clusters.collect())
    
    // Final outputs
    cluster_summary.view { p -> "✅ PopPIPE analysis completed: ${p}" }
    
    // Emit final results
    emit:
    poppunk_clusters = final_csv
    poppunk_summary = poppunk_summary
    poppipe_clusters = cluster_summary
}

workflow.onComplete {
    println """
    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║                    COMBINED POPPUNK + POPPIPE PIPELINE                       ║
    ║                                 COMPLETED                                    ║
    ╠══════════════════════════════════════════════════════════════════════════════╣
    ║ Phase 1 (PopPUNK): Bacterial genome clustering completed                    ║
    ║ Phase 2 (PopPIPE): Downstream analysis and subclustering completed          ║
    ║                                                                              ║
    ║ Results available in: ${params.resultsDir}                                  ║
    ║                                                                              ║
    ║ Key outputs:                                                                 ║
    ║ - PopPUNK clusters: poppunk_full/full_assign.csv                           ║
    ║ - PopPIPE subclusters: output/all_clusters.txt                             ║
    ║ - Summary reports: summary/pipeline_summary.txt                             ║
    ╚══════════════════════════════════════════════════════════════════════════════╝
    """.stripIndent()
}