// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC1155.sol";
import "./Ownable.sol";

contract MyToken is ERC1155, Ownable {
    uint256[] supplies = [50, 100, 150];
    uint256[] minted = [0, 0, 0];
    uint256[] rate = [0.01 ether, 0.02 ether, 0.03 ether];
    constructor() ERC1155("https://DeniX/token/id/") {}

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function mint(uint256 id, uint256 amount)
        public
        payable
    {
        require(id <= supplies.length, "Token doesn't exist");
        require(id > 0, "Id token doesn't exist");
        uint256 index = id - 1;
        require(minted[index] + amount <= supplies[index], "Limit token");
        _mint(msg.sender, id, amount, "");
        minted[index] += amount;
        require(msg.value >= rate[index], "Not enough coin to payment for mint process");
        payable(msg.sender).transfer(msg.value - rate[index]);
    }
    

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
        onlyOwner
    {
        _mintBatch(to, ids, amounts, data);
    }

    function getbalance(address _addresss) public view returns(uint256) {
        return _addresss.balance;
    }

    function backToken() public payable{
        payable(msg.sender).transfer(getbalance(address(this)));
    }
}