/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { VPTSEGMENTATION } from '../subworkflows/local/vptsegmentation'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow SPATIALSEGMENTATION {

    take:
    ch_samplesheet // channel: samplesheet read in from --input
    tile_size
    tile_overlap
    update_vzg

    main:

    VPTSEGMENTATION(
        ch_samplesheet,
        tile_size,
        tile_overlap,
        update_vzg
    )

    emit:
    segmentation   = VPTSEGMENTATION.out.segmentation
    metadata       = VPTSEGMENTATION.out.metadata
    entity_by_gene = VPTSEGMENTATION.out.entity_by_gene
    vzg            = VPTSEGMENTATION.out.vzg
    versions       = VPTSEGMENTATION.out.versions        // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
