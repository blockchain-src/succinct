#!/bin/bash

# Exit on any error
set -e

# Function to print messages
print_message() {
    echo "===> $1"
}

# Function to check if command was successful
check_status() {
    if [ $? -eq 0 ]; then
        print_message "Success: $1"
    else
        print_message "Error: $1 failed"
        exit 1
    fi
}

# Function to check CUDA version
check_cuda_version() {
    if ! command -v nvidia-smi &> /dev/null; then
        print_message "nvidia-smi not found"
        return 1
    fi
    
    # Get driver version from nvidia-smi, take only the first line
    driver_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n1 | cut -d. -f1)
    print_message "Current NVIDIA Driver Version: $driver_version"
    
    if [ -z "$driver_version" ]; then
        print_message "Unable to determine driver version"
        return 1
    fi
    
    if [ "$driver_version" -lt 555 ]; then
        print_message "Driver version $driver_version is below required 555 (for CUDA 12.5)"
        return 1
    fi
    
    print_message "Driver version $driver_version meets requirements (for CUDA 12.5+)"
    return 0
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then 
    print_message "Please run as root (use sudo)"
    exit 1
fi

# Set noninteractive frontend
export DEBIAN_FRONTEND=noninteractive

# Install additional packages
print_message "Installing additional packages..."
apt update
apt install -y curl openssl iptables build-essential protobuf-compiler git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev tar clang bsdmainutils ncdu unzip libleveldb-dev libclang-dev ninja-build
check_status "Additional packages installation"

# Install Docker if not already installed
if ! command -v docker &> /dev/null; then
    print_message "Docker not found. Installing Docker..."
    # Remove any conflicting packages
    for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do apt remove -y $pkg || true; done

    # Install prerequisites
    apt install -y ca-certificates curl gnupg software-properties-common
    check_status "Docker prerequisites installation"
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    check_status "Docker GPG key setup"
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Add Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    check_status "Docker repository setup"

    # Update and install Docker
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    check_status "Docker installation"

    # Start and enable Docker service
    systemctl start docker
    systemctl enable docker
    check_status "Docker service setup"

    # Add current user to docker group if not already added
    if [ -z "$SUDO_USER" ]; then
        print_message "Error: SUDO_USER is not set. Please run the script with sudo'sudo'."
        exit 1
    fi
    if ! groups "$SUDO_USER" | grep -q docker; then
        print_message "Adding user $SUDO_USER to docker group..."
        usermod -aG docker "$SUDO_USER"
        check_status "Adding user to docker group"
        print_message "Note: Log out and back in, or run 'newgrp docker' to apply group changes."
    fi

    # Verify Docker is working
    print_message "Verifying Docker installation..."
    docker run hello-world > /dev/null 2>&1
    check_status "Docker verification"
else
    print_message "Docker already installed, skipping Docker installation"
    
    # Verify Docker group membership
    if [ -z "$SUDO_USER" ]; then
        print_message "Error: SUDO_USER is not set. Please run the script with sudo."
        exit 1
    fi
    if ! groups "$SUDO_USER" | grep -q docker; then
        print_message "Adding user $SUDO_USER to docker group..."
        usermod -aG docker "$SUDO_USER"
        check_status "Adding user to docker group"
        print_message "Note: Log out and back in, or run 'newgrp docker' to apply group changes."
    fi

    # Verify Docker is working
    print_message "Verifying Docker installation..."
    docker ps -a > /dev/null 2>&1
    check_status "Docker verification"
fi

# Install NVIDIA Container Toolkit if not already installed
if ! dpkg -l | grep -q nvidia-container-toolkit; then
    print_message "Installing NVIDIA Container Toolkit..."
    
    # Set up the NVIDIA Container Toolkit repository and GPG key
    print_message "Setting up NVIDIA Container Toolkit repository..."
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    check_status "NVIDIA Container Toolkit GPG key setup"
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    check_status "NVIDIA Container Toolkit repository setup"

    # Update package list and install
    apt update
    apt install -y nvidia-container-toolkit
    check_status "NVIDIA Container Toolkit installation"

    # Configure Docker to use NVIDIA Container Runtime
    print_message "Configuring Docker to use NVIDIA Container Runtime..."
    nvidia-ctk runtime configure --runtime=docker
    systemctl restart docker
    check_status "Docker runtime configuration"
else
    print_message "NVIDIA Container Toolkit already installed, skipping installation"
fi

# Check CUDA version and install/update NVIDIA drivers if necessary
if ! check_cuda_version; then
    print_message "Installing/Updating NVIDIA drivers to support CUDA 12.5 or higher..."
    
    # Update system
    print_message "Updating system packages..."
    apt update
    check_status "System update"

    # Remove existing NVIDIA installations
    print_message "Removing existing NVIDIA installations..."
    apt remove -y nvidia-* --purge || true
    apt autoremove -y
    check_status "NVIDIA cleanup"

    # Add NVIDIA repository
    print_message "Adding NVIDIA repository..."
    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb -O
    check_status "NVIDIA repository key download"
    dpkg -i cuda-keyring_1.1-1_all.deb
    apt update
    check_status "NVIDIA repository setup"

    # Install latest NVIDIA driver and CUDA
    print_message "Installing latest NVIDIA driver and CUDA..."
    apt install -y cuda-drivers
    check_status "NVIDIA driver and CUDA installation"

    print_message "NVIDIA drivers installed. Please reboot the system to apply changes."
    sleep 5
fi

# Pull Succinct Prover Docker image
print_message "Pulling Succinct Prover Docker image..."
docker pull public.ecr.aws/succinct-labs/spn-node:latest-gpu
check_status "Docker image pull"

print_message "Setup complete! All system requirements are installed."
