// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @title Simple ERC20 staking contract from solidity-by-example
contract SimpleStaker {
    IERC20 public stakingToken;
    IERC20 public rewardsToken;

    bool initialized;

    // Duration of rewards to be paid out (in seconds)
    uint public duration;
    // Timestamp of when the rewards finish
    uint public finishAt;
    // Minimum of last updated time and reward finish time
    uint public updatedAt;
    // Reward to be paid out per second
    uint public rewardRate;
    // Sum of (reward rate * dt * 1e18 / total supply)
    uint public rewardPerTokenStored;
    // User address => rewardPerTokenStored
    mapping(address => uint) public userRewardPerTokenPaid;
    // User address => rewards to be claimed
    mapping(address => uint) public rewards;

    // Total staked
    uint public totalSupply;
    // User address => staked amount
    mapping(address => uint) public balanceOf;

    error AlreadyInit();

    function init(
        address _stakingToken,
        address _rewardToken,
        uint256 stakingDuration,
        uint256 rewardAmount
    ) external {
        if (initialized) revert AlreadyInit();

        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardToken);

        // make sure the contract has the necessary amount of rewards to pay out
        IERC20(rewardsToken).transferFrom(
            msg.sender,
            address(this),
            rewardAmount
        );

        // set staking duration
        duration = stakingDuration;
        finishAt = block.timestamp + stakingDuration;

        updatedAt = block.timestamp;
        rewardRate = rewardAmount / stakingDuration;
    }

    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = lastTimeRewardApplicable();

        rewards[_account] = earned(_account)    ;
        userRewardPerTokenPaid[_account] = rewardPerTokenStored;

        _;
    }

    function lastTimeRewardApplicable() public view returns (uint) {
        // if finished returns finishAt else returns block.timestamp
        return _min(finishAt, block.timestamp);
    }

    function rewardPerToken() public view returns (uint) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }

        // current rewardPerTokenStored amount plus ->
        // seconds since last update * 10**18 divided by total supply
        // so 10 seconds / 100 supply = 0.1
        // 10 seconds / 200 supply = 0.05 (so amount of tokens earned per second is lower if more tokens are staked) 
        return
            rewardPerTokenStored +
            (rewardRate * (lastTimeRewardApplicable() - updatedAt) * 1e18) /
            totalSupply;
    }

    // allows user to stake tokens
    // sends the tokens to this contract
    // tracks user balance and total supply internally (not via ERC20 functions)
    function stake(uint _amount) external updateReward(msg.sender) {
        require(_amount > 0, "amount = 0");
        stakingToken.transferFrom(msg.sender, address(this), _amount);
        balanceOf[msg.sender] += _amount;
        totalSupply += _amount;
    }

    // allows user to withdraw staked tokens
    // updates internal balances then transfers the ERC20 back
    function withdraw(uint _amount) external updateReward(msg.sender) {
        require(_amount > 0, "amount = 0");
        balanceOf[msg.sender] -= _amount;
        totalSupply -= _amount;
        stakingToken.transfer(msg.sender, _amount);
    }

    // how much an account has earned
    function earned(address _account) public view returns (uint) {
        // account balance * (rewardPerToken - userRewardPerTokenPaid) / 1**18 + current rewards
        return
            ((balanceOf[_account] *
                (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e18) +
            rewards[_account];
    }

    function getReward() external updateReward(msg.sender) {
        uint reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.transfer(msg.sender, reward);
        }
    }

    function _min(uint x, uint y) private pure returns (uint) {
        return x <= y ? x : y;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint);

    function balanceOf(address account) external view returns (uint);

    function transfer(address recipient, uint amount) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint);

    function approve(address spender, uint amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}
