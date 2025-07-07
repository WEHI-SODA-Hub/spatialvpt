/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { VPTSEGMENTATION                                  } from '../subworkflows/local/vptsegmentation'
include { VIZGENPOSTPROCESSING_GENERATESEGMENTATIONMETRICS } from '../modules/local/vizgenpostprocessing/generatesegmentationmetrics/main'

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
    images_regex
    um_to_mosaic_file
    detected_transcripts
    custom_weights
    update_vzg
    input_vzg
    tile_size
    tile_overlap
    z_index
    red_stain_name
    green_stain_name
    blue_stain_name
    transcript_count_threshold
    volume_filter_threshold
    report_only
    metadata
    entity_by_gene
    boundaries

    main:

    sample.map{ sample -> [id: sample] }
        .set{ meta }

    if (report_only.value) {
        //
        // MODULE: vpt generate-segmentation-metrics
        //
        VIZGENPOSTPROCESSING_GENERATESEGMENTATIONMETRICS(
            meta,
            entity_by_gene,
            metadata,
            detected_transcripts,
            images_dir,
            boundaries,
            um_to_mosaic_file,
            z_index,
            red_stain_name,
            green_stain_name,
            blue_stain_name,
            transcript_count_threshold,
            volume_filter_threshold
        )

        ch_versions = VIZGENPOSTPROCESSING_GENERATESEGMENTATIONMETRICS.out.versions
    } else {
        //
        // SUBWORKFLOW: Run segmentation workflow with vpt
        //
        VPTSEGMENTATION(
            meta,
            algorithm_json,
            images_dir,
            images_regex,
            um_to_mosaic_file,
            detected_transcripts,
            custom_weights,
            update_vzg,
            input_vzg,
            tile_size,
            tile_overlap
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
        VIZGENPOSTPROCESSING_GENERATESEGMENTATIONMETRICS(
            meta,
            ch_entity_by_gene,
            ch_metadata,
            ch_transcripts,
            ch_images,
            ch_boundaries,
            ch_mosaic,
            z_index,
            red_stain_name,
            green_stain_name,
            blue_stain_name,
            transcript_count_threshold,
            volume_filter_threshold
        )

        VPTSEGMENTATION.out.versions
            .combine(VIZGENPOSTPROCESSING_GENERATESEGMENTATIONMETRICS.out.versions)
            .set{ ch_versions }
    }

    emit:
    report         = VIZGENPOSTPROCESSING_GENERATESEGMENTATIONMETRICS.out.report
    versions       = ch_versions // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
