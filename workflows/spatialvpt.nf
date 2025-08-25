/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { TIFF_SEGMENTATION_VPT                            } from '../subworkflows/nf-core/tiff_segmentation_vpt/main'
include { VPTUPDATEMETA                                    } from '../subworkflows/local/vptupdatemeta/main'
include { VIZGENPOSTPROCESSING_GENERATESEGMENTATIONMETRICS } from '../modules/local/vizgenpostprocessing/generatesegmentationmetrics/main'
include { VIZGENPOSTPROCESSING_CONVERTGEOMETRY             } from '../modules/local/vizgenpostprocessing/convertgeometry/main'

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
    _tile_size
    _tile_overlap
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

    sample.map{ it -> [id: it] }
        .set{ meta }

    ch_segmentation = Channel.empty()
    ch_versions     = Channel.empty()

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

        ch_versions = ch_versions.mix(VIZGENPOSTPROCESSING_GENERATESEGMENTATIONMETRICS.out.versions)
    } else if (convert_geometry.value) {
        // Create channel for conversion
        meta.combine(boundary_dir)
            .combine(boundary_regex)
            .set{ ch_convert }

        //
        // MODULE: vpt convert-geometry
        //
        VIZGENPOSTPROCESSING_CONVERTGEOMETRY(
            ch_convert
        )

        // Need to remove meta for downstream processing
        VIZGENPOSTPROCESSING_CONVERTGEOMETRY.out.segmentation
            .map { _meta, parquet -> parquet
            }.set{ ch_segmentation }

        ch_versions = ch_versions.mix(VIZGENPOSTPROCESSING_CONVERTGEOMETRY.out.versions)
    } else {
        // Crate input channel for segmentation workflow
        ch_input = meta
            .combine(images_dir)
            .combine(um_to_mosaic_file)
            .map { meta_val, img_dir, transform_file ->
                [meta_val, img_dir, transform_file]
            }

        //
        // SUBWORKFLOW: Run segmentation workflow with vpt
        //
        TIFF_SEGMENTATION_VPT(
            ch_input,
            algorithm_json.first(),
            images_regex,
            custom_weights.first()
        )
        ch_versions = ch_versions.mix(TIFF_SEGMENTATION_VPT.out.versions)

        TIFF_SEGMENTATION_VPT.out.micron_space_segmentation.set{ ch_segmentation }
    }

    if (!report_only.value) {
        //
        // SUBWORKFLOW: Update metadata with segmentation results
        //
        VPTUPDATEMETA(
            ch_segmentation,
            detected_transcripts,
            update_vzg,
            input_vzg
        )
        ch_versions = ch_versions.mix(VPTUPDATEMETA.out.versions)

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
        ch_versions = ch_versions.mix(VIZGENPOSTPROCESSING_GENERATESEGMENTATIONMETRICS.out.versions)
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
