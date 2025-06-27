# Succinct Prover Guide

## Hardware Requirements:
**Minimal Setup**
* CPU: 8 cores or more
* Memory: 16GB+
* NVIDIA GPU (e.g., RTX 4090, L4, A10G)

---

### Software
* Supported: Ubuntu 20.04/22.04/24.04
* NVIDIA Driver: 555+
* If you are running on Windows os locally, install Ubuntu 22 WSL using this [Guide](https://github.com/0xmoei/Install-Linux-on-Windows)

---

## Rent GPU

**Recommended GPU Providers**
* **[Vast.ai](https://cloud.vast.ai/?ref_id=62897&creator_id=62897&name=Ubuntu%2022.04%20VM)**: SSH-Key needed
  * Rent **VM Ubuntu** [template](https://cloud.vast.ai/?ref_id=62897&creator_id=62897&name=Ubuntu%2022.04%20VM)
  * Refer to this [Guide](https://github.com/0xmoei/Rent-and-Config-GPU) to generate SSH-Key, Rent GPU and connect to your Vast GPU

---

## Prover Setup
* 1- Create a Prover in [Succinct Staking Dashboard](https://staking.sepolia.succinct.xyz/prover) on Sepolia network
* 2- Save your prover 0xaddress under *My Prover*
* 3- Stake $PROVE token on your Prover [here](https://staking.sepolia.succinct.xyz/)
* 4- You can add a new signer wallet (fresh wallet) in [prover interface](https://staking.sepolia.succinct.xyz/prover) to your prover since you have to input the privatekey into the CLI

---

## Dependecies
### Update Packages
```
sudo apt update && sudo apt upgrade -y
```

### Install Packages
```
apt install curl  openssl iptables build-essential protobuf-compiler git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev tar clang bsdmainutils ncdu unzip libleveldb-dev libclang-dev ninja-build linux-headers-$(uname -r) -y
```

### Install Docker
```bash
sudo apt update -y && sudo apt upgrade -y
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove $pkg; done

sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update -y && sudo apt upgrade -y

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Test Docker
sudo docker run hello-world

sudo systemctl enable docker
sudo systemctl restart docker
```

### Install Nvidia Driver & CUDA
Verify if installed: `nvidia-smi`

* If not installed:
```
sudo apt update
ubuntu-drivers list --gpgpu
sudo ubuntu-drivers install --gpgpu nvidia-driver-575
sudo apt install -y nvidia-utils-575

# Verify
nvidia-smi
```

### Install Nvidia Container Toolkit
Verify if installed: `dpkg -l | grep nvidia-container-toolkit`

* If not installed:
```console
# Set up the NVIDIA Container Toolkit repository and GPG key
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
    && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# Update the package list and install the toolkit
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

dpkg -l | grep nvidia-container-toolkit
```






```
docker run \
    --gpus all \
    --network host \
    -e NETWORK_PRIVATE_KEY="$PRIVATE_KEY" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    public.ecr.aws/succinct-labs/spn-node:latest-gpu \
    calibrate \
    --usd-cost-per-hour 0.80 \
    --utilization-rate 0.5 \
    --profit-margin 0.1 \
    --prove-price 1.00
```


This will output calibration results that look like the following:
```
Parameters:
┌──────────────────┬────────┐
│ Parameter        │ Value  │
├──────────────────┼────────┤
│ Cost Per Hour    │ $0.80  │
├──────────────────┼────────┤
│ Utilization Rate │ 50.00% │
├──────────────────┼────────┤
│ Profit Margin    │ 10.00% │
├──────────────────┼────────┤
│ Price of $PROVE  │ $1.00  │
└──────────────────┴────────┘

Starting calibration...

Calibration Results:
┌──────────────────────┬─────────────────────────┐
│ Metric               │ Value                   │
├──────────────────────┼─────────────────────────┤
│ Estimated Throughput │ 1742469 PGUs/second     │
├──────────────────────┼─────────────────────────┤
│ Estimated Bid Price  │ 0.28 $PROVE per 1B PGUs │
└──────────────────────┴─────────────────────────┘
```


This tells you that your prover can prove 1742469 prover gas units (PGUs) per second and that you should bid 0.28 $PROVE per 1B PGUs for proofs.


Set Prover parameters:
```
export PGUS_PER_SECOND=<PGUS_PER_SECOND>
export PROVE_PER_BPGU=<PROVE_PER_BPGU>
export PROVER_ADDRESS=<PROVER_ADDRESS>
export PRIVATE_KEY=<PRIVATE_KEY>
```
* Replace the values and execute the commands


Run
```
docker run --gpus all \
    --device-cgroup-rule='c 195:* rmw' \
    --network host \
    -e NETWORK_PRIVATE_KEY=$PRIVATE_KEY \
    -v /var/run/docker.sock:/var/run/docker.sock \
    public.ecr.aws/succinct-labs/spn-node:latest-gpu \
    prove \
    --rpc-url https://rpc.sepolia.succinct.xyz \
    --throughput $PGUS_PER_SECOND \
    --bid $PROVE_PER_BPGU \
    --private-key $PRIVATE_KEY \
    --prover $PROVER_ADDRESS
```
