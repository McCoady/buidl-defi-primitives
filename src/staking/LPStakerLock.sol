// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "lib/solmate/src/tokens/ERC20.sol";

contract LPStakerLock {
    /* ========== TYPES ========== */
    struct LockInfo {
        bool claimed;
        address user;
        uint256 amount;
        uint128 unlockTime;
        uint128 id;
    }

    /* ========== STATE VARS ========== */
    ERC20 public lpToken;
    ERC20 public rewardToken;

    uint public constant LOCK_DURATION = 7 days;
    uint256 nextId = 1;

    mapping(address => uint256[]) addressToLockIds;
    mapping(address => uint256) public claimableRewards;
    mapping(uint256 => LockInfo) public idToLockInfo;

    /* ========== EVENTS ========== */
    event RewardsRedeemed(address indexed user, uint256 rewardAmount);
    event TokensLocked(address indexed user, uint256 amountLocked);
    event TokensUnlocked(address indexed user, uint256 amountUnlocked);

    /* ========== CUSTOM ERRORS ========== */
    error InvalidId();
    error LpAlreadyClaimed();
    error LpNotUnlockedYet();
    error LpTransferFailed();
    error NoRewardsClaimable();
    error NotYourLp();
    error RewardTransferFailed();

    /* ========== CONSTRUCTOR ========== */
    constructor(ERC20 _lpToken, ERC20 _rewardToken) {
        lpToken = _lpToken;
        rewardToken = _rewardToken;
    }

    /* ========== FUNCTIONS ========== */

    /// @notice allows user to lock lpToken
    /// @param amount the amount of the lpToken to lock
    function lockLp(uint256 amount) external {
        uint256 thisId = nextId;
        idToLockInfo[thisId] = LockInfo(
            false,
            msg.sender,
            amount,
            uint128(block.timestamp + LOCK_DURATION),
            uint128(thisId)
        );
        addressToLockIds[msg.sender].push(thisId);

        ++nextId;

        bool lpTransferred = lpToken.transferFrom(
            msg.sender,
            address(this),
            amount
        );
        if (!lpTransferred) revert LpTransferFailed();

        emit TokensLocked(msg.sender, amount);
    }

    /// @notice allows users to unlock their LP tokens after LOCK_DURATION
    /// @param id the id the LockInfo struct to redeem
    /// @dev user can call getUserActiveLockIds to see which of their locks are active
    /// @dev rewards are claimable by calling redeemRewards, this stops funds being locked if contract has no rewards tokens
    function redeemUnlockedLp(uint256 id) external {
        if (id >= nextId) revert InvalidId();
        LockInfo storage thisId = idToLockInfo[id];
        if (thisId.claimed == true) revert LpAlreadyClaimed();
        if (thisId.unlockTime > block.timestamp) revert LpNotUnlockedYet();
        if (thisId.user != msg.sender) revert NotYourLp();

        thisId.claimed = true;

        uint256 rewardAmount = thisId.amount / 20;
        claimableRewards[msg.sender] += rewardAmount;

        bool lpTransferred = lpToken.transfer(msg.sender, thisId.amount);
        if (!lpTransferred) revert LpTransferFailed();

        emit TokensUnlocked(msg.sender, thisId.amount);
    }

    /// @notice allow users to redeem rewards tokens
    function redeemRewards() external {
        uint256 rewardAmount = claimableRewards[msg.sender];
        if (rewardAmount == 0) revert NoRewardsClaimable();
        claimableRewards[msg.sender] = 0;

        bool rewardTransferred = rewardToken.transfer(msg.sender, rewardAmount);
        if (!rewardTransferred) revert RewardTransferFailed();

        emit RewardsRedeemed(msg.sender, rewardAmount);
    }

    /// @notice returns array of users lockIds
    /// @param user address to check
    /// @dev if a lockId has already been claimed the slot in the array is changed to 0
    /// @return array of users lockIds
    function getUserActiveLockIds(
        address user
    ) external view returns (uint256[] memory) {
        uint256[] memory allLockIds = addressToLockIds[user];
        uint256 allIdsLength = allLockIds.length;
        for (uint256 i; i < allIdsLength; ++i) {
            uint256 id = allLockIds[i];
            if (idToLockInfo[id].claimed) {
                allLockIds[i] = 0;
            }
        }
        return allLockIds;
    }

    /// @notice allow users to see the timestamp their tokens will be unlocked
    /// @param id the id of LockInfo struct to check
    /// @return timestamp of LockInfo's unlock
    function checkIdExpiryTimestamp(
        uint256 id
    ) external view returns (uint256) {
        if (id >= nextId) revert InvalidId();
        LockInfo memory thisId = idToLockInfo[id];
        return thisId.unlockTime;
    }

    /// @notice allow users to see how many seconds until their tokens unlock
    /// @param id the id of LockInfo struct to check
    /// @return seconds until LockInfo's unlock
    /// @dev returns zero if unlock ready
    function checkIdExpiryCountdown(
        uint256 id
    ) external view returns (uint256) {
        if (id >= nextId) revert InvalidId();
        LockInfo memory thisId = idToLockInfo[id];

        if (thisId.claimed) revert LpAlreadyClaimed();
        if (thisId.unlockTime < block.timestamp) return 0;
        return thisId.unlockTime - block.timestamp;
    }
}
