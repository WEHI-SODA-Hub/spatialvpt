//
// Subworkflow with functionality specific to the WEHI-SODA-Hub/spatialvpt pipeline
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { UTILS_NFVALIDATION_PLUGIN } from '../../nf-core/utils_nfvalidation_plugin'
include { paramsSummaryMap          } from 'plugin/nf-validation'
include { fromSamplesheet           } from 'plugin/nf-validation'
include { UTILS_NEXTFLOW_PIPELINE   } from '../../nf-core/utils_nextflow_pipeline'
include { completionEmail           } from '../../nf-core/utils_nfcore_pipeline'
include { completionSummary         } from '../../nf-core/utils_nfcore_pipeline'
include { dashedLine                } from '../../nf-core/utils_nfcore_pipeline'
include { nfCoreLogo                } from '../../nf-core/utils_nfcore_pipeline'
include { imNotification            } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NFCORE_PIPELINE     } from '../../nf-core/utils_nfcore_pipeline'
include { workflowCitation          } from '../../nf-core/utils_nfcore_pipeline'

/*
========================================================================================
    SUBWORKFLOW TO INITIALISE PIPELINE
========================================================================================
*/

workflow PIPELINE_INITIALISATION {

    take:
    version           // boolean: Display version and exit
    help              // boolean: Display help text
    validate_params   // boolean: Boolean whether to validate parameters against the schema at runtime
    monochrome_logs   // boolean: Do not use coloured log outputs
    nextflow_cli_args //   array: List of positional nextflow CLI args
    outdir            //  string: The output directory where the results will be saved
    sample            //  string: Sample name
    algorithm_json    //  string: Path to algorithm JSON file
    images_dir        //  string: Directory containing image files
    um_to_mosaic_file //  string: Path to micron to mosaic file
    detected_transcripts // string: Path to detected transcripts file
    custom_weights    //  string: Path to file containing custom weights (optional)
    update_vzg        // boolean: Whether to create an updated VZG file after segmentation
    input_vzg         //  string: Path to VZG file for MERSCOPE visualisation
    tile_size         // integer: Pixels tile width and height
    tile_overlap      // integer: Overlap between adjacent tiles
    report_only       // boolean: Whether to run vpt generate-segmentation-metrics only on already segmented data
    metadata          //  string: Path to metadata file (optional, only required for report_only mode)
    entity_by_gene    //  string: Path to entity_by_gene file (optional, only required for report_only mode)
    boundaries        //  string: Path to parquet boundaries file (optional, onle required for report_only mode)
    combine_channels  // boolean: Whether to combine channels; requires settings to be specified in sample sheet
    combine_channel_settings // string: Settings to combine channels

    main:

    ch_versions = Channel.empty()

    //
    // Print version and exit if required and dump pipeline parameters to JSON file
    //
    UTILS_NEXTFLOW_PIPELINE (
        version,
        true,
        outdir,
        workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1
    )

    //
    // Validate parameters and generate parameter summary to stdout
    //
    pre_help_text = nfCoreLogo(monochrome_logs)
    post_help_text = '\n' + workflowCitation() + '\n' + dashedLine(monochrome_logs)
    def String workflow_command = "nextflow run ${workflow.manifest.name} -profile <docker/singularity/.../institute> --input samplesheet.csv --outdir <OUTDIR>"
    UTILS_NFVALIDATION_PLUGIN (
        help,
        workflow_command,
        pre_help_text,
        post_help_text,
        validate_params,
        "nextflow_schema.json"
    )

    //
    // Check config provided to the pipeline
    //
    UTILS_NFCORE_PIPELINE (
        nextflow_cli_args
    )

    // Create channels from file inputs
    ch_alg_json  = Channel.fromPath(algorithm_json, checkIfExists: true)
    ch_input_vzg = Channel.fromPath(input_vzg, checkIfExists: true)
    ch_images    = Channel.fromPath(images_dir, checkIfExists: true)
    ch_mosaic    = Channel.fromPath(um_to_mosaic_file, checkIfExists: true)
    ch_txs       = Channel.fromPath(detected_transcripts, checkIfExists: true)

    // These channels are only required if running in report_only mode
    ch_metadata  = Channel.empty()
    ch_ebgene    = Channel.empty()
    ch_bound     = Channel.empty()

    if (report_only.value) {
        ch_metadata = Channel.fromPath(metadata, checkIfExists: true)
        ch_ebgene   = Channel.fromPath(entity_by_gene, checkIfExists: true)
        ch_bound    = Channel.fromPath(boundaries, checkIfExists: true)
    }

    // Use blank file definition for custom weights unless custom_weights
    // is defined in config, in which case construct a path channel
    ch_weights = Channel.fromPath('.')
    if (custom_weights != null && custom_weights != '') {
        ch_weights = Channel.fromPath(custom_weights, checkIfExists: true)
    }

    if (!tile_size.toString().isInteger()) {
        error "The tile_size parameter is not a valid integer"
    }
    if (!tile_overlap.toString().isInteger()) {
        error "The tile_size parameter is not a valid integer"
    }

    emit:
    sample                   = sample
    algorithm_json           = ch_alg_json
    images_dir               = ch_images
    um_to_mosaic_file        = ch_mosaic
    detected_transcripts     = ch_txs
    custom_weights           = ch_weights
    update_vzg               = update_vzg
    input_vzg                = ch_input_vzg
    tile_size                = tile_size
    tile_overlap             = tile_overlap
    report_only              = report_only
    metadata                 = ch_metadata
    entity_by_gene           = ch_ebgene
    boundaries               = ch_bound
    combine_channels         = combine_channels
    combine_channel_settings = combine_channel_settings
    versions                 = ch_versions
}

/*
========================================================================================
    SUBWORKFLOW FOR PIPELINE COMPLETION
========================================================================================
*/

workflow PIPELINE_COMPLETION {

    take:
    email           //  string: email address
    email_on_fail   //  string: email address sent on pipeline failure
    plaintext_email // boolean: Send plain-text email instead of HTML
    outdir          //    path: Path to output directory where results will be published
    monochrome_logs // boolean: Disable ANSI colour codes in log output
    hook_url        //  string: hook URL for notifications

    main:

    summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")

    //
    // Completion email and summary
    //
    workflow.onComplete {
        if (email || email_on_fail) {
            completionEmail(summary_params, email, email_on_fail, plaintext_email, outdir, monochrome_logs)
        }

        completionSummary(monochrome_logs)

        if (hook_url) {
            imNotification(summary_params, hook_url)
        }
    }

    workflow.onError {
        log.error "Pipeline failed. Please refer to troubleshooting docs: https://nf-co.re/docs/usage/troubleshooting"
    }
}

/*
========================================================================================
    FUNCTIONS
========================================================================================
*/

//
// Validate channels from input samplesheet
//
def validateInputSamplesheet(input) {
    // TODO: add argument that handles regex for mosaic file
    def (meta, algorithm, images, mosaic_file, detected_txs, vzg, metadata, entity_by_gene, boundaries, combine_settings) = input
    if (meta.size() != 1) {
        error("Only one sample can be processed via the pipeline. Please check your samplesheet")
    }
    return input
}

//
// Generate methods description for MultiQC
//
def toolCitationText() {
    // TODO nf-core: Optionally add in-text citation tools to this list.
    // Can use ternary operators to dynamically construct based conditions, e.g. params["run_xyz"] ? "Tool (Foo et al. 2023)" : "",
    // Uncomment function in methodsDescriptionText to render in MultiQC report
    def citation_text = [
            "Tools used in the workflow included:",
            "Vizgen Postprocessing Tool",
            "."
        ].join(' ').trim()

    return citation_text
}

def toolBibliographyText() {
    // TODO nf-core: Optionally add bibliographic entries to this list.
    // Can use ternary operators to dynamically construct based conditions, e.g. params["run_xyz"] ? "<li>Author (2023) Pub name, Journal, DOI</li>" : "",
    // Uncomment function in methodsDescriptionText to render in MultiQC report
    def reference_text = [
        ].join(' ').trim()

    return reference_text
}

def methodsDescriptionText(mqc_methods_yaml) {
    // Convert  to a named map so can be used as with familar NXF ${workflow} variable syntax in the MultiQC YML file
    def meta = [:]
    meta.workflow = workflow.toMap()
    meta["manifest_map"] = workflow.manifest.toMap()

    // Pipeline DOI
    if (meta.manifest_map.doi) {
        // Using a loop to handle multiple DOIs
        // Removing `https://doi.org/` to handle pipelines using DOIs vs DOI resolvers
        // Removing ` ` since the manifest.doi is a string and not a proper list
        def temp_doi_ref = ""
        String[] manifest_doi = meta.manifest_map.doi.tokenize(",")
        for (String doi_ref: manifest_doi) temp_doi_ref += "(doi: <a href=\'https://doi.org/${doi_ref.replace("https://doi.org/", "").replace(" ", "")}\'>${doi_ref.replace("https://doi.org/", "").replace(" ", "")}</a>), "
        meta["doi_text"] = temp_doi_ref.substring(0, temp_doi_ref.length() - 2)
    } else meta["doi_text"] = ""
    meta["nodoi_text"] = meta.manifest_map.doi ? "" : "<li>If available, make sure to update the text to include the Zenodo DOI of version of the pipeline used. </li>"

    // Tool references
    meta["tool_citations"] = ""
    meta["tool_bibliography"] = ""

    // TODO nf-core: Only uncomment below if logic in toolCitationText/toolBibliographyText has been filled!
    // meta["tool_citations"] = toolCitationText().replaceAll(", \\.", ".").replaceAll("\\. \\.", ".").replaceAll(", \\.", ".")
    // meta["tool_bibliography"] = toolBibliographyText()


    def methods_text = mqc_methods_yaml.text

    def engine =  new groovy.text.SimpleTemplateEngine()
    def description_html = engine.createTemplate(methods_text).make(meta)

    return description_html.toString()
}
