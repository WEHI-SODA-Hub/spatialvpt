process VIZGENPOSTPROCESSING_DERIVEENTITYMETADATA {
    tag "$meta.id"
    label 'process_medium'

    container 'nf-core/vizgen-postprocessing_container:v0.1.1'

    input:
    tuple val(meta), path(micron_space)

    output:
    path("*.csv"), emit: entity_metadata
    path  "versions.yml"          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error "VIZGENPOSTPROCESSING is unavailable via Conda. Please use Docker / Singularity / Apptainer / Podman instead."
    }
    def args = task.ext.args ?: ''
    """
    vpt --verbose \\
        derive-entity-metadata \\
        $args \\
        --input-boundaries $micron_space \\
        --output-metadata cell_metadata_resegmented.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        vpt: \$( pip show vpt | grep Version | sed -e "s/Version: //g" )
        vpt-plugin-cellpose2: \$( pip show vpt-plugin-cellpose2 | grep Version | sed -e "s/Version: //g" )
    END_VERSIONS
    """
}
