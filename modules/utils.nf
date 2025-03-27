import groovy.json.JsonOutput


process FILE_PLACEHOLDER {
    input:
    val x

    output:
    file "${x}.empty"

    script:
    """
    echo "$x" > "${x}.empty"
    """
}


process SAVE_PARAMS {
    output:
        publishDir "$params.output_dir", mode: 'copy', overwrite: true, pattern: 'params.json'
        path 'params.json'

    script:
      "echo '${JsonOutput.toJson(params)}' > params.json"
}


process DOWNLOAD_CLINVAR {
    input:
    val genome_assembly

    output:
    path "clinvar.vcf.gz"

    script:
    """
    if [ "$genome_assembly" = "hg19" ]; then
        wget https://ftp.ncbi.nlm.nih.gov/pub/clinvar/vcf_GRCh37/clinvar.vcf.gz 
    else
        wget https://ftp.ncbi.nlm.nih.gov/pub/clinvar/vcf_GRCh38/clinvar.vcf.gz
    fi
    """
}

process SAVE_METADATA {
    input:
    tuple file(annots), file(annots_index)

    output:
    publishDir "$params.output_dir", mode: 'copy', overwrite: true, pattern: 'annots_params.json'
    path 'annots_params.json'

    script:
    """
    #!/usr/bin/python
    import vcfpy
    import json

    reader = vcfpy.Reader.from_path("${annots}")
    params = {line.key: line.value for line in reader.header.lines if line.key in ["fileformat", "fileDate", "source", "reference"]}

    with open("annots_params.json", "w") as handle:
        json.dump(params, handle, indent=2)
    """
}
