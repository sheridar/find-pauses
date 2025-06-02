#! /usr/bin/env bash

set -o pipefail -o errexit

mkdir -p logs


# Set default inputs
install=0
dry_run=0
snake_args='--jobs 100 --keep-going --retries 1'
bind_dir='/beevol/home'


# Parse arguments
usage() {
    echo """
This will submit the pipeline to the LSF job manager, before submitting
update the SAMPLES.yaml config file with the correct sample names and
paths. It is also helpful to first run this script using the '-d' option
to check for any potential issues with the input files.

USAGE
$0 [-h] [-d] [-i] [-a SNAKE_ARGS] [-b BIND_PATH]

OPTIONS
-h, display this help message
-d, execute dry-run to test pipeline and print summary of jobs
-i, install python and snakemake dependencies in micromamba environment,
    this will result in the creation of a 'micromamba' folder in your
    home directory, this option only needs to be included for the first
    run
-a, additional arguments to pass to snakemake, these should be wrapped in
    quotes, default arguments are:
    '$snake_args' 
-b, directory path to bind to container, this is required for access to
    files that are outside of the workflow directory, default path is:
    '$bind_dir'
    """
}

while getopts ":hdia:b:" args
do
    case "$args" in
        h)
            usage
            exit 0
            ;;
        d) dry_run=1 ;;
        i) install=1 ;;
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
    local install="$1"
    local dry_run="$2"
    local snake_args="$3"
    local bind_dir="$4"
    local env_name="$5"
    local env_file="$6"

    # Path to .ssh directory
    # this is used to provide the container access to ssh keys for
    # transferring files to amc-sandbox
    local ssh_key_dir="$7"

    # Add dry run argument
    if [ "$dry_run" -eq 1 ]
    then
        local snake_args="--dry-run --quiet $snake_args"
    fi

    # Check that --jobs is always provided
    if [[ ! "$snake_args" == *"--jobs"* ]]
    then
        local snake_args="--jobs 100 $snake_args"
    fi

    # Install micromamba environment
    # combine curl command with dummy command or script exits after install
    if [ "$install" -eq 1 ]
    then
        if ! command -v micromamba &> /dev/null
        then
            yes "" | bash <(curl -L micro.mamba.pm/install.sh) > /dev/null &&
                sleep
        fi

        # initialize shell for micromamba
        export MAMBA_ROOT_PREFIX="${MAMBA_ROOT_PREFIX:=$HOME/micromamba}"

        eval "$(micromamba shell hook --shell bash)"

        micromamba create -y -n "$env_name" -f "$env_file"
    fi

    # need to initialize here also in case user runs pipeline multiple
    # times after install but before starting new shell
    # MAMBA_ROOT_PREFIX is still unset after initializing
    if command -v micromamba &> /dev/null
    then
        export MAMBA_ROOT_PREFIX="${MAMBA_ROOT_PREFIX:=$HOME/micromamba}"
    
        eval "$(micromamba shell hook --shell bash)"

        if [ -d "$MAMBA_ROOT_PREFIX/envs/$env_name" ]
        then
            micromamba activate "$env_name"
        fi
    fi

    # module load singularity

    drmaa_args='
        -J {params.job_name}
        -oo {log.out} 
        -eo {log.err} 
        -R "rusage[mem={resources.mem_gb}] span[hosts=1]"
        -M {resources.mem_gb}
        -n {threads} '

    snakemake $snake_args \
        --snakefile 'src/pipelines/net.snake' \
        --use-singularity \
        --singularity-args "--bind $bind_dir" \
        --drmaa "$drmaa_args" \
        --config SSH_KEY_DIR="$ssh_key_dir" \
        --configfiles 'SAMPLES.yaml' 'src/configs/net.yaml' 'src/configs/pauses.yaml'
}


# Run the pipeline
# make variables available to bsub
function_def=$(declare -f run_snakemake)

export install
export dry_run
export snake_args
export bind_dir
export function_def

bsub \
    -J 'NET-seq' \
    -o 'logs/net_%J.out' \
    -e 'logs/net_%J.err' \
    -R 'rusage[mem=4GB] span[hosts=1]' \
    -M 4GB \
    -n 1 <<EOF
#! /usr/bin/env bash

set -o nounset -o pipefail -o errexit -x

$function_def

run_snakemake \
    "$install" \
    "$dry_run" \
    "$snake_args" \
    "$bind_dir" \
    'snakemake' \
    'env/snakemake.yml' \
    "$HOME/.ssh"
EOF


