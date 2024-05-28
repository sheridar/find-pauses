#! /usr/bin/env bash

#BSUB -J NET-seq
#BSUB -o logs/snake_%J.out
#BSUB -e logs/snake_%J.err

set -o nounset -o pipefail -o errexit -x

module load singularity

mkdir -p logs


# Functions to run snakemake
sng_args='--bind /beevol/home'

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
        --singularity-args "$sng_args" \
        --drmaa "$args" \
        --jobs 100 \
        --config SSH_KEY=\'"$HOME/.ssh"\' \
        --configfiles $config_file
}

run() {
    config_dir='src/configs'

    run_snakemake \
        src/pipelines/net.snake \
        "SAMPLES.yaml $config_dir/net.yaml $config_dir/pauses.yaml"
}


# # Run pipeline using singularity
# singularity exec "$sng_args" docker://rmsheridan/find-pauses:v5 run

run


