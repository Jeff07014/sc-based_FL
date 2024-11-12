from de_fed import ChainFunc
from solcx import install_solc, compile_files
import json
from web3 import Web3
import compress_pickle
from de_fed import DeFed
import compress_pickle

install_solc(version='0.8.27')
max_size = 8192
account_private_key = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80' # cli
url = "http://0.0.0.0:8545"

# with open('../contract/FLContract.sol') as f:
#     flc = f.read()
compiled_sol = compile_files(['../../contract/FLContract.sol'], output_values=['abi', 'bin'], solc_version='0.8.27')
FLContract, TrainingContract = compiled_sol.keys()
bytecode = compiled_sol[FLContract]['bin']
abi = compiled_sol[FLContract]['abi']
with open('../../contract/abi.json', 'w') as f:
    f.write(json.dumps(abi))

w3 = Web3(Web3.HTTPProvider(endpoint_uri=url, request_kwargs={'timeout':600}))
w3.eth.default_account = w3.eth.accounts[0]
FLContract = w3.eth.contract(abi=abi, bytecode=bytecode)
tx_hash = FLContract.constructor(2, 10, 8192).transact()

tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
contract_addr = tx_receipt.contractAddress
print(f'contract address: {contract_addr}')

chain_func = ChainFunc(url, contract_addr, account_private_key, '../../contract/abi.json')

################################
with open('../../initial/init_model', 'rb') as f:
    weight = f.read()

chain_func.init_global_model(weight)
chain_func.init_done()
weight = compress_pickle.loads(weight, 'bz2')
g = chain_func.get_global_weight()

print(True if g == weight else False)
#################################

# priv_key = '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d'
# fc = FedChain(url, contract_addr, priv_key)
# fc.chain_func.join_training()
# fc.chain_func.upload_weight(b'0x1234')
# w = fc.chain_func.get_local_weights()
# print(fc.chain_func.is_aggregator())
