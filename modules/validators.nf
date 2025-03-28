process VALIDATE_SAMPLE_SHEET {
    input:
    path file

    script:
    """
    #!/usr/bin/python
    import pandas as pd 

    ss = pd.read_csv("$file")
    expected_cols = ["Sample_Name","Path","Caller"]
    supported_callers = ['sv', 'ploidy', 'cnv', 'small_variant', 'repeats']
    
    callers = ss["Caller"].unique()

    assert set(callers) == set(supported_callers), f"Supported callers types are: {supported_callers}!"
    assert set(expected_cols) == set(ss.columns), f"Sample sheet should contain three columns: {expected_cols}!"
    """
}

process VALIDATE_CLINICAL_DATA {
    input:
    path file

    script:
    """
    #!/usr/bin/python
    import pandas as pd 

    ss = pd.read_csv("$file")
    expected_cols = ["Sample_Name","Clinical_Description"]

    assert set(expected_cols) == set(ss.columns), f"Clinical data file should contain three columns: {expected_cols}!"
    """
}

process VALIDATE_INTEROPERABILITY {
    input:
    path sample_sheet
    path clinical_sheet

    script:
    """
    #!/usr/bin/python
    import pandas as pd 

    ss = set(pd.read_csv("$sample_sheet").Sample_Name)
    cs = set(pd.read_csv("$clinical_sheet").Sample_Name)

    assert ss == cs, "Sample names defined in sample_sheet and clinical_data sheet should be the same!"
    """
}
