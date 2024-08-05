process COMPILE_TILE_SEGMENTATION {
    tag "$meta.id"
    label 'process_large'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://ghcr.io/bioimageanalysiscorewehi/vizgen-postprocessing_container:main' :
        'ghcr.io/bioimageanalysiscorewehi/vizgen-postprocessing_container:main' }"

    input:
    tuple val(meta), path(segmentation_spec), path(images), path(algorithm_json)
    path(segmentation_tiles)

    output:
    tuple val(meta), path("*_space.parquet"), emit: segmented_tiles
    path  "versions.yml"          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    mkdir result_tiles
    for segment in ${segmentation_tiles}; do
        cp -d \$segment result_tiles
    done

    vpt --verbose \\
        compile-tile-segmentation \\
        $args \\
        --input-segmentation-parameters $segmentation_spec

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        vpt: \$( pip show vpt | grep Version | sed -e "s/Version: //g" )
        vpt-plugin-cellpose2: \$( pip show vpt-plugin-cellpose2 | grep Version | sed -e "s/Version: //g" )
    END_VERSION
    """
}
