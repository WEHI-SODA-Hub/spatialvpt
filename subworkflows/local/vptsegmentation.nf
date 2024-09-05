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
    ch_samplesheet   // channel: samplesheet read in from --input
    tile_size        // value: defined by params.tile_size (int)
    tile_overlap     // value: defined by params.tile_overlap (int)
    update_vzg       // value: defined by params.update_vzg (boolean)
    combine_channels // value: defined by params.combine_channels (boolean)

    main:

    ch_versions = Channel.empty()

    // get images channel for combine channels input
    ch_samplesheet.map {
            meta, alg_json, images, mosaic, detected_txs, vzg, metadata, entity_by_gene, boundaries, combine_settings ->
            [meta, detected_txs]
            [meta, images]
        }
        .set{ ch_images }

    // Prepare input for segmentation
    ch_samplesheet
        .map { meta, alg_json, images, mosaic, detected_txs, vzg, metadata, entity_by_gene, boundaries, combine_settings ->
            [meta, alg_json, images, mosaic, detected_txs, vzg] }
        .set{ ch_segmentation_input }

    if (combine_channels.value) {
        // Extract and parse combine channel settings
        ch_samplesheet
            .map { meta, alg_json, images, mosaic, detected_txs, vzg, metadata, entity_by_gene, boundaries, combine_settings ->
                combine_settings}
            .first()
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
                        'mosiac_' + merged_channel + '_z',
                        z_index, tile_size, mpp]
            }
            .set{ ch_combine_settings }

        //
        // MODULE: Run combine_channels script
        //
        COMBINECHANNELS(
            ch_images,
            ch_combine_settings,
            ch_images.map { meta, images -> images }
        )

        //
        // MODULE: Run vpt prepare-segmentation
        //
        PREPARE_SEGMENTATION (
            ch_segmentation_input,
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
            ch_segmentation_input,
            tile_size,
            tile_overlap,
            true
        )
    }

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
        .set{ ch_tile_segments }

    //
    // MODULE: Run vpt run-segmentation-on-tile
    //
    RUN_SEGMENTATION_ON_TILE(
        ch_tile_segments
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
        COMPILE_TILE_SEGMENTATION.out.micron_space
    )

    // Extract detected transcripts from samplesheet
    ch_samplesheet
        .map { meta, alg_json, images, mosaic, detected_txs, vzg, metadata, entity_by_gene, boundaries, combine_settings ->
            detected_txs }
        .set{ ch_detected_txs }

    // Combine detected transcripts with micron space file
    // to create input for partition-transcripts step
    COMPILE_TILE_SEGMENTATION.out.micron_space
        .combine(ch_detected_txs)
        .set{ ch_partition_txs_input }

    //
    // MODULE: Run vpt partition-transcripts
    //
    PARTITION_TRANSCRIPTS(
        ch_partition_txs_input
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
        // Put together input for update-vzg
        ch_samplesheet.map {
                meta, alg_json, images, mosaic, detected_txs, vzg, metadata, entity_by_gene, boundaries, combine_settings ->
                [meta, vzg]
            }
            .join(ch_segmentation_output)
            .join(ch_entity_by_gene)
            .join(ch_entity_metadata)
            .flatten()
            .toList()
            .set{ ch_update_vzg_input }

        //
        // MODULE: Run vpt update-vzg
        //
        UPDATE_VZG(
            ch_update_vzg_input
        )

        ch_vzg = UPDATE_VZG.out.vzg_file
    }

    // get transcripts channel for downstream output
    ch_samplesheet.map {
            meta, alg_json, images, mosaic, detected_txs, vzg, metadata, entity_by_gene, boundaries, combine_settings ->
            [meta, detected_txs]
        }
        .set{ ch_transcripts }

    // get micron_to_mosaic channel for downstream output
    ch_samplesheet.map {
            meta, alg_json, images, mosaic, detected_txs, vzg, metadata, entity_by_gene, boundaries, combine_settings ->
            [meta, mosaic]
        }
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

