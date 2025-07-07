//
// Perform cell segmentation using vizgen post-processing tool
// Optionally update VZG file
//

include { VIZGENPOSTPROCESSING_PREPARESEGMENTATION     } from '../../modules/nf-core/vizgenpostprocessing/preparesegmentation/main'
include { VIZGENPOSTPROCESSING_RUNSEGMENTATIONONTILE   } from '../../modules/nf-core/vizgenpostprocessing/runsegmentationontile/main'
include { VIZGENPOSTPROCESSING_COMPILETILESEGMENTATION } from '../../modules/local/vizgenpostprocessing/compiletilesegmentation/main'
include { VIZGENPOSTPROCESSING_PARTITIONTRANSCRIPTS    } from '../../modules/local/vizgenpostprocessing/partitiontranscripts/main'
include { VIZGENPOSTPROCESSING_DERIVEENTITYMETADATA    } from '../../modules/local/vizgenpostprocessing/deriveentitymetadata/main'
include { VIZGENPOSTPROCESSING_UPDATEVZG               } from '../../modules/local/vizgenpostprocessing/updatevzg/main'
include { softwareVersionsToYAML                       } from '../../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText                       } from '../../subworkflows/local/utils_nfcore_spatialvpt_pipeline'

workflow VPTSEGMENTATION {

    take:
    meta
    algorithm_json
    images_dir
    images_regex
    um_to_mosaic_file
    detected_txs
    custom_weights
    update_vzg
    input_vzg
    tile_size
    tile_overlap

    main:

    ch_versions = Channel.empty()

    // Create images channel
    meta.concat(images_dir)
        .set{ ch_images }

    //
    // MODULE: Run vpt prepare-segmentation
    //
    VIZGENPOSTPROCESSING_PREPARESEGMENTATION (
        meta.combine(images_dir)
            .combine(um_to_mosaic_file)
            .map { meta_val, images, um_file ->
                tuple(meta_val, images, um_file)
        },
        algorithm_json,
        images_regex
    )

    // Create list sequence of 0..N tiles
    VIZGENPOSTPROCESSING_PREPARESEGMENTATION.out.segmentation_files
        .map { meta, seg_json -> seg_json }
        .splitJson(path: 'window_grid' )
        .filter { it.key == 'num_tiles' }
        .map { it.value as Integer }
        .flatMap { num -> (0..num-1).toList() }
        .set{ ch_tiles }


    // Create channel containing required segmentation files
    VIZGENPOSTPROCESSING_PREPARESEGMENTATION.out.segmentation_files
        .combine(ch_images)
        .map { meta, seg_params, input_images ->
            tuple(
                meta,
                input_images,
                seg_params,
            )
        }.set{ ch_segmentation_files }

    // Add tile infomration for running segmentation on tile and reorder channel
    ch_segmentation_files
        .combine(ch_tiles)
        .set{ ch_tile_segments }

    //
    // MODULE: Run vpt run-segmentation-on-tile
    //
    VIZGENPOSTPROCESSING_RUNSEGMENTATIONONTILE(
        ch_tile_segments,
        algorithm_json.first(),
        custom_weights.first()
    )

    /// collect segmented tiles
    VIZGENPOSTPROCESSING_RUNSEGMENTATIONONTILE.out.segmented_tile
        .map { meta, seg_tile -> seg_tile }
        .flatten()
        .collect()
        .set{ ch_segmented_tiles }

    ch_segmented_tiles.view()
    //
    // MODULE: Run vpt compile-tile-segmentation
    //
    VIZGENPOSTPROCESSING_COMPILETILESEGMENTATION(
        ch_segmentation_files,
        algorithm_json,
        ch_segmented_tiles
    )

    //
    // MODULE: Run vpt derive-entity-metadata
    //
    VIZGENPOSTPROCESSING_DERIVEENTITYMETADATA(
        meta,
        VIZGENPOSTPROCESSING_COMPILETILESEGMENTATION.out.micron_space
    )

    //
    // MODULE: Run vpt partition-transcripts
    //
    VIZGENPOSTPROCESSING_PARTITIONTRANSCRIPTS(
        meta,
        VIZGENPOSTPROCESSING_COMPILETILESEGMENTATION.out.micron_space,
        detected_txs
    )

    // Output channels
    ch_segmentation_output =
        VIZGENPOSTPROCESSING_COMPILETILESEGMENTATION.out.micron_space

    ch_entity_metadata =
        VIZGENPOSTPROCESSING_DERIVEENTITYMETADATA.out.entity_metadata

    ch_entity_by_gene =
        VIZGENPOSTPROCESSING_PARTITIONTRANSCRIPTS.out.transcripts

    ch_vzg = Channel.empty()
    if (update_vzg.value) {
        //
        // MODULE: Run vpt update-vzg
        //
        VIZGENPOSTPROCESSING_UPDATEVZG(
            meta,
            input_vzg,
            ch_segmentation_output,
            ch_entity_by_gene,
            ch_entity_metadata
        )

        ch_vzg = VIZGENPOSTPROCESSING_UPDATEVZG.out.vzg_file
    }

    // get transcripts channel for downstream output
    meta.concat(detected_txs)
        .set{ ch_transcripts }

    // get micron_to_mosaic channel for downstream output
    meta.concat(um_to_mosaic_file)
        .set{ ch_mosaic }

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
    entity_by_gene = ch_entity_by_gene
    metadata       = ch_entity_metadata
    transcripts    = ch_transcripts
    images         = ch_images
    segmentation   = ch_segmentation_output
    mosaic         = ch_mosaic
    vzg            = ch_vzg

    versions       = ch_collated_versions // channel: [ path(versions.yml) ]
}

