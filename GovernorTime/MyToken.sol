// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract MyToken is ERC20, ERC20Burnable, Ownable, ERC20Permit, ERC20Votes {
    constructor() ERC20("MyToken", "MTK") ERC20Permit("MyToken") {
            _mint(0x6Ccb41eedA5a073076F3E7dC1614C185b5fA41eD, 1000 ether);
            _mint(0x4f0B12bBF40Fc182559822A5b1dB6D34dbC3E016, 2000 ether);
            _mint(0x39Ba3ca2AE86A881a1De9cC4B81d0fD59CA189BD, 3000 ether);
            _mint(0xe4c1eC323AA9AB600bA062614D254AC678afa484, 4000 ether);
            _mint(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, 5000 ether);
            _mint(0x70997970C51812dc3A010C7d01b50e0d17dc79C8, 6000 ether);
    }

    // The following functions are overrides required by Solidity.

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }
}
