process VPT_GENERATESEGMENTATIONMETRICS {
    tag "$meta.id"
    label 'process_medium'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://ghcr.io/wehi-soda-hub/vizgen-postprocessing_container:v0.1.0' :
        'ghcr.io/wehi-soda-hub/vizgen-postprocessing_container:v0.1.0' }"

    input:
    val(meta)
    path(entity_by_gene)
    path(metadata)
    path(transcripts)
    path(images)
    path(boundaries)
    path(micron_to_mosaic)
    val(red_stain_name)
    val(green_stain_name)
    val(blue_stain_name)
    val(transcript_count_threshold)
    val(volume_filter_threshold)

    output:
    path("*.html"),       emit: report
    path("*.csv"),        emit: metrics
    path "versions.yml",  emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error "VPT is unavailable via Conda. Please use Docker / Singularity / Apptainer / Podman instead."
    }
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def red_stain_param = red_stain_name ? "--red-stain-name ${red_stain_name}" : ''
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
        ${red_stain_param} \\
        --green-stain-name ${green_stain_name} \\
        --blue-stain-name ${blue_stain_name} \\
        --transcript-count-filter-threshold ${transcript_count_threshold} \\
        --volume-filter-threshold ${volume_filter_threshold} \\
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
