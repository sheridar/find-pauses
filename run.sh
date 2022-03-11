#! /usr/bin/env bash

#BSUB -J snake
#BSUB -o logs/snake_%J.out
#BSUB -e logs/snake_%J.err
#BSUB -q rna

set -o nounset -o pipefail -o errexit -x

module load fastqc
module load bowtie2
module load samtools
module load subread

mkdir -p logs


# Directories
pipe_dir=src/pipelines
cons=src/configs


# Function to run snakemake
run_snakemake() {
    local snake_file=$1
    local config_file=$2

    args='
        -oo {log.out} 
        -eo {log.err} 
        -J {params.job_name}
        -R "rusage[mem={params.memory}] span[hosts=1]"
        -n {threads}
        -q rna '

    snakemake --nolock -n \
        --snakefile $snake_file \
        --drmaa "$args" \
        --jobs 100 \
        --latency-wait 60 \
        --configfiles $config_file
}


# Run pipeline to align and filter mNET-seq reads
snake=$pipe_dir/NETseq.snake
samples=$cons/samples.yaml
config=$cons/NETseq.yaml

run_snakemake $snake "$samples $config"


# Run pipeline to identify pause sites
config=$cons/pauses.yaml

run_snakemake $snake "$samples $config"



