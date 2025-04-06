#!/usr/bin/python

import json
import sys
from datetime import datetime

import pandas as pd
from jinja2 import Environment, FileSystemLoader


def load_clinical_data(
    path: str,
    sample: str,
    sample_name_col: str = "Sample_Name",
    clinical_data_col: str = "Clinical_Description",
) -> str:
    df = pd.read_csv(path).set_index(sample_name_col)
    df[clinical_data_col] = df[clinical_data_col].fillna("NOT PROVIDED.")
    
    return df.loc[sample, clinical_data_col]


def sort_dict(
    obj: dict, order: tuple = ("small_variant", "repeats", "cnv", "sv", "ploidy")
):
    return {k: obj[k] for k in order if k in obj.keys()}


def load_json(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def render_html(json_data, template_path, sample_name):
    env = Environment(loader=FileSystemLoader("."))
    template = env.get_template(template_path)

    output = template.render(json_data)

    with open(f"{sample_name}.html", "w", encoding="utf-8") as f:
        f.write(output)


def main():
    if len(sys.argv) != 10:
        print("Usage: generate_report.py <...>")
        sys.exit(1)

    (
        sample_name,
        variants_json_files,
        variants_interpretation_file,
        clinical_data,
        sex_chromosomes_json,
        workflow_parameters,
        annotation_metadata,
        html_template,
        glossary,
    ) = sys.argv[1:]

    all_variants = {}
    variants_json_files = [v.strip() for v in variants_json_files.split(",")]

    for source in variants_json_files:
        variants_per_caller = load_json(source)
        caller_type = variants_per_caller["SOURCE"]["caller"]
        all_variants[caller_type] = variants_per_caller

    if sex_chromosomes_json:
        sex_chromosomes = load_json(sex_chromosomes_json)
    else:
        sex_chromosomes = {"sex": "not-detected"}

    if not variants_interpretation_file.endswith("empty"):
        variants_interpretatios = load_json(variants_interpretation_file)
    else:
        variants_interpretatios = {
            "interpretation": "LLM assistant is turend off, for more info see docs: https://github.com/RCMC-PUM/ClinVar-Integration-Pipeline."
        }

    if not clinical_data.endswith("empty"):
        clinical_data = load_clinical_data(clinical_data, sample_name)
    else:
        clinical_data = ""

    data = {
        "sample_name": sample_name,
        "sex": sex_chromosomes,
        "date": datetime.today().strftime("%Y-%m-%d"),
        "workflow_parameters": load_json(workflow_parameters),
        "annotation_metadata": load_json(annotation_metadata),
        "variants": sort_dict(all_variants),
        "clinical_data": clinical_data,
        "glossary": load_json(glossary),
        "assistant": variants_interpretatios,
    }

    with open(f"{sample_name}.json", "w", encoding="utf-8") as file:
        json.dump(data, file, indent=2)

    render_html(data, html_template, sample_name)


if __name__ == "__main__":
    main()
