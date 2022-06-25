// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../ERC721/IERC721ReceiverUpgradeable.sol";
import "../ERC721/ERC721Upgradeable.sol";

import "../ERC1155/ERC1155Upgradeable.sol";
import "../ERC1155/ERC1155ReceiverUpgradeable.sol";

import "../ERC20/ERC20Upgradeable.sol";

contract TokenHolderUpgradeable is Initializable, IERC721ReceiverUpgradeable, ERC1155ReceiverUpgradeable {
    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     *
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /**
    * Simple implementation of `ERC1155Receiver` that will allow a contract to hold ERC1155 tokens.
    *
    * IMPORTANT: When inheriting this contract, you must include a way to use the received tokens, otherwise they will be
    * stuck.
    *
    * @dev _Available since v3.1._
    */

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    //------------------------------------ERC721-------------------------------------------
    function adminSendERC721Token(
        address token,
        address from,
        address to,
        uint256 tokenId
    ) external {
        ERC721Upgradeable(token).safeTransferFrom(from, to, tokenId);
    }

    function adminSetApprovalERC721ForAll(
        address token, 
        address operator,
        bool _approved
    ) external {
        ERC721Upgradeable(token).setApprovalForAll(operator, _approved);
    }
    //------------------------------------ERC20------------------------------------------
    function adminSendERC20Token(
        address token,
        address to,
        uint256 amount
    ) external {
        ERC20Upgradeable(token).transfer( to, amount);
    }
    //------------------------------------ERC1155---------------------------------------------
    function adminSendERC1155Token(
        address token,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external {
        ERC1155Upgradeable(token).safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function adminSetApprovalForAll(
        address token,
        address operator,
        bool approved
    ) external {
        ERC1155Upgradeable(token).setApprovalForAll(operator, approved);
    } 
    //----------------------------------------------------------------------------------------

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}