/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { VPTSEGMENTATION                                  } from '../subworkflows/local/vptsegmentation/main'
include { VPTUPDATEMETA                                    } from '../subworkflows/local/vptupdatemeta/main'
include { VIZGENPOSTPROCESSING_GENERATESEGMENTATIONMETRICS } from '../modules/local/vizgenpostprocessing/generatesegmentationmetrics/main'
include { VIZGENPOSTPROCESSING_CONVERTGEOMETRY           } from '../modules/local/vizgenpostprocessing/convertgeometry/main'

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
    convert_geometry
    boundary_dir
    boundary_regex

    main:

    sample.map{ sample -> [id: sample] }
        .set{ meta }

    ch_segmentation = Channel.empty()

    if (report_only.value && convert_geometry.value) {
        error "The 'convert_geometry parameter' is incompatible with 'report_only'. Please set 'convert_geometry' to false or remove 'report_only'."
    } else if (report_only.value) {
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
    } else if (convert_geometry.value) {
        //
        // MODULE: vpt convert-geometry
        //
        VIZGENPOSTPROCESSING_CONVERTGEOMETRY(
            [ meta, boundary_dir, boundary_regex ]
        )

        VIZGENPOSTPROCESSING_CONVERTGEOMETRY.out.segmentation
            .set{ ch_segmentation }

        ch_versions = VIZGENPOSTPROCESSING_CONVERTGEOMETRY.out.versions
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
            custom_weights,
        )

        VPTSEGMENTATION.out.segmentation.set{ ch_segmentation }

        ch_versions = VPTSEGMENTATION.out.versions
    }

    if (!report_only.value) {
        //
        // SUBWORKFLOW: Update metadata with segmentation results
        //
        VPTUPDATEMETA(
            meta,
            ch_segmentation,
            detected_transcripts,
            update_vzg,
            input_vzg
        )

        // compile channels for input to generate-segmentation-metrics
        ch_metadata       = VPTUPDATEMETA.out.metadata
        ch_transcripts    = VPTUPDATEMETA.out.transcripts
        ch_images         = meta.concat(images_dir)

        //
        // MODULE: vpt generate-segmentation-metrics
        //
        VIZGENPOSTPROCESSING_GENERATESEGMENTATIONMETRICS(
            meta,
            entity_by_gene,
            ch_metadata,
            ch_transcripts,
            ch_images,
            ch_segmentation,
            um_to_mosaic_file,
            z_index,
            red_stain_name,
            green_stain_name,
            blue_stain_name,
            transcript_count_threshold,
            volume_filter_threshold
        )

        ch_versions
            .combine(VIZGENPOSTPROCESSING_GENERATESEGMENTATIONMETRICS.out.versions)
            .combine(VPTUPDATEMETA.out.versions)
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
