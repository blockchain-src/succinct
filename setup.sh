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
    
    # Get driver version from nvidia-smi
    driver_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | cut -d. -f1)
    print_message "Current NVIDIA Driver Version: $driver_version"
    
    if [ -z "$driver_version" ] || [ "$driver_version" -lt 555 ]; then
        print_message "Driver version $driver_version is below required 555 (for CUDA 12.5)"
        return 1
    fi
    
    print_message "Driver version $driver_version meets requirements (for CUDA 12.5+)"
    return 0
}

# Function to check if all requirements are installed
check_requirements_installed() {
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        return 1
    fi

    # Check if NVIDIA Container Toolkit is installed
    if ! dpkg -l | grep -q nvidia-container-toolkit; then
        return 1
    fi

    # Check if NVIDIA driver version meets requirements
    if ! check_cuda_version; then
        return 1
    fi

    return 0
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then 
    print_message "Please run as root (use sudo)"
    exit 1
fi

# Set noninteractive frontend
export DEBIAN_FRONTEND=noninteractive

# Perform installations only if requirements are not fully met
if ! check_requirements_installed; then
    # Update and upgrade the system
    print_message "Updating and upgrading system packages..."
    apt update && apt upgrade -y
    check_status "System update and upgrade"

    # Install additional packages from the second script
    print_message "Installing additional packages..."
    apt install -y curl openssl iptables build-essential protobuf-compiler git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev tar clang bsdmainutils ncdu unzip libleveldb-dev libclang-dev ninja-build
    check_status "Additional packages installation"
fi

# Install Docker if not already installed
if ! command -v docker &> /dev/null; then
    print_message "Docker not found. Installing Docker..."
    # Remove any conflicting packages
    for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do apt-get remove -y $pkg || true; done

    # Install prerequisites
    apt install -y ca-certificates curl gnupg software-properties-common
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Add Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Update and install Docker
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    check_status "Docker installation"

    # Start and enable Docker service
    systemctl start docker
    systemctl enable docker
    check_status "Docker service setup"

    # Add current user to docker group if not already added
    if ! groups $SUDO_USER | grep -q docker; then
        print_message "Adding user to docker group..."
        usermod -aG docker $SUDO_USER
        check_status "Adding user to docker group"
        print_message "Note: Docker group changes will take effect after next login or reboot"
    fi

    # Verify Docker is working
    print_message "Verifying Docker installation..."
    docker run hello-world > /dev/null 2>&1
    check_status "Docker verification"
else
    print_message "Docker already installed, skipping Docker installation"
    
    # Verify Docker group membership
    if ! groups $SUDO_USER | grep -q docker; then
        print_message "Adding user to docker group..."
        usermod -aG docker $SUDO_USER
        check_status "Adding user to docker group"
        print_message "Note: Docker group changes will take effect after next login or reboot"
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
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
        && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    check_status "Repository setup"

    # Update package list and install
    apt-get update
    apt-get install -y nvidia-container-toolkit
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

    # Install essential packages
    print_message "Installing build essential and headers..."
    apt install -y build-essential linux-headers-$(uname -r)
    check_status "Essential packages installation"

    # Remove existing NVIDIA installations
    print_message "Removing existing NVIDIA installations..."
    apt remove -y nvidia-* --purge || true
    apt autoremove -y
    check_status "NVIDIA cleanup"

    # Add NVIDIA repository
    print_message "Adding NVIDIA repository..."
    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb -O
    dpkg -i cuda-keyring_1.1-1_all.deb
    apt update
    check_status "NVIDIA repository setup"

    # Install latest NVIDIA driver and CUDA
    print_message "Installing latest NVIDIA driver and CUDA..."
    apt install -y cuda-drivers
    check_status "NVIDIA driver and CUDA installation"

    print_message "NVIDIA drivers installed. System needs to reboot."
    print_message "Please run this script again after reboot to complete the setup."
    sleep 10
    reboot
fi

# Pull Succinct Prover Docker image
print_message "Pulling Succinct Prover Docker image..."
docker pull public.ecr.aws/succinct-labs/spn-node:latest-gpu
check_status "Docker image pull"

print_message "Setup complete! All system requirements are installed."
