# NET-seq analysis workflow

This pipeline will process NET-seq data and identify pause sites.

<br>

## Getting started

1. Create a new repository using this template
2. Clone and navigate to the project directory
3. Specify sample names and modify pipeline parameters using the SAMPLES.yaml
   config file
5. Run the pipeline using the run.sh script, run `./run.sh -h` to view
   various options for running the pipeline

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
5. Subsample reads so libraries within the same group have the same
   per-gene number of aligned reads for each provided subsampling region
6. Generate bigwigs
6. Generate bed files for metaplots
7. Check subsampling output files

### Identify pauses

1. Find pauses using bedgraph files
2. Filter for strong pauses
3. Identify reads that align to pauses
4. Generate bed files for metaplots
5. Create summary plots

<br>

## Output

* Summary plots (results/analysis.html)
* URLs for bigwigs, subsampled so libraries that
  are being compared have the same number of reads (results/urls/urls.tsv)
* URLs for bigwigs without read subsampling (results/urls/nosub_urls.tsv)
* URLs for bigwigs without filtering for
  reads near protein coding genes and without subsampling
  (results/urls/nofilt_urls.tsv)
* URLs for matrix files that can be used to
  generate metaplots (results/urls/matrix_urls.tsv)

