# Use a minimal Ubuntu base image
FROM rocker/rstudio:latest

# No prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install wget, curl, ca-certificates, and build essentials
# everything before vim was recommended for singularity
RUN apt-get update && apt-get install -y --no-install-recommends \
    vim \
    wget \
    git \
    curl \
    unzip \
    locales \
    openssh-client \
    ca-certificates \
    build-essential \
    libffi-dev \
    libssl-dev \
    zlib1g-dev && \
    apt-get clean && \
    apt-get autoremove --yes && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# Install micromamba
RUN curl -sL https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xj && \
    chmod +x /bin/micromamba && \
    /bin/micromamba shell init -s bash -p /opt/conda && \
    touch /root/.bashrc && \
    mkdir -p /opt/conda && \
    grep -v '[ -z "$PS1" ] && return' /root/.bashrc > /opt/conda/bashrc

# Copy the environment.yml file into the container
COPY environment.yml .

# Create micromamba environment with environment.yml
# this works better when creating a new environment as opposed to updating base
SHELL ["/bin/bash", "-l" ,"-c"]

RUN source /opt/conda/bashrc && \
    micromamba create -n find-pauses -f environment.yml && \
    micromamba clean --all --yes

# Set environment variables
ENV PATH="/opt/conda/envs/find-pauses/bin:$PATH"
ENV MAMBA_ROOT_PREFIX="/opt/conda"

# Set up locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Install R packages
COPY renv.lock .

RUN source /opt/conda/bashrc && \
    micromamba activate find-pauses && \
    Rscript -e "install.packages('renv', repos = 'http://cran.rstudio.com')" && \
    Rscript -e "renv::restore(lockfile = 'renv.lock')"

# Activate the environment in ENTRYPOINT
ENTRYPOINT ["/bin/bash", "-c", "source /opt/conda/bashrc && micromamba activate find-pauses && exec bash"]


