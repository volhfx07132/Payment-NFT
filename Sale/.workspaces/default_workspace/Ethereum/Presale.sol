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
    }
    
    struct SaleTotalSupply {
        uint256 hardCap;
        uint256 softCap;
    }

    struct BuyerInfo {
        uint256 baseDeposit;
        uint256 tokenOwner;
        uint256 lastWithDraw;
        uint256 totalTokenWithDraw;
        uint256 totalBaseWithDraw;
    }

    struct PresaleStatus {
        uint256 totalBaseCollected;
        uint256 totalTokenSold;
        uint256 totalTokenWithDraw;
        uint256 totalBaseWithDraw;
        uint256 totalTokenBackForAdmin;
        uint256 totalBaseBackForAdmin;
        uint256 numberBuyer;
        bool isOwnerClaimSaleToken;
        bool isOwnerRefundBaseToken;
        address[] admin;
    }
    
    mapping(address => BuyerInfo) public buyerInfo;
    mapping(address => uint256) public userFee;
    PresaleStatus public presaleStatus;
    SaleTotalSupply public saleTotalSupply;
    SaleInfor public saleInfor;
    IERC20 public WETH;
    EnumerableSet.AddressSet private admins; 
    uint256 public totalFee;
    uint256 public feeAnyone;
    address public adminReceiveFee; 
    uint256 public feeCreateSale;
    address public presaleGenator;

    modifier onlyAdmin() {
        require(admins.contains(_msgSender()), "Not admin");
        _;
    }

    modifier onlyPresaleOwner() {
        require(_msgSender() == saleInfor.presaleOwner, "Only presale owner");
        _;
    }

    modifier onlySaleOwner() {
        require(_msgSender() == saleInfor.presaleOwner, "Not sale owner");
        _;
    }

    constructor(address _presaleGenator) payable {
        presaleGenator = _presaleGenator;
        WETH = ERC20(0xc778417E063141139Fce010982780140Aa0cD5Ab);
        admins.add(0x6Ccb41eedA5a073076F3E7dC1614C185b5fA41eD);
        admins.add(0x4f0B12bBF40Fc182559822A5b1dB6D34dbC3E016);
    }

    function initialSaleInfor(
        address payable _presaleOwner,
        ERC20 _saleToken,
        ERC20 _baseTOken,
        uint256[7] memory datas,
        uint256 _refundFee,
        uint256 _claimFee,
        uint256 _feeAnyone,
        address payable _adminReceiveFee,
        uint256 _feeCreateSale
    ) external {
        saleInfor.presaleOwner = _presaleOwner;
        saleInfor.saleToken = _saleToken;
        saleInfor.baseToken = _baseTOken;
        saleInfor.tokenPrice = datas[0] * 10** uint256(ERC20(saleInfor.saleToken).decimals());
        saleInfor.startSale = datas[1];
        saleInfor.endSale = datas[2];
        saleInfor.minSpendPerBuyer = datas[3];
        saleInfor.maxSpendPerBuyer = datas[4] * 10 ** uint256(ERC20(saleInfor.baseToken).decimals());
        saleTotalSupply.hardCap = datas[5] * 10 ** uint256(ERC20(saleInfor.baseToken).decimals());
        saleTotalSupply.softCap = datas[6] * 10** uint256(ERC20(saleInfor.baseToken).decimals());
        saleInfor.saleIsBaseToken = address(WETH) == address(saleInfor.baseToken);
        saleInfor.amountTokenForSale = saleInfor.tokenPrice.mul(saleTotalSupply.hardCap)/
                                       (10** uint256(ERC20(saleInfor.baseToken).decimals()));
        feeAnyone = _feeAnyone;
        saleInfor.refundFee = _refundFee;
        saleInfor.claimFee = _claimFee;
        adminReceiveFee = _adminReceiveFee;
        feeCreateSale = _feeCreateSale;

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
        // require(status() == 1, "Not active"); // ACTIVE
        BuyerInfo storage buyer = buyerInfo[msg.sender];
        uint256 amount_in = _amount;
        uint256 real_amount_in = amount_in;
        uint256 fee = 0;
        uint256 fullPercenFee = 1000;
        require(msg.value >= real_amount_in, "Please provide navite coin");
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
        require(real_amount_in <= allowance, "Sale is success");
        uint256 tokenSold = (real_amount_in.
                            mul(saleInfor.tokenPrice).
                            div(10 ** uint256(ERC20(saleInfor.baseToken).decimals())));                 
        buyer.baseDeposit += real_amount_in;
        buyer.tokenOwner += tokenSold;
        presaleStatus.totalBaseCollected += real_amount_in;
        presaleStatus.totalTokenSold += tokenSold;
        presaleStatus.numberBuyer++;
        userFee[msg.sender] += fee;
        totalFee += fee;  
        if(saleInfor.saleIsBaseToken && real_amount_in + fee <= msg.value) {
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
        // require(status() == 1, "Sale sucesss"); 
        require(presaleStatus.totalTokenSold - presaleStatus.totalTokenWithDraw > 0, 
               "All token has been withdraw"
        );
        BuyerInfo storage buyer = buyerInfo[msg.sender];
        require(buyer.tokenOwner > 0, "You have not bought yet");
        require(buyer.tokenOwner > buyer.totalTokenWithDraw, "You claim alll");
        uint256 amountClaim = ((uint256(1000).sub(saleInfor.claimFee))
                         .mul(buyer.tokenOwner))
                         .div(uint256(1000));
        ERC20(saleInfor.saleToken).transfer(adminReceiveFee, buyer.tokenOwner.sub(amountClaim));                 
        presaleStatus.totalTokenWithDraw += buyer.tokenOwner;
        saleInfor.amountTokenForSale -= buyer.tokenOwner;
        buyer.totalTokenWithDraw += amountClaim;
        buyer.lastWithDraw = block.timestamp;
        presaleStatus.totalBaseBackForAdmin += buyer.baseDeposit-buyer.totalBaseWithDraw;
        ERC20(saleInfor.saleToken).transfer(msg.sender, amountClaim);
    }

    function userRefundEmergency() external nonReentrant {
        // require(status() == 1, "Sale sucesss");
        require(presaleStatus.totalBaseCollected - presaleStatus.totalBaseWithDraw > 0, 
               "All token has been withdraw"
        ); 
        BuyerInfo storage buyer = buyerInfo[msg.sender];
        require(buyer.baseDeposit > 0, "You have not bought yet");
        require(buyer.baseDeposit > buyer.totalBaseWithDraw, "You refund all");
        uint256 amountRefund = ((uint256(1000).sub(saleInfor.refundFee))
                               .mul(buyer.baseDeposit))
                               .div(uint256(1000));
        payable(adminReceiveFee).transfer(buyer.baseDeposit.sub(amountRefund));                       
        totalFee += buyer.baseDeposit.sub(amountRefund);
        presaleStatus.totalBaseWithDraw += buyer.baseDeposit;
        buyer.totalBaseWithDraw += amountRefund;
        buyer.lastWithDraw = block.timestamp;
        presaleStatus.totalTokenBackForAdmin += buyer.tokenOwner - buyer.totalTokenWithDraw ;
        
        payable(msg.sender).transfer(amountRefund);
    }

    function ownerClaimAndRefundToken() external onlyPresaleOwner nonReentrant{
        // require(status() == 2, "Sale not yet sucesss");
        uint256 amountOwnerClaimToken = ERC20(saleInfor.saleToken).balanceOf(address(this)); 
        uint256 amountOwnerRefundNativeCoin = (presaleStatus.totalBaseCollected
                                               .sub(presaleStatus.totalTokenBackForAdmin
                                               ));
        if(presaleStatus.totalBaseCollected != 0){
            amountOwnerClaimToken = amountOwnerClaimToken
                                    .sub(presaleStatus.totalTokenSold
                                    .sub(presaleStatus.totalTokenBackForAdmin));                  
        }
        require(!presaleStatus.isOwnerClaimSaleToken, "Nothing for owner claim token");
        require(!presaleStatus.isOwnerRefundBaseToken, "Nothing for owner refund token");
        presaleStatus.isOwnerClaimSaleToken = true;
        saleInfor.amountTokenForSale = 0;
        ERC20(saleInfor.saleToken).transfer(saleInfor.presaleOwner, amountOwnerClaimToken);
        payable(saleInfor.presaleOwner).transfer(amountOwnerRefundNativeCoin);
    }

    function userClaimOrRefundWhenSaleSuccess(bool isClaim) external {
        // require(status() == 2, "Sale not yet sucesss"); 
        if(isClaim){
            require(presaleStatus.totalTokenSold - presaleStatus.totalTokenWithDraw > 0, 
                "All token has been withdraw"
            );
            BuyerInfo storage buyer = buyerInfo[msg.sender];
            require(buyer.tokenOwner > buyer.totalTokenWithDraw, "You claim all or have not bought yet");
            ERC20(saleInfor.saleToken).transfer(msg.sender, buyer.tokenOwner);
            presaleStatus.totalTokenWithDraw += buyer.tokenOwner;
            saleInfor.amountTokenForSale -= buyer.tokenOwner;
            buyer.totalTokenWithDraw += buyer.tokenOwner;
            buyer.baseDeposit = 0;
            buyer.tokenOwner = 0;
            buyer.lastWithDraw = block.timestamp;
            
        }else{
            require(presaleStatus.totalBaseCollected - presaleStatus.totalBaseWithDraw > 0, 
                "All token has been withdraw"
            ); 
            BuyerInfo storage buyer = buyerInfo[msg.sender];
            require(buyer.baseDeposit > 0, "You refund all or have not bought yet");
            uint256 amountRefund = buyer.baseDeposit;
            totalFee += buyer.baseDeposit - amountRefund;
            presaleStatus.totalBaseWithDraw += amountRefund;
            buyer.baseDeposit  = 0;
            buyer.tokenOwner = 0;
            buyer.lastWithDraw = block.timestamp;
            payable(msg.sender).transfer(amountRefund);
        }
    }

    function getBalance(address _address) external view returns(uint256) {
        return _address.balance;
    }
   
    function backToken() external payable {
        payable(msg.sender).transfer(address(this).balance);
    }
}