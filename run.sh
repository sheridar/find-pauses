#! /usr/bin/env bash

set -o pipefail -o errexit

mkdir -p logs rule_logs


# Set default inputs
install=0
dry_run=0


# Parse arguments
usage() {
    echo """
This will submit the pipeline to the SLURM job manager, before submitting
update the SAMPLES.yaml config file with the correct sample names and
paths. It is also helpful to first run this script using the '-d' option
to check for any potential issues with the input files.

USAGE
$0 [-h] [-d] [-i]

OPTIONS
-h, display this help message
-d, execute dry-run to test pipeline and print summary of jobs
-i, install python and snakemake dependencies in micromamba environment,
    this will result in the creation of a 'micromamba' folder in your
    home directory, this option only needs to be included for the first
    run
    """
}

while getopts ":hdi" args
do
    case "$args" in
        h)
            usage
            exit 0
            ;;
        d) dry_run=1 ;;
        i) install=1 ;;
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
    local env_name="$3"
    local env_file="$4"
    local ssh_key_dir="$5"

    # Build snakemake args
    local snake_args=''

    if [ "$dry_run" -eq 1 ]
    then
        local snake_args="--dry-run --quiet"
    fi

    # Install micromamba environment
    if [ "$install" -eq 1 ]
    then
        if ! command -v micromamba &> /dev/null
        then
            yes "" | bash <(curl -L micro.mamba.pm/install.sh) > /dev/null &&
                sleep
        fi

        export MAMBA_ROOT_PREFIX="${MAMBA_ROOT_PREFIX:=$HOME/micromamba}"
        eval "$(micromamba shell hook --shell bash)"
        micromamba create -y -n "$env_name" -f "$env_file"
    fi

    # Activate micromamba environment if available
    if command -v micromamba &> /dev/null
    then
        export MAMBA_ROOT_PREFIX="${MAMBA_ROOT_PREFIX:=$HOME/micromamba}"
        eval "$(micromamba shell hook --shell bash)"

        if [ -d "$MAMBA_ROOT_PREFIX/envs/$env_name" ]
        then
            micromamba activate "$env_name"
        fi
    fi

    snakemake $snake_args \
        --profile 'src/profiles/slurm' \
        --snakefile 'src/pipelines/net.snake' \
        --configfiles 'SAMPLES.yaml' 'src/configs/net.yaml' 'src/configs/pauses.yaml' \
        --singularity-prefix "/beevol/home/${USER}/.singularity_cache" \
        --config SSH_KEY_DIR="$ssh_key_dir"
}


# Run the pipeline
function_def=$(declare -f run_snakemake)

export install
export dry_run
export function_def

sbatch \
    --job-name='NET-seq' \
    --output='logs/net_%j.out' \
    --error='logs/net_%j.err' \
    --mem=4G \
    --nodes=1 \
    --ntasks=1 \
    --partition=normal \
    --qos=normal \
    --time='1-00:00:00' <<EOF
#! /usr/bin/env bash

set -o nounset -o pipefail -o errexit -x

$function_def

run_snakemake \
    "$install" \
    "$dry_run" \
    'snakemake' \
    'env/snakemake.yml' \
    "$HOME/.ssh"
EOF