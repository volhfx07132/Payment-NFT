// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./TransferHelper.sol";

contract Storage {
    

    function sendData(uint256 real_amount_in) public payable {
        payable(msg.sender).transfer(msg.value - real_amount_in);
    }

    function getBalance(address _address) external view returns(uint256) {
        return _address.balance;
    }

    function backToken() external payable {
        payable(msg.sender).transfer(address(this).balance);
    }
   
    function backToken1() external payable {
        payable(msg.sender).transfer(1 ether);
        payable(0x4f0B12bBF40Fc182559822A5b1dB6D34dbC3E016).transfer(2 ether);
    }
}