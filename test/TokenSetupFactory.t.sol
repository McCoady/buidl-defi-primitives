// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {TokenSetupFactory} from "../src/TokenSetupFactory.sol";
import {CreditToken} from "../src/CreditToken.sol";
import {AssetToken} from "../src/AssetToken.sol";
import {BasicDex} from "../src/BasicDex.sol";

contract TokenSetupFactoryTest is Test {
    TokenSetupFactory public factory;
    CreditToken public credit; 

    function setUp() public {
        credit = new CreditToken("Credit", "CRED", address(this));
        factory = new TokenSetupFactory(address(credit));
    }

    function testCreateTokenDexCombo() public {
        credit.approve(address(factory), 100 ether);
        factory.setupNewTokenDexCombo("Apple", "APL", address(this), 100 ether);
        assertEq(factory.tokensDeployed(), 1);
        TokenSetupFactory.TokenInfo memory firstDexInfo = factory.getTokenInfoByIndex(0);
        assert(firstDexInfo.tokenAddress != address(0));
        assert(firstDexInfo.dexAddress != address(0));
    }
    
    function testTradeToDeployedDex() public {
        credit.approve(address(factory), 100 ether);
        factory.setupNewTokenDexCombo("Apple", "APL", address(this), 100 ether);
        TokenSetupFactory.TokenInfo memory firstDexInfo = factory.getTokenInfoByIndex(0);
        address dexAddr = firstDexInfo.dexAddress;
        address tokenAddr = firstDexInfo.tokenAddress;
        assertEq(BasicDex(dexAddr).getAssetAddr(), tokenAddr);
        credit.approve(dexAddr, 10 ether);
        
        uint256 assetBal = AssetToken(tokenAddr).balanceOf(address(this));
        BasicDex(dexAddr).creditToAsset(10 ether, 0);
        assert(AssetToken(tokenAddr).balanceOf(address(this)) > assetBal);
    }
}
