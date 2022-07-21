//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.12;

import "./IExchange.sol";

contract Context {
    // Empty internal constructor, to prevent people from mistakenly deploying
    // an instance of this contract, which should be used via inheritance.
    constructor() internal {}

    function _msgSender() internal view returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

/* --------- Access Control --------- */
contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

library SafeMath {
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x, "ds-math-add-overflow");
    }

    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x, "ds-math-sub-underflow");
    }

    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x, "ds-math-mul-overflow");
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256 c) {
        require(b > 0, "ds-math-mul-overflow");
        c = a / b;
    }
}

interface IERC20 {
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function burn(uint amount) external ;
    
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function mint(uint256 amount) external returns (bool);
}

// each staking instance mapping to each pool
contract Staking is Ownable {
    using SafeMath for uint256;
    event Stake(address staker, uint256 amount);
    event Reward(address staker, uint256 amount_1, uint256 amount_2);
    event Withdraw(address staker, uint256 amount);
    //staker inform
    struct Staker {
        uint referal;
        uint256 stakingAmount; // staking token amount
        uint256 lastUpdateTime; // last amount updatetime
        uint256 lastStakeUpdateTime; // last Stake updatetime
        uint256 stake; // stake amount
        uint256 rewards_1; // stake amount
        uint256 rewards_2; // stake amount
    }
    //stakeToken is
    address public rewardTokenAddress_1;
    address public rewardTokenAddress_2;
    address public stakeTokenAddress; //specify farming token when contract created

	address public marketingAddress;

    uint256 public totalStakingAmount; // total staking token amount
    uint256 public lastUpdateTime; // total stake amount and reward update time
    uint256 public totalStake; // total stake amount

    uint256 public stakerNum;

    IPancakeSwapRouter public PancakeSwapRouter;

    mapping(address => Staker) public stakers;

    constructor(
        address _stakeTokenAddress,
        address _rewardTokenAddress_1,
        address _rewardTokenAddress_2
    ) public {
        rewardTokenAddress_1 = _rewardTokenAddress_1;
        rewardTokenAddress_2 = _rewardTokenAddress_2;
        stakeTokenAddress = _stakeTokenAddress;
        lastUpdateTime = block.timestamp;
    }

    /* ----------------- total counts ----------------- */

    function countTotalStake() public view returns (uint256 _totalStake) {
        _totalStake =
            totalStake +
            totalStakingAmount.mul((block.timestamp).sub(lastUpdateTime));
    }

    function countTotalReward()
        public
        view
        returns (uint256 _totalReward_1, uint256 _totalReward_2)
    {
        _totalReward_1 = IERC20(rewardTokenAddress_1).balanceOf(address(this));
        _totalReward_2 = IERC20(rewardTokenAddress_2).balanceOf(address(this));
    }

    function updateTotalStake() internal {
        (uint256 _rewardableAmount_1, ) = getRewardableAmount();
        if (_rewardableAmount_1 > 1e1 * 1e18) {
            swapTokenForReward();
        }

        totalStake = countTotalStake();
        lastUpdateTime = block.timestamp;
    }

    function APY() external view returns (uint) {
        uint256 _totalStakte = countTotalStake();
        if (_totalStakte == 0) return 0;
        (uint256 _reward1, uint256 _reward2) = countTotalReward();

        uint256 rewardable1 ;
        uint256 rewardable2 ;
		if(_reward1 > 1e17&&_reward2 > 1e17){
			address[] memory path_1 = new address[](2);
			address[] memory path_2 = new address[](2);
			path_1[0] = stakeTokenAddress;
			path_1[1] = rewardTokenAddress_1;
			path_2[0] = stakeTokenAddress;
			path_2[1] = rewardTokenAddress_2;

			uint256[] memory d1 = PancakeSwapRouter.getAmountsIn(_reward1, path_1);
			uint256[] memory d2 = PancakeSwapRouter.getAmountsIn(_reward2, path_2);

			rewardable1 = d1[0];
			rewardable2 = d2[1];
		}

        uint256 _totalReward = rewardable1 +
            rewardable2 +
            IERC20(stakeTokenAddress).balanceOf(address(this)) - totalStakingAmount;

        return (_totalReward * 1000000 * 365 days) / _totalStakte;
    }

    /* ----------------- personal counts ----------------- */

    function getStakeInfo(address stakerAddress)
        public
        view
        returns (
            uint256 _total,
            uint256 _staking,
            uint256 _rewardable_1,
            uint256 _rewardable_2,
            uint256 _rewards_1,
            uint256 _rewards_2
        )
    {
        _total = totalStakingAmount;
        _staking = stakers[stakerAddress].stakingAmount;
        (_rewardable_1, _rewardable_2) = countReward(stakerAddress);
        _rewards_1 = stakers[stakerAddress].rewards_1;
        _rewards_2 = stakers[stakerAddress].rewards_2;
    }

    function countStake(address stakerAddress)
        public
        view
        returns (uint256 _stake)
    {
        Staker memory _staker = stakers[stakerAddress];
        if (_staker.lastUpdateTime == 0) return 0;
        _stake =
            _staker.stake +
            ((block.timestamp).sub(_staker.lastUpdateTime)).mul(
                _staker.stakingAmount
            );
    }

    function countReward(address stakerAddress)
        public
        view
        returns (uint256 _reward_1, uint256 _reward_2)
    {
        uint256 _totalStake = countTotalStake();
        (uint256 _totalReward1, uint256 _totalReward2) = countTotalReward();
        uint256 stake = countStake(stakerAddress);
        _reward_1 = _totalStake == 0
            ? 0
            : _totalReward1.mul(stake).div(_totalStake);
        _reward_2 = _totalStake == 0
            ? 0
            : _totalReward2.mul(stake).div(_totalStake);
    }

    function countFee(address stakerAddress)
        public
        view
        returns (uint256 _fee)
    {
        if (
            block.timestamp.sub(stakers[stakerAddress].lastStakeUpdateTime) <
            42 days
        ) {
            _fee = 250;
        } else _fee = 0;
    }

	function checkReward(address stakerAddress)
        public
        view
        returns (uint256 _reward_1, uint256 _reward_2)
    {
        uint256 _totalStake = countTotalStake();
        (uint256 _totalReward1, uint256 _totalReward2) = countTotalReward();

		(uint tokenAmount_1, uint tokenAmount_2) = getRewardableAmount();
		
		if( tokenAmount_1 > 1e17 && tokenAmount_2 > 1e17 ){
			address[] memory path_1 = new address[](2);
			address[] memory path_2 = new address[](2);
			path_1[0] = stakeTokenAddress;
			path_1[1] = rewardTokenAddress_1;
			path_2[0] = stakeTokenAddress;
			path_2[1] = rewardTokenAddress_2;

			uint[] memory d1 = PancakeSwapRouter.getAmountsOut(
					tokenAmount_1,
					path_1
				);

			uint[] memory d2 = PancakeSwapRouter.getAmountsOut(
					tokenAmount_2,
					path_2
				);

			_totalReward1 = _totalReward1 + d1[0];
			_totalReward2 = _totalReward2 + d2[0];
		}		
        uint256 stake = countStake(stakerAddress)+ stakers[stakerAddress].referal;
        _reward_1 = _totalStake == 0
            ? 0
            : _totalReward1.mul(stake).div(_totalStake);
        _reward_2 = _totalStake == 0
            ? 0
            : _totalReward2.mul(stake).div(_totalStake);
    }

    /* ----------------- actions ----------------- */

    function stake(uint256 amount ,address referrar) external {
        address stakerAddress = msg.sender;
        if (stakers[stakerAddress].lastUpdateTime == 0) stakerNum++;
        
        stakers[stakerAddress].stake = countStake(stakerAddress);
        
        stakers[stakerAddress].stakingAmount += amount.mul(990).div(1000);
        stakers[stakerAddress].lastUpdateTime = block.timestamp;
        stakers[stakerAddress].lastStakeUpdateTime = block.timestamp;
        

        if(referrar != address(0) && referrar != stakerAddress) {
            uint referalReward = amount * 1 days;
            stakers[referrar].referal += referalReward;
            totalStake += referalReward;
        }

        updateTotalStake();

		IERC20(stakeTokenAddress).transferFrom(
			stakerAddress,
			address(this),
			amount.mul(995).div(1000)
		);

        IERC20(stakeTokenAddress).transferFrom(
            stakerAddress,
			marketingAddress,
			amount.mul(5).div(1000)
		);

        totalStakingAmount = totalStakingAmount + amount.mul(995).div(1000);
        emit Stake(stakerAddress, amount);
    }

    function unstaking() external {
        address stakerAddress = msg.sender;
        uint256 amount = stakers[stakerAddress].stakingAmount;
        require(0 <= amount, "staking : amount over stakeAmount");
        uint256 withdrawFee = countFee(stakerAddress);


        stakers[stakerAddress].stake = countStake(stakerAddress);
        stakers[stakerAddress].stakingAmount -= amount;
        stakers[stakerAddress].lastUpdateTime = block.timestamp;
        stakers[stakerAddress].lastStakeUpdateTime = block.timestamp;

        updateTotalStake();
        totalStakingAmount = totalStakingAmount - amount;

        if(withdrawFee > 0){
            IERC20(stakeTokenAddress).burn(
                amount.mul(4).div(1000)
            );
            
            IERC20(stakeTokenAddress).transfer(
                marketingAddress,
                amount.mul(5).div(1000)
            );
        }

        IERC20(stakeTokenAddress).transfer(
            stakerAddress,
            amount.mul(1000 - withdrawFee).div(1000)
        );
        emit Withdraw(stakerAddress, amount);
    }

    function claimRewards() external {
        address stakerAddress = msg.sender;

        updateTotalStake();
        uint256 _stake = countStake(stakerAddress) + stakers[stakerAddress].referal;
        (uint256 _reward_1, uint256 _reward_2) = countReward(stakerAddress);

        require(_reward_1 > 0, "staking : reward amount is 0");
        IERC20 rewardToken_1 = IERC20(rewardTokenAddress_1);
        IERC20 rewardToken_2 = IERC20(rewardTokenAddress_2);

        rewardToken_1.transfer(stakerAddress, _reward_1);
        rewardToken_2.transfer(stakerAddress, _reward_2);

        stakers[stakerAddress].rewards_1 += _reward_1;
        stakers[stakerAddress].rewards_2 += _reward_2;
        totalStake -= _stake;

        stakers[stakerAddress].stake = 0;
        stakers[stakerAddress].referal = 0;
        stakers[stakerAddress].lastUpdateTime = block.timestamp;

        emit Reward(stakerAddress, _reward_1, _reward_2);
    }

    /* ----------------- swap for token ----------------- */


    function setInitialAddresses(address _RouterAddress, address _marketingAddress) external onlyOwner {
        marketingAddress = _marketingAddress;
        IPancakeSwapRouter _PancakeSwapRouter = IPancakeSwapRouter(
            _RouterAddress
        );
        PancakeSwapRouter = _PancakeSwapRouter;
    }

    function getRewardableAmount()
        public
        view
        returns (uint256 _rewardableAmount_1, uint256 _rewardableAmount_2)
    {
		uint rewardable = IERC20(stakeTokenAddress).balanceOf(address(this)) - totalStakingAmount;
        _rewardableAmount_1 =
            rewardable /
            2;
        _rewardableAmount_2 =
            rewardable /
            2;
    }

    function swapTokenForReward() public {
        (
            uint256 _rewardableAmount_1,
            uint256 _rewardableAmount_2
        ) = getRewardableAmount();
        swapTokensForRewardToken(_rewardableAmount_1, _rewardableAmount_2);
    }

    function swapTokensForRewardToken(
        uint256 tokenAmount_1,
        uint256 tokenAmount_2
    ) internal {
        address[] memory path_1 = new address[](2);
        address[] memory path_2 = new address[](2);
        path_1[0] = stakeTokenAddress;
        path_1[1] = rewardTokenAddress_1;
        path_2[0] = stakeTokenAddress;
        path_2[1] = rewardTokenAddress_2;

        IERC20(stakeTokenAddress).approve(
            address(PancakeSwapRouter),
            tokenAmount_1 + tokenAmount_2
        );

        // make the swap

        PancakeSwapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                tokenAmount_1,
                0, // accept any amount of usdt
                path_1,
                address(this),
                block.timestamp
            );

        PancakeSwapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                tokenAmount_2,
                0, // accept any amount of usdt
                path_2,
                address(this),
                block.timestamp
            );
    }
}
