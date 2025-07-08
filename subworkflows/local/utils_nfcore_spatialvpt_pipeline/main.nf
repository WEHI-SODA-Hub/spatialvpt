//
// Subworkflow with functionality specific to the WEHI-SODA-Hub/spatialvpt pipeline
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsHelp                } from 'plugin/nf-schema'
include { paramsSummaryMap          } from 'plugin/nf-schema'
include { UTILS_NFSCHEMA_PLUGIN     } from '../../nf-core/utils_nfschema_plugin'
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
    images_regex      //  string: Regex string for input images
    um_to_mosaic_file //  string: Path to micron to mosaic file
    detected_transcripts // string: Path to detected transcripts file
    custom_weights    //  string: Path to file containing custom weights (optional)
    update_vzg        // boolean: Whether to create an updated VZG file after segmentation
    input_vzg         //  string: Path to VZG file for MERSCOPE visualisation
    tile_size         // integer: Pixels tile width and height
    tile_overlap      // integer: Overlap between adjacent tiles
    z_index           // integer: Z index used to generate patch for report
    red_stain_name    //  string: Name for red channel in report
    green_stain_name  //  string: Name for green channel in report
    blue_stain_name   //  string: Name for blue channel in report
    transcript_count_threshold // integer: Filter threshold for transript counts
    volume_filter_threshold // integer: Filter threshold for cell volume
    report_only       // boolean: Whether to run vpt generate-segmentation-metrics only on already segmented data
    metadata          //  string: Path to metadata file (optional, only required for report_only mode)
    entity_by_gene    //  string: Path to entity_by_gene file (optional, only required for report_only mode)
    boundaries        //  string: Path to parquet boundaries file (optional, only required for report_only mode)
    convert_geometry  // boolean: Whether to convert geometries instead of running vpt's segmentation
    boundary_dir      //  string: Directory containing boundary files (optional, only required for convert_geometry mode)
    boundary_regex    //  string: Regex for boundary files (optional, only required for convert_geometry mode)

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
    // Print help text and exit if required
    //
    pre_help_text = nfCoreLogo(monochrome_logs)
    post_help_text = '\n' + workflowCitation() + '\n' + dashedLine(monochrome_logs)

    if (params.help) {
        def String workflow_command = "nextflow run ${workflow.manifest.name} -profile <docker/singularity/.../institute> -params-file params.yml --outdir <OUTDIR>"

        log.info pre_help_text + paramsHelp(workflow_command) + post_help_text
        exit 0
    } else {
        log.info pre_help_text + post_help_text
    }

    //
    // Validate parameters and generate parameter summary to stdout
    //
    UTILS_NFSCHEMA_PLUGIN (
        workflow,
        validate_params,
        "${projectDir}/nextflow_schema.json"
    )

    //
    // Check config provided to the pipeline
    //
    UTILS_NFCORE_PIPELINE (
        nextflow_cli_args
    )

    // Create channels from file inputs
    ch_alg_json  = Channel.fromPath(algorithm_json, checkIfExists: true)
    ch_input_vzg = Channel.fromPath(input_vzg, checkIfExists: false)
    ch_images    = Channel.fromPath(images_dir, checkIfExists: true)
    ch_mosaic    = Channel.fromPath(um_to_mosaic_file, checkIfExists: true)
    ch_txs       = Channel.fromPath(detected_transcripts, checkIfExists: true)

    // Construct channel from image regex
    ch_images_regex = Channel.of(images_regex)

    // These channels are only required if running in report_only mode
    ch_metadata  = Channel.empty()
    ch_ebgene    = Channel.empty()
    ch_bound     = Channel.empty()

    if (report_only.value) {
        ch_metadata = Channel.fromPath(metadata, checkIfExists: true)
        ch_ebgene   = Channel.fromPath(entity_by_gene, checkIfExists: true)
        ch_bound    = Channel.fromPath(boundaries, checkIfExists: true)
    }

    // This channel is only required if running in convert_geometry mode
    ch_boundaries = Channel.empty()

    if (convert_geometry.value) {
        ch_boundaries = Channel.fromPath(boundary_dir, checkIfExists: true)
    }

    // Use blank file definition for custom weights unless custom_weights
    // is defined in config, in which case construct a path channel
    ch_weights = Channel.fromPath('.')
    if (custom_weights != null && custom_weights != '') {
        ch_weights = Channel.fromPath(custom_weights, checkIfExists: true)
    }

    // Validate parameters
    if (params.input != null && params.input != '') {
        error "The input parameter is not supported. Please use -params-file instead."
    }
    if (!transcript_count_threshold.toString().isInteger() &&
        transcript_count_threshold > 0) {
        error "The transcript_count_threshold parameter is not a valid positive integer"
    }

    if (!volume_filter_threshold.toString().isInteger() &&
        volume_filter_threshold > 0) {
        error "The volume_filter_threshold parameter is not a valid positive integer"
    }

    if (!tile_size.toString().isInteger() &&
        tile_size > 0) {
        error "The tile_size parameter is not a valid positive integer"
    }
    if (!tile_overlap.toString().isInteger() &&
        tile_overlap > 0) {
        error "The tile_size parameter is not a valid positive integer"
    }

    emit:
    sample                     = sample
    algorithm_json             = ch_alg_json
    images_dir                 = ch_images
    images_regex               = ch_images_regex
    um_to_mosaic_file          = ch_mosaic
    detected_transcripts       = ch_txs
    custom_weights             = ch_weights
    update_vzg                 = update_vzg
    input_vzg                  = ch_input_vzg
    tile_size                  = tile_size
    tile_overlap               = tile_overlap
    z_index                    = z_index
    red_stain_name             = red_stain_name
    green_stain_name           = green_stain_name
    blue_stain_name            = blue_stain_name
    transcript_count_threshold = transcript_count_threshold
    volume_filter_threshold    = volume_filter_threshold
    report_only                = report_only
    metadata                   = ch_metadata
    entity_by_gene             = ch_ebgene
    boundaries                 = ch_bound
    convert_geometry           = convert_geometry
    boundary_dir               = ch_boundaries
    boundary_regex             = boundary_regex
    versions                   = ch_versions
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
