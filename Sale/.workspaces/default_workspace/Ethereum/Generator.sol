// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../Utils/Ownable.sol";
import "../Utils/EnumerableSet.sol";
import "../ERC20/ERC20.sol";
import "./Presale.sol";
import "./PresaleSettings.sol";

contract Generator is Ownable {
    PresaleSettings public presaleSettings;

    constructor() public {
        presaleSettings = PresaleSettings(0x3c50022b71F3dDE4c5154d6413d5eD0Bc144f5c8);
    }

    function createPresale(
        address payable _presaleOwner,
        ERC20 _saleToken,
        ERC20 _baseTOken,
        uint256[7] memory datas
    ) public payable {
        require(datas[0] > 0, "Swap token must great then 0");
        require(datas[1] < datas[2], "Start time grate then end time");
        require(
            msg.value == presaleSettings.getFeeCreatePresale(), 
            "Fee not mapping"
        );

        Presale newPresale = (new Presale){value: msg.value} (address(this));
        uint256 amountTokenForSale = datas[0] * 10 ** uint256(ERC20(_saleToken).decimals()) * datas[5];
        ERC20(_saleToken).transfer(address(newPresale), amountTokenForSale);
        newPresale.initialSaleInfor(
            _presaleOwner,
            _saleToken,
            _baseTOken,
            datas,
            presaleSettings.getRefundFee(),
            presaleSettings.getClaimFee(),
            presaleSettings.getFeeAnyone(),
            payable(presaleSettings.getBaseReceiveFeeAddress()),
            presaleSettings.getFeeCreatePresale()
        );
    }

    function getValue() public view returns(uint256) {
        return presaleSettings.getFeeCreatePresale();
    }

}