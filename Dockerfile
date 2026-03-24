# Simple Dockerfile for NeuroAnsible deployment
ARG UBUNTU_VERSION=24.04

FROM ubuntu:${UBUNTU_VERSION}

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install Ansible
RUN apt-get update && \
    apt-get install -y --no-install-recommends software-properties-common curl ca-certificates git && \
    add-apt-repository --yes --update ppa:ansible/ansible && \
    apt-get install -y ansible && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /opt/NeuroAnsible

# Copy NeuroAnsible code
COPY . .

# Install Ansible Galaxy role
RUN ansible-galaxy role install mambaorg.micromamba

# Create required directories
RUN mkdir -p /scratch /opt/quarantine

# Set environment variables
ENV APPTAINER_TMPDIR=/scratch
ENV QUARANTINE_PATH=/opt/quarantine
ENV MODULEPATH=/opt/quarantine/modulefiles

# Allow customizing ansible tags via build argument
ARG ANSIBLE_TAGS=--skip-tags resources
ENV ANSIBLE_TAGS=${ANSIBLE_TAGS}
# Run deployment (default: skip resources to keep image size ~20GB)
RUN apt update && ansible-playbook -i inventory deploy.yml ${ANSIBLE_TAGS}

# Verify installation
RUN ls -la /opt/quarantine/software/ && \
    echo "NeuroAnsible deployment completed successfully"

WORKDIR /opt/NeuroAnsible
CMD ["/bin/bash"]
