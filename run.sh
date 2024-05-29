#! /usr/bin/env bash

set -o nounset -o pipefail -o errexit

mkdir -p logs


# Script default inputs
snake_exec='/beevol/home/sheridanr/.local/bin/snakemake'
bind_dir='/beevol/home'
snake_args='--keep-going --jobs 100'
dry_run=0

if [ ! -f "$snake_exec" ] || [ ! -x "$snake_exec" ]
then
    snake_exec=snakemake
fi


# Parse arguments
usage() {
    echo """
This will submit the pipeline to the LSF job manager, before submitting
update the SAMPLES.yaml config file with the correct sample names and
paths.

USAGE
$0 [-h] [-d] [-s SNAKE_PATH] [-a SNAKE_ARGS] [-b BIND_PATH]

OPTIONS
-h, display this message.
-d, execute dry-run to test pipeline
-s, snakemake executable to use when running pipeline, default path is
    $snake_exec
-a, additional arguments to pass to snakemake, these should be wrapped in
    quotes, default arguments are '$snake_args' 
-b, directory path to bind to container, this is required for access to
    files that are outside of the workflow directory, default path is
    $bind_dir
    """
}

while getopts ":hds:b:" args
do
    case "$args" in
        h)
            usage
            exit 0
            ;;
        d) dry_run=1 ;;
        s) snake_exec="$OPTARG" ;;
        a) snake_args="$OPTARG" ;;
        b) bind_dir="$OPTARG" ;;
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


# Function to run snakemake
run_snakemake() {
    local dry_arg=${dry_arg:-}

    if [ "$dry_run" -eq 1 ]
    then
        local dry_arg='-n'
    fi

    args='
        -oo {log.out} 
        -eo {log.err} 
        -J {params.job_name}
        -R "rusage[mem={params.memory}] span[hosts=1]"
        -n {threads} '

    "$snake_exec" $dry_arg $snake_args \
        --snakefile 'src/pipelines/net.snake' \
        --use-singularity \
        --singularity-args "--bind $bind_dir" \
        --drmaa "$args" \
        --config SSH_KEY_DIR="$ssh_key_dir" \
        --configfiles 'SAMPLES.yaml' 'src/configs/net.yaml' 'src/configs/pauses.yaml'
}


# Path to .ssh directory
# this is used to provide the container access to ssh keys for
# transferring files
ssh_key_dir="$HOME/.ssh"


# Run the pipeline
# make function and variables available to bsub
function_def=$(declare -f run_snakemake)

export snake_exec
export bind_dir
export function_def
export ssh_key_dir
export dry_run

module load singularity

bsub \
    -J 'NET-seq' \
    -o 'logs/net_%J.out' \
    -e 'logs/net_%J.err' <<EOF
#! /usr/bin/env bash

$function_def

run_snakemake

EOF


