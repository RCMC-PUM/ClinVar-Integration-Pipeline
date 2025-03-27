process RENAME_CHR {
    input:
    tuple file(annots), file(index)

    output:
    tuple file("clinvar_chr_renamed.vcf.gz"), file("clinvar_chr_renamed.vcf.gz.tbi")

    script:
    """

    for i in {1..22} X Y MT; do
        echo "\$i chr\$i" >> chr_name_conv.txt
    done

    bcftools annotate --rename-chrs chr_name_conv.txt $annots | bgzip > clinvar_chr_renamed.vcf.gz
    bcftools index -t clinvar_chr_renamed.vcf.gz
    """
}

process INDEX {
    input:
    path object

    output:
    tuple file(object), file("${object.name}.tbi")

    script:
    """
    bcftools index -t $object
    """
}

process FILTER_PASSING_VARIANTS {
    input:
    tuple val(sample), file(vcf), val(caller)

    output:
    publishDir "$params.output_dir/samples/$sample/raw", mode: 'copy', overwrite: true, pattern: '*.pass.vcf.gz'
    tuple val(sample), file("${vcf.getSimpleName()}.${caller}.pass.vcf.gz"), val(caller)

    script:
    """
    if [[ "$caller" == "ploidy" ]]; then
        bcftools view -O z -o "${vcf.getSimpleName()}.${caller}.pass.vcf.gz" $vcf 
    else
        bcftools view -i 'FILTER=="PASS" && ALT!="."' -O z -o "${vcf.getSimpleName()}.${caller}.pass.vcf.gz" $vcf 
    fi
    """
}


process ANNOTATE_VARIANTS {
    input:
    tuple val(sample), file(vcf), val(caller)
    tuple file(annots), file(annots_index)

    output:
    publishDir "$params.output_dir/samples/$sample/annotated_raw", mode: 'copy', overwrite: true, pattern: '*.pass.annot.vcf.gz'
    tuple val(sample),file("${vcf.getSimpleName()}.${caller}.pass.annot.vcf.gz"), val(caller)

    script:
    """
    bcftools index -t $vcf
    bcftools annotate -a $annots -c CHROM,POS,REF,ALT,INFO -O z -o "${vcf.getSimpleName()}.${caller}.pass.annot.vcf.gz" $vcf
    """
}


process FILTER_ANNOTATED_VARIANTS {
    input:
    tuple val(sample), file(vcf), val(caller)
    val clinical_significance 
    val clinical_review_status

    output:
    publishDir "$params.output_dir/samples/$sample/annotated_filtered", mode: 'copy', overwrite: true, pattern: '*.filtered.pass.annot.vcf.gz'
    tuple val(sample), file("${vcf.getSimpleName()}.${caller}.filtered.pass.annot.vcf.gz"), val(caller)

    script:
    """
    if [[ "$caller" == "ploidy" ]]; then
        bcftools filter -i '(ALT~"DEL") || (ALT~"DUP")' -O z -o "${vcf.getSimpleName()}.${caller}.filtered.pass.annot.vcf.gz" $vcf
    else
        bcftools filter -i '(INFO/CLNSIG="$clinical_significance") && (INFO/CLNREVSTAT="$clinical_review_status")' -O z -o "${vcf.getSimpleName()}.${caller}.filtered.pass.annot.vcf.gz" $vcf
    fi
    """
}


process EXTRACT_VARIANTS {
    // max forks as well as error strategy due to NCBI API restrictions 
    maxForks 1
    errorStrategy { sleep(task.attempt * 25); return 'retry' }
    maxRetries 10

    // previously defined NCBI API KEY
    // for more info see https://www.nextflow.io/docs/latest/secrets.html
    secret 'NCBI_API_KEY'

    input:
    tuple val(sample), file(vcf), val(caller)
    val limits 

    output:
    publishDir "$params.output_dir/samples/$sample/variants", mode: 'copy', overwrite: true, pattern: '*.json'
    tuple val(sample), file("${vcf.getSimpleName()}.${caller}.variants.json") 

    script:
    """
    export NCBI_API_KEY="\$NCBI_API_KEY"
    vcf_to_json.py $sample $caller $vcf "${vcf.getSimpleName()}.${caller}.variants.json" $limits
    """
}

process EXTRACT_SEX_CHROM {
    input:
    tuple val(sample), file(vcf), val(caller)

    output:
    publishDir "$params.output_dir/samples/$sample/", mode: 'copy', overwrite: true, pattern: '*.json'
    path "${vcf.getSimpleName()}.sex.json", optional: true

    script:
    """
    if [[ "$caller" == "ploidy" ]]; then
        extract_sex_chrom.py $vcf "${vcf.getSimpleName()}.sex.json"
    fi
    """
}

