process UPDATE_VZG {
    tag "$meta.id"
    label 'process_large'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://ghcr.io/wehi-soda-hub/vizgen-postprocessing_container:main' :
        'ghcr.io/wehi-soda-hub/vizgen-postprocessing_container:main' }"

    input:
    tuple val(meta), path(input_vzg), path(micron_space), path(entity_by_gene), path(metadata)

    output:
    tuple val(meta), path("*.vzg"), emit: vzg_file
    path  "versions.yml"          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error "VPT is unavailable via Conda. Please use Docker / Singularity / Apptainer / Podman instead."
    }
    def args = task.ext.args ?: ''
    def vzg_name = input_vzg.getSimpleName()
    """
    vpt --verbose \\
        update-vzg \\
        $args \\
        --input-boundaries $micron_space \\
        --input-entity-by-gene $entity_by_gene \\
        --input-metadata $metadata \\
        --input-vzg $input_vzg \\
        --output-vzg ${vzg_name}_resegmented.vzg

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        vpt: \$( pip show vpt | grep Version | sed -e "s/Version: //g" )
        vpt-plugin-cellpose2: \$( pip show vpt-plugin-cellpose2 | grep Version | sed -e "s/Version: //g" )
    END_VERSION
    """
}
