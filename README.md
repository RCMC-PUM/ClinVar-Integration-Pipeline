# CVI: ClinVar Integration Pipeline


## Overview
This Nextflow pipeline automates the process of filtering, annotating, and interpreting clinically relevant variants using ClinVar and user-provided data. Currently, it supports `small_variant`, `repeats`, `cnv`, `sv`, and `ploidy` callers from the Illumina DRAGEN pipeline.


## Prerequisites
- [Nextflow](https://www.nextflow.io/)
- [Docker](https://www.docker.com/) 


## Parameters
| Parameter | Description |
|-----------|-------------|
| `--sample_sheet` | Path to the sample sheet |
| `--output_dir` | Directory for storing results |
| `--clinical_data` | Path to the clinical comma-separated data sheet (optional, enables AI interpretation) |
| `--clinical_significance` | Comma-separated filters for variant pathogenicity (default: `Pathogenic,Likely_pathogenic,...`) |
| `--clinical_review_status` | Comma-separated filters for clinical review status (default: `_multiple_submitters,...`) |
| `--genome_assembly` | Genome version (`hg19` or `hg38`), used to download the newest ClinVar annotations if `--annotations_file` is not provided |
| `--annotations_file` | Path to user-provided annotations VCF file (optional, but required if --genome_assembly is not provided) |
| `--rename_chrom_notation` | Convert chromosome notation if `true` (default: true) |
| `--variant_limit` | Maximum number of variants to process (default: 100) |


## Exemplary sample sheet CSV-file
File shoud contain **three** comma-separated columns including: `Sample_Name`: unique sample identifier, `Path`: comprising aboslute path to vcf file, as well as `Caller` type, either `small_variant`, `cnv`, `repeats`, `sv` or `ploidy`.

| Sample_Name | Path | Caller |
|-------------|------|--------|
| BB-0043 | BB-0043.sv.vcf.gz | sv |
| BB-0043 | BB-0043.hard-filtered.vcf.gz | small_variant |
| BB-0043 | BB-0043.cnv.vcf.gz | cnv |
| BB-0043 | BB-0043.ploidy.vcf.gz | ploidy |
| BB-0043 | BB-0043.repeats.vcf.gz | repeats |


## Exemplary clinical data CSV-file
File shoud contain **two** comma-separated columns `Sample_Name`, `Clinical_Description`.

| Sample_Name | Clinical_Description |
|-------------|------|
| BB-0043 | Abnormal facial shape; Abnormality of the ear; Behavioral abnormality |


## Filters
Parameters `--clinical_significance` and `--clinical_review_status` are design to work with `INFO/CLNSIG` and `INFO/CLNREVSTAT` fields respectively.
By default:

    - clinical_significance = 'Pathogenic,Likely_pathogenic,Pathogenic/Likely_pathogenic,Pathogenic|risk_factor'
    - clinical_review_status = '_multiple_submitters,criteria_provided,reviewed_by_expert_panel'


## Secrets
The pipeline requires the following secrets:

- **NCBI_API_KEY**: Needed to access NCBI services for MedGen concepts extractions.
- **OPENAI_KEY**: Required if `--clinical_data` is provided, enabling AI-assisted interpretation of identified variants.

Secrets can be defined in Nextflow using:
```sh
nextflow secrets set NCBI_API_KEY <your_api_key>
nextflow secrets set OPENAI_KEY <your_api_key>
```


## Annotation Source Selection
Users have two options for providing ClinVar annotations:
1. **Use a custom VCF annotation file** by specifying `--annotations_file <path>`.
2. **Download the latest ClinVar annotations** by specifying `--genome_assembly hg19` or `--genome_assembly hg38`. The pipeline will fetch the latest ClinVar VCF file corresponding to the chosen genome version.


## Running the Pipeline
To display help page:
```sh
nextflow run main.nf -- help
```

To start exemplary analysis:
```sh
nextflow run main.nf --sample_sheet samples.csv --output_dir results --genome_assembly hg38 --clinical_data clinical.csv --annotations_file annotations.vcf.gz
```


## Output structure
```
output_dir/
├── samples/
│   ├── {sample_name}/
│   │   ├── raw/                # VCF files comprising passing filters variants
│   │   ├── annotated_raw/      # Annotated VCF files
│   │   ├── annotated_filtered/ # Filtered annotated VCFs comprising only clinically relevant variants
│   │   ├── variants/           # Extracted variants in JSON format
│   │   ├── interpretation.json # AI-assisted interpretation (if enabled)
│   │   ├── report.html         # Final clinical report
│   ├── params.json             # Workflow parameters
│   ├── annots_params.json      # Annotation metadata
```
