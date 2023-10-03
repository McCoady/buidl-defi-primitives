// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "lib/solmate/src/tokens/ERC20.sol";
import {ERC4626} from "lib/solmate/src/mixins/ERC4626.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);

    function transfer(address, uint256) external returns (bool);

    function transferFrom(address, address, uint256) external returns (bool);
}

// TODO: store loan ID?
struct BorrowInfo {
    uint128 amount;
    uint64 start;
    uint32 id;
    bool cleared;
    address borrower;
}

contract BasicBorrower is ERC4626 {
    /* ========== STATE VARS ========== */
    uint256 constant STATIC_BORROW_PCT = 5; // 0.5%
    uint256 constant FEE_PER_HOUR = 1; // 0.1%

    uint256 public totalCurrentlyBorrowed;
    uint256 loanId;

    mapping(address => uint256) public userBorrowedAmount;
    mapping(uint256 => BorrowInfo) public borrowIdToInfo;

    /* ========== EVENTS ========== */
    event LiqudityDeposited(address indexed user, uint256 amount);
    event LiquidityWithdrawn(address indexed user, uint256 amount);
    event FundsBorrowed(address indexed user, uint256 amount);
    event FundsRepaid(address indexed user, uint256 amount);

    /* ========== CUSTOM ERRORS ========== */
    error AlreadyInit();
    error BorrowNotUnderwater();
    error FundsRequiredForCollateral();
    error InsufficientBalance();
    error InsufficientBorrowAmount();
    error InsufficientCollateral();
    error InsufficientWithdrawal();
    
    /* ========== CONSTRUCTOR ========== */
    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol
    ) ERC4626(_asset, _name, _symbol) {}

    /* ========== FUNCTIONS ========== */

    /// @notice nothing required in current form
    /// @notice assets not required
    /// @notice shares not required
    function afterDeposit(uint256 assets, uint256 shares) internal override {}

    /// @notice check user doesn't have outstanding borrows before they withdraw their collateral
    /// @param assets not required
    /// @param shares not required
    function beforeWithdraw(uint256 assets, uint256 shares) internal override {
        // TODO: do maths to check if user has required liquidity
        if (userBorrowedAmount[msg.sender] != 0)
            revert FundsRequiredForCollateral();
    }


    /// @notice borrow funds from the pool
    /// @param amount how much to borrow
    /// @dev user must have provided 1.2x their borrow amount as collateral
    function borrowFunds(uint256 amount) external {
        if (amount < 1 ether) revert InsufficientBorrowAmount();

        uint256 userTotalBorrowAmount = userBorrowedAmount[msg.sender] + amount;
        uint256 requiredCollateral = (userTotalBorrowAmount * 12) / 10;
        uint256 userLpShare = _getUserLpShare(msg.sender);
        if (userLpShare < requiredCollateral) revert InsufficientCollateral();

        uint256 thisId = loanId;
        BorrowInfo memory thisBorrow = BorrowInfo(
            uint128(amount),
            uint64(block.timestamp),
            uint32(thisId),
            false,
            msg.sender
        );
        userBorrowedAmount[msg.sender] = userTotalBorrowAmount;

        totalCurrentlyBorrowed += amount;
        borrowIdToInfo[thisId] = thisBorrow;
        ++thisId;
        asset.transfer(msg.sender, amount);

        emit FundsBorrowed(msg.sender, amount);
    }

    // @TODO better way to return? needing to know your borrow id is annoying
    /// @notice allow users to return borrowed funds
    /// @param id the id number of their borrow
    function returnFunds(uint256 id) external {
        uint256 totalDue = _calculateReturnFee(id);

        asset.transferFrom(msg.sender, address(this), totalDue);

        BorrowInfo memory thisBorrow = borrowIdToInfo[id];

        totalCurrentlyBorrowed -= thisBorrow.amount;
        borrowIdToInfo[id].cleared = true;
        userBorrowedAmount[thisBorrow.borrower] -= uint256(thisBorrow.amount);

        emit FundsRepaid(msg.sender, totalDue);
    }

    /// @notice allows borrows which have fallen below the liquidation threshold to be liquidated
    /// @dev if users provided collateral is less than 1.05x their borrow amount they can be liquidated
    /// @dev liquidator receives 2% of the liquidation amount as reward
    /// @param id the borrow id of the borrow to be liquidated
    function liquidate(uint256 id) external {
        BorrowInfo memory thisBorrow = borrowIdToInfo[id];
        uint256 borrowerLpShare = _getUserLpShare(thisBorrow.borrower);
        uint256 amountDue = _calculateReturnFee(id);

        uint256 requiredCollateral = (amountDue * 105) / 100;
        if (borrowerLpShare > requiredCollateral) revert BorrowNotUnderwater();

        borrowIdToInfo[id].cleared = true;
        _burn(thisBorrow.borrower, balanceOf[thisBorrow.borrower]);

        uint256 callerReward = borrowerLpShare / 100; // 2%

        asset.transfer(msg.sender, callerReward);
    }

    /// @notice calculates the current required funds to pay back a borrow
    /// @param id the borrow id of the borrow to calculate
    /// @return total amount to repay 
    function _calculateReturnFee(uint256 id) internal view returns (uint256) {
        BorrowInfo memory thisBorrow = borrowIdToInfo[id];
        uint256 amountWithStaticFee = thisBorrow.amount +
            ((thisBorrow.amount * STATIC_BORROW_PCT) / 1000);

        uint256 timeSinceBorrow = block.timestamp - thisBorrow.start;
        uint256 hoursSinceBorrow = timeSinceBorrow / 3600 + 1;

        uint256 interestFee = (amountWithStaticFee *
            (hoursSinceBorrow * FEE_PER_HOUR)) / 1000;
        uint256 totalDue = amountWithStaticFee + interestFee;

        return totalDue;
    }

    /// @notice external _calculateReturnFee
    function calculateReturnFee(uint256 id) external view returns (uint256) {
        return _calculateReturnFee(id);
    }

    /// @notice total amount of assets managed by the contract
    /// @dev includes current balance + all outstanding borrows
    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf((address(this))) + totalCurrentlyBorrowed;
    }

    /// @notice returns amount of CREDIT tokens redeemable by user
    /// @param user the address to query
    function _getUserLpShare(address user) internal view returns (uint256) {
        if (balanceOf[user] == 0) return 0;
        return
            (asset.balanceOf(address(this)) + totalCurrentlyBorrowed) * balanceOf[user] / totalSupply;
    }

    /// @notice external _getUserLpShare
    function getUserLpShare(address user) external view returns (uint256) {
        return _getUserLpShare(user);
    }
}
