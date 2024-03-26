#! /usr/bin/env bash

#BSUB -J NET-seq
#BSUB -o logs/snake_%J.out
#BSUB -e logs/snake_%J.err

set -o nounset -o pipefail -o errexit -x

module load fastqc
module load bowtie2
module load samtools
module load subread
module load gcc/7.4.0
module load R/4.0.3

mkdir -p logs


# Function to run snakemake
run_snakemake() {
    local snake_file=$1
    local config_file=$2

    args='
        -oo {log.out} 
        -eo {log.err} 
        -J {params.job_name}
        -R "rusage[mem={params.memory}] span[hosts=1]"
        -n {threads} '

    snakemake -n \
        --snakefile $snake_file \
        --drmaa "$args" \
        --jobs 100 \
        --configfiles $config_file
}


# Run pipeline to process mNET-seq reads
pipe_dir=src/pipelines
samples=SAMPLES.yaml

snake=$pipe_dir/NETseq.snake
config=NETseq.yaml

run_snakemake $snake "$samples $config"

# Run pipeline to identify pause sites
snake=$pipe_dir/pauses.snake
config=pauses.yaml

run_snakemake $snake "$samples $config"


