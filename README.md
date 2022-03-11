## mNET-seq analysis workflow

The analysis workflow is composed of two separate snakemake pipelines, one
to perform the initial processing steps and the other to identify pause
sites. To run, specify sample names in the samples.yaml config file, and
workflow parameters in the NETseq.yaml and pauses.yaml config files.

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

