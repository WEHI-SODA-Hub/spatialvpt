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

    //
    // MODULE: Run vpt partition-transcripts
    //
    VIZGENPOSTPROCESSING_PARTITIONTRANSCRIPTS(
        micron_space,
        detected_txs
    )

    // Output channels
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
            micron_space.map { meta, _micron_space -> meta },
            input_vzg,
            micron_space,
            ch_entity_by_gene,
            ch_entity_metadata
        )

        ch_vzg = VIZGENPOSTPROCESSING_UPDATEVZG.out.vzg_file
    }

    // get transcripts channel for downstream output
    micron_space
    .map { meta, _micron_space -> meta }.concat(detected_txs)
    .set{ ch_transcripts }

    emit:
    metadata       = ch_entity_metadata
    transcripts    = ch_transcripts
    vzg            = ch_vzg

    versions = ch_versions                     // channel: [ versions.yml ]
}
