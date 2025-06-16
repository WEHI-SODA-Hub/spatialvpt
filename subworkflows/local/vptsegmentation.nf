//
// Perform cell segmentation using vizgen post-processing tool
// Optionally update VZG file
//

include { VIZGENPOSTPROCESSING_PREPARESEGMENTATION } from '../../modules/nf-core/vizgenpostprocessing/preparesegmentation/main'
include { VPT_RUNSEGMENTATIONONTILE                } from '../../modules/local/vpt/runsegmentationontile/main'
include { VPT_COMPILETILESEGMENTATION              } from '../../modules/local/vpt/compiletilesegmentation/main'
include { VPT_PARTITIONTRANSCRIPTS                 } from '../../modules/local/vpt/partitiontranscripts/main'
include { VPT_DERIVEENTITYMETADATA                 } from '../../modules/local/vpt/deriveentitymetadata/main'
include { VPT_UPDATEVZG                            } from '../../modules/local/vpt/updatevzg/main'
include { softwareVersionsToYAML                   } from '../../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText                   } from '../../subworkflows/local/utils_nfcore_spatialvpt_pipeline'

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
        .combine(algorithm_json)
        .set{ ch_segmentation_files }

    // Add tile infomration for running segmentation on tile
    ch_segmentation_files
        .combine(ch_tiles)
        .set{ ch_tile_segments }

    //
    // MODULE: Run vpt run-segmentation-on-tile
    //
    VPT_RUNSEGMENTATIONONTILE(
        ch_tile_segments,
        custom_weights.first()
    )

    /// collect segmented tiles
    VPT_RUNSEGMENTATIONONTILE.out.segmented_tile
        .map { meta, seg_tile -> seg_tile }
        .flatten()
        .collect()
        .set{ ch_segmented_tiles }


    //
    // MODULE: Run vpt compile-tile-segmentation
    //
    VPT_COMPILETILESEGMENTATION(
        ch_segmentation_files,
        ch_segmented_tiles
    )

    //
    // MODULE: Run vpt derive-entity-metadata
    //
    VPT_DERIVEENTITYMETADATA(
        meta,
        VPT_COMPILETILESEGMENTATION.out.micron_space
    )

    //
    // MODULE: Run vpt partition-transcripts
    //
    VPT_PARTITIONTRANSCRIPTS(
        meta,
        VPT_COMPILETILESEGMENTATION.out.micron_space,
        detected_txs
    )

    // Output channels
    ch_segmentation_output =
        VPT_COMPILETILESEGMENTATION.out.micron_space

    ch_entity_metadata =
        VPT_DERIVEENTITYMETADATA.out.entity_metadata

    ch_entity_by_gene =
        VPT_PARTITIONTRANSCRIPTS.out.transcripts

    ch_vzg = Channel.empty()
    if (update_vzg.value) {
        //
        // MODULE: Run vpt update-vzg
        //
        VPT_UPDATEVZG(
            meta,
            input_vzg,
            ch_segmentation_output,
            ch_entity_by_gene,
            ch_entity_metadata
        )

        ch_vzg = VPT_UPDATEVZG.out.vzg_file
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

