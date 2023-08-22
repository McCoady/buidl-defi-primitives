// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/AssetToken.sol";
import "../src/CreditToken.sol";
import "../src/BasicDex.sol";

// deploy tokens & dexes
// approve dexes for tokens
// init dex liquidity

// script, trade %s change based on time passed (50/50 direction for first 15 minutes, then 55/45, then 60/40, then maybe flips back)
// ideas, price graph, AI twitter

contract DexDeployScript is Script {
    function run() public {
        vm.startBroadcast();
        CreditToken cred = new CreditToken("BuidlCoin", "BUIDL", msg.sender);
        AssetToken banana = new AssetToken("Banana", "BNNA");
        AssetToken apple = new AssetToken("Apple", "APL");
        AssetToken orange = new AssetToken("Orange", "ORG");
        AssetToken lemon = new AssetToken("Lemon", "LMN");

        BasicDex bananaCred = new BasicDex(address(cred), address(banana));
        BasicDex appleCred = new BasicDex(address(cred), address(apple));
        BasicDex orangeCred = new BasicDex(address(cred), address(orange));
        BasicDex lemonCred = new BasicDex(address(cred), address(lemon));

        // approve dexes
        cred.approve(address(bananaCred), type(uint256).max);
        cred.approve(address(appleCred), type(uint256).max);
        cred.approve(address(orangeCred), type(uint256).max);
        cred.approve(address(lemonCred), type(uint256).max);
        banana.approve(address(bananaCred), type(uint256).max);
        apple.approve(address(appleCred), type(uint256).max);
        orange.approve(address(orangeCred), type(uint256).max);
        lemon.approve(address(lemonCred), type(uint256).max);

        // Add initial liquidity to dexes;
        bananaCred.init(0.1 ether);
        appleCred.init(0.1 ether);
        orangeCred.init(0.1 ether);
        lemonCred.init(0.1 ether);
        vm.stopBroadcast();
    }
}
