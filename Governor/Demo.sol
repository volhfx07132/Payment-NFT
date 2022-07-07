// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (governance/Governor.sol)

pragma solidity ^0.8.0;

import "./DoubleEndedQueue.sol";

contract Demo{
    /*
    struct Bytes32Deque {
        int128 _begin;
        int128 _end;
        mapping(int128 => bytes32) _data;
    }
    */
    using DoubleEndedQueue for DoubleEndedQueue.Bytes32Deque;
    DoubleEndedQueue.Bytes32Deque private _governanceCall;

    constructor() {
        _governanceCall._begin = 1;
        _governanceCall._end = 5;
        _governanceCall._data[1] = 0x5472616e2056616e204200000000000000000000000000000000000000000000;
        _governanceCall._data[2] = 0x4e677579656e2054686920420000000000000000000000000000000000000000;
        _governanceCall._data[3] = 0x4c4520484f4e4720564f00000000000000000000000000000000000000000000;
        _governanceCall._data[4] = 0x5f676f7665726e616e636543616c6c0000000000000000000000000000000000;
        _governanceCall._data[5] = 0x5f626567696e0000000000000000000000000000000000000000000000000000;
    }

    function getGovernanceCall() public view returns(int128, int128, bytes32, bytes32) {
        return (
            _governanceCall._begin, 
            _governanceCall._end, 
            _governanceCall._data[_governanceCall._begin], 
            _governanceCall._data[_governanceCall._end]
        );
    }

    function pushBackData(bytes32 value) public {
        _governanceCall.pushBack(value);
    }

    function popBackData() public {
        _governanceCall.popBack();
    }

    function popFrontData() public{
        _governanceCall.popFront();
    }

    function frontData() public {
        _governanceCall.front();
    }

    function backData() public view returns(bytes32) {
        bytes32 data = _governanceCall.back();
        return data;
    }

    function atData(uint256 index) public view returns(bytes32) {
        return _governanceCall.at(index);
    }

    function clearData() public {
        return _governanceCall.clear();
    }


    function lengthData() public view returns(uint256) {
        return _governanceCall.length();
    }

    function emptyData() public view returns(bool) {
        return _governanceCall.empty();
    }
}