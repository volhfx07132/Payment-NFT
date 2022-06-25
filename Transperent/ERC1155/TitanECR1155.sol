// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./ERC1155Upgradeable.sol";
import "../../Utils/OwnableUpgradeable.sol";
import "../../Utils/PausableUpgradeable.sol";
import "./ERC1155BurnableUpgradeable.sol";
import "../../Utils/Initializable.sol";

contract TitanECR1155 is Initializable, ERC1155Upgradeable, OwnableUpgradeable, PausableUpgradeable, ERC1155BurnableUpgradeable {

    constructor() initializer public {
        __ERC1155_init("https://Titan/token/index/erc1155/id/");
        __Ownable_init();
        __Pausable_init();
        __ERC1155Burnable_init();
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address account, uint256 id, uint256 amount, bytes memory data)
        public
        onlyOwner
    {
        _mint(account, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
        onlyOwner
    {
        _mintBatch(to, ids, amounts, data);
    }

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}