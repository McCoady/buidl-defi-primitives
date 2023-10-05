// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IERC20 {
    function transferFrom(address, address, uint256) external returns (bool);

    function transfer(address, uint256) external returns (bool);
}

/// @title basic contract to lock tokens
/// @author mctoady.eth
/// @notice contract can lock any ERC20, not LP token specific
contract BasicLPLock {
    /* ========== TYPES ========== */
    struct LockInfo {
        bool claimed;
        address user;
        address lpToken;
        uint256 amount;
        uint128 unlockTime;
        uint128 id;
    }

    /* ========== STATE VARS ========== */
    uint256 nextId = 1;

    // contract has an arbitrary locking duration of 7 days, alternative could be user defined
    uint public constant LOCK_DURATION = 7 days;

    mapping(address => uint256[]) addressToLockIds;
    mapping(uint256 => LockInfo) public idToLockInfo;

    /* ========== EVENTS ========== */
    event TokensLocked(address indexed user, address indexed token, uint256 amountLocked);
    event TokensUnlocked(address indexed user, address indexed token, uint256 amountUnlocked);

    /* ========== CUSTOM ERRORS ========== */
    error InvalidId();
    error LpAlreadyClaimed();
    error LpNotUnlockedYet();
    error LpTransferFailed();
    error NotYourLp();
    error RewardTransferFailed();

    /* ========== FUNCTIONS ========== */

    /// @notice allows user to lock ERC20 tokens
    /// @param lpToken the address of the token to lock
    /// @param amount the amount of the token to lock
    /// @dev doesn't stop users from locking non LP tokens, and requires allowance set first
    function lockLp(address lpToken, uint256 amount) external {
        uint256 thisId = nextId;
        idToLockInfo[thisId] = LockInfo(
            false,
            msg.sender,
            lpToken,
            amount,
            uint128(block.timestamp + LOCK_DURATION),
            uint128(thisId)
        );
        addressToLockIds[msg.sender].push(thisId);

        ++nextId;

        bool lpTransferred = IERC20(lpToken).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        if (!lpTransferred) revert LpTransferFailed();

        emit TokensLocked(msg.sender, lpToken, amount);
    }

    /// @notice allows users to unlock ERC20 tokens after LOCK_DURATION
    /// @param id the id the LockInfo struct to redeem
    /// @dev user can call getUserActiveLockIds to see which of their locks are active
    function redeemUnlockedLp(uint256 id) external {
        if (id >= nextId) revert InvalidId();
        LockInfo storage thisId = idToLockInfo[id];
        if (thisId.claimed == true) revert LpAlreadyClaimed();
        if (thisId.unlockTime > block.timestamp) revert LpNotUnlockedYet();
        if (thisId.user != msg.sender) revert NotYourLp();

        thisId.claimed = true;

        bool lpTransferred = IERC20(thisId.lpToken).transfer(msg.sender, thisId.amount);
        if (!lpTransferred) revert LpTransferFailed();

        emit TokensUnlocked(msg.sender, thisId.lpToken, thisId.amount);
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
        if (thisId.unlockTime < block.timestamp) return 0;
        if (thisId.claimed) revert LpAlreadyClaimed();
        return thisId.unlockTime - block.timestamp;
    }
}
