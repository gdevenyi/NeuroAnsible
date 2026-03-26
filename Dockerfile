# NeuroAnsible Dockerfile
#
# This Dockerfile builds a complete neuroimaging workstation environment
# using Ansible for deployment automation.
#
# Build arguments:
#   UBUNTU_VERSION - Ubuntu base version (default: 24.04)
#   ANSIBLE_TAGS   - Ansible tags to skip/include (default: --skip-tags resources)
#   BUILD_DATE     - Build timestamp for reproducibility
#   VCS_REF        - Git commit SHA for traceability
#
# Environment:
#   APPTAINER_TMPDIR  - Temp directory for Apptainer/Singularity
#   QUARANTINE_PATH   - Path to installed software
#   MODULEPATH        - Path to Lmod module files
#
# Usage:
#   docker build -t neuroansible:latest .
#   docker run -it --rm neuroansible:latest /bin/bash
#
# Build with resources (~110GB):
#   docker build --build-arg ANSIBLE_TAGS="" -t neuroansible:full .

# Build-time arguments for customization and reproducibility
ARG UBUNTU_VERSION=24.04
ARG ANSIBLE_TAGS="--skip-tags resources"
ARG BUILD_DATE=${BUILD_DATE:-}
ARG VCS_REF=${VCS_REF:-}

FROM docker.io/willhallonline/ansible:2.16-ubuntu-${UBUNTU_VERSION}

# Redeclare build args to make them available after FROM
ARG ANSIBLE_TAGS
ARG UBUNTU_VERSION
ARG BUILD_DATE
ARG VCS_REF

# OCI Image Metadata - Enables image tracking and automation
LABEL maintainer="Gabriel Devenyi Consulting <consulting@gabriel.devenyi.ca>" \
      description="NeuroAnsible - Complete neuroimaging workstation deployment" \
      version="1.0" \
      org.opencontainers.image.title="NeuroAnsible" \
      org.opencontainers.image.description="Complete neuroimaging workstation in a container" \
      org.opencontainers.image.version="1.0" \
      org.opencontainers.image.authors="consulting@gabriel.devenyi.ca" \
      org.opencontainers.image.source="https://github.com/gdevenyi/NeuroAnsible" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}"

# Set working directory
WORKDIR /opt/NeuroAnsible

# Copy NeuroAnsible codebase (frequently changes - after dependencies for caching)
COPY . .

# Set environment variables
ENV APPTAINER_TMPDIR=/scratch
ENV QUARANTINE_PATH=/opt/quarantine
ENV MODULEPATH=/opt/quarantine/modulefiles

# Create required directories for deployment
RUN mkdir -p ${APPTAINER_TMPDIR} ${QUARANTINE_PATH} ${MODULEPATH}

RUN echo ${ANSIBLE_TAGS}

# Update package lists and run Ansible playbook
RUN ansible-galaxy role install mambaorg.micromamba && \
    ansible-playbook -i inventory deploy.yml ${ANSIBLE_TAGS} && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Verify deployment completed successfully
RUN test -d /opt/quarantine/software && \
    test -d /opt/quarantine/modulefiles || \
    (echo "ERROR: Deployment failed - directories not found" && exit 1)

# Display deployment summary and verify installation
RUN echo "=== NeuroAnsible Deployment Summary ===" && \
    echo "Software installed in: /opt/quarantine/software" && \
    echo "Module files in: /opt/quarantine/modulefiles" && \
    echo "" && \
    echo "Installed software:" && \
    ls -la /opt/quarantine/software/ && \
    echo "" && \
    echo "NeuroAnsible deployment completed successfully"

WORKDIR /opt/NeuroAnsible
CMD ["/bin/bash"]
