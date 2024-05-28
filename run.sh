#! /usr/bin/env bash

#BSUB -J NET-seq
#BSUB -o logs/snake_%J.out
#BSUB -e logs/snake_%J.err

set -o nounset -o pipefail -o errexit

mkdir -p logs


# Script default inputs
CONTAINER='docker://rmsheridan/find-pauses:latest'
RESULTS='results'
DRY_RUN=0


# Parse arguments
usage() {
    echo """
OPTIONS
-h, display this message.
-c, container to use for running pipeline
-r, directory to output results
-d, execute dry-run to test pipeline
    """
}

while getopts ":hc:r:d" args
do
    case "$args" in
        h)
            usage
            exit 0
            ;;
        c) CONTAINER="$OPTARG" ;;
        r) RESULTS="$OPTARG" ;;
        d) DRY_RUN=1 ;;
        :)
            echo -e "\nERROR: -$OPTARG requires an argument"

            usage
	        exit 1
            ;;
	    *) 
            usage
	        exit 1
            ;;
    esac
done


# Load modules
module load singularity


# This is required to bind file system to container
# this is specific for amc-bodhi and would need to be updated if running on
# different system
sng_args='--bind /beevol/home'


# Functions to run snakemake
run_snakemake() {
    local snake_file='src/pipelines/net.snake'
    local cfig_dir='src/configs'
    local cfig_files="SAMPLES.yaml $cfig_dir/net.yaml $cfig_dir/pauses.yaml"

    local snake_args=${snake_args:-}

    if [ "$DRY_RUN" -eq 1 ]
    then
        local snake_args='-n'
    fi

    args='
        -oo {log.out} 
        -eo {log.err} 
        -J {params.job_name}
        -R "rusage[mem={params.memory}] span[hosts=1]"
        -n {threads} '

    snakemake $snake_args \
        --snakefile "$snake_file" \
        --use-singularity \
        --singularity-args "$sng_args" \
        --drmaa "$args" \
        --jobs 100 \
        --config CONTAINER="$CONTAINER" RESULTS="$RESULTS" SSH_KEY_DIR="$HOME/.ssh" \
        --configfiles $cfig_files 
}


# Run pipeline using singularity
singularity exec "$sng_args" "$CONTAINER" run_snakemake


