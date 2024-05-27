# Use a minimal Ubuntu base image
FROM --platform=linux/amd64 ubuntu:22.04

# No prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install wget, curl, ca-certificates, and build essentials
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    curl \
    unzip \
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
ENV PATH="/opt/conda/bin:$PATH"
ENV MAMBA_ROOT_PREFIX="/opt/conda"

# # Install R packages
# COPY renv.lock .
# 
# RUN source /opt/conda/bashrc && \
#     micromamba activate base && \
#     Rscript -e "install.packages('renv', repos = 'http://cran.rstudio.com')" && \
#     Rscript -e "renv::restore(lockfile = 'renv.lock')"

# # Create .bashrc file to activate environment
# RUN echo "source /opt/conda/etc/profile.d/micromamba.sh && micromamba activate base" >> /root/.bashrc

# Activate the environment in ENTRYPOINT
ENTRYPOINT ["/bin/bash", "-c", "source /opt/conda/bashrc && micromamba activate find-pauses && exec bash"]
