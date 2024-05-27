#! /usr/bin/env bash

#BSUB -J NET-seq
#BSUB -o logs/snake_%J.out
#BSUB -e logs/snake_%J.err

set -o nounset -o pipefail -o errexit -x

module load singularity

mkdir -p logs


# Functions to run snakemake
run_snakemake() {
    local snake_file=$1
    local config_file=$2

    args='
        -oo {log.out} 
        -eo {log.err} 
        -J {params.job_name}
        -R "rusage[mem={params.memory}] span[hosts=1]"
        -n {threads} '

    snakemake \
        --snakefile $snake_file \
        --use-singularity \
        --singularity-args '--bind /beevol/home' \
        --drmaa "$args" \
        --jobs 100 \
        --configfiles $config_file
}

run() {
    run_snakemake \
        src/pipeline/net.snake \
        "SAMPLES.yaml src/configs/net.yaml src/configs/pauses.yaml"
}


# Run pipeline using singularity
singularity exec --bind /beevol/home docker://rmsheridan/find-pauses:v5 run


