#!/usr/bin/python

import json
import sys

import vcfpy


def extract_sex_chrom(path: str, output_json: str) -> None:
    vcf = vcfpy.Reader.from_path(path)
    vcf = vcf.__dict__["header"].__dict__["lines"]
    sex_karyotype = [line.value for line in vcf if line.key == "estimatedSexKaryotype"]

    if len(sex_karyotype) == 0:
        sex_karyotype = "UNKNOWN"

    elif len(sex_karyotype) == 1:
        sex_karyotype = sex_karyotype[0]

    else:
        sex_karyotype = " | ".join(sex_karyotype)

    with open(output_json, "w", encoding="utf-8") as file:
        json.dump({"sex": sex_karyotype}, file)


def main():
    if len(sys.argv) != 3:
        print("Usage: extract_sex_chrom.py <input_vcf: str> <output_json: str>")
        sys.exit(1)

    input_vcf, output_json = sys.argv[1:]
    extract_sex_chrom(input_vcf, output_json)


if __name__ == "__main__":
    main()
