from web3 import Web3
from flwr.server.strategy.fedxgb_bagging import FedXgbBagging
from flwr.common.logger import log
from flwr.server.client_proxy import ClientProxy
from flwr.server.client_manager import ClientManager
from typing import Optional, Union
from flwr.common import (
    Code,
    DisconnectRes,
    EvaluateIns,
    EvaluateRes,
    FitIns,
    FitRes,
    Parameters,
    ReconnectIns,
    Scalar,
)
from logging import WARNING, DEBUG, INFO
import json
import compress_pickle
from time import sleep

class ChainFunc():

    def __init__(
        self,
        url,
        contract_addr,
        private_key,
        abi_path = "abi.json",
    ):
        self.url = url
        self.priv_key = private_key
        self.w3 = Web3(Web3.HTTPProvider(endpoint_uri=url, request_kwargs={'timeout': 600}))
        with open(abi_path, 'r') as abi:
            contract_abi = json.loads(abi.read())
        self.fl_contract = self.w3.eth.contract(address=contract_addr, abi=contract_abi)
        self.account = self.w3.eth.account.from_key(private_key)
        self.max_size = self.fl_contract.functions.getMaxSize().call()

    def init_global_model(self, weight):
        size = len(weight)
        seg = size // self.max_size
        log(INFO, f'initialize global model weight... , txhash:')
        log(INFO, "")
        for i in range(seg):
            txhash = self.fl_contract.functions.initGlobalModel(weight[i * self.max_size:(i+1) * self.max_size]).transact({'from': self.account.address})
            log(INFO, f'        0x{txhash.hex()}')
        txhash = self.fl_contract.functions.initGlobalModel(weight[seg * self.max_size:size]).transact({'from': self.account.address})
        log(INFO, f'        0x{txhash.hex()}')

    def init_done(self):
        self.fl_contract.functions.initDone().transact({'from': self.account.address})
        log(INFO, "Initialization Done!")

    def join_training(self):
        value = self.fl_contract.functions.getDepositValue().call()
        self.fl_contract.functions.joinTraining().transact({'from': self.account.address, 'value': value})
        log(INFO, "Successfully join training process!")

    def upload_weight(self, weight):
        pic_weight = compress_pickle.dumps(weight, 'bz2')
        size = len(pic_weight)
        seg = size // self.max_size
        for i in range(seg):
            txhash = self.fl_contract.functions.localTraining(pic_weight[i * self.max_size:(i+1) * self.max_size]).transact({'from': self.account.address})
            log(INFO, f'upload local model weight... , txhash: 0x{txhash.hex()}')
        txhash = self.fl_contract.functions.localTraining(pic_weight[seg * self.max_size:size]).transact({'from': self.account.address})
        log(INFO, f'upload local model weight... , txhash: 0x{txhash.hex()}')

    def aggregate_ready(self):
        self.fl_contract.functions.aggregationReady().transact({'from': self.account.address})
        log(INFO, "Ready for aggregation!")

    def upload_aggregated_weight(self, weight):
        pic_weight = compress_pickle.dumps(weight, 'bz2')
        size = len(pic_weight)
        seg = size // self.max_size
        for i in range(seg):
            txhash = self.fl_contract.functions.saveGlobalModel(pic_weight[i * self.max_size:(i+1) * self.max_size]).transact({'from': self.account.address})
            log(INFO, f'upload global model weight... , txhash: 0x{txhash.hex()}')
        txhash = self.fl_contract.functions.saveGlobalModel(pic_weight[seg * self.max_size:size]).transact({'from': self.account.address})
        log(INFO, f'upload global model weight... , txhash: 0x{txhash.hex()}')

    def get_local_weights(self):
        all_local_weights = self.fl_contract.functions.getLocalWeights().call()
        results = []
        for w in all_local_weights:
            results.append(compress_pickle.loads(b"".join(w), 'bz2'))
        return results

    def validation_ready(self):
        self.fl_contract.functions.validationReady().transact({'from': self.account.address})
        log(INFO, "Ready for validation!")
        
    def validation(self, ballot):
        self.fl_contract.functions.validation(ballot).transact({'from': self.account.address})
        log(INFO, "Validation Done!")

    def get_global_weight(self):
        return compress_pickle.loads(b"".join(self.fl_contract.functions.getGlobalModel().call()), 'bz2')

    def is_aggregator(self):
        return self.fl_contract.functions.getAggregator().call({'from': self.account.address})

    def aggregate_start(self):
        return self.fl_contract.functions.aggregateStart().call()

    def get_validation_state(self):
        return self.fl_contract.functions.getValidationState().call()


class DeFed(FedXgbBagging):

    def __init__(
        self,
        url,
        fl_contract,
        priv_key,
         **kwargs: any,
    ):
        self.chain_func = ChainFunc(url, fl_contract, priv_key)
        super().__init__(**kwargs)

    def aggregate_fit(
        self,
        server_round: int,
        results: list[tuple[ClientProxy, FitRes]],
        failures: list[Union[tuple[ClientProxy, FitRes], BaseException]],
    ) -> tuple[Optional[Parameters], dict[str, Scalar]]:
        """Upload model weight to the fl_contract after training."""
        # print(results, failures)
        if failures:
            log(WARNING, f'fail: {failures}')
            return None, {}
        weight = results[0][1]
        self.chain_func.upload_weight(weight)
        self.chain_func.aggregate_ready()

        """Download model weights from the fl_contract before aggregatation."""
        while not self.chain_func.aggregate_start():
            sleep(1)
        log(INFO, "Aggregatation start!!")
        all_weights = self.chain_func.get_local_weights()
        results = []
        for w in all_weights:
            r = tuple(['', w])
            results.append(r)
        parameters_aggregated, metrics_aggregated = super().aggregate_fit(server_round, results, [])
        
        # log(WARNING, f'agg: {self.chain_func.is_aggregator()}, {self.chain_func.account.address}')

        if self.chain_func.is_aggregator():
            log(INFO, "You are aggregator.")
            self.chain_func.upload_aggregated_weight(parameters_aggregated)
            self.chain_func.validation_ready()
            self.chain_func.validation(True)
        else:
            log(INFO, "You are validator.")
            while not self.chain_func.get_validation_state():
                sleep(1)
            if self.chain_func.get_global_weight() == parameters_aggregated:
                self.chain_func.validation(True)
            else:
                self.chain_func.validation(False)

        return parameters_aggregated, metrics_aggregated

    def initialize_parameters(
        self, client_manager: ClientManager
    ) -> Optional[Parameters]:
        """Initialize global model parameters."""
        self.chain_func.join_training()
        log(INFO, "Downloading initial model weight...")
        init_weight = self.chain_func.get_global_weight()
        return init_weight
