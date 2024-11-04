#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    WEHI-SODA-Hub/spatialvpt
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/WEHI-SODA-Hub/spatialvpt
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { SPATIALVPT  } from './workflows/spatialvpt'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_spatialvpt_pipeline'
include { PIPELINE_COMPLETION     } from './subworkflows/local/utils_nfcore_spatialvpt_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run main analysis pipeline depending on type of input
//
workflow WEHISODAHUB_SPATIALVPT {

    take:
    sample
    algorithm_json
    images_dir
    um_to_mosaic_file
    update_vzg
    input_vzg
    tile_size
    tile_overlap
    report_only
    detected_transcripts
    metadata
    entity_by_gene
    boundaries
    combine_channels
    combine_channel_settings

    main:

    //
    // WORKFLOW: Run pipeline
    //
    SPATIALVPT (
        sample,
        algorithm_json,
        images_dir,
        um_to_mosaic_file,
        update_vzg,
        input_vzg,
        tile_size,
        tile_overlap,
        report_only,
        detected_transcripts,
        metadata,
        entity_by_gene,
        boundaries,
        combine_channels,
        combine_channel_settings
    )

    emit:
    report          = SPATIALVPT.out.report
    versions        = SPATIALVPT.out.versions

}
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:

    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION (
        params.version,
        params.help,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.sample,
        params.algorithm_json,
        params.images_dir,
        params.um_to_mosaic_file,
        params.update_vzg,
        params.input_vzg,
        params.tile_size,
        params.tile_overlap,
        params.report_only,
        params.detected_transcripts,
        params.metadata,
        params.entity_by_gene,
        params.boundaries,
        params.combine_channels,
        params.combine_channel_settings
    )

    //
    // WORKFLOW: Run main workflow
    //
    WEHISODAHUB_SPATIALVPT (
        PIPELINE_INITIALISATION.out.sample,
        PIPELINE_INITIALISATION.out.algorithm_json,
        PIPELINE_INITIALISATION.out.images_dir,
        PIPELINE_INITIALISATION.out.um_to_mosaic_file,
        PIPELINE_INITIALISATION.out.update_vzg,
        PIPELINE_INITIALISATION.out.input_vzg,
        PIPELINE_INITIALISATION.out.tile_size,
        PIPELINE_INITIALISATION.out.tile_overlap,
        PIPELINE_INITIALISATION.out.report_only,
        PIPELINE_INITIALISATION.out.detected_transcripts,
        PIPELINE_INITIALISATION.out.metadata,
        PIPELINE_INITIALISATION.out.entity_by_gene,
        PIPELINE_INITIALISATION.out.boundaries,
        PIPELINE_INITIALISATION.out.combine_channels,
        PIPELINE_INITIALISATION.out.combine_channel_settings
    )

    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION (
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
        params.hook_url
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
