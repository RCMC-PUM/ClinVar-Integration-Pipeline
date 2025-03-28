# CVI: ClinVar Integration Pipeline


## Overview
This Nextflow pipeline automates the process of filtering, annotating, and interpreting clinically relevant variants using ClinVar and user-provided data. Currently, it supports `small_variant`, `repeats`, `cnv`, `sv`, and `ploidy` callers from the Illumina DRAGEN pipeline.


## Prerequisites
- [Nextflow](https://www.nextflow.io/)
- [Docker](https://www.docker.com/) 


## Parameters
```
Typical pipeline command:

  nextflow run main.nf --sample_sheet sample_sheet.csv --output_dir test/ --clinical_data clinical.csv --assistant=true

--help                     [boolean, string] Show the help message for all top level parameters. When a parameter is given to `--help`, the full help message of that parameter will be printed. 
--helpFull                 [boolean]         Show the help message for all non-hidden parameters. 
--showHidden               [boolean]         Show all hidden parameters in the help message. This needs to be used in combination with `--help` or `--helpFull`. 

I/O
  --sample_sheet           [string] Input CSV file comprising: Sample_Name, Path and Caller fields.
  --output_dir             [string] Output directory.

Filters
  --clinical_review_status [string] Pathogenicity (comma-separated) level(s) [default: Pathogenic,Likely_pathogenic,Pathogenic/Likely_pathogenic,Pathogenic|risk_factor].
  --clinical_significance  [string] Clinical significance (comma-separated) level(s) [default: _multiple_submitters,criteria_provided,reviewed_by_expert_panel].

Annotations
  --genome_assembly        [string]  Genome assembly used to fetch appropriate ClinVar annotations  (accepted: hg19, hg38) [default: hg38].
  --annotations_file       [string]  Path to annotation file [OPTIONAL].
  --rename_chrom_notation  [boolean] If true rename chromosome notation from 1 -- > chr1 [default: true].

LLM assistant
  --clinical_data          [string]  Path to comma-separated CSV file comprising: Sample_Name and Clinical_Description fields. 
  --assistant              [boolean] If true use LLM assistant.
```

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
|-------------|-------------------------------------------------------------------|
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

To start exemplary analysis `LLM-assitant turned OFF`:
```sh
nextflow run main.nf --sample_sheet samples.csv --output_dir results --genome_assembly hg38
```

To start exemplary analysis `LLM-assitant turned ON`:
**IMPORTANTLY**, the clinical_data and sample_sheet files should contain the same set of samples. If clinical data are not available or not provided for a specific sample, leave the `Clinical_Description` field empty.
```sh
nextflow run main.nf --sample_sheet samples.csv --output_dir results --genome_assembly hg38 --clinical_data clinical.csv --assistant=true
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
