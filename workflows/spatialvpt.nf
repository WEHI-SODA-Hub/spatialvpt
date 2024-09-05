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

workflow SPATIALVPT {

    take:
    ch_samplesheet // channel: samplesheet read in from --input
    tile_size
    tile_overlap
    update_vzg
    report_only
    combine_channels

    main:

    if (report_only.value) {
        // compile channels for input to generate-segmentation-metrics from samplesheet
        ch_samplesheet.map {
                meta, alg_json, images, mosaic, transcripts, vzg, metadata, entity_by_gene, boundaries, combine_settings ->
                [ meta, entity_by_gene, metadata, transcripts, images, boundaries, mosaic ]
        }
        .set{ ch_metrics_input }

        //
        // MODULE: vpt generate-segmentation-metrics
        //
        VPT_GENERATESEGMENTATIONMETRICS(
            ch_metrics_input
        )

        ch_versions = VPT_GENERATESEGMENTATIONMETRICS.out.versions
    } else {
        //
        // SUBWORKFLOW: Run segmentation workflow with vpt
        //
        VPTSEGMENTATION(
            ch_samplesheet,
            tile_size,
            tile_overlap,
            update_vzg,
            combine_channels
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

        ch_versions = VPTSEGMENTATION.out.versions
    }

    emit:
    report         = VPT_GENERATESEGMENTATIONMETRICS.out.report
    versions       = ch_versions // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
