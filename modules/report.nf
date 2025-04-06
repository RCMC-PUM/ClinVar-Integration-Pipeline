process INTERPRET {
    maxForks 5

    // previously defined OpenAI API KEY
    // for more info see https://openai.com/index/openai-api/
    secret 'OPENAI_KEY'

    input:
    publishDir "$params.output_dir/samples/$sample", mode: 'copy', overwrite: true, pattern: '*.json'
    tuple val(sample), file(variants)
    file clincial_data 
    file model_config 

    output:
    tuple val(sample), file("${sample}.interpretation.json")

    script: 
    """
    export OPENAI_KEY="\$OPENAI_KEY"
    interpret.py $sample ${variants.join(',')} $clincial_data $model_config
    """
}


process CREATE_REPORT {
    input:
    tuple val(sample), file(variants), file(interpretation)
    path clinical_data
    path sex_chromosomes

    val workflow_params
    val annotation_metadata

    path html_template
    path glossary 

    output:
    publishDir "$params.output_dir/samples/$sample", mode: 'copy', overwrite: true, pattern: '*.html'
    publishDir "$params.output_dir/samples/$sample", mode: 'copy', overwrite: true, pattern: '*.json'
    file "*.html"
    file "*.json"

    script:
    def sex_chromosomes = sex_chromosomes != '' ? "$sex_chromosomes" : ' '
    """
    reports.py $sample ${variants.join(',')} $interpretation $clinical_data $sex_chromosomes $workflow_params $annotation_metadata $html_template $glossary
    """
}
