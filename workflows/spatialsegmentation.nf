/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { PREPARE_SEGMENTATION     } from '../modules/local/vpt/prepare-segmentation/main'
include { RUN_SEGMENTATION_ON_TILE } from '../modules/local/vpt/run-segmentation-on-tile/main'
include { paramsSummaryMap         } from 'plugin/nf-validation'
include { softwareVersionsToYAML   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText   } from '../subworkflows/local/utils_nfcore_spatialsegmentation_pipeline'

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
        .set{ ch_segment_tiles }

    //
    // MODULE: Run vpt run-segmentation-on-tile
    //
    RUN_SEGMENTATION_ON_TILE(
        ch_segment_tiles
    )

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
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
