//
// Perform cell segmentation using vizgen post-processing tool
// Optionally update VZG file
//

include { paramsSummaryMap          } from 'plugin/nf-validation'
include { COMBINECHANNELS           } from '../../modules/local/combinechannels/main'
include { PREPARE_SEGMENTATION      } from '../../modules/local/vpt/prepare-segmentation/main'
include { RUN_SEGMENTATION_ON_TILE  } from '../../modules/local/vpt/run-segmentation-on-tile/main'
include { COMPILE_TILE_SEGMENTATION } from '../../modules/local/vpt/compile-tile-segmentation/main'
include { PARTITION_TRANSCRIPTS     } from '../../modules/local/vpt/partition-transcripts/main'
include { DERIVE_ENTITY_METADATA    } from '../../modules/local/vpt/derive-entity-metadata/main'
include { UPDATE_VZG                } from '../../modules/local/vpt/update-vzg/main'
include { softwareVersionsToYAML    } from '../../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText    } from '../../subworkflows/local/utils_nfcore_spatialvpt_pipeline'

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
    combine_channels
    combine_channel_settings
    combined_images_dir

    main:

    ch_versions = Channel.empty()

    // Create images channel
    meta.concat(images_dir)
        .set{ ch_images }

    println(combine_channels.value)
    if (combine_channels.value) {
        // Throw an error as this functionality doesn't work properly
        error "Combine channel functionality is currently unsupported"

        // Extract and parse combine channel settings
        combine_channel_settings
            .map { comb_str ->
                def channels_to_merge = comb_str
                    .split('=')[0]
                    .replace('+', ',')

                def merged_channel = comb_str
                    .split('=')[1]
                    .split(':')[0]

                def z_index = comb_str
                    .split('=')[1]
                    .split(':')[1]
                    .replace('z', '')

                def tile_size = comb_str
                    .split('=')[1]
                    .split(':')[2]
                    .replace('t', '')

                def mpp = comb_str
                    .split('=')[1]
                    .split(':')[3]
                    .replace('m', '')

                return [channels_to_merge,
                        'mosaic_' + merged_channel + '_z',
                        z_index, tile_size, mpp]
            }
            .set{ ch_combine_settings }

        //
        // MODULE: Run combine_channels script
        //
        COMBINECHANNELS (
            meta.merge(images_dir),
            ch_combine_settings,
            combined_images_dir
        )

        //
        // MODULE: Run vpt prepare-segmentation
        //
        PREPARE_SEGMENTATION (
            meta,
            algorithm_json,
            combined_images_dir,
            images_regex,
            um_to_mosaic_file,
            tile_size,
            tile_overlap,
            COMBINECHANNELS.out.done
        )
    } else {
        // No channel combination
        //
        // MODULE: Run vpt prepare-segmentation
        //
        PREPARE_SEGMENTATION (
            meta,
            algorithm_json,
            images_dir,
            images_regex,
            um_to_mosaic_file,
            tile_size,
            tile_overlap,
            true
        )
    }

    // Create list sequence of 0..N tiles
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
        ch_tile_segments,
        custom_weights.first()
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
        meta,
        COMPILE_TILE_SEGMENTATION.out.micron_space
    )

    //
    // MODULE: Run vpt partition-transcripts
    //
    PARTITION_TRANSCRIPTS(
        meta,
        COMPILE_TILE_SEGMENTATION.out.micron_space,
        detected_txs
    )

    // Output channels
    ch_segmentation_output =
        COMPILE_TILE_SEGMENTATION.out.micron_space

    ch_entity_metadata =
        DERIVE_ENTITY_METADATA.out.entity_metadata

    ch_entity_by_gene =
        PARTITION_TRANSCRIPTS.out.transcripts

    ch_vzg = Channel.empty()
    if (update_vzg.value) {
        //
        // MODULE: Run vpt update-vzg
        //
        UPDATE_VZG(
            meta,
            input_vzg,
            ch_segmentation_output,
            ch_entity_by_gene,
            ch_entity_metadata
        )

        ch_vzg = UPDATE_VZG.out.vzg_file
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

