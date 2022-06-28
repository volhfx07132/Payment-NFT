// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../Utils/Ownable.sol";
import "../Utils/EnumerableSet.sol";

contract PresaleSettings is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;  

    struct SettingFee{
        uint256 refundFee;
        uint256 claimFee;
        uint256 feeCreatePresale;
        uint256 feeAnyone;
        address payable baseReceiveFeeAddress;
        address payable tokenReceiveFeeAddress;
    }
    
    SettingFee public settingFee;

    constructor() public {
        settingFee.refundFee = 100;
        settingFee.claimFee = 50;
        settingFee.feeCreatePresale = 1 ether;
        settingFee.feeAnyone = 20;
        settingFee.baseReceiveFeeAddress = payable(_msgSender());
        settingFee.tokenReceiveFeeAddress = payable(_msgSender());
    }

    function getRefundFee() public view returns(uint256) {
        return settingFee.refundFee;
    }

    function getClaimFee() public view returns(uint256) {
        return settingFee.claimFee;
    }

    function getFeeCreatePresale() public view returns(uint256) {
        return settingFee.feeCreatePresale;
    }

    function getFeeAnyone() public view returns(uint256) {
        return settingFee.feeAnyone;
    }

    function getBaseReceiveFeeAddress() public view returns(address) {
        return settingFee.baseReceiveFeeAddress;
    }

    function getTokenReceiveFeeAddress() public view returns(address) {
        return settingFee.tokenReceiveFeeAddress;
    }

    function update(
        uint256 _refundFee,
        uint256 _claimFee,
        uint256 _feeCreatePresale,
        uint256 _feeAnyone,
        address payable _baseReceiveFeeAddress,
        address payable _tokenReceiveFeeAddress
    ) external onlyOwner {
        settingFee.refundFee = _refundFee;
        settingFee.claimFee = _claimFee;
        settingFee.feeCreatePresale = _feeCreatePresale;
        settingFee.feeAnyone = _feeAnyone;
        settingFee.baseReceiveFeeAddress = _baseReceiveFeeAddress;
        settingFee.tokenReceiveFeeAddress = _tokenReceiveFeeAddress;
    }
}
