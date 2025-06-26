# Succinct Prover Guide


## Hardware Requirements:
**Minimal Setup**
* CPU: 8 cores or more
* Memory: 16GB+
* Optional: NVIDIA GPU (e.g., RTX 4090, L4, A10G)


**Competitive Setup (Optimized)**
* Nodes: 64+ prover instances
* Hardware: Multiple high-end NVIDIA GPUs (e.g., RTX 4090, L40s)
* CPU: 16+ cores per GPU
* Memory: 16GB+ per GPU

> Currently People are already proving with single 3090 GPUs.



Onchain Requirements
* A fresh Ethereum wallet with Sepolia ETH
* At least 1000 $PROVE tokens


## Install Dependecies
### Update Packages
```
apt update && apt upgrade -y
```

### Install Packages
```
apt install curl  openssl iptables build-essential protobuf-compiler git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev tar clang bsdmainutils ncdu unzip libleveldb-dev libclang-dev ninja-build -y
```

### Install Rust
```console
# Install rustup:
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
. "$HOME/.cargo/env"
source $HOME/.cargo/env

# Update rustup:
rustup update

# Install the Rust Toolchain:
apt update
apt install cargo

# Unset Rust Toolchain variable
unset RUSTUP_TOOLCHAIN
```

### Instal Succinct Rust Toolchain
```console
curl -L https://sp1up.succinct.xyz | bash

source /root/.bashrc

sp1up

# Verify installation:
RUSTUP_TOOLCHAIN=succinct cargo --version
```


```
git clone https://github.com/succinctlabs/network.git
cd network
```

Build:
```
cd bin/node
RUSTFLAGS="-C target-cpu=native" cargo build --release
```

We provide a Dockerfile for building the prover on CPU and GPU.

To build the image from source, navigate to the root of the repository and run the following for CPU:

go to repo main directory (`/network`)
```
cd ../..
```

```
docker build --target cpu -t spn-node:latest-cpu .
```
and the following for GPU:
```
docker build --target gpu -t spn-node:latest-gpu .
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
