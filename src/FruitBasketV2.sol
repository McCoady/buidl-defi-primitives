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

    function totalAssets() public view override returns (uint256 assets) {
        TokenInfo memory avocadoInfo = avocado;
        TokenInfo memory bananaInfo = banana;
        TokenInfo memory tomatoInfo = tomato;

        assets += avocadoInfo.dex.assetInPrice(
            avocadoInfo.token.balanceOf(address(this))
        );
        assets += bananaInfo.dex.assetInPrice(
            bananaInfo.token.balanceOf(address(this))
        );
        assets += tomatoInfo.dex.assetInPrice(
            tomatoInfo.token.balanceOf(address(this))
        );
    }

    // sell users cut of fruit tokens
    function beforeWithdraw(uint256 assets, uint256 shares) internal override {
        TokenInfo memory avocadoInfo = avocado;
        TokenInfo memory bananaInfo = banana;
        TokenInfo memory tomatoInfo = tomato;

        // sell avocado
        uint256 tokensToSell = avocadoInfo.token.balanceOf(address(this)) * shares / totalSupply;
        avocadoInfo.dex.assetToCredit(tokensToSell, avocadoInfo.dex.assetInPrice(tokensToSell));

        // sell banana
        tokensToSell = bananaInfo.token.balanceOf(address(this)) * shares / totalSupply;
        bananaInfo.dex.assetToCredit(tokensToSell, bananaInfo.dex.assetInPrice(tokensToSell));
        
        // sell tomato
        tokensToSell = tomatoInfo.token.balanceOf(address(this)) * shares / totalSupply;
        tomatoInfo.dex.assetToCredit(tokensToSell, tomatoInfo.dex.assetInPrice(tokensToSell));

    }
 
    // @TODO how to implement slippage protection?
    function afterDeposit(uint256 assets, uint256 shares) internal override {
        if (assets < 0.1 ether) revert InsufficientBuyAmount();
        
        TokenInfo memory avocadoInfo = avocado;
        TokenInfo memory bananaInfo = banana;
        TokenInfo memory tomatoInfo = tomato;

        uint256 third = (assets * 333) / 1000;
        uint256 remaining = assets - third * 2;

        // buy avocado
        BasicDex(avocadoInfo.dex).creditToAsset(third, 0);
        // buy banana
        BasicDex(bananaInfo.dex).creditToAsset(third, 0);
        // buy tomato
        BasicDex(tomatoInfo.dex).creditToAsset(remaining, 0);
    }
}
