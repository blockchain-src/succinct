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
 
Also saw people mentioning [GenesisCloud](https://id.genesiscloud.com/signin/) & [Tensordock](https://dashboard.tensordock.com/deploy) that I am not using them due to not supporting cryptocurrencies

---

## Prover Setup
* 1- Create a Prover in [Succinct Staking Dashboard](https://staking.sepolia.succinct.xyz/prover) on Sepolia network
* 2- Save your prover 0xaddress under *My Prover*
* 3- Stake $PROVE token on your Prover [here](https://staking.sepolia.succinct.xyz/)
* 4- You can add a new signer wallet (fresh wallet) in [prover interface](https://staking.sepolia.succinct.xyz/prover) to your prover since you have to input the privatekey into the CLI


* Note: I'm currently proving with less than 1000 $PROVE tokens staked while team says you need 1000 tokens, I'm experimenting things and will update this.

---

## Dependecies
### Update Packages
```
sudo apt update && sudo apt upgrade -y
sudo apt install git -y
```

### Clone Repo
```
git clone https://github.com/0xmoei/succinct

cd succinct
```

### Install Dependecies
```
chmod +x setup.sh
./setup.sh
```

---

## Setup Prover
Copy .env from example
```bash
cp .env.example .env
```
Edit `.env`:
```
nano .env
```
* Replace the variables with your own values.
* `PGUS_PER_SECOND` & `PROVE_PER_BPGU`: Keep default values, or go through [Calibrate](#calibrate-prover) section to configure them.

---

## Calibrate Prover
The prover needs to be calibrated to your hardware in order to configure key parameters that govern its behavior. There are two key parameters that need to be set:
* **Bidding Price (`PROVE_PER_BPGU`)**: This is the price per proving gas unit (PGU) that the prover will bid for. This determines the profit margin of the prover and it's competitiveness with the rest of the network.
* **Expected Throughput(`PGUS_PER_SECOND`)**: This is an estimate of the prover's proving throughput in PGUs per second. This is used to estimate whether a prover can complete a proof before its deadline.
```
docker run --gpus all \
    --device-cgroup-rule='c 195:* rmw' \
    --name spn-callibrate \
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
* This tells you that your prover can prove 1742469 prover gas units (PGUs) per second and that you should bid 0.28 $PROVE per 1B PGUs for proofs.
* Now you can set `PGUS_PER_SECOND` & `PROVE_PER_BPGU` based on your callibration in `.env` file
* Although, you can keep `PROVE_PER_BPGU` as low as `1.01` to prove more requests with less income

After Callibration, delete its docker container:
```
docker rm spn-callibrate
```

---

## Run Prover
```console
# Ensure you are in succinct directory
cd succinct

# Run
docker compose up -d
```

---

## Prover Logs
```console
# Logs
docker compose logs -f

# Last 100 logs
docker compose logs -fn 100
```

When looking for a request:

![image](https://github.com/user-attachments/assets/9945cdd4-0b99-4dfd-ad75-ad156bc6410e)


When proving a request:

![image](https://github.com/user-attachments/assets/596d1c1a-213c-4d71-8585-58a2e5439f92)


### Common Errors
> 1- docker: Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?

* Make sure your server runs Ubuntu VM.


> 2- ERROR:  Permanent error encountered when Bid: request is not in the requested state (Client specified an invalid argument)
>
> 3- ERROR  Permanent error encountered when Bid: Timeout expired (The operation was cancelled)

* Normal errors due to network or your prover's behaviour.


---

## Stop Prover
```console
docker stop sp1-gpu succinct-spn-node-1
docker rm sp1-gpu succinct-spn-node-1
```

---

I will update the guide with more optimization soon.
