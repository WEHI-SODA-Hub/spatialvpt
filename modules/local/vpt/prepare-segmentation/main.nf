process PREPARE_SEGMENTATION {
    tag "$meta.id"
    label 'process_small'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://ghcr.io/bioimageanalysiscorewehi/vizgen-postprocessing_container:main' :
        'ghcr.io/bioimageanalysiscorewehi/vizgen-postprocessing_container:main' }"

    input:
    tuple val(meta), path(algorithm_json), path(input_images), path(um_to_mosaic_file)
    val(tile_size)
    val(tile_overlap)

    output:
    tuple val(meta), path("*.json"), emit: specification_json
    path  "versions.yml"          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
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
