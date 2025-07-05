# Succinct 证明者指南

## 硬件要求：
**最低配置**
* CPU：8核或以上
* 内存：16GB+
* NVIDIA GPU（如 RTX 4090、L4、A10G）

---

### 软件
* 支持系统：Ubuntu 20.04/22.04/24.04
* NVIDIA 驱动：555+
* 如果你在本地 Windows 系统上运行，请按照这个[指南](https://github.com/0xmoei/Install-Linux-on-Windows)安装 Ubuntu 22 WSL

---

## 证明者设置
* 1- 在 [Succinct Staking Dashboard](https://staking.sepolia.succinct.xyz/prover)（Sepolia 网络）创建一个 Prover
* 2- 在 *My Prover* 下保存你的 prover 0x 地址（钱包里只需保留极少量资金）
* 3- 在你的 Prover 上质押 $PROVE 代币 [点此质押](https://staking.sepolia.succinct.xyz/)
* 4- 你可以在 [prover 界面](https://staking.sepolia.succinct.xyz/prover)为你的 prover 添加一个新的签名钱包（新钱包），因为你需要在 CLI 中输入私钥

* 注意：我目前在只质押 140 个 $PROVE 代币的情况下进行证明，虽然官方说需要 1000 个代币，我正在实验，后续会更新此内容。

---

## 依赖项
### 克隆仓库
```
git clone https://github.com/blockchain-src/succinct.git && cd succinct
```

### 安装依赖
```
chmod +x setup.sh && sudo ./setup.sh
```

---

## 设置 Prover
编辑 `.env` 文件：
```
nano .env
```
* 用你自己的值替换变量。
* `PGUS_PER_SECOND` 和 `PROVE_PER_BPGU`：保持默认值，或参考[校准](#calibrate-prover)部分进行配置。

---

## 校准 Prover
Prover 需要根据你的硬件进行校准，以配置其行为的关键参数。需要设置两个关键参数：
* **竞价价格（`PROVE_PER_BPGU`）**：这是 prover 每个证明 gas 单位（PGU）的竞价价格。它决定了 prover 的利润率以及与网络其他 prover 的竞争力。
* **预期吞吐量（`PGUS_PER_SECOND`）**：这是 prover 每秒可处理的 PGU 数量的估算值，用于评估 prover 是否能在截止时间前完成证明。
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

这会输出类似如下的校准结果：
```
参数:
┌──────────────────┬────────┐
│ 参数             │ 值     │
├──────────────────┼────────┤
│ 每小时成本       │ $0.80  │
├──────────────────┼────────┤
│ 利用率           │ 50.00% │
├──────────────────┼────────┤
│ 利润率           │ 10.00% │
├──────────────────┼────────┤
│ $PROVE 价格      │ $1.00  │
└──────────────────┴────────┘

开始校准...

校准结果:
┌──────────────────────┬─────────────────────────┐
│ 指标                 │ 值                      │
├──────────────────────┼─────────────────────────┤
│ 估算吞吐量           │ 1742469 PGUs/秒         │
├──────────────────────┼─────────────────────────┤
│ 估算竞价价格         │ 0.28 $PROVE/1B PGUs     │
└──────────────────────┴─────────────────────────┘
```
* 这表示你的 prover 每秒可处理 1742469 个 PGU，建议每 10 亿 PGU 竞价 0.28 $PROVE。
* 现在你可以根据校准结果在 `.env` 文件中设置 `PGUS_PER_SECOND` 和 `PROVE_PER_BPGU`
* 当然，你也可以将 `PROVE_PER_BPGU` 设置为低至 `1.01`，以更低收入证明更多请求

校准后，删除该 docker 容器：
```
docker rm spn-callibrate
```

---

## 运行 Prover
```console
# 确保你在 succinct 目录下
cd succinct

# 运行
docker compose up -d
```

---

## Prover 日志
```console
# 查看日志
docker compose logs -f

# 查看最近 100 条日志
docker compose logs -fn 100
```

查找请求时：

![image](https://github.com/user-attachments/assets/9945cdd4-0b99-4dfd-ad75-ad156bc6410e)

正在证明请求时：

![image](https://github.com/user-attachments/assets/596d1c1a-213c-4d71-8585-58a2e5439f92)

### 常见错误
> 1- docker: 无法连接到 Docker 守护进程 unix:///var/run/docker.sock。Docker 守护进程是否正在运行？

* 确保你的服务器运行的是 Ubuntu 虚拟机。

> 2- ERROR:  Bid 时遇到永久性错误：请求未处于请求状态（客户端指定了无效参数）
>
> 3- ERROR  Bid 时遇到永久性错误：超时（操作被取消）

* 这些是由于网络或 prover 行为导致的正常错误。

---

## 停止 Prover
```console
docker stop sp1-gpu succinct-spn-node-1
docker rm sp1-gpu succinct-spn-node-1
```

---

## 通过 CLI 质押到 Prover
**1- 安装 Rust 和 foundry：**
```console
# 安装 Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# 安装 Foundry
curl -L https://foundry.paradigm.xyz | bash
source /$HOME/.bashrc
foundryup

# 检查 Foundry 版本
cast --version
```

**2- 质押命令：**

**授权（Approve）：**
```bash
cast send --rpc-url https://sepolia.drpc.org --private-key YOUR_PRIVATE_KEY 0x376099fd6B50B60FE8b24B909827C1795D6e5096 "approve(address,uint256)" 0x837D40650aB3b0AA02E7e28238D9FEA73031856C 10000000000000000000
```
* 替换上述命令中的以下内容：
  * `YOUR_PRIVATE_KEY`：你的 EVM 钱包私钥，钱包中有 $PROVE 代币（Sepolia ETH）
  * `100000000000000000000`：表示 `10` 个 $PROVE 代币，可自行修改

**质押（Stake）：**
```bash
cast send --rpc-url https://sepolia.drpc.org --gas-limit 200000000 --private-key YOUR_PRIVATE_KEY 0x837D40650aB3b0AA02E7e28238D9FEA73031856C "stake(address,uint256)" 0x24Fb606c055f28f2072EaFf2D63e16Ba01f48348 10000000000000000000
```
* 替换上述命令中的以下内容：
  * `YOUR_PRIVATE_KEY`：你的 EVM 钱包私钥，钱包中有 $PROVE 代币（Sepolia ETH）
  * `100000000000000000000`：表示 `10` 个 $PROVE 代币，可自行修改
  * `0x24Fb606c055f28f2072EaFf2D63e16Ba01f48348` 是我的 prover 地址，你可以替换为其他 prover 地址

**查询 $PROVE 余额**
```
cast call --rpc-url https://sepolia.drpc.org 0x376099fd6B50B60FE8b24B909827C1795D6e5096 "balanceOf(address)(uint256)" WALLET_ADDRESS
```
* 替换 `WALLET_ADDRESS` 为你的钱包地址

**查询已质押 $PROVE 余额**
```bash
cast call --rpc-url https://sepolia.drpc.org 0x837D40650aB3b0AA02E7e28238D9FEA73031856C "balanceOf(address)(uint256)" WALLET_ADDRESS
```
* 替换 `WALLET_ADDRESS` 为你的钱包地址

---

我会很快更新更多优化内容。
