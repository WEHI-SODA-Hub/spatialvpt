/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { VPTSEGMENTATION                 } from '../subworkflows/local/vptsegmentation'
include { VPT_GENERATESEGMENTATIONMETRICS } from '../modules/local/vpt/generatesegmentationmetrics/generatesegmentationmetrics'

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
    update_vzg

    main:

    //
    // SUBWORKFLOW: Run segmentation workflow with vpt
    //
    VPTSEGMENTATION(
        ch_samplesheet,
        tile_size,
        tile_overlap,
        update_vzg
    )

    // compile channels for input to generate-segmentation-metrics
    ch_entity_by_gene = VPTSEGMENTATION.out.entity_by_gene
    ch_metadata       = VPTSEGMENTATION.out.metadata
    ch_transcripts    = VPTSEGMENTATION.out.transcripts
    ch_images         = VPTSEGMENTATION.out.images
    ch_boundaries     = VPTSEGMENTATION.out.segmentation
    ch_mosaic         = VPTSEGMENTATION.out.mosaic

    //
    // MODULE: vpt generate-segmentation-metrics
    //
    VPT_GENERATESEGMENTATIONMETRICS(
        ch_entity_by_gene
            .join(ch_metadata)
            .join(ch_transcripts)
            .join(ch_images)
            .join(ch_boundaries)
            .join(ch_mosaic)
    )

    emit:
    segmentation   = VPTSEGMENTATION.out.segmentation
    metadata       = VPTSEGMENTATION.out.metadata
    entity_by_gene = VPTSEGMENTATION.out.entity_by_gene
    vzg            = VPTSEGMENTATION.out.vzg
    report         = VPT_GENERATESEGMENTATIONMETRICS.out.report
    versions       = VPTSEGMENTATION.out.versions        // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
