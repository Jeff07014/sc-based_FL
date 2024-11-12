// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//import {ERC20} from "@openzeppelin/contracts/token/ERC721/ERC20.sol";


contract TrainingContract{
    // The maximum allowed size
    uint256 public maxsize;
    // parent FLContract address
    address public flc_addr;
    uint public approval;
    uint public rejection;
    /*struct weight_data{
        address client;
        bytes[] local_weight;
    }*/
    bytes[] public global_weight;
    mapping(address => bytes[]) public local_weight;
    enum Status {
        LocalTraining,
        Aggregation,
        AllDone
    }
    mapping(address => Status) public clients_state;
    
    constructor(uint _maxsize){
        flc_addr = msg.sender;
        maxsize = _maxsize;
    }

    function saveLocalWeight(bytes memory data, address client) public {
        //require(bytes(key).length > 0, "Key must not be empty");
        require(data.length > 0, "Data must not be empty");
        require(data.length <= maxsize, string(abi.encodePacked("Data must shorter than maxsize")));
        require(msg.sender == flc_addr, "not allowed.");
        require(clients_state[client] == Status.LocalTraining, "already done.");
        //emit Log((localWeight[key]));
        local_weight[client].push(data);
        //localWeightKeys[round].push(key);
        //emit saving(key, data);
    }

    function trainingDone(address client) public {
        require(msg.sender == flc_addr, "not allowed.");
        require(clients_state[client] == Status.LocalTraining, "already done.");
        clients_state[client] = Status.Aggregation;
    }

    function saveGlobalWeight(bytes memory data) public {
        require(msg.sender == flc_addr, "not allowed.");
        require(data.length > 0, "Data must not be empty.");
        require(data.length <= maxsize, string(abi.encodePacked("Data must shorter than maxsize.")));
        global_weight.push(data);
    }

    function voting(bool ballot, address client) public {
        require(msg.sender == flc_addr, "not allowed.");
        require(clients_state[client] == Status.Aggregation, "already done.");
        // TODO: restrict one client vote once.
        if(ballot) {
            approval += 1;
        }
        else {
            rejection += 1;
        }
        clients_state[client] = Status.AllDone;
    }

    function voteResult() public view returns(bool) {
        require(msg.sender == flc_addr, "not allowed.");
        if(approval > rejection) {
            return true;
        }
        else {
            return false;
        }
    }

    function getGlobalModel() public view returns (bytes[] memory) {
        return global_weight;
    }

    function getLocalWeights(address client) public view returns (bytes[] memory) {
        return local_weight[client];
    }

}

contract FLContract{
    // The maximum allowed size
    uint256 public maxsize;
    // The round number of the fl training
    uint256 public round = 0;
    // The number of keys in one round
    uint256 public count = 0;
    // All keys of local weights 
    //string[][] public localWeightKeys;
    TrainingContract[] public training_list;
    // the minimum amount of client deposit before join the training.
    uint public deposit_value;
    // all clients who join training
    mapping(address => uint) public valid_clients;
    address[] public all_clients;
    uint public aggragator = 0;
    uint public ballots = 0;
    address public owner;

    uint public client_cnt;
    uint public max_client_num;
    uint16 public training_done_cnt = 0;

    bool public training_start = false;
    bool public validation_start = false;

    bytes[] public global_model;
    //address public first_agg;

    event LogAddress(address);
    event Log(string);
    event Log(uint16);

    constructor(uint _max_client_num, uint _deposit_value, uint _maxsize){
        deposit_value = _deposit_value;
        max_client_num = _max_client_num;
        maxsize = _maxsize;
        TrainingContract new_round = new TrainingContract(_maxsize);
        training_list.push(new_round);
        owner = msg.sender;
    }

    function initGlobalModel(bytes memory data) public {
        require(data.length > 0, "Data must not be empty.");
        require(data.length <= maxsize, string(abi.encodePacked("Data must shorter than maxsize.")));
        require(msg.sender == owner, "not permitted");
        //emit Log((globalModel[round]));
        global_model.push(data);
    }

    function initDone() public {
        require(msg.sender == owner, "not permitted");
        training_start = true;
    }

    function joinTraining() public payable {
        // TODO: extendable client count
        require(training_start == true, "Initialization not completed.");
        require(client_cnt < max_client_num, "too much.");
        require(round == 0, "not allowed.");
        require(msg.value >= deposit_value, "deposit not enough.");
        valid_clients[msg.sender] = msg.value;
        all_clients.push(msg.sender);
        client_cnt += 1;
    }

    function localTraining(bytes memory data) public {
        require(valid_clients[msg.sender] >= deposit_value, "not permitted");
        training_list[round].saveLocalWeight(data, msg.sender);
    }

    function aggregationReady() public{
        require(valid_clients[msg.sender] >= deposit_value, "not permitted");
        training_list[round].trainingDone(msg.sender);
        training_done_cnt ++;
    }

    function saveGlobalModel(bytes memory data) public {
        // TODO: threshold setting
        require(training_done_cnt >= max_client_num, "not ready yet.");
        require(valid_clients[msg.sender] >= deposit_value, "not permitted.");
        require(all_clients[aggragator] == msg.sender, "not you.");
        training_list[round].saveGlobalWeight(data);
    }

    function validationReady() public {
        require(valid_clients[msg.sender] >= deposit_value, "not permitted.");
        require(all_clients[aggragator] == msg.sender, "not you.");
        validation_start = true;
    }

    function validation(bool ballot) public {
        require(valid_clients[msg.sender] >= deposit_value, "not permitted.");
        require(validation_start == true, "not ready yet.");
        training_list[round].voting(ballot, msg.sender);
        ballots += 1;
        if(ballots == max_client_num) {
            validation_start = false;
            ballots = 0;
            training_done_cnt = 0;
            aggragator = (aggragator + 1) < client_cnt ? aggragator + 1 : 0;
            TrainingContract new_round = new TrainingContract(maxsize);
            // TODO: test the result of successful and failed aggregation
            if(training_list[round].voteResult()) {
                // push the new one
                round += 1;
                training_list.push(new_round);
            } else {
                // cover the failed one
                training_list[round] = new_round;
            }
        }
    }

    function getGlobalModel() public view returns (bytes[] memory) {
        if(round == 0) {
            return global_model;
        } else {
            return training_list[round - 1].getGlobalModel();
        }
    }

    function getLocalWeights() public view returns (bytes[][] memory) {
        bytes[][] memory all_weights = new bytes[][](client_cnt);
        for (uint i = 0; i < client_cnt; i ++) {
            all_weights[i] = training_list[round].getLocalWeights(all_clients[i]);
        }
        return all_weights;
    }

    function getDepositValue() public view returns (uint) {
        return deposit_value;
    }

    function getAggregator() public view returns (bool) {
        return (all_clients[aggragator] == msg.sender);
    }

    function getMaxSize() public view returns (uint) {
        return maxsize;
    }

    function aggregateStart() public view returns (bool) {
        return (training_done_cnt >= max_client_num ? true : false);
    }

    function getValidationState() public view returns (bool) {
        return validation_start;
    }

}

