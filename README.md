[![GitHub Actions CI Status](https://github.com/BioimageAnalysisCoreWEHI/szpatialsegmentation/actions/workflows/ci.yml/badge.svg)](https://github.com/BioimageAnalysisCoreWEHI/spatialvpt/actions/workflows/ci.yml)
[![GitHub Actions Linting Status](https://github.com/BioimageAnalysisCoreWEHI/spatialvpt/actions/workflows/linting.yml/badge.svg)](https://github.com/BioimageAnalysisCoreWEHI/spatialvpt/actions/workflows/linting.yml)[![Cite with Zenodo](http://img.shields.io/badge/DOI-10.5281/zenodo.XXXXXXX-1073c8?labelColor=000000)](https://doi.org/10.5281/zenodo.XXXXXXX)
[![nf-test](https://img.shields.io/badge/unit_tests-nf--test-337ab7.svg)](https://www.nf-test.com)

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A524.04.0-23aa62.svg)](https://www.nextflow.io/)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![Launch on Seqera Platform](https://img.shields.io/badge/Launch%20%F0%9F%9A%80-Seqera%20Platform-%234256e7)](https://cloud.seqera.io/launch?pipeline=https://github.com/BioimageAnalysisCoreWEHI/spatialvpt)

## Introduction

**BioimageAnalysisCoreWEHI/spatialvpt** is a bioinformatics pipeline that performs cell segmentation and creates a QC report for MERSCOPE data using the vizgen-postprocessing tool.

<!-- TODO nf-core:
   Complete this sentence with a 2-3 sentence summary of what types of data the pipeline ingests, a brief overview of the
   major pipeline sections and the types of output it produces. You're giving an overview to someone new
   to nf-core here, in 15-20 seconds. For an example, see https://github.com/nf-core/rnaseq/blob/master/README.md#introduction
-->

<!-- TODO nf-core: Include a figure that guides the user through the major workflow steps. Many nf-core
     workflows use the "tube map" design for that. See https://nf-co.re/docs/contributing/design_guidelines#examples for examples.   -->
<!-- TODO nf-core: Fill in short bullet-pointed list of the default steps in the pipeline -->

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline) with `-profile test` before running the workflow on actual data.

First, prepare a samplesheet with your input data that looks as follows:

`samplesheet.yml`:

```yaml
- sample: "sample_name"
  algorithm_json: "/path/to/algorithm.json"
  images_dir: "/path/to/images"
  um_to_mosaic_file: "/path/to/micron_to_mosaic_pixel_transform.csv"
  detected_transcripts: "/path/to/detected_transcripts.csv"
  input_vzg: "/path/to/sample.vzg"
  metadata: "/path/to/entity_metadata.csv"
  entity_by_gene: "/path/to/entity_by_gene.csv"
  boundaries: "/path/to/segmentation.parquet"
```

The `metadata`, `entity_by_gene` and `boundaries` values are only required if running in `report_only` mode.

Note that the `algorithm_json` file is temperamental. Check the [Vizgen documentation](https://vizgen.github.io/vizgen-postprocessing/segmentation_options/json_file_format.html) on the requirements.

Currently, only one sample can be processed at one time.

To run cell segmentation via VPT, you can run the pipeline using:

```bash
nextflow run BioimageAnalysisCoreWEHI/spatialvpt \
   -profile <docker/singularity/.../institute> \
   --input samplesheet.yml \
   --outdir <OUTDIR> \
   --tile_size <tile_size> \
   --tile_overlap <tile_overlap>
```

If you are running with Apptainer or Singularity, you will have to set the following environmental variable before running the pipeline:

Apptainer:

```bash
export NXF_APPTAINER_HOME_MOUNT=true
nextflow run BioimageAnalysisCoreWEHI/spatialvpt \
   -profile apptainer \
   --input samplesheet.yml \
   --outdir <OUTDIR> \
   --tile_size <tile_size> \
   --tile_overlap <tile_overlap>
```

Singularity:

```bash
export NXF_SINGULARITY_HOME_MOUNT=true
nextflow run BioimageAnalysisCoreWEHI/spatialvpt \
   -profile singularity \
   --input samplesheet.yml \
   --outdir <OUTDIR> \
   --tile_size <tile_size> \
   --tile_overlap <tile_overlap>
```

If you would like to only generate a QC report, and you already have your metadata, cell_by_gene and boundary files, you can do so as follows:

```bash
nextflow run BioimageAnalysisCoreWEHI/spatialvpt \
   -profile <docker/singularity/.../institute> \
   --input samplesheet.yml \
   --outdir <OUTDIR> \
  --report_only true
```

> [!WARNING]
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_;
> see [docs](https://nf-co.re/usage/configuration#custom-configuration-files).

## Credits

BioimageAnalysisCoreWEHI/spatialvpt was originally written by Marek Cmero.

We thank the following people for their extensive assistance in the development of this pipeline:

<!-- TODO nf-core: If applicable, make list of people who have also contributed -->

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

## Citations

<!-- TODO nf-core: Add citation for pipeline after first release. Uncomment lines below and update Zenodo doi and badge at the top of this file. -->
<!-- If you use BioimageAnalysisCoreWEHI/spatialvpt for your analysis, please cite it using the following doi: [10.5281/zenodo.XXXXXX](https://doi.org/10.5281/zenodo.XXXXXX) -->

<!-- TODO nf-core: Add bibliography of tools and data used in your pipeline -->

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/master/LICENSE).

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
