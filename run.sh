#! /usr/bin/env bash

set -o nounset -o pipefail -o errexit

mkdir -p logs


# Script default inputs
container='docker://rmsheridan/find-pauses:latest'
results='results'
dry_run=0


# Parse arguments
usage() {
    echo """
OPTIONS
-h, display this message.
-c, container to use for running pipeline
-r, directory to use for writing results
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
        c) container="$OPTARG" ;;
        r) results="$OPTARG" ;;
        d) dry_run=1 ;;
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


# This is required to bind file system to container
# this is specific for amc-bodhi and would need to be updated if running on
# different system
sng_args='--bind /beevol/home'
ssh_key_dir="$HOME/.ssh"


# Function to run snakemake
run_snakemake() {
    local snake_args=${snake_args:-}

    if [ "$dry_run" -eq 1 ]
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
        --snakefile 'src/pipelines/net.snake' \
        --use-singularity \
        --singularity-args '--bind /beevol/home' \
        --drmaa "$args" \
        --jobs 100 \
        --config CONTAINER="$container" RESULTS="$results" SSH_KEY_DIR="$ssh_key_dir" \
        --configfiles 'SAMPLES.yaml' 'src/configs/net.yaml' 'src/configs/pauses.yaml'
}


# Run the pipeline using singularity
# make function and variables available to bsub
function_def=$(declare -f run_snakemake | sed 's/"/\\"/g' | sed "s/'/\\'/g")

export function_def
export container
export results
export ssh_key_dir
export dry_run
export sng_args

module load singularity

bsub \
    -J 'NET-seq' \
    -o 'logs/net_%J.out' \
    -e 'logs/net_%J.err' <<EOF
#! /usr/bin/env bash

$function_def

singularity exec \
    $sng_args \
    --env function_def="$function_def" \
    --env container="$container" \
    --env results="$results" \
    --env ssh_key_dir="$ssh_key_dir" \
    --env dry_run=$dry_run \
    "$container" \
    bash -c "eval \"$function_def\"; run_snakemake"
EOF


