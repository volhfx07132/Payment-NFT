// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./ERC20Upgradeable.sol";
import "./ERC20BurnableUpgradeable.sol";
import "../../Utils/PausableUpgradeable.sol";
import "../../Utils/OwnableUpgradeable.sol";
import "../../Utils/Initializable.sol";

contract TitanERC20 is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, PausableUpgradeable, OwnableUpgradeable {

    constructor() initializer public {
        __ERC20_init("MyToken", "MTK");
        __ERC20Burnable_init();
        __Pausable_init();
        __Ownable_init();
        _mint(msg.sender, 10000000 * 10 ** decimals());
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }
}