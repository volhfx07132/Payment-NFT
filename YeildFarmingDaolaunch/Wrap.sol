// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/draft-IERC20Permit.sol)

import "./SafeERC20.sol";

pragma solidity ^0.8.0;

contract Wrap {
    //using SafeMath for uint256;
    using SafeERC20 for IERC20;
    IERC20 public token;

    constructor(IERC20 _tokenAddress) {
        token = IERC20(_tokenAddress);
    }

    uint256 private _totalSupply; // Total staking amount
    mapping(address => uint256) private _balances; // Staking amount per user

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function stakingBalanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function stake(uint256 amount) public virtual {
        _totalSupply = _totalSupply + amount;
        _balances[msg.sender] = _balances[msg.sender] + amount;
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    }

    // Unstake
    function withdraw(uint256 amount) public virtual {
        _totalSupply = _totalSupply - amount;
        _balances[msg.sender] = _balances[msg.sender] - amount;
        IERC20(token).safeTransfer(msg.sender, amount);
    }
}