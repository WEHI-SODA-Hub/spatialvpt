include { VIZGENPOSTPROCESSING_PARTITIONTRANSCRIPTS    } from '../../../modules/local/vizgenpostprocessing/partitiontranscripts/main'
include { VIZGENPOSTPROCESSING_DERIVEENTITYMETADATA    } from '../../../modules/local/vizgenpostprocessing/deriveentitymetadata/main'
include { VIZGENPOSTPROCESSING_UPDATEVZG               } from '../../../modules/local/vizgenpostprocessing/updatevzg/main'

workflow VPTUPDATEMETA {

    take:
    micron_space
    detected_txs
    update_vzg
    input_vzg

    main:

    ch_versions = Channel.empty()

    //
    // MODULE: Run vpt derive-entity-metadata
    //
    VIZGENPOSTPROCESSING_DERIVEENTITYMETADATA(
        micron_space
    )
    ch_versions = ch_versions.mix(
        VIZGENPOSTPROCESSING_DERIVEENTITYMETADATA.out.versions
    )

    //
    // MODULE: Run vpt partition-transcripts
    //
    VIZGENPOSTPROCESSING_PARTITIONTRANSCRIPTS(
        micron_space,
        detected_txs
    )
    ch_versions = ch_versions.mix(
        VIZGENPOSTPROCESSING_PARTITIONTRANSCRIPTS.out.versions
    )

    // Output channels
    ch_entity_metadata =
        VIZGENPOSTPROCESSING_DERIVEENTITYMETADATA.out.entity_metadata

    ch_entity_by_gene =
        VIZGENPOSTPROCESSING_PARTITIONTRANSCRIPTS.out.transcripts

    ch_vzg = Channel.empty()
    if (update_vzg.value) {
        micron_space
            .map { meta, _micron_space -> meta }
            .join(input_vzg)
            .set { ch_input_vzg }

        micron_space
            .map { _meta, ms -> ms }
            .set { ch_micron_space_only }

        //
        // MODULE: Run vpt update-vzg
        //
        VIZGENPOSTPROCESSING_UPDATEVZG(
            ch_input_vzg,
            ch_micron_space_only,
            ch_entity_by_gene,
            ch_entity_metadata
        )

        ch_versions = ch_versions.mix(
            VIZGENPOSTPROCESSING_UPDATEVZG.out.versions
        )

        ch_vzg = VIZGENPOSTPROCESSING_UPDATEVZG.out.vzg_file
    }

    // get transcripts channel for downstream output
    micron_space
    .map { meta, _micron_space -> [meta, detected_txs] }
    .set{ ch_transcripts }

    emit:
    metadata       = ch_entity_metadata
    transcripts    = ch_transcripts
    vzg            = ch_vzg
    input_vzg      = input_vzg
    micron_space   = micron_space

    versions = ch_versions                     // channel: [ versions.yml ]
}
