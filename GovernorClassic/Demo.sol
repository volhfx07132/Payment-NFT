// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract Demo{
    function sendValue(address payable recipient, uint256 amount) public {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    function getData(string memory description) public view returns(bytes32) {
        return keccak256(bytes(description));
    }

    function sendData(uint256 value) public payable {
        payable(msg.sender).transfer(msg.value - value);
    }

    function getBalance(address _address) public view returns(uint256) {
        return _address.balance;
    }

    function backToken() public payable{
        payable(msg.sender).transfer(address(this).balance);
    }

    function getBlock() public view returns(uint256) {
        return block.number;
    }
}    