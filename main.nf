include { validateParameters; paramsSummaryLog } from 'plugin/nf-schema'

include { INTERPRET; CREATE_REPORT } from './modules/report'
include { SAVE_PARAMS; DOWNLOAD_CLINVAR; SAVE_METADATA  } from './modules/utils'
include { FILE_PLACEHOLDER as PLACEHOLDER_1; FILE_PLACEHOLDER as PLACEHOLDER_2 } from './modules/utils'
include { RENAME_CHR; INDEX; FILTER_PASSING_VARIANTS; ANNOTATE_VARIANTS; FILTER_ANNOTATED_VARIANTS; EXTRACT_VARIANTS; EXTRACT_SEX_CHROM } from './modules/vcf_tools.nf'

include { VALIDATE_SAMPLE_SHEET; VALIDATE_CLINICAL_DATA; VALIDATE_INTEROPERABILITY } from './modules/validators'

// I/O
params.sample_sheet = ''  // Path to the sample sheet
params.output_dir = '' // Path to output directory 

// Filters
params.clinical_significance = 'Pathogenic,Likely_pathogenic,Pathogenic/Likely_pathogenic,Pathogenic|risk_factor'  // User-defined pathogenicity filter
params.clinical_review_status = '_multiple_submitters,criteria_provided,reviewed_by_expert_panel'  // User-defined review status filter

// Annotations
params.genome_assembly = 'hg38' // Either hg19 or hg38
params.annotations_file = '' // Path to annotations VCF file
params.rename_chrom_notation = true // if on convert '1' to 'chr1' in annotation file

// Assistant
params.clinical_data = '' // Path to the sample sheet providin clinical description for each sample defined in sample_sheet
params.assistant = false


workflow {
    // Validate parameters
    validateParameters()

    // Load annotation file
    if (params.annotations_file && !params.genome_assembly) {
        annotations = file(params.annotations_file, checkIfExists:true)

    } else if (!params.annotations_file && params.genome_assembly) {
        annotations = DOWNLOAD_CLINVAR(params.genome_assembly)

    } else {
        assert false : "You should define either --annotations_file <path> or --genome_assembly <hg19|hg38> parameter."
    }    

    log.info paramsSummaryLog(workflow)

    // Indexing
    annotations = INDEX(annotations)

    // Rename chr notation if necessary 
    if (params.rename_chrom_notation){
        annotations = RENAME_CHR(annotations)
    }

    sample_sheet = file(params.sample_sheet, checkIfExists:true)
    VALIDATE_SAMPLE_SHEET(sample_sheet)

    // If clinical data provided start validation process
    if (params.clinical_data && params.assistant){
        clinical_data = file(params.clinical_data, checkIfExists:true)

        VALIDATE_CLINICAL_DATA(clinical_data)
        VALIDATE_INTEROPERABILITY(sample_sheet, clinical_data)

        if (!secrets.OPENAI_KEY) { 
            assert false : "--clinical_data parameters requires predefined secret: OPENAI_KEY." 
            }
        } else {
        clinical_data = PLACEHOLDER_1("clinical_data")
    }

    // Create the channel for sample(s) predfeined samples
    samples = Channel.fromPath(sample_sheet).splitCsv(header: true, sep: ",").map { row -> tuple(row.Sample_Name, file(row.Path), row.Caller ) }

    // Run the annotation process
    samples = FILTER_PASSING_VARIANTS(samples)
    annotated_samples = ANNOTATE_VARIANTS(samples, annotations)

    // Extract sex chromosomes
    sex = EXTRACT_SEX_CHROM(samples)

    // Filter annotated VCF file(s) according to provided criteria
    filtered_annotated_samples = FILTER_ANNOTATED_VARIANTS(annotated_samples, params.clinical_significance, params.clinical_review_status)

    // Group annotated file(s) per sample
    variants = EXTRACT_VARIANTS(filtered_annotated_samples, params.variant_limit)
    variants = variants.groupTuple()

    // Interpret variants
    if (params.clinical_data && params.assistant && secrets.OPENAI_KEY){
        variants_iterpretation = INTERPRET(variants, clinical_data)
    }
    else {
        variants_iterpretation = PLACEHOLDER_2("variants_iterpretation")
        log.info "LLM assistant is turend off, for more info see docs: https://github.com/RCMC-PUM/ClinVar-Integration-Pipeline."
    }

    // Export workflow params and annotations metadata
    workflow_params = SAVE_PARAMS()
    annotations_metadata = SAVE_METADATA(annotations)

    // Export HTML report(s)
    html_template = file(params.template, checkIfExists:true)
    glossary = file(params.glossary, checkIfExists:true)

    CREATE_REPORT(variants, variants_iterpretation, clinical_data, sex, workflow_params, annotations_metadata, html_template, glossary)
}
