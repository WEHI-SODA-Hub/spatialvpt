process RUN_SEGMENTATION_ON_TILE {
    tag "$meta.id"
    label 'process_medium'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://ghcr.io/wehi-soda-hub/vizgen-postprocessing_container:main' :
        'ghcr.io/wehi-soda-hub/vizgen-postprocessing_container:main' }"

    input:
    tuple val(meta), path(segmentation_spec), path(input_images), path(algorithm_json), val(tile_index)

    output:
    tuple val(meta), path("result_tiles/*.parquet"), emit: segmented_tile
    path  "versions.yml"          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error "VPT is unavailable via Conda. Please use Docker / Singularity / Apptainer / Podman instead."
    }
    def args = task.ext.args ?: ''
    """
    vpt --verbose \\
        run-segmentation-on-tile \\
        $args \\
        --input-segmentation-parameters $segmentation_spec \\
        --tile-index $tile_index

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        vpt: \$( pip show vpt | grep Version | sed -e "s/Version: //g" )
        vpt-plugin-cellpose2: \$( pip show vpt-plugin-cellpose2 | grep Version | sed -e "s/Version: //g" )
    END_VERSION
    """
}
