process VPT_GENERATESEGMENTATIONMETRICS {
    tag "$meta.id"
    label 'process_medium'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://ghcr.io/bioimageanalysiscorewehi/vizgen-postprocessing_container:main' :
        'ghcr.io/bioimageanalysiscorewehi/vizgen-postprocessing_container:main' }"

    input:
    tuple val(meta), path(entity_by_gene), path(metadata), path(transcripts), path(images), path(boundaries), path(micron_to_mosaic)

    output:
    tuple val(meta), path("*.html"), emit: report
    tuple val(meta), path("*.csv"),  emit: metrics
    path "versions.yml"           ,  emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error "VPT is unavailable via Conda. Please use Docker / Singularity / Apptainer / Podman instead."
    }
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    vpt --verbose \\
        generate-segmentation-metrics \\
        $args \\
        --input-entity-by-gene $entity_by_gene \\
        --input-metadata $metadata \\
        --input-transcripts $transcripts \\
        --input-images $images \\
        --input-boundaries $boundaries \\
        --input-micron-to-mosaic $micron_to_mosaic \\
        --output-csv ${prefix}_metrics.csv \\
        --output-report ${prefix}_metrics.html

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        vpt: \$( pip show vpt | grep Version | sed -e "s/Version: //g" )
        vpt-plugin-cellpose2: \$( pip show vpt-plugin-cellpose2 | grep Version | sed -e "s/Version: //g" )
    END_VERSION
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_metrics.csv
    touch ${prefix}_metrics.html

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        vpt: \$( pip show vpt | grep Version | sed -e "s/Version: //g" )
        vpt-plugin-cellpose2: \$( pip show vpt-plugin-cellpose2 | grep Version | sed -e "s/Version: //g" )
    END_VERSION
    """
}
