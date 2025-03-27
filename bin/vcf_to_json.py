#!/usr/bin/python

import json
import re
import sys
from collections import defaultdict
from time import sleep

import vcfpy
from metapub import MedGenFetcher


def clean_value(val: str) -> str:
    return (
        str(val).replace("[", "").replace("]", "").replace("'", "").replace("|", " | ")
    )


def constrain(val: str, n: int = 50) -> str:
    return f"{val[:n]}[...]" if len(val) > n else val


def find_medgen_cui(val: str) -> list[str]:
    return [
        cui.replace("MedGen:", "") for cui in re.findall(r"MedGen:[A-Za-z0-9]+", val)
    ]


def request_medgen(cuis: list[str], tlimit: float = 0.01) -> dict[str, dict]:
    if not cuis:
        return {}

    fetch = MedGenFetcher()
    fetched_data = {}

    for cui in cuis:
        try:
            concept = fetch.concept_by_cui(cui)
            if concept.title in ["not provided", "not specified"]:
                continue

            if concept.definition:
                definition = concept.definition
                if concept.modes_of_inheritance:
                    moi = [
                        inh.get("name", "UNKNOWN/NOT-PROVIDED")
                        for inh in concept.modes_of_inheritance
                    ]
                    moi = " | ".join(moi)
                else:
                    moi = "UNKNOWN/NOT-PROVIDED"

            else:
                definition = "UNKNOWN/NOT-PROVIDED"
                moi = "UNKNOWN/NOT-PROVIDED"

            concept_data = {
                "title": concept.title,
                "definition": definition,
                "modes_of_inheritance": moi,
            }
            fetched_data[cui] = concept_data
            sleep(tlimit)

        except:  # pylint: disable=W0702
            # silent error, not perfect but there is nothing i can do right now
            pass

    return fetched_data


def parse_vcf(
    input_vcf: str, sample: str, caller: str, limit: int = 100
) -> dict[str, dict]:

    n_variants = len(list(vcfpy.Reader.from_path(input_vcf)))
    parsed = defaultdict(dict)

    if n_variants > int(limit):
        parsed["STATUS"] = {
            "STATUS": "Number of variants exceeded limit [>100], skipping."
        }
        parsed["SOURCE"] = {"sample": sample, "file": input_vcf, "caller": caller}
        return parsed

    if n_variants == 0:
        parsed["STATUS"] = {"STATUS": "No variants detected, skipping."}
        parsed["SOURCE"] = {"sample": sample, "file": input_vcf, "caller": caller}
        return parsed

    reader = vcfpy.Reader.from_path(input_vcf)
    parsed["VARIANTS"] = defaultdict(dict)

    for cnt, record in enumerate(reader):
        info = {key: clean_value(value) for key, value in record.INFO.items()}
        pos = f"{record.CHROM}:{record.POS}"

        ref = constrain(record.REF)
        alt = " | ".join([f"{constrain(a.value)} [{a.type}]" for a in record.ALT])

        gt = record.calls[0].data.get("GT", "")
        rs = " | ".join([f"rs{rs}" for rs in record.INFO.get("RS", [])])

        cuis = find_medgen_cui(info.get("CLNDISDB", ""))
        medgen_annots = request_medgen(cuis)

        parsed["STATUS"] = "OK"
        parsed["SOURCE"] = {"sample": sample, "file": input_vcf, "caller": caller}
        parsed["VARIANTS"][cnt] = {
            "VARIANT": {"POS": pos, "REF": ref, "ALT": alt, "GT": gt, "RS ID": rs},
            "INFO": info,
            "CALLS": record.calls[0].data,
            "MEDGEN": medgen_annots,
        }

    return parsed


def main():
    if len(sys.argv) != 6:
        print(
            "Usage: vcf_to_json.py <sample: str> <caller: str> <input_vcf: str> <output_json: str> <variats_number_limit: int>"
        )
        sys.exit(1)

    sample_name, caller, vcf_file, output_json, limit = sys.argv[1:]
    parsed_data = parse_vcf(vcf_file, sample_name, caller, limit)

    with open(output_json, "w", encoding="utf-8") as f:
        json.dump(parsed_data, f, indent=2)


if __name__ == "__main__":
    main()
