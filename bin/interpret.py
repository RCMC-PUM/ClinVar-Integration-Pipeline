#!/usr/bin/python

import json
import os
import sys
import time

import pandas as pd
from openai import OpenAI


def load_json(path: str):
    with open(path, "r") as file:
        return json.load(file)


def load_clinical_data(
    path: str,
    sample: str,
    sample_name_col: str = "Sample_Name",
    clinical_data_col: str = "Clinical_Description",
) -> str:
    df = pd.read_csv(path).set_index(sample_name_col)
    df["Clinical_Description"] = df["Clinical_Description"].fillna("NOT PROVIDED/NOT AVAILABLE.")
    
    return df.loc[sample, clinical_data_col]


def load_variants(files: list[str]) -> dict:
    merged = []

    for file in files:
        file = load_json(file)

        if file["STATUS"] != "OK":
            continue

        for variant in file.get("VARIANTS").values():
            variant_id = variant["INFO"].get("CLNHGVS", "UNKNOWN")
            variant_cldn = variant["INFO"].get("CLNDN", "UNKNOWN")
            variant_gt = variant["CALLS"].get("GT", "UNKNOWN")
            variant_medgen_data = []

            if variant["MEDGEN"]:
                for medgen_concept in variant["MEDGEN"].values():
                    if medgen_concept["definition"] != "UNKNOWN/NOT-PROVIDED":
                        variant_medgen_data.append(medgen_concept)

            if not variant_medgen_data:
                variant_medgen_data = "No associated MedGen concepts found."

            merged.append(
                {
                    "Variant": variant_id,
                    "Genotype": variant_gt,
                    "Clinical description": variant_cldn,
                    "MedGen associated concepts": variant_medgen_data,
                }
            )

    filtered = [
        variant
        for variant in merged
        if (variant["Clinical description"] != "UNKNOWN")
        or (
            variant["MedGen associated concepts"]
            != "No associated MedGen concepts found"
        )
    ]

    return filtered


def main():
    if len(sys.argv) != 5:
        print(
            "Usage: interpret.py <sample_name: str> <input_variants_files: str,str,str[...]> <clinical_data: str> <model_config: str>"
        )
        sys.exit(1)

    OPENAI_KEY = os.environ["OPENAI_KEY"]

    sample, variants_files, clinical_data, model_config_file = sys.argv[1:]
    variants_files = [file.strip() for file in variants_files.split(",")]

    variants = load_variants(variants_files)
    clinical_data = load_clinical_data(clinical_data, sample)
    model_config = load_json(model_config_file)
    
    try:
        client = OpenAI(api_key=OPENAI_KEY)

        response = client.responses.create(
            model=model_config["model"],
            instructions=model_config["instruction"],
            input=f"Clinical features: {clinical_data}. Genetic variants: {variants}.",
        )

        # Interpretation result
        interpretation = response.output_text
        output = {
            "interpretation": interpretation,
        }
        time.sleep(1)

    except Exception as e:  # pylint: disable=W0718
        output = {
            "interpretation": e,
        }

    with open(f"{sample}.interpretation.json", "w", encoding="utf-8") as file:
        json.dump(output, file, indent=2)


if __name__ == "__main__":
    main()
