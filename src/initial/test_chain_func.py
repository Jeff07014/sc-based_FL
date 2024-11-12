from ..training.fedchain import ChainFunc
from solcx import install_solc, compile_files
import json
from web3 import Web3

install_solc(version='0.8.27')
max_size = 8192
account_private_key = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80' # cli
url = "http://0.0.0.0:8545"

# with open('../contract/FLContract.sol') as f:
#     flc = f.read()
compiled_sol = compile_files(['../contract/FLContract.sol'], output_values=['abi', 'bin'], solc_version='0.8.27')
FLContract, TrainingContract = compiled_sol.keys()
bytecode = compiled_sol[FLContract]['bin']
abi = compiled_sol[FLContract]['abi']
with open('../contract/abi.json', 'w') as f:
    f.write(json.dumps(abi))

w3 = Web3(Web3.HTTPProvider(endpoint_uri=url, request_kwargs={'timeout':600}))
w3.eth.default_account = w3.eth.accounts[0]
FLContract = w3.eth.contract(abi=abi, bytecode=bytecode)
tx_hash = FLContract.constructor(3, 10, 8192).transact()

tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
contract_addr = tx_receipt.contractAddress

chain_func = ChainFunc(url, contract_addr, account_private_key)

################################
with open('../initial/init_model', 'rb') as f:
    weight = f.read()

chain_func.init_global_model(weight)
g = chain_func.get_global_weight()

print(True if g == weight else False)
#################################

# chain_func.join_training()
