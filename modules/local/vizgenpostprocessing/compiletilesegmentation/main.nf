process VIZGENPOSTPROCESSING_COMPILETILESEGMENTATION {
    tag "$meta.id"
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://ghcr.io/wehi-soda-hub/vizgen-postprocessing_container:v0.1.0' :
        'ghcr.io/wehi-soda-hub/vizgen-postprocessing_container:v0.1.0' }"

    input:
    tuple val(meta), path(images), path(segmentation_spec)
    path(algorithm_json)
    path(segmentation_tiles)

    output:
    path("${prefix}/*_mosaic_space.parquet"), emit: mosaic_space
    path("${prefix}/*_micron_space.parquet"), emit: micron_space
    path  "versions.yml"          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error "VIZGENPOSTPROCESSING is unavailable via Conda. Please use Docker / Singularity / Apptainer / Podman instead."
    }
    def args = task.ext.args ?: ''
    prefix   = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p ${prefix}/result_tiles
    for segment in ${segmentation_tiles}; do
        cp -d \$segment ${prefix}/result_tiles
    done

    vpt --verbose \\
        compile-tile-segmentation \\
        $args \\
        --input-segmentation-parameters $segmentation_spec

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        vpt: \$( pip show vpt | grep Version | sed -e "s/Version: //g" )
        vpt-plugin-cellpose2: \$( pip show vpt-plugin-cellpose2 | grep Version | sed -e "s/Version: //g" )
    END_VERSIONS
    """
}
