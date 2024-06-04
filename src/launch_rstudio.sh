#! /usr/bin/env bash

#BSUB -n 12
#BSUB -J rstudio
#BSUB -o '../logs/rstudio.out'
#BSUB -e '../logs/rstudio.err'
#BSUB -R 'rusage[mem=16] span[hosts=1]'
#BSUB -W 23:59

# This will start rstudio-server in a singularity container
# adapted from @kriemo

singularity_sif_file='docker://rmsheridan/find-pauses:latest'
r_user_lib_path='/opt/conda/envs/find-pauses/lib/R/library'

max_n_cores=$(grep 'processor' '/proc/cpuinfo' | wc -l)

# Create temporary directory to be populated with directories to bind-mount in the container
# where writable file systems are necessary. Adjust path as appropriate for your computing environment.
workdir=$(python -c 'import tempfile; print(tempfile.mkdtemp())')

mkdir -p -m 700 "${workdir}/run" "${workdir}/tmp" "${workdir}/var/lib/rstudio-server"

cat > "${workdir}/database.conf" <<END
provider=sqlite
directory=/var/lib/rstudio-server
END

# Set OMP_NUM_THREADS to prevent OpenBLAS (and any other OpenMP-enhanced
# libraries used by R) from spawning more threads than the number of processors
# allocated to the job.
#
# Set R_LIBS_USER to a path specific to rocker/rstudio to avoid conflicts with
# personal libraries from any R installation in the host environment
cat > "${workdir}/rsession.sh" <<END
#! /usr/bin/env bash

export OMP_NUM_THREADS=${max_n_cores}
export R_LIBS_USER='${r_user_lib_path}'

exec /usr/lib/rstudio-server/bin/rsession "\${@}"
END

chmod +x "${workdir}/rsession.sh"

export SINGULARITY_BIND="${workdir}/run:/run,${workdir}/tmp:/tmp,${workdir}/database.conf:/etc/rstudio/database.conf,${workdir}/rsession.sh:/etc/rstudio/rsession.sh,${workdir}/var/lib/rstudio-server:/var/lib/rstudio-server"

# Do not suspend idle sessions.
# Alternative to setting session-timeout-minutes=0 in /etc/rstudio/rsession.conf
# https://github.com/rstudio/rstudio/blob/v1.4.1106/src/cpp/server/ServerSessionManager.cpp#L126
export SINGULARITYENV_RSTUDIO_SESSION_TIMEOUT=0
export SINGULARITYENV_USER=$(id -un)
export SINGULARITYENV_PASSWORD=$(openssl rand -base64 15)

# Get unused socket per https://unix.stackexchange.com/a/132524
# tiny race condition between the python & singularity commands
readonly PORT=$(python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')

cat 1>&2 <<END
1. SSH tunnel from your workstation using the following command:

   ssh -N -L 8787:${HOSTNAME}:${PORT} ${SINGULARITYENV_USER}@LOGIN-HOST

   and point your web browser to http://localhost:8787

2. log in to RStudio Server using the following credentials:

   user: ${SINGULARITYENV_USER}
   password: ${SINGULARITYENV_PASSWORD}

When done using RStudio Server, terminate the job by:

1. Exit the RStudio Session ("power" button in the top right corner of the RStudio window)
2. Issue the following command on the login node:

   bkill ${LSB_JOBID}
END

singularity exec --cleanenv "$singularity_sif_file" /bin/bash <<END
source /opt/conda/bashrc

micromamba activate find-pauses

rserver --www-port ${PORT} \
        --server-user ${USER} \
        --auth-none=0 \
        --auth-pam-helper-path=pam-helper \
        --auth-stay-signed-in-days=30 \
        --auth-timeout-minutes=0 \
        --rsession-path=/etc/rstudio/rsession.sh
END

printf 'rserver exited' 1>&2


