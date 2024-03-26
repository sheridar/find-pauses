# NET-seq analysis workflow

This workflow is composed of two separate snakemake pipelines, one
to perform the initial processing steps and another to identify pause
sites. Workflow settings can be modified with the NETseq.yaml and
pauses.yaml config files.

<br>

## Getting started

1. Create a new repository using this template
2. Clone and navigate to the project directory
3. Specify sample names, groups, and directory paths using the SAMPLES.yaml config file
5. Run the pipeline by submitting the run.sh script
6. Check the subsampling test results by running `cat results/stats/*_test.tsv`.
   This double checks that the per-gene subsampling was performed correctly, each file should be marked with 'PASS' 

<br>

## Workflow

### Process reads

1. Run FastQC
1. Trim adapters
2. Aign reads with bowtie2
3. Remove PCR duplicates based on UMI
4. Summarize read mapping with featureCounts
4. Subsample reads so samples within the same group have the same total
   number of aligned reads
5. Subsample reads so libraries within the same group have the same number
   of aligned reads for each provided subsampling region
6. Generate bigwigs
6. Generate bed files for metaplots
7. Check subsampling output files

### Identify pauses

1. Find pauses using bedgraph files
2. Filter for strong pauses
3. Identify reads that align to pauses
4. Generate bed files for metaplots
5. Create summary plots
