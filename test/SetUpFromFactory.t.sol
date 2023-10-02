// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {AssetTokenV2} from "../src/tokens/AssetTokenV2.sol";
import {BasicDex} from "../src/dex/BasicDex.sol";
import {CreditToken} from "../src/tokens/CreditToken.sol";
import {TokenSetupFactory} from "../src/factories/TokenSetupFactory.sol";

interface IERC20 {
    function balanceOf(address) external view returns(uint256);
}
contract SetupFromFactoryTest is Test {
    CreditToken public credit;
    TokenSetupFactory public factory;

    function setUp() public {
        credit = new CreditToken("Credit", unicode"💸", address(this));
        factory = new TokenSetupFactory(address(credit));
    }

    function testSetUpAvocado() public {
        // create avocado token & dex
        credit.approve(address(factory), 100 ether);
        factory.setupNewTokenDexCombo("Avocado", unicode"🥑", address(this), 100 ether);

        // check dex has been init
        TokenSetupFactory.TokenInfo memory avocadoInfo = factory.getTokenInfoByIndex(0);
        address avocadoToken = avocadoInfo.tokenAddress;
        address avocadoDex = avocadoInfo.dexAddress;

        uint256 thisAvocadoBalance = IERC20(avocadoToken).balanceOf(address(this));
        assert(thisAvocadoBalance != 0);
        assertEq(IERC20(avocadoToken).balanceOf(avocadoDex), 100 ether);

        credit.approve(avocadoDex, 1 ether);
        BasicDex(avocadoDex).creditToAsset(1 ether, 0);
        assert(IERC20(avocadoToken).balanceOf(address(this)) > thisAvocadoBalance);
        assert(IERC20(avocadoToken).balanceOf(address(avocadoDex)) > 100);
    }

    function testSetUpThreeFruits() public {
        credit.approve(address(factory), type(uint256).max);
        factory.setupNewTokenDexCombo("Avocado", unicode"🥑", address(this), 100 ether);
        factory.setupNewTokenDexCombo("Banana", unicode"🍌", address(this), 100 ether);
        factory.setupNewTokenDexCombo("Tomato", unicode"🍅", address(this), 100 ether);

        TokenSetupFactory.TokenInfo memory avocadoInfo = factory.getTokenInfoByIndex(0);
        TokenSetupFactory.TokenInfo memory bananaInfo = factory.getTokenInfoByIndex(1);
        TokenSetupFactory.TokenInfo memory tomatoInfo = factory.getTokenInfoByIndex(2);

        assert(avocadoInfo.dexAddress != address(0));
        assert(bananaInfo.dexAddress != address(0));
        assert(tomatoInfo.dexAddress != address(0));
    }
}   