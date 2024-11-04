process PREPARE_SEGMENTATION {
    tag "$meta.id"
    label 'process_small'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://ghcr.io/wehi-soda-hub/vizgen-postprocessing_container:main' :
        'ghcr.io/wehi-soda-hub/vizgen-postprocessing_container:main' }"

    input:
    val(meta)
    path(algorithm_json)
    path(input_images)
    path(um_to_mosaic_file)
    val(tile_size)
    val(tile_overlap)
    val(channel_merge_ready)

    output:
    tuple val(meta), path("*.json"), path(input_images), path(algorithm_json), emit: segmentation_files
    path  "versions.yml"          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error "VPT is unavailable via Conda. Please use Docker / Singularity / Apptainer / Podman instead."
    }
    def args = task.ext.args ?: ''
    """
    vpt --verbose \\
        prepare-segmentation \\
        $args \\
        --segmentation-algorithm $algorithm_json \\
        --input-images $input_images \\
        --input-micron-to-mosaic $um_to_mosaic_file \\
        --output-path . \\
        --tile-size $tile_size \\
        --tile-overlap $tile_overlap

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        vpt: \$( pip show vpt | grep Version | sed -e "s/Version: //g" )
        vpt-plugin-cellpose2: \$( pip show vpt-plugin-cellpose2 | grep Version | sed -e "s/Version: //g" )
    END_VERSION
    """
}
