# Smart Contract-based Decentralized Federated Learning (Using Flower Framework)

This is a prototype of a decentralized federated learning framework built on smart contracts. It utilizes [Flower](https://github.com/adap/flower/tree/main) as the foundational framework for federated learning and integrates with a smart contract I designed ([FLContract.sol](https://github.com/Jeff07014/sc-based_FL/blob/master/src/contract/FLContract.sol)). The training algorithm for the model is the [XGBoost example](https://github.com/adap/flower/tree/main/examples/xgboost-comprehensive) provided by Flower.

## Main Concept of This Project

In traditional federated learning, a central server is responsible for aggregating the trained models, which can introduce several issues due to its centralized structure. However, the training process in this project differs from conventional federated learning. **I have transferred the aggregation tasks to the clients participating in the training through smart contracts.** Each client can verify the correctness of the aggregation results for each round and cast votes. This allows them to reach a consensus on the model aggregation outcomes, achieving a decentralized effect.

## Training Steps
1. Deploy the FLContract and upload the initial global model weights.
2. Clients join the training process.
3. Clients download the global model weights and begin training with their local datasets.
4. Clients upload their local model weights to the FLContract.
5. Clients download all local model weights from the FLContract and perform aggregation.
6. Select a client to upload the aggregated global model weights.
7. Other clients download the new global model weights to verify the correctness of the aggregated results and vote to approve them.
8. Upon approval, initiate a new training round.

## Set up
Clone this repo:

```bash
git clone https://github.com/Jeff07014/sc-based_FL.git
```
Build hardhat for test blockchain network:

```bash
cd hardhat
sudo docker build -t hardhat .
sudo docker run -p 8545:8545 hardhat
```
Build the training environment:

```bash
cd src
sudo docker build -t fed_app .
```

Deploy the FLContract (currently in src/training/strategy/ and soon to be relocated to src/initial):

```python
python test_chain_func.py
```

## Training
After deploying the FLContract, you can begin the training process. The following command demonstrates a setup for two clients:

```bash
sudo docker run --name="app1" --network="host" -t fed_app -c 'fl_contract="ADDRESS_OF_YOUR_FLCONTRACT" rpc_url="http://localhost:8545" priv_key="ACCOUNT_PRIVATE_KEY_GENERATED_BY_HARDHAT" partition_id=0 num_partitions=2'
```
```bash
sudo docker run --name="app2" --network="host" -t fed_app -c 'fl_contract="ADDRESS_OF_YOUR_FLCONTRACT" rpc_url="http://localhost:8545" priv_key="ACCOUNT_PRIVATE_KEY_GENERATED_BY_HARDHAT" partition_id=1 num_partitions=2'
```
You can train with many clients. (if your memory is enough)
