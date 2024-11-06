process PARTITION_TRANSCRIPTS {
    tag "$meta.id"
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://ghcr.io/wehi-soda-hub/vizgen-postprocessing_container:main' :
        'ghcr.io/wehi-soda-hub/vizgen-postprocessing_container:main' }"

    input:
    val(meta)
    path(micron_space)
    path(input_transcripts)

    output:
    path("*.csv"), emit: transcripts
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
        partition-transcripts \\
        $args \\
        --input-boundaries $micron_space \\
        --input-transcripts $input_transcripts \\
        --output-entity-by-gene cell_by_gene_repartitioned.csv \\
        --output-transcripts cell_by_gene_repartitioned.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        vpt: \$( pip show vpt | grep Version | sed -e "s/Version: //g" )
        vpt-plugin-cellpose2: \$( pip show vpt-plugin-cellpose2 | grep Version | sed -e "s/Version: //g" )
    END_VERSION
    """
}
