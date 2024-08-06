/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { PREPARE_SEGMENTATION      } from '../modules/local/vpt/prepare-segmentation/main'
include { RUN_SEGMENTATION_ON_TILE  } from '../modules/local/vpt/run-segmentation-on-tile/main'
include { COMPILE_TILE_SEGMENTATION } from '../modules/local/vpt/compile-tile-segmentation/main'
include { PARTITION_TRANSCRIPTS     } from '../modules/local/vpt/partition-transcripts/main'
include { DERIVE_ENTITY_METADATA    } from '../modules/local/vpt/derive-entity-metadata/main'
include { paramsSummaryMap          } from 'plugin/nf-validation'
include { softwareVersionsToYAML    } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText    } from '../subworkflows/local/utils_nfcore_spatialsegmentation_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow SPATIALSEGMENTATION {

    take:
    ch_samplesheet // channel: samplesheet read in from --input
    tile_size
    tile_overlap

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    //
    // MODULE: Run vpt prepare-segmentation
    //
    PREPARE_SEGMENTATION (
        ch_samplesheet,
        tile_size,
        tile_overlap
    )

    // Create list sequence of 0..N tiles
    // TODO: determine whether multi-sample functionality
    // is required -- with this current structure, we can
    // only support processing a single sample at a time
    PREPARE_SEGMENTATION.out.segmentation_files
        .map { meta, seg_json, images, alg_alg -> seg_json }
        .splitJson(path: 'window_grid' )
        .filter { it.key == 'num_tiles' }
        .map { it.value as Integer }
        .flatMap { num -> (0..num-1).toList() }
        .set{ ch_tiles }

    // Combine specification json files with tile ID
    PREPARE_SEGMENTATION.out.segmentation_files
        .combine(ch_tiles)
        .set{ ch_tile_segments }

    //
    // MODULE: Run vpt run-segmentation-on-tile
    //
    RUN_SEGMENTATION_ON_TILE(
        ch_tile_segments
    )

    /// collect segmented tiles
    RUN_SEGMENTATION_ON_TILE.out.segmented_tile
        .map { meta, seg_tile -> seg_tile }
        .flatten()
        .collect()
        .set{ ch_segmented_tiles }

    //
    // MODULE: Run vpt compile-tile-segmentation
    //
    COMPILE_TILE_SEGMENTATION(
        PREPARE_SEGMENTATION.out.segmentation_files,
        ch_segmented_tiles
    )

    //
    // MODULE: Run vpt derive-entity-metadata
    //
    DERIVE_ENTITY_METADATA(
        COMPILE_TILE_SEGMENTATION.out.micron_space
    )

    // Extract detected transcripts from samplesheet
    ch_samplesheet
        .map { meta, alg_json, images, mosaic, detected_txs -> detected_txs }
        .set{ ch_detected_txs }

    // Combine detected transcripts with micron space file
    // to create input for partition-transcripts step
    COMPILE_TILE_SEGMENTATION.out.micron_space
        .combine(ch_detected_txs)
        .set{ ch_partition_txs_input }

    //
    // MODULE: Run vpt partition-transcripts
    //
    PARTITION_TRANSCRIPTS(
        ch_partition_txs_input
    )

    // Output channels
    ch_segmentation_output =
        COMPILE_TILE_SEGMENTATION.out.micron_space

    ch_entity_metadata =
        DERIVE_ENTITY_METADATA.out.entity_metadata

    ch_transcripts =
        PARTITION_TRANSCRIPTS.out.transcripts

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_pipeline_software_mqc_versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }

    emit:
    segmentation   = ch_segmentation_output
    metadata       = ch_entity_metadata
    transcripts    = ch_transcripts
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
