// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "lib/solmate/src/tokens/ERC20.sol";
import {ERC4626} from "lib/solmate/src/mixins/ERC4626.sol";
import {console2} from "forge-std/console2.sol";

interface BasicDex {
    function creditToAsset(uint256, uint256) external returns (uint256);

    function assetToCredit(uint256, uint256) external returns (uint256);

    function creditInPrice(uint256) external view returns (uint256);

    function assetInPrice(uint256) external view returns (uint256);
}

contract FruitBasketV2 is ERC4626 {
    error InsufficientBuyAmount();
    TokenInfo avocado;
    TokenInfo banana;
    TokenInfo tomato;

    struct TokenInfo {
        ERC20 token;
        BasicDex dex;
    }

    constructor(
        address _avocadoTkn,
        address _bananaTkn,
        address _tomatoTkn,
        address _avocadoDex,
        address _bananaDex,
        address _tomatoDex,
        ERC20 _asset,
        string memory _name,
        string memory _symbol
    ) ERC4626(_asset, _name, _symbol) {
        avocado = TokenInfo(ERC20(_avocadoTkn), BasicDex(_avocadoDex));
        banana = TokenInfo(ERC20(_bananaTkn), BasicDex(_bananaDex));
        tomato = TokenInfo(ERC20(_tomatoTkn), BasicDex(_tomatoDex));

        avocado.token.approve(_avocadoDex, type(uint256).max);
        banana.token.approve(_bananaDex, type(uint256).max);
        tomato.token.approve(_tomatoDex, type(uint256).max);

        _asset.approve(_avocadoDex, type(uint256).max);
        _asset.approve(_bananaDex, type(uint256).max);
        _asset.approve(_tomatoDex, type(uint256).max);
    }

    function totalAssets() public view override returns (uint256) {
        TokenInfo memory avocadoInfo = avocado;
        TokenInfo memory bananaInfo = banana;
        TokenInfo memory tomatoInfo = tomato;

        uint256 assets;

        assets += avocadoInfo.dex.assetInPrice(
            avocadoInfo.token.balanceOf(address(this))
        );
        assets += bananaInfo.dex.assetInPrice(
            bananaInfo.token.balanceOf(address(this))
        );
        assets += tomatoInfo.dex.assetInPrice(
            tomatoInfo.token.balanceOf(address(this))
        );
        console2.log("Predicted Assets", assets);
        return assets;
    }

    // sell users cut of fruit tokens
    function beforeWithdraw(uint256 assets, uint256 shares) internal override {
        TokenInfo[] memory tokens = new TokenInfo[](3);
        tokens[0] = avocado;
        tokens[1] = banana;
        tokens[2] = tomato;

        // for loop more expensive than 3 calls (~1.5k gas) but code cleaner
        for (uint256 i; i < 3; ++i) {
            uint256 tokensToSell = tokens[i].token.balanceOf(address(this)) * shares / totalSupply;
            uint256 expectedCredits = tokens[i].dex.assetInPrice(tokensToSell);
            tokens[i].dex.assetToCredit(tokensToSell, expectedCredits);
        }
    }

    // buy fruit tokens with users asset
    function afterDeposit(uint256 assets, uint256 shares) internal override {
        if (assets < 0.1 ether) revert InsufficientBuyAmount();
        
        TokenInfo memory avocadoInfo = avocado;
        TokenInfo memory bananaInfo = banana;
        TokenInfo memory tomatoInfo = tomato;

        uint256 third = (assets * 333) / 1000;
        uint256 remaining = assets - third * 2;

        uint256 expectedAvocado = avocadoInfo.dex.creditInPrice(third);
        BasicDex(avocadoInfo.dex).creditToAsset(third, expectedAvocado);

        uint256 expectedBanana = bananaInfo.dex.creditInPrice(third);
        BasicDex(bananaInfo.dex).creditToAsset(third, expectedBanana);

        uint256 expectedTomato = tomatoInfo.dex.creditInPrice(third);
        BasicDex(tomatoInfo.dex).creditToAsset(remaining, expectedTomato);
    }
}
