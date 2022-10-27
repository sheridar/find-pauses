## mNET-seq analysis workflow

The analysis workflow is composed of two separate snakemake pipelines, one
to perform the initial processing steps and the other to identify pause
sites. Workflow settings can be modified with the NETseq.yaml and
pauses.yaml config files.

To run:

1. Specify sample names and directory paths using the SAMPLE.yaml config file
2. Specify sample groups and colors for plotting using the PLOTS.yaml
  config file
3. Run the pipeline by submitting the run.sh script through bsub

### Processing

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

### Pauses

1. Find pauses using bedgraph files
2. Filter for strong pauses
3. Identify reads that align to pauses
4. Generate bed files for metaplots
5. Create summary plots


