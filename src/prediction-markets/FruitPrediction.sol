// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IERC20 {
    function transferFrom(address, address, uint256) external returns (bool);

    function transfer(address, uint256) external returns (bool);
}

interface BasicDex {
    function creditInPrice(uint256) external view returns (uint256);
}

///@notice Allow users to wager their predicted price of a fruit token at a future point in time
///@dev Uses dex as oracle so vulnerable to flash loans
contract FruitPrediction {
    /* ========== TYPES ========== */
    struct Wager {
        uint256 targetPrice;
        WagerDirection direction;
        uint256 expiry;
        uint256 amount;
        bool claimed;
    }
    
    enum WagerDirection {
        BULL,
        BEAR
    }
    /* ========== STATE VARS ========== */
    uint256 public constant MAX_WAGER = 10 ether;
    address public immutable CREDIT_ADDR;
    address public immutable ORACLE;

    uint256 currentId;
    mapping(uint256 => Wager) public idToWager;

    /* ========== EVENTS ========== */
    event WagerClaimed(
        address indexed user,
        WagerDirection direction,
        uint256 wagerAmount
    );
    event WagerMade(
        address indexed user,
        WagerDirection direction,
        uint256 wagerAmount
    );

    /* ========== CUSTOM ERRORS ========== */
    error NoHighRollers();
    error ZeroWagerAmount();
    error WagerAlreadyClaimed();
    error WagerTooOld();
    error UnsuccessfulClaim();
    error NonExistantId();

    /* ========== CONSTRUCTOR ========== */
    constructor(address _credit, address _oracle) {
        CREDIT_ADDR = _credit;
        ORACLE = _oracle;
    }

    /* ========== FUNCTIONS ========== */

    /// @notice allow user to make Bull Wager
    /// @param _wagerAmount amount to wager
    /// @return this bets id number
    function betBull(uint256 _wagerAmount) external returns (uint256) {
        return _bet(_wagerAmount, WagerDirection.BULL);
    }

    /// @notice allow user to make Bear Wager
    /// @param _wagerAmount amount to wager
    /// @return this bets id number
    function betBear(uint256 _wagerAmount) external returns (uint256) {
        return _bet(_wagerAmount, WagerDirection.BEAR);
    }

    /// @notice internal wager function
    /// @param _wagerAmount amount to wager
    /// @param _direction the trade direction of the wager (bull or bear)
    /// @return this bets id number
    function _bet(
        uint256 _wagerAmount,
        WagerDirection _direction
    ) internal returns (uint256) {
        if (_wagerAmount == 0) revert ZeroWagerAmount();
        if (_wagerAmount > MAX_WAGER) revert NoHighRollers();
        // call dex to get current price in $CREDIT
        uint256 targetPrice = BasicDex(ORACLE).creditInPrice(1 ether);
        uint256 expiry = block.timestamp + 10 minutes;

        uint256 thisId = currentId;
        idToWager[thisId] = Wager(
            targetPrice,
            _direction,
            expiry,
            _wagerAmount,
            false
        );
        ++currentId;
        // take funds
        require(
            IERC20(CREDIT_ADDR).transferFrom(
                msg.sender,
                address(this),
                _wagerAmount
            )
        );

        emit WagerMade(msg.sender, _direction, _wagerAmount);

        return thisId;
    }

    /// @notice allow user to claim successful Wager
    /// @param _wagerId the wager id to claim
    function claim(uint256 _wagerId) external {
        if (_wagerId >= currentId) revert NonExistantId();
        Wager memory thisWager = idToWager[_wagerId];
        if (thisWager.claimed == true) revert WagerAlreadyClaimed();
        if (thisWager.expiry + 10 minutes < block.timestamp)
            revert WagerTooOld();

        // call dex to get current price in $CREDIT
        uint256 currentPrice = BasicDex(ORACLE).creditInPrice(1 ether);
        if (thisWager.direction == WagerDirection.BULL) {
            if (thisWager.targetPrice <= currentPrice)
                revert UnsuccessfulClaim();
        } else {
            if (thisWager.targetPrice >= currentPrice)
                revert UnsuccessfulClaim();
        }
        uint256 fivePercent = (thisWager.amount * 5) / 100; // fee amount 5%
        uint256 claimAmount = thisWager.amount * 2 - fivePercent;

        idToWager[_wagerId].claimed = true;
        require(IERC20(CREDIT_ADDR).transfer(msg.sender, claimAmount));

        emit WagerClaimed(msg.sender, thisWager.direction, thisWager.amount);
    }

    /// @notice allows users to check when a wager expires
    /// @param _wagerId the wager id to check
    /// @return timestamp the wager expires
    function checkWagerExpiry(
        uint256 _wagerId
    ) external view returns (uint256) {
        Wager memory wager = idToWager[_wagerId];
        return wager.expiry;
    }
}
