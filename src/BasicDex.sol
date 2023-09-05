// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IERC20 {
    function transfer(address receiver, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address receiver,
        uint256 amount
    ) external returns (bool);

    function balanceOf(address user) external view returns (uint256);
}

/// @title Token-Token DEX
/// @author mctoady.eth
/// @notice A simple token to token DEX with built in slippage protection
contract BasicDex {
    /* ========== CUSTOM ERRORS ========== */
    error InitError();
    error TokenTransferError(address _token);
    error ZeroQuantityError();
    error SlippageError();
    error InsufficientLiquidityError(uint256 _liquidityAvailable);

    /* ========== STATE VARS ========== */

    IERC20 public creditToken;
    IERC20 public assetToken;

    uint256 public totalLiquidity;
    mapping(address => uint256) public liquidity;

    /* ========== EVENTS ========== */

    event TokenSwap(
        address _user,
        uint256 _tradeDirection,
        uint256 _tokensSwapped,
        uint256 _tokensReceived
    );
    event LiquidityProvided(
        address _user,
        uint256 _liquidityMinted,
        uint256 _creditTokenAdded,
        uint256 _assetTokenAdded
    );
    event LiquidityRemoved(
        address _user,
        uint256 _liquidityAmount,
        uint256 _creditTokenAmount,
        uint256 _assetTokenAmount
    );

    /* ========== CONSTRUCTOR ========== */
    constructor(address _creditToken, address _assetToken) {
        creditToken = IERC20(_creditToken);
        assetToken = IERC20(_assetToken);
    }

    /// @notice initializes amount of liquidity in the dex, will start with a balanced 1:1 ratio of creditToken to assetToken TODO: make this optional?
    /// @dev user should approve dex contract as spender for assetToken and creditToken before calling init
    /// @param tokens number of tokens to initialise the liquidity with
    /// @return totalLiquidity is the number of LPTs minted as a result of deposits made to DEX contract
    function init(uint256 tokens) public returns (uint256) {
        if (totalLiquidity != 0) revert InitError();

        totalLiquidity = tokens;

        liquidity[msg.sender] = tokens;

        // transfer credit tokens to the contract
        bool creditTokenTransferred = creditToken.transferFrom(
            msg.sender,
            address(this),
            tokens
        );
        if (!creditTokenTransferred)
            revert TokenTransferError(address(creditToken));

        // transfer asset tokens to the contract
        bool assetTokenTransferred = assetToken.transferFrom(
            msg.sender,
            address(this),
            tokens
        );
        if (!assetTokenTransferred)
            revert TokenTransferError(address(assetToken));

        return totalLiquidity;
    }

    /// @notice returns yOutput, or yDelta for xInput (or xDelta)
    /// @param xInput amount of token X to be sold
    /// @param xReserves amount of liquidity for token X
    /// @param yReserves amount of liquidity for token Y
    /// @return yOutput amount of token Y that can be purchased
    function price(
        uint256 xInput,
        uint256 xReserves,
        uint256 yReserves
    ) public pure returns (uint256 yOutput) {
        uint256 xInputWithFee = xInput * 997;
        uint256 numerator = xInputWithFee * yReserves;
        uint256 denominator = (xReserves * 1000) + xInputWithFee;
        return numerator / denominator;
    }

    function getAssetAddr() external view returns (address) {
        return address(assetToken);
    }

    function getCreditAddr() external view returns (address) {
        return address(creditToken);
    }

    /// @notice helper function to get assetOut from a specified creditIn
    /// @dev external function to avoid having to know reserve amounts to check prices
    /// @param creditIn amount of credits to calculate assetToken price
    /// @return assetOut amount of assets tradable for 'creditIn' amount of credits (including fee)
    function creditInPrice(
        uint256 creditIn
    ) external view returns (uint256 assetOut) {
        uint256 credReserves = creditToken.balanceOf(address(this));
        uint256 assetReserves = assetToken.balanceOf(address(this));
        return price(creditIn, credReserves, assetReserves);
    }

    /// @notice helper function to get creditOut from a specified assetIn
    /// @dev external function to avoid having to know reserve amounts to check prices
    /// @param assetIn amount of assets to calculate creditToken price
    /// @return creditOut amount of credits tradable for 'assetIn' amount of assets (including fee)
    function assetInPrice(
        uint256 assetIn
    ) external view returns (uint256 creditOut) {
        uint256 assetReserves = assetToken.balanceOf(address(this));
        uint256 creditReserves = creditToken.balanceOf(address(this));
        return price(assetIn, assetReserves, creditReserves);
    }

    /// @notice helper function to get assetIn required for a specified creditOut
    /// @dev external function to help frontend calculate token amounts for user
    /// @param creditOut amount of credit the user wishes to receive
    /// @return assetIn amount of asset necessary to receive creditOut
    function creditOutPrice(
        uint256 creditOut
    ) external view returns (uint256 assetIn) {
        uint256 assetReserves = assetToken.balanceOf(address(this));
        uint256 creditReserves = creditToken.balanceOf(address(this));

        if (creditOut >= creditReserves)
            revert InsufficientLiquidityError(creditReserves);

        uint256 numerator = assetReserves * creditOut * 1000;
        uint256 denominator = (creditReserves - creditOut) * 997;
        return (numerator / denominator) + 1;
    }

    /// @notice helper function to get creditIn required for a specified assetOut
    /// @dev external function to help frontend calculate token amounts for user
    /// @param assetOut amount of asset the user wishes to receive
    /// @return creditIn amount of credit necessary to receive assetOut
    function assetOutPrice(
        uint256 assetOut
    ) external view returns (uint256 creditIn) {
        uint256 assetReserves = assetToken.balanceOf(address(this));
        uint256 creditReserves = creditToken.balanceOf(address(this));

        if (assetOut >= assetReserves)
            revert InsufficientLiquidityError(assetReserves);

        uint256 numerator = creditReserves * assetOut * 1000;
        uint256 denominator = (assetReserves - assetOut) * 997;
        return (numerator / denominator) + 1;
    }

    /// @notice returns amount of liquidity provided by an address
    /// @param _user the address to check the liquidity of
    /// @return amount of liquidity _user has provided
    function getLiquidity(address _user) public view returns (uint256) {
        return liquidity[_user];
    }

    /// @notice trades creditTokens for assetTokens
    /// @dev the applications frontend should calculate price and provide the user with suitable values for minTokensBack
    /// @param tokensIn the number of credit tokens to be sold
    /// @param minTokensBack the minimum number of asset tokens the user will accept in return (for slippage protection)
    /// @return tokenOutput the number of asset tokens received by the user
    function creditToAsset(
        uint256 tokensIn,
        uint256 minTokensBack
    ) public returns (uint256 tokenOutput) {
        if (tokensIn == 0) revert ZeroQuantityError();
        uint256 creditTokenReserve = creditToken.balanceOf(address(this));
        uint256 assetTokenReserve = assetToken.balanceOf(address(this));

        // Calculate how many tokens they'll receive
        tokenOutput = price(tokensIn, creditTokenReserve, assetTokenReserve);
        // Check received tokens greater than their minimum accepted amount
        if (tokenOutput < minTokensBack) revert SlippageError();

        // transfer credit tokens from user to dex
        bool creditTokenTransferred = creditToken.transferFrom(
            msg.sender,
            address(this),
            tokensIn
        );
        if (!creditTokenTransferred)
            revert TokenTransferError(address(creditToken));

        // transfer asset tokens from dex to user
        bool assetTokenTransferred = assetToken.transfer(
            msg.sender,
            tokenOutput
        );
        if (!assetTokenTransferred)
            revert TokenTransferError(address(assetToken));

        emit TokenSwap(msg.sender, 0, tokensIn, tokenOutput);
    }

    /// @notice trades assetTokens for creditTokens
    /// @dev the applications frontend should calculate price and provide the user with suitable values for minTokensBack
    /// @param tokensIn the number of asset tokens to be sold
    /// @param minTokensBack the minimum number of credit tokens the user will accept in return (for slippage protection)
    /// @return tokenOutput the number of credit tokens received by the user
    function assetToCredit(
        uint256 tokensIn,
        uint256 minTokensBack
    ) public returns (uint256 tokenOutput) {
        if (tokensIn == 0) revert ZeroQuantityError();
        uint256 assetTokenReserve = assetToken.balanceOf(address(this));
        uint256 creditTokenReserve = creditToken.balanceOf(address(this));
        // Calculate how many tokens they'll receive
        tokenOutput = price(tokensIn, assetTokenReserve, creditTokenReserve);
        // Check received tokens greater than their minimum accepted amount
        if (tokenOutput < minTokensBack) revert SlippageError();

        // transfer asset tokens from user to dex
        bool assetTokenTransferred = assetToken.transferFrom(
            msg.sender,
            address(this),
            tokensIn
        );
        if (!assetTokenTransferred)
            revert TokenTransferError(address(assetToken));

        // transfer credit tokens from user to dex
        bool creditTokenTransferred = creditToken.transfer(
            msg.sender,
            tokenOutput
        );
        if (!creditTokenTransferred)
            revert TokenTransferError(address(creditToken));

        emit TokenSwap(msg.sender, 1, tokensIn, tokenOutput);
    }

    /// @notice allows used to provide liquidity to the dex
    /// @dev the user should know prior to calling the amount of asset tokens they will need to provide liquidity evenly
    /// @param creditTokenDeposited the number of credit tokens the user wishes to deposit, the function will calculate the amount of asset tokens required to balance the liquidity provided
    /// @return liquidityMinted the amount of liquidity added by user in this transaction
    function deposit(
        uint256 creditTokenDeposited
    ) public returns (uint256 liquidityMinted) {
        if (creditTokenDeposited == 0) revert ZeroQuantityError();

        uint256 creditTokenReserve = creditToken.balanceOf(address(this));
        uint256 assetTokenReserve = assetToken.balanceOf(address(this));
        uint256 assetTokenDeposited = (creditTokenDeposited *
            creditTokenReserve) / assetTokenReserve;

        liquidityMinted =
            (creditTokenDeposited * totalLiquidity) /
            creditTokenReserve;

        // TODO: check this is correct
        liquidity[msg.sender] += liquidityMinted;
        totalLiquidity += creditTokenDeposited;

        // transfer credit tokens from user to dex
        bool creditTokenTransferred = creditToken.transferFrom(
            msg.sender,
            address(this),
            creditTokenDeposited
        );
        if (!creditTokenTransferred)
            revert TokenTransferError(address(creditToken));

        // transfer asset tokens from user to dex
        bool assetTokenTransferred = assetToken.transferFrom(
            msg.sender,
            address(this),
            assetTokenDeposited
        );
        if (!assetTokenTransferred)
            revert TokenTransferError(address(assetToken));

        emit LiquidityProvided(
            msg.sender,
            liquidityMinted,
            creditTokenDeposited,
            assetTokenDeposited
        );
    }

    /// @notice allows users to withdraw liquidity previously deposited to the dex
    /// @dev users should be aware that the proportion of tokens deposited can change over time (see: impermanent loss)
    /// @param amount the amount of liquidity they wish to withdraw
    /// @return creditTokenAmount the number of credit tokens they'll receive
    /// @return assetTokenAmount the number of asset tokens they'll receive
    function withdraw(
        uint256 amount
    ) public returns (uint256 creditTokenAmount, uint256 assetTokenAmount) {
        if (liquidity[msg.sender] < amount)
            revert InsufficientLiquidityError(liquidity[msg.sender]);

        uint256 creditTokenReserve = creditToken.balanceOf(address(this));
        uint256 assetTokenReserve = assetToken.balanceOf(address(this));

        creditTokenAmount = (amount * creditTokenReserve) / totalLiquidity;
        assetTokenAmount = (amount * assetTokenReserve) / totalLiquidity;

        // update liquidity amounts for owner
        liquidity[msg.sender] -= amount;
        // update liquidity amounts of dex
        totalLiquidity -= amount;

        // Send credit tokens from dex to user
        bool creditTokenSent = creditToken.transfer(
            msg.sender,
            creditTokenAmount
        );
        if (!creditTokenSent) revert TokenTransferError(address(creditToken));
        // Send asset tokens from dex to user
        bool assetTokenSent = assetToken.transfer(msg.sender, assetTokenAmount);
        if (!assetTokenSent) revert TokenTransferError(address(assetToken));

        emit LiquidityRemoved(
            msg.sender,
            amount,
            creditTokenAmount,
            assetTokenAmount
        );
    }
}
