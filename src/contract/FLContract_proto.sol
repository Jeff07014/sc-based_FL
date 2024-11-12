// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FLContract {
    // The maximum allowed size
    uint256 public maxSize = 32768;

    // The round number of the fl training
    uint256 public round = 0;
    // The number of keys in one round
    uint256 public count = 0;
    // All keys of local weights 
    string[][] public localWeightKeys;

    uint16 public client_cnt = 3;
    uint private aggregate_threshold = 2;
    uint16 public client_done_cnt = 0;
    uint16 public agg_done_cnt = 0;
    uint256 public local_weight_size = 9;
    uint16 public matching = 2;

    bool public aggregate_start = true;

    bytes[][] public globalModel;

    event LogAddress(address);
    //event Log(bytes[]);
    event Log(string);
    event Log(uint16);

    mapping(string => bytes[]) private localWeight;

    address public first_agg;

    event saving(string indexed key, bytes data);

    constructor (){
        globalModel.push();
        localWeightKeys.push();
    }

    function saveGlobalModel(bytes memory data) public {
        require(data.length > 0, "Data must not be empty");
        require(data.length <= maxSize, string(abi.encodePacked("Data must shorter than maxsize")));
        //emit Log((globalModel[round]));

        globalModel[round].push(data);

    }
    function aggregateCheck(uint256 cnt, bytes memory data) public {
        if (aggregate_start) {
            if (first_agg == address(0)) {
                first_agg = msg.sender;
                saveGlobalModel(data);
            }
            else {
                if (first_agg == msg.sender) {
                    saveGlobalModel(data);
                }
                else {
                    emit LogAddress(first_agg);
                    emit LogAddress(msg.sender);
                    if (keccak256(abi.encodePacked(globalModel[round][cnt])) == keccak256(abi.encodePacked(data))) {
                        matching ++;
                        emit Log("match!");
                    }
                    //require(keccak256(abi.encodePacked(globalModel[round][cnt])) == keccak256(abi.encodePacked(data)), "model must be the same");
                }
            }
        }
    }
    function aggregateReady() public {
        client_done_cnt ++;
        if (client_done_cnt == client_cnt) {
            aggregate_start = true;
            client_done_cnt = 0;
            matching = 0;
        }
    }
    function aggregateDone() public {
        agg_done_cnt ++;
        if (agg_done_cnt == client_cnt) {
            if (matching >= aggregate_threshold) {
                emit Log("success!");
                aggregate_start = false;
                agg_done_cnt = 0;
                first_agg = address(0);
                round ++;
                globalModel.push();
                localWeightKeys.push();
            }
            else {
                emit Log(matching);
                aggregate_start = false;
                agg_done_cnt = 0;
                first_agg = address(0);
            }
        }
    }



    function saveLocalWeight(string memory key, bytes memory data) public {
        require(bytes(key).length > 0, "Key must not be empty");
        require(data.length > 0, "Data must not be empty");
        require(data.length <= maxSize, string(abi.encodePacked("Data must shorter than maxsize")));

        //emit Log((localWeight[key]));
        localWeight[key].push(data);
        localWeightKeys[round].push(key);
        emit saving(key, data);
    }
    function getStoredLocalWeights(string memory key) public view returns (bytes[] memory) {
        return localWeight[key];
    }

    function getStoredGlobalModel(uint256 key) public view returns (bytes[] memory) {
        return globalModel[key];
    }

    function getStoredSize(string memory key) public view returns (uint256) {
        return localWeight[key].length;
    }

    function getkeys() public view returns (string[] memory) {
        return localWeightKeys[round];
    }
}
