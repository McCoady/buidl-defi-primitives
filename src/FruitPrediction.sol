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
    error NoHighRollers();
    error ZeroWagerAmount();
    error WagerAlreadyClaimed();
    error WagerTooOld();
    error UnsuccessfulClaim();

    event WagerClaimed(
        address indexed user,
        TradeDirection direction,
        uint256 wagerAmount
    );
    event WagerMade(
        address indexed user,
        TradeDirection direction,
        uint256 wagerAmount
    );

    // prediction direction
    enum TradeDirection {
        BULL,
        BEAR
    }

    struct Wager {
        uint256 targetPrice;
        TradeDirection direction;
        uint256 expiry;
        uint256 amount;
        bool claimed;
    }

    uint256 public constant MAX_WAGER = 10 ether;
    address public immutable CREDIT_ADDR;
    address public immutable ORACLE;

    uint256 wagerId;
    mapping(uint256 => Wager) public idToWager;

    constructor(address _credit, address _oracle) {
        CREDIT_ADDR = _credit;
        ORACLE = _oracle;
    }

    ///@notice allow user to make Bull Wager
    function betBull(uint256 _wagerAmount) external returns (uint256) {
        return _bet(_wagerAmount, TradeDirection.BULL);
    }

    ///@notice allow user to make Bear Wager
    function betBear(uint256 _wagerAmount) external returns (uint256) {
        return _bet(_wagerAmount, TradeDirection.BEAR);
    }

    ///@notice internal wager function
    function _bet(
        uint256 _wagerAmount,
        TradeDirection _direction
    ) internal returns (uint256) {
        if (_wagerAmount == 0) revert ZeroWagerAmount();
        if (_wagerAmount > MAX_WAGER) revert NoHighRollers();
        // call dex to get current price in $CREDIT
        uint256 targetPrice = BasicDex(ORACLE).creditInPrice(1 ether);
        uint256 expiry = block.timestamp + 10 minutes;

        uint256 thisId = wagerId;
        idToWager[thisId] = Wager(
            targetPrice,
            _direction,
            expiry,
            _wagerAmount,
            false
        );
        ++wagerId;
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

    ///@notice allow user to claim successful Wager
    function claim(uint256 _wagerId) external {
        Wager memory thisWager = idToWager[_wagerId];
        if (thisWager.claimed == true) revert WagerAlreadyClaimed();
        if (thisWager.expiry + 10 minutes < block.timestamp)
            revert WagerTooOld();

        // call dex to get current price in $CREDIT
        uint256 currentPrice = BasicDex(ORACLE).creditInPrice(1 ether);
        if (thisWager.direction == TradeDirection.BULL) {
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

        emit WagerClaimed(
            msg.sender,
            thisWager.direction,
            thisWager.amount
        );
    }

    function checkWagerExpiry(uint256 _wagerId) external view returns(uint256) {
        Wager memory wager = idToWager[_wagerId];
        return wager.expiry;
    }
}
