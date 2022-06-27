// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../ERC20/ERC20.sol";
import "../Utils/ReentrancyGuard.sol";
import "../Utils/TransferHelper.sol";
import "../Utils/EnumerableSet.sol";
import "../Utils/Ownable.sol";
import "../Utils/Context.sol";
import "../Utils/SafeMath.sol";



contract Presale is ReentrancyGuard, Ownable{
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeMath for uint256;

    struct SaleInfor {
        address payable presaleOwner;
        ERC20 saleToken;
        ERC20 baseToken;
        uint256 tokenPrice;
        uint256 startSale;
        uint256 endSale;
        uint256 minSpendPerBuyer;
        uint256 maxSpendPerBuyer;
        uint256 refundFee;
        uint256 claimFee;
        bool saleIsBaseToken;
        uint256 amountTokenForSale;
        uint256 hardCap;
        uint256 softCap;
    }

    struct BuyerInfo {
        uint256 baseDeposit;
        uint256 tokenOwner;
        uint256 lastWithDraw;
        uint256 totalTokenWithDraw;
        bool isRefund;
        bool isClaim;
    }

    struct PresaleStatus {
        uint256 totalBaseCollected;
        uint256 totalTokenSold;
        uint256 totalTokenWithDraw;
        uint256 totalBaseWithDraw;
        uint256 numberBuyer;
        uint256 totalFee;
        address[] admin;
    }
    
    mapping(address => BuyerInfo) public buyerInfo;
    mapping(address => uint256) public userFee;
    PresaleStatus public presaleStatus;
    SaleInfor public saleInfor;
    IERC20 public WETH;
    uint256 public feeAnyone;
    EnumerableSet.AddressSet private admins; 
    uint256 public totalFee;

    modifier onlyAdmin() {
        require(admins.contains(_msgSender()), "Not admin");
        _;
    }

    modifier onlySaleOwner() {
        require(_msgSender() == saleInfor.presaleOwner, "Not sale owner");
        _;
    }

    constructor() payable {
        WETH = ERC20(0xc778417E063141139Fce010982780140Aa0cD5Ab);
        admins.add(0x6Ccb41eedA5a073076F3E7dC1614C185b5fA41eD);
        admins.add(0x4f0B12bBF40Fc182559822A5b1dB6D34dbC3E016);
        feeAnyone = 20;
    }

    function initialSaleInfor(
        address payable _presaleOwner,
        ERC20 _saleToken,
        ERC20 _baseTOken,
        uint256[9] memory datas
    ) external {
        saleInfor.presaleOwner = _presaleOwner;
        saleInfor.saleToken = _saleToken;
        saleInfor.baseToken = _baseTOken;
        saleInfor.tokenPrice = datas[0] * 10** uint256(ERC20(saleInfor.saleToken).decimals());
        saleInfor.startSale = datas[1];
        saleInfor.endSale = datas[2];
        saleInfor.minSpendPerBuyer = datas[3];
        saleInfor.maxSpendPerBuyer = datas[4] * 10** uint256(ERC20(saleInfor.baseToken).decimals());
        saleInfor.refundFee = datas[5];
        saleInfor.claimFee = datas[6];
        saleInfor.hardCap = datas[7];
        saleInfor.softCap = datas[8];
        saleInfor.saleIsBaseToken = address(WETH) == address(saleInfor.baseToken);
        saleInfor.amountTokenForSale = saleInfor.tokenPrice.mul(saleInfor.hardCap);
    } 

    function status() public view returns(uint256) {
        if(block.timestamp < saleInfor.startSale) {
            return 0; // Not Active
        }else{
            if(block.timestamp > saleInfor.endSale) {
                return 2; // Suceess
            }else{
                return 1; // Active
            }
        }
    } 

    function checkAdminAddress() public view returns(bool) {
        return admins.contains(_msgSender());
    }

    function deposit(uint256 _amount) external payable nonReentrant {
        require(status() == 1, "Not active"); // ACTIVE
        BuyerInfo storage buyer = buyerInfo[msg.sender];
        uint256 amount_in = _amount;
        uint256 real_amount_in = amount_in;
        uint256 fee = 0;
        uint256 fullPercenFee = 1000;
        require(real_amount_in >= saleInfor.minSpendPerBuyer, 
                "Not enough value"
        );
        require(real_amount_in <= saleInfor.maxSpendPerBuyer, 
                "Overflow value"
        );
        if(!checkAdminAddress()) {
            real_amount_in = ((fullPercenFee.sub(feeAnyone))
                             .mul(real_amount_in))
                             .div(fullPercenFee);
            fee = amount_in - real_amount_in;                 
        }
        uint256 remainingByUser = saleInfor.maxSpendPerBuyer - buyer.baseDeposit;
        uint256 remainingByPool = saleInfor.amountTokenForSale - presaleStatus.totalBaseCollected;
        uint256 allowance = remainingByUser > remainingByPool ? remainingByPool : remainingByUser;
        require(real_amount_in < allowance, "Sale is success");
        uint256 tokenSold = (real_amount_in.
                            mul(saleInfor.tokenPrice).
                            div(10 ** uint256(ERC20(saleInfor.baseToken).decimals())));                 
        buyer.baseDeposit += amount_in;
        buyer.tokenOwner += tokenSold;
        presaleStatus.totalBaseCollected += real_amount_in;
        presaleStatus.totalTokenSold += tokenSold;
        presaleStatus.numberBuyer++;
        userFee[msg.sender] += fee;
        totalFee += fee;  
        if(saleInfor.saleIsBaseToken && real_amount_in + fee < msg.value) {
            payable(msg.sender).transfer(msg.value - real_amount_in - fee);
        } 
        if(!saleInfor.saleIsBaseToken) {
            TransferHelper.safeTransferFrom(
                address(saleInfor.baseToken),
                msg.sender,
                address(this),
                real_amount_in + fee
            );
        }            
    }

    function userClaimEmergency() external nonReentrant {
        require(status() == 1, "Sale sucesss"); 
        require(presaleStatus.totalTokenSold - presaleStatus.totalTokenWithDraw > 0, 
               "All token has been withdraw"
        );
        BuyerInfo storage buyer = buyerInfo[msg.sender];
        require(buyer.tokenOwner > 0, "You withdraw all or have not bought yet");
        // uint256 amount = (buyer.tokenOwner.mul(saleInfor.claimFee)).div(1000);
        uint256 amountClaim = ((uint256(1000).sub(saleInfor.claimFee))
                         .mul(buyer.tokenOwner))
                         .div(uint256(1000));
        presaleStatus.totalTokenWithDraw += amountClaim;
        uint256 feeClaimToken = buyer.tokenOwner - amountClaim;
        buyer.tokenOwner = amountClaim; 
        ERC20(saleInfor.saleToken).transfer(msg.sender, amountClaim);
    }

    function getBalance(address _address) external view returns(uint256) {
        return _address.balance;
    }
   
    function backToken() external payable {
        payable(msg.sender).transfer(address(this).balance);
    }
}