// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "lib/solmate/src/tokens/ERC20.sol";

interface IERC20 {
    function approve(address, uint256) external returns (bool);

    function balanceOf(address) external view returns (uint256);

    function transferFrom(address, address, uint256) external returns (bool);

    function transfer(address, uint256) external returns (bool);
}

interface BasicDex {
    function creditToAsset(uint256, uint256) external returns (uint256);

    function assetToCredit(uint256, uint256) external returns (uint256);

    function creditInPrice(uint256) external view returns (uint256);

    function assetInPrice(uint256) external view returns (uint256);
}

///@notice Allow user to invest in an evenly distributed stake of fruit tokens
///@dev 100% feeless, could add fee (but for what?)
contract FruitBasket is ERC20 {
    error InsufficientBuy();
    error InsufficientClaim();

    TokenInfo avocado;
    TokenInfo banana;
    TokenInfo tomato;

    IERC20 public creditToken;

    struct TokenInfo {
        IERC20 token;
        BasicDex dex;
    }

    constructor(
        address _avocadoTkn,
        address _bananaTkn,
        address _tomatoTkn,
        address _creditTkn,
        address _avocadoDex,
        address _bananaDex,
        address _tomatoDex
    ) ERC20("FruitBasket", "FRT", 18) {
        avocado = TokenInfo(IERC20(_avocadoTkn), BasicDex(_avocadoDex));
        banana = TokenInfo(IERC20(_bananaTkn), BasicDex(_bananaDex));
        tomato = TokenInfo(IERC20(_tomatoTkn), BasicDex(_tomatoDex));
        creditToken = IERC20(_creditTkn);

        avocado.token.approve(_avocadoDex, type(uint256).max);
        banana.token.approve(_bananaDex, type(uint256).max);
        tomato.token.approve(_tomatoDex, type(uint256).max);

        creditToken.approve(_avocadoDex, type(uint256).max);
        creditToken.approve(_bananaDex, type(uint256).max);
        creditToken.approve(_tomatoDex, type(uint256).max);
    }

    ///@notice Allow users to buy amount of stake in the fruitbasket
    ///@param amount how much credit to split between the 3 fruits
    function buy(uint256 amount) external {
        if (amount < 0.1 ether) revert InsufficientBuy();
        // take amount credits from user
        creditToken.transferFrom(msg.sender, address(this), amount);
        // buy amount / 3 avocado/banana/tomato

        TokenInfo memory avocadoInfo = avocado;
        TokenInfo memory bananaInfo = banana;
        TokenInfo memory tomatoInfo = tomato;

        uint256 third = (amount * 333) / 1000;
        uint256 expectedAvocado = BasicDex(avocadoInfo.dex).creditInPrice(
            third
        );
        BasicDex(avocadoInfo.dex).creditToAsset(third, expectedAvocado);
        uint256 expectedBanana = BasicDex(bananaInfo.dex).creditInPrice(third);
        BasicDex(bananaInfo.dex).creditToAsset(third, expectedBanana);

        uint256 remaining = amount - third * 2;
        uint256 expectedTomato = BasicDex(tomatoInfo.dex).creditInPrice(
            remaining
        );
        BasicDex(tomatoInfo.dex).creditToAsset(remaining, expectedTomato);

        // mint amount FruitBasket to user
        _mint(msg.sender, amount);
    }

    ///@notice allow users to buy an amount of stake with prefined accepted token slippage
    ///@dev the frontend can calculate appropriate slippage offchain to save gas
    ///@param amount how much credit to split between the 3 fruits
    ///@param minAvo minimum acceptable avocado to purchase
    ///@param minBan minimum acceptable banana to purchase
    ///@param minTom minimum acceptable tomato to purchase
    function buySetMin(
        uint256 amount,
        uint256 minAvo,
        uint256 minBan,
        uint256 minTom
    ) external {
        if (amount < 0.1 ether) revert InsufficientBuy();
        // take amount credits from user
        creditToken.transferFrom(msg.sender, address(this), amount);
        // buy amount / 3 avocado/banana/tomato

        TokenInfo memory avocadoInfo = avocado;
        TokenInfo memory bananaInfo = banana;
        TokenInfo memory tomatoInfo = tomato;

        uint256 third = (amount * 333) / 1000;
        uint256 remaining = amount - third * 2;

        BasicDex(avocadoInfo.dex).creditToAsset(third, minAvo);
        BasicDex(bananaInfo.dex).creditToAsset(third, minBan);

        BasicDex(tomatoInfo.dex).creditToAsset(remaining, minTom);

        // mint amount FruitBasket to user
        _mint(msg.sender, amount);
    }

    ///@notice burns users fruit basket tokens, converts their % of the totalSupply from fruits > credit
    ///@param amount how much fruit basket token to convert
    function claim(uint256 amount) external {
        if (amount < 0.1 ether) revert InsufficientClaim();

        // calc amount * 100 / totalSupply
        uint256 percentageClaim = (amount * 100) / totalSupply;

        // burn amount of fruit basket tokens
        _burn(msg.sender, amount);

        TokenInfo[] memory tokens = new TokenInfo[](3);
        tokens[0] = avocado;
        tokens[1] = banana;
        tokens[2] = tomato;

        // for loop more expensive than 3 calls (~1.5k gas) but code cleaner
        for (uint256 i; i < 3; ++i) {
            uint256 tokensToSell = (tokens[i].token.balanceOf(address(this)) *
                percentageClaim) / 100;
            uint256 expectedCredits = tokens[i].dex.assetInPrice(tokensToSell);
            tokens[i].dex.assetToCredit(tokensToSell, expectedCredits);
        }

        // send credits to user
        creditToken.transfer(msg.sender, creditToken.balanceOf(address(this)));
    }
}
