process COMBINECHANNELS {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://mcmero/tifftools:aicsimageio_dask_tifffile_xmlschema--9aaffd8b5252c207': 'docker.io/mcmero/tifftools:aicsimageio_dask_tifffile_xmlschema--9aaffd8b5252c207' }"

    input:
    tuple val(meta), path(images)
    val(channels_to_combine)
    val(combined_channel)
    val(zindex)
    val(combine_tile_size)
    val(microns_per_pixel)

    output:
    tuple val(meta), path("*.tif"), emit: tif
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    combine_channels.py \\
        $args \\
        --images $images \\
        --channels $channels_to_combine \\
        --name $combined_channel \\
        --zindex $zindex \\
        --tile-size $combine_tile_size \\
        --microns-per-pixel $microns_per_pixel \\
        --outdir .

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | grep -E -o \"([0-9]{1,}\\.)+[0-9]{1,}\")
        dask: \$(python -c 'import dask; print(dask.__version__)')
        aicsimageio: \$(python -c 'import aicsimageio; print(aicsimageio.__version__)')
        tifffile: \$(python -c 'import tifffile; print(tifffile.__version__)')
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${combined_channel}${zindex}.tif

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | grep -E -o \"([0-9]{1,}\\.)+[0-9]{1,}\")
        dask: \$(python -c 'import dask; print(dask.__version__)')
        aicsimageio: \$(python -c 'import aicsimageio; print(aicsimageio.__version__)')
        tifffile: \$(python -c 'import tifffile; print(tifffile.__version__)')
    END_VERSIONS
    """
}