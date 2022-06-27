startSale
endSale
valueSwapERC20
feeTransaction
maxSpendPerBuyer
minSpendPerBuyer
amountERC20

strust Sale{
    presale presaleOwner;
    uint256 startSale;
    uint256 endSale;
    uint256 valueSwapERC20;
    uint256 feeTransaction;
    uint256 minSpendPerBuyer;
    uint256 maxSpendPerBuyer;
    uint256 refundFee;
    uint256 claimFee;
}

strust BuyerInfo{
    address buyer
    uint256 baseDeposit;
    uint256 tokenOwner;
    uint256 lastWithDraw;
    uint256 totalTokenWithDraw;
    bool isRefund,
    bool isClaim,
}

mapping(address => BuyerInfo) public buyers;
Sale public sales;
uint256 public TOTAL_FEE;
