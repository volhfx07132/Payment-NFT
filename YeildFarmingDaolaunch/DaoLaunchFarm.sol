//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "hardhat/console.sol";

//import "../common/SafeMath.sol";
import "./Address.sol";
import "./Ownable.sol";
import "./IERC1155.sol";
import "./IERC721.sol";
import "./CloneFactory.sol";
import "./IERC20.sol";
import "./SafeERC20.sol";
import "./Wrap.sol";


contract DaoLaunchFarm is Wrap, Ownable, CloneFactory {
    //using SafeMath for uint256;

    // NFT properties when add NFT to Farm
    struct Card {
        bool trueForERC1155;
        uint256 requiredPoints;
        uint256 royalities;
        uint256 startTime;
        uint256 endTime;
        uint256 supply;
        address artist;
        //////// For Staking Token Lock /////////
        bool isStakingTokenLock;
        //////// For SHOP MODE /////////
        bool trueForShopMode; // false for Stake Mode
        uint256 pricePerPiece; // only meaningful in cloned farm, nonsense in genesis
        address shop;
    }
    

    // For Cloned Farm to manage Staker infor
    mapping(address => uint256) public lastUpdateTime;
    mapping(address => uint256) public points; // Staker => accumulated points
    // mapping(address => uint256) public lockedBalance; // Staker =>  locked Balance (only able to unstake unlocked balance)
    mapping(address => uint256) public debtPoint; // staker => Get NFT in advance, then be locked token, debt point of that NFT
    //uint256 public nftAddedNum; // cloned farm address => number of NFT added
    mapping(address => uint256) public consumedPoint; // NFT adder => consumedPoint

    // Use for Stake Mode when is in Genesis Farm (Farm for the whole System),
    mapping(address => mapping(address => mapping(uint256 => Card))) public cards; // adder account => NFT address => tokenID => Card
    // and For Shop Mode when is in Cloned Farm (farms for each wallet)
    mapping(address => mapping(uint256 => Card)) public shopCards; //NFT address => tokenID => ShopCard

    mapping(address => address[]) public farms; // Farm Creator => Farms Address
    // mapping(address => mapping( address => uint256[]) ) public farmAddedNftList; // Farm Address => NFT Contract => added NFT tokenIDs
    mapping(address => mapping(address => mapping(uint256 => address[]))) public stakingListFarm; // adder account => NFT Contract =>  the added NFT tokenID => list Farms
    mapping(address => mapping(address => mapping(uint256 => mapping(address => uint256)))) public minLockedAmount; // adder account => NFT Contract =>  the added NFT tokenID =>  Farms =>  min lock amount per NFT

    bool public isCloned = false;
    bool public constructed = false;
    address public genesisFarm;

    bytes4 internal constant ERC1155_RECEIVED_VALUE = 0xf23a6e61;
    bytes4 internal constant ERC721_RECEIVED_VALUE = 0x150b7a02;
    bytes4 internal constant ERC_RECEIVED_ERR_VALUE = 0x0;

    uint256 public minStake;
    uint256 public maxStake;
    uint256 public rewardRate; // points will be rewarded for staking 1 token for 1 hour.

    event CardAdded(address indexed nftContractAddress, uint256 indexed tokenId);
    event Staked(address indexed user, uint256 amount);
    event Redeemed(address indexed user, address indexed erc1155, uint256 indexed id, uint256 amount);
    event FarmCreated(address indexed user, address indexed farm);
    event Withdrawn(address indexed user, uint256 amount);

    modifier updateReward(address stakingAccount) {
        if (stakingAccount != address(0)) {
            points[stakingAccount] = points[stakingAccount] + getCurrPoints(stakingAccount);
            lastUpdateTime[stakingAccount] = block.timestamp;

            if (debtPoint[stakingAccount] > 0 && points[stakingAccount] >= debtPoint[stakingAccount]) {
                points[stakingAccount] -= debtPoint[stakingAccount];

                debtPoint[stakingAccount] = 0;
                // lockedBalance[stakingAccount] = 0;
            }
        }
        _;
    }

    /*
    function earned(address account) public view returns (uint256) {
        return points[account] + getCurrPoints(account);
    }
    */

    // for functions which called from Child Farm to Genesis Farm
    //user == 0x6Ccb41eedA5a073076F3E7dC1614C185b5fA41eD
    //cloneFarm == 0xC6d583548268eaf22033f59a25951A4ef18830BE
    modifier onlyChildFarm(address user, address clonedFarm) {
        require(!isCloned, "onlyChildFarm: Not callable in Cloned ");

        bool isOwnedFarm = false;
        for (uint256 i = 0; i < farms[user].length; i++) {
            if (farms[user][i] == clonedFarm) {
                isOwnedFarm = true;
                break;
            }
        }
        require(isOwnedFarm, "Only Child Farm is able call this function");
        _;
    }

    constructor(
        IERC20 _tokenAddress
    ) Wrap(_tokenAddress) {
        constructed = true;
        genesisFarm = Context._msgSender();
    }

    /**
     * Cloning functions
     * Disabled in clones and only working in the genesis contract.
     * */
    function init(
        uint256 _rewardRate,
        uint256 _minStake,
        uint256 _maxStake,
        IERC20 _tokenAddress
    ) external {
        require(!constructed && !isCloned, "DaoLaunchFarm must not be constructed yet or cloned.");
        // require(!isCloned, "DaoLaunchFarm must not be constructed yet or cloned.");
        require(_minStake >= 0 && _maxStake > 0 && _maxStake >= _minStake, "Problem with min and max stake setup");
        rewardRate = _rewardRate;
        minStake = _minStake;
        maxStake = _maxStake;
        token = _tokenAddress;
        genesisFarm = Context._msgSender();
        super.initOwnable();
        // super.initWhiteListAdmin();
        // super.initPauserRole();
    }

    /**
     * @notice Call from original farm (the genesis contract).
     *
     */
    function newFarm(
        uint256 _rewardRate,
        uint256 _minStake,
        uint256 _maxStake,
        IERC20 _tokenAddress,
        address newOwner
    ) public {
        require(!isCloned, "Not callable from clone");
        address clone = createClone(address(this));
        DaoLaunchFarm(clone).init(_rewardRate, _minStake, _maxStake, _tokenAddress);
        DaoLaunchFarm(clone).setCloned();
        DaoLaunchFarm(clone).transferOwnership(newOwner);

        farms[newOwner].push(clone);

        emit FarmCreated(newOwner, clone);
    }

    function setCloned() external onlyOwner {
        require(!isCloned, "Not callable from clone");
        isCloned = true;
    }

    /**
     * Call from Genesis to Cloned Farm to update the number of NFT
     */
    // function updateNftNum(uint256 oldNum, uint256 newNum) private {
    // 	if(newNum  > oldNum)
    // 		nftAddedNum += newNum - oldNum;
    // 	else
    // 		nftAddedNum -= oldNum - newNum;
    // }

    // function updateNftNum2(uint256 oldNum, uint256 newNum) external {
    // 	require(msg.sender == genesisFarm, "only genesis can update from outside");
    // 	if(newNum  > oldNum)
    // 		nftAddedNum += newNum - oldNum;
    // 	else
    // 		nftAddedNum -= oldNum - newNum;
    // }

    /*
     * Update Farm Setting
     * call from owner to cloned farm
     */
    function settingFarm(
        IERC20 _token,
        uint256 _rewardRate,
        uint256 _minStake,
        uint256 _maxStake
    ) external onlyOwner {
        if (token != _token) {
            require(totalSupply() == 0, "Already staked in old token");
            //require(nftAddedNum == 0, "Already added NFT in old token");
            Wrap.token = _token;
        }
        require(_minStake >= 0 && _maxStake > 0 && _maxStake >= _minStake, "Problem with min and max stake setup");
        require(_rewardRate > 0, "Reward rate too low");
        minStake = _minStake;
        maxStake = _maxStake;
        rewardRate = _rewardRate;
    }

    /*
     * Get point at the moment
     */
    function earned(address account) public view returns (uint256) {
        return points[account] + getCurrPoints(account);
    }

    /**
     * "Issued Points" = "Amount of Tokens" x "Stake days" x "Reward Rate"
     * Points will be distributed to all stakers "every 1 hour" depend on their amount of staking tokens.
     * "Reward Rate" is setting 1 day, so we have to divide by 24
     */
    function getCurrPoints(address stakingAccount) public view returns (uint256) {
        uint256 denominator = 10**IERC20(token).decimals();
        return ((block.timestamp - lastUpdateTime[stakingAccount]) * stakingBalanceOf(stakingAccount) * rewardRate * 10000000) / 86400 / denominator;
        //return blockTime.sub(lastUpdateTime[stakingAccount]).div(86400).mul(balanceOf(stakingAccount)).mul(rewardRate).div(24);
    }

    /*
     * Call from user to Cloned Farm
     * in order to STAKE
     */
    
    function stake(uint256 amount) public override updateReward(msg.sender) {
        require(amount + stakingBalanceOf(msg.sender) >= minStake && amount > 0, "Too few deposit");
        require(amount + stakingBalanceOf(msg.sender) <= maxStake, "Deposit limit reached");
        super.stake(amount);
        emit Staked(msg.sender, amount);
    }

    /*
     * Call from user to Cloned Farm
     * in order to UNSTAKE
     */
    function withdraw(uint256 amount) public override updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        if (points[msg.sender] > debtPoint[msg.sender]) {
            // require(amount <= stakingBalanceOf(msg.sender) - lockedBalance[msg.sender] , "only able to unstake free balance");

            super.withdraw(amount);
            emit Withdrawn(msg.sender, amount);
        }
        // else if (amount <= stakingBalanceOf(msg.sender) - lockedBalance[msg.sender] ) {
        // 	super.withdraw(amount);
        // 	emit Withdrawn(msg.sender, amount);
        // }
        else {
            revert("Please wait until enough point to unlock");
        }
    }

    /**
     * @notice Call from cloned Farm to Genesis Farm
     * to get Stake mode information
     * so this function is useful in Genesis Farm
     * @dev msg.sender ===> Cloned Farm address
     *
     */

    function _beforeRedeem(
        address holder,
        address _nftContract,
        uint256 _id
    ) external returns (uint256, bool, bool, uint256) {
        //stakingListFarm[msg.sender][_NftContractAddress][_id] = _desfarms;
        address clonedFarm = _msgSender();
        bool farmIsValid = false;
        for (uint256 i = 0; i < stakingListFarm[holder][_nftContract][_id].length; i++) {
            if (clonedFarm == stakingListFarm[holder][_nftContract][_id][i]) {
                farmIsValid = true;
                break;
            }
        }
        require(farmIsValid, "Call from not VALID Farm");
        Card storage c = cards[holder][_nftContract][_id];
        require(c.requiredPoints != 0, "Card not found");
        require(c.trueForShopMode == false, "Card is in Shop Mode");
        //require(block.timestamp >= c.startTime, "Card not started");
        //if(c.endTime > 0) require(block.timestamp <= c.endTime, "Card is Ended ");
        // ==> start time and end time is not used anymore, because of new specification
        require(c.supply >= 1, "this NFT is run out ");
        c.supply -= 1;
        return (c.requiredPoints, c.trueForERC1155, c.isStakingTokenLock, minLockedAmount[holder][_nftContract][_id][clonedFarm]);
    }

    /**
     * @notice Call from User wallet to cloned Farm
     *
     */

    function getData() external view returns(address) {
        return _msgSender();
    }
    
    function redeem(
        address nftAdder,
        address nftAddress,
        uint256 id
    ) external updateReward(msg.sender) {
        require(isCloned, "Not callable in Genesis Farm");
        require(points[msg.sender] >= debtPoint[msg.sender], "Unable to harvest other NFT until paid whole debt point");
        // Get requiredPoints from Genesis Farm
        uint256 requiredPoint;
        bool trueForERC1155;
        bool isStakingTokenLock;
        uint256 minLocked;
        (requiredPoint, trueForERC1155, isStakingTokenLock, minLocked) = DaoLaunchFarm(genesisFarm)._beforeRedeem(nftAdder, nftAddress, id);

        // require(points[msg.sender] >= requiredPoint, "Redemption exceeds point balance");

        if (points[msg.sender] >= requiredPoint) {
            points[msg.sender] = points[msg.sender] - requiredPoint;
            consumedPoint[nftAdder] += requiredPoint;
        } else if (isStakingTokenLock) {
            require(stakingBalanceOf(msg.sender) >= minLocked, "Not enough balance to be Locked");
            // lockedBalance[msg.sender] += stakingBalanceOf(msg.sender); // If customer want to lock whole the balance,  lockedBalance[msg.sender] += stakingBalanceOf(msg.sender);
            debtPoint[msg.sender] += requiredPoint;
            consumedPoint[nftAdder] += requiredPoint;
        } else {
            revert("redeem#: Please wait for enough Point");
        }

        if (trueForERC1155) {
            IERC1155(nftAddress).safeTransferFrom(address(genesisFarm), msg.sender, id, 1, "");
        } else {
            IERC721(nftAddress).safeTransferFrom(address(genesisFarm), msg.sender, id, "");
        }

        //updateNftNum(1, 0);

        // Update again farmAddedNftList

        emit Redeemed(msg.sender, nftAddress, id, requiredPoint);
    }

    // To handle Stack is too deep
    struct FrontendCard {
        address _NftContractAddress;
        uint256 _id;
        bool _trueForERC1155;
        uint256 _requiredPoints;
        uint256 _royalities;
        uint256 _startTime;
        uint256 _endTime; // Maybe = 0
        uint256 _supply;
    }

    /**
     * @notice Call from User to  Genesis farm direcly
     * Add NFT to Farm in Stake mode
     */

    function addForStake(
        FrontendCard calldata f,
        address _artist,
        address[] calldata _desfarms,
        bool isTokenLockSetting,
        uint256[] calldata minLockAmount
    ) external {
        require(!isCloned, "Not callable from clone");
        require(_desfarms.length > 0, "List of Farm must large than 0");
        // require(f._supply > 0, "Can not add supply Zero");
        if (!f._trueForERC1155) require(f._supply == 1 || f._supply == 0, "ERC721 supply is larger than 1");
        Card storage c = cards[msg.sender][f._NftContractAddress][f._id];
        c.artist = _artist;
        c.trueForERC1155 = f._trueForERC1155;
        // require(c.supply == 0, "Make sure not added in stakeMode yet");
        // Change from Shop Mode to Stake Mode
        // transfer all NFT from shop to genesis Farm
        if (c.trueForShopMode && (c.shop != address(0))) {
            if (f._trueForERC1155) {
                uint256 shopAmount = IERC1155(f._NftContractAddress).balanceOf(c.shop, f._id);
                IERC1155(f._NftContractAddress).safeTransferFrom(address(c.shop), msg.sender, f._id, shopAmount, "");
            } else {
                IERC721(f._NftContractAddress).safeTransferFrom(address(c.shop), msg.sender, f._id, "");
            }
            c.supply = 0;
            c.trueForShopMode = false;
            c.shop = address(0);
        }
        updateGeneral_stake(f._NftContractAddress, f._id, f._requiredPoints, f._royalities, f._startTime, f._endTime, f._supply);
        updateListFarm_stake(f._NftContractAddress, f._id, _desfarms, isTokenLockSetting, minLockAmount);
        c.supply = f._supply;
        // true for ERC1155 NFT, false for ERC721 NFT, when it is ERC721, the amount will always be 1
        emit CardAdded(f._NftContractAddress, f._id);
    }

    /**
     * @notice Call from User to the Genesis farm
     *
     struct FrontendCard {
        address _NftContractAddress;
        uint256 _id;
        bool _trueForERC1155;
        uint256 _requiredPoints;
        uint256 _royalities;
        uint256 _startTime;
        uint256 _endTime; // Maybe = 0
        uint256 _supply;
    }
     */

    function updateGeneral_stake(
        address _NftContractAddress,
        uint256 _id,
        uint256 _requiredPoints,
        uint256 _royalitiesPercent,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _amount
    ) internal {
        require(!isCloned, "Not callable from clone");

        if (_endTime > 0) {
            require(_endTime > _startTime, "End Time must be larger than Start Time");
        }
        require(_royalitiesPercent < 100, "Royalities is LARGER than 100%");
        Card storage c = cards[msg.sender][_NftContractAddress][_id];
        c.requiredPoints = _requiredPoints;
        c.royalities = _royalitiesPercent;
        c.startTime = _startTime;
        c.endTime = _endTime;
        c.trueForShopMode = false;
        // Repay NFT too the owner
        if (_amount < c.supply) {
            //removeNfts(_NftContractAddress, _id, c.supply - _amount, msg.sender);
            if (c.trueForERC1155) {
                IERC1155(_NftContractAddress).safeTransferFrom(address(this), msg.sender, _id, c.supply - _amount, "");
            } else {
                IERC721(_NftContractAddress).safeTransferFrom(address(this), msg.sender, _id, "");
            }
        } else if (_amount > c.supply) {
            if (c.trueForERC1155) {
                IERC1155(_NftContractAddress).safeTransferFrom(msg.sender, address(this), _id, _amount - c.supply, "");
            } else {
                IERC721(_NftContractAddress).safeTransferFrom(msg.sender, address(this), _id, ""); // Not use this case
            }
        }
    }

    /**
     * @notice Call from User to the Genesis farm
     *
     */
    function updateListFarm_stake(
        address _NftContractAddress,
        uint256 _id,
        address[] calldata _desfarms,
        bool isTokenLockSetting,
        uint256[] calldata minLockAmount
    ) internal {
        require(!isCloned, "Not callable from clone");

        //require(checkFarmsToAdd(_desfarms), "GenesisFarm: Array of Farms to add is NOT VALID");
        // Because normal User can add NFT to DAL farm, so don't need to check checkFarmsToAdd.

        if (isTokenLockSetting) {
            require(minLockAmount.length == _desfarms.length, "StakeFarm Length must equal to minLockAmount Length");
        }

        Card storage c = cards[msg.sender][_NftContractAddress][_id];
        c.isStakingTokenLock = isTokenLockSetting;

        removeFarming(msg.sender, _NftContractAddress, _id);
        stakingListFarm[msg.sender][_NftContractAddress][_id] = _desfarms;

        for (uint256 i = 0; i < _desfarms.length; i++) {
            address farm = _desfarms[i];
            // farmAddedNftList[farm][address(_erc721Address)].push(_tokenId);

            // Set Approve for Farms that NFT were added // No meaning
            if (c.trueForERC1155) {
                IERC1155(_NftContractAddress).setApprovalForAll(farm, true);
            } else {
                IERC721(_NftContractAddress).setApprovalForAll(farm, true);
            }
            // Just for count num of NFTs
            //DaoLaunchFarm(farm).updateNftNum2( 0, _amount);

            if (isTokenLockSetting) {
                minLockedAmount[msg.sender][_NftContractAddress][_id][_desfarms[i]] = minLockAmount[i];
            }
        }
    }

    function addedStakeModeAmount(
        address adder,
        address nftContract,
        uint256 tokenId
    ) public view returns (uint256) {
        return cards[adder][nftContract][tokenId].supply;
    }

    /*
     * Is Available in Genesis Farm
     * Call when update list farm, or when change from Stake mode to shop mode
     */
    function removeFarming(
        address holder,
        address _NftContractAddress,
        uint256 _id
    ) private {
        // Update again stakingListFarm in update mode
        if (stakingListFarm[holder][_NftContractAddress][_id].length > 0) {
            delete stakingListFarm[holder][_NftContractAddress][_id];
        }
    }

    /**
     * @notice Available in Genesis Farm
     * Check the Array of Farm to Add NFT is belongs to the User or not.
     * Before adding Stake mode
     */

    // function checkFarmsToAdd(address[] calldata _desfarms) private view returns(bool) {
    // 	bool ok = true;
    // 	for (uint j = 0; j < _desfarms.length; j++){
    // 		bool found = false;

    // 		for(uint i = 0; i < farms[msg.sender].length; i++) {
    // 			if(_desfarms[j] == farms[msg.sender][i]){
    // 				found = true;
    // 				break;
    // 			}
    // 		}
    // 		if(found == false) {
    // 			ok = false;
    // 			break;
    // 		}
    // 	}

    // 	return ok;
    // }

    /**
     * @notice Call from user to cloned farm
     *
     */
    function addShopMode(
        address _NftContractAddress, //0x7CD2c27792840F862a58500706c6b68D01FdB312
        uint256 _tokenId,//1
        bool _trueForERC1155,//true
        uint256 _royalitiesPercent,//10
        address _artist,//0x6Ccb41eedA5a073076F3E7dC1614C185b5fA41eD
        uint256 _startTime,//1657693220
        uint256 _endTime,//1657893220
        uint256 _pricePerPiece,//20
        uint256 _amount//300
    ) external {
        require(isCloned, "Not callable in Genesis Farm");
        if (_endTime > 0) {
            require(_endTime > _startTime, "End Time must be larger than Start Time");
        }
        require(_royalitiesPercent < 100, "Royalities is LARGER than 100%");
        if (!_trueForERC1155) require(_amount < 2, "when ERC721, amount must less than 2");
        require(_pricePerPiece > 0, "Price is TOO LOW");

        Card storage c = shopCards[_NftContractAddress][_tokenId];

        c.startTime = _startTime;
        c.endTime = _endTime;
        c.royalities = _royalitiesPercent;
        c.artist = _artist;
        c.trueForERC1155 = _trueForERC1155;
        c.pricePerPiece = _pricePerPiece;

        c.trueForShopMode = true; // Nonsense ?

        DaoLaunchFarm(genesisFarm)._beforeShopMode(_NftContractAddress, _tokenId, _trueForERC1155, msg.sender);

        if (_amount > 0) {
            if (_trueForERC1155) {
                uint256 holderBalance = IERC1155(_NftContractAddress).balanceOf(msg.sender, _tokenId);

                if (holderBalance >= _amount) {
                    IERC1155(_NftContractAddress).safeTransferFrom(msg.sender, address(this), _tokenId, _amount, "");
                }
                IERC1155(_NftContractAddress).setApprovalForAll(genesisFarm, true); // Approve for Genesis to manage late
            } else {
                if (IERC721(_NftContractAddress).ownerOf(_tokenId) == msg.sender) {
                    IERC721(_NftContractAddress).safeTransferFrom(msg.sender, address(this), _tokenId, "");
                    IERC721(_NftContractAddress).setApprovalForAll(genesisFarm, true); // Approve for Genesis to manage later
                }
            }
        }
        //updateNftNum(c.supply, _amount);
        c.supply = _amount;

        // true for ERC1155 NFT, false for ERC721 NFT, when it is ERC721, the amount will always be 1
        emit CardAdded(_NftContractAddress, _tokenId);
    }

    /**
     * When User call to cloned Farm for adding NFT shop mode. After that, inside those function
     * @notice Call from Cloned Farm to Genesis farm
     * this function is only available in Genesis Farm
     * @dev msg.sender is cloned farm
     */
    function _beforeShopMode(
        address _NftContractAddress,
        uint256 _tokenId,
        bool _trueForERC1155,
        address _endUser
    ) external onlyChildFarm(_endUser, msg.sender) {
        require(!isCloned, "Not callable in Cloned Farm");
        Card storage c = cards[_endUser][_NftContractAddress][_tokenId];
        // Being added in stake mode, or not yet added to Farm yet
        if (!c.trueForShopMode && c.shop == address(0)) {
            // Update again stakingListFarm
            removeFarming(_endUser, _NftContractAddress, _tokenId);
            if (_trueForERC1155) {
                uint256 stakeModeBalance = IERC1155(_NftContractAddress).balanceOf(address(this), _tokenId);
                if (stakeModeBalance > 0) {
                    IERC1155(_NftContractAddress).safeTransferFrom(address(this), _endUser, _tokenId, c.supply, "");
                }
            } else {
                if (IERC721(_NftContractAddress).ownerOf(_tokenId) == address(this)) {
                    IERC721(_NftContractAddress).safeTransferFrom(address(this), _endUser, _tokenId, "");
                }
            }

            // Update again Card in Genesis Farm
            c.trueForShopMode = true;
            c.shop = msg.sender;
            c.supply = 0; // Set Stake Amount = Zero
        } else {
            // Being shopmode already
            // Transfer all from old Farm to Genesis to manage
            if (_trueForERC1155) {
                uint256 oldShopBalance = IERC1155(_NftContractAddress).balanceOf(address(c.shop), _tokenId);
                IERC1155(_NftContractAddress).safeTransferFrom(address(c.shop), _endUser, _tokenId, oldShopBalance, "");
                // IERC1155(_NftContractAddress).setApprovalForAll(address(c.shop), false);
                //DaoLaunchFarm(c.shop).updateNftNum2(oldShopBalance, 0);
            } else {
                if (IERC721(_NftContractAddress).ownerOf(_tokenId) == address(c.shop)) {
                    IERC721(_NftContractAddress).safeTransferFrom(address(c.shop), _endUser, _tokenId, "");
                    // IERC721(_NftContractAddress).setApprovalForAll(address(c.shop), false);
                    //DaoLaunchFarm(c.shop).updateNftNum2(1, 0);
                }
            }
            c.shop = msg.sender;
            c.trueForShopMode = true;
        }

        // Set Approval for new Shop
        if (_trueForERC1155) {
            IERC1155(_NftContractAddress).setApprovalForAll(msg.sender, true);
            //c.trueForERC1155 = true;
        } else {
            IERC721(_NftContractAddress).setApprovalForAll(msg.sender, true);
            //c.trueForERC1155 = false;
        }

        // update again "farmAddedNftList"
        /*
		uint256[] storage farmAddedNfts = farmAddedNftList[msg.sender][_NftContractAddress];
		uint256 temp = farmAddedNfts[farmAddedNfts.length - 1];
		bool found = false;
		for(uint i = 0; i < farmAddedNfts.length ; i++){
			if (farmAddedNfts[i] == _tokenId){
				found = true;
				farmAddedNfts[i] = temp;
				break;
			}
		}

		if(found){
			farmAddedNfts.pop();
		}
		*/
    }

    /**
     * Call from user to Cloned Farm to buy NFT
     */
    function buy(
        address _nftContract,
        uint256 _id,
        uint256 _amount
    ) external {
        require(isCloned, "Buy: Only call from cloned");
        require(_amount > 0, "Amount must not be 0");
        Card storage c = shopCards[_nftContract][_id];
        require(c.pricePerPiece > 0 && c.trueForShopMode && c.supply >= _amount, "Not available NFT for buying");
        require(block.timestamp >= c.startTime, "Card not started");
        if (c.endTime > 0) require(block.timestamp <= c.endTime, "Card is Ended ");
        if (!c.trueForERC1155) require(_amount == 1, "NFT is ERC721, so amount must be 1");

        uint256 userBalance = IERC20(token).balanceOf(msg.sender);
        require(_amount * c.pricePerPiece <= userBalance, "Buy: Wallet not enough token");

        if (c.artist != address(0) && c.royalities > 0) {
            IERC20(token).transferFrom(msg.sender, owner(), (_amount * c.pricePerPiece * (100 - c.royalities)) / 100);
            IERC20(token).transferFrom(msg.sender, address(c.artist), (_amount * c.pricePerPiece * c.royalities) / 100);
        } else {
            IERC20(token).transferFrom(msg.sender, owner(), _amount * c.pricePerPiece);
        }

        if (c.trueForERC1155) {
            IERC1155(_nftContract).safeTransferFrom(address(this), msg.sender, _id, _amount, "");
            c.supply -= _amount;
        } else {
            IERC721(_nftContract).safeTransferFrom(address(this), msg.sender, _id, "");
            c.supply -= 1;
        }
    }

    function getFarmsLength(address _address) external view returns (uint256) {
        return farms[_address].length;
    }

    function onERC1155Received(
        address _operator,
        address _from,
        uint256 _id,
        uint256 _amount,
        bytes calldata _data
    ) external returns (bytes4) {
        if (IERC1155(_operator) == IERC1155(address(this))) {
            return ERC1155_RECEIVED_VALUE;
        }

        return ERC_RECEIVED_ERR_VALUE;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        if (IERC721(operator) == IERC721(address(this))) {
            return ERC721_RECEIVED_VALUE;
        }

        return ERC_RECEIVED_ERR_VALUE;
    }

    /*
     * Delete this contract
     */
    function discard() external onlyOwner {
        selfdestruct(payable(owner()));
    }
}
