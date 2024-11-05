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
    sample
    algorithm_json
    images_dir
    um_to_mosaic_file
    detected_transcripts
    custom_weights
    update_vzg
    input_vzg
    tile_size
    tile_overlap
    report_only
    metadata
    entity_by_gene
    boundaries
    combine_channels
    combine_channel_settings
    combined_images_dir

    main:

    sample.map{ sample -> [id: sample] }
        .set{ meta }

    if (report_only.value) {
        //
        // MODULE: vpt generate-segmentation-metrics
        //
        VPT_GENERATESEGMENTATIONMETRICS(
            meta,
            entity_by_gene,
            metadata,
            detected_transcripts,
            images_dir,
            boundaries,
            um_to_mosaic_file
        )

        ch_versions = VPT_GENERATESEGMENTATIONMETRICS.out.versions
    } else {
        //
        // SUBWORKFLOW: Run segmentation workflow with vpt
        //
        VPTSEGMENTATION(
            meta,
            algorithm_json,
            images_dir,
            um_to_mosaic_file,
            detected_transcripts,
            custom_weights,
            update_vzg,
            input_vzg,
            tile_size,
            tile_overlap,
            combine_channels,
            combine_channel_settings,
            combined_images_dir
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
            meta,
            ch_entity_by_gene,
            ch_metadata,
            ch_transcripts,
            ch_images,
            ch_boundaries,
            ch_mosaic
        )

        VPTSEGMENTATION.out.versions
            .combine(VPT_GENERATESEGMENTATIONMETRICS.out.versions)
            .set{ ch_versions }
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
