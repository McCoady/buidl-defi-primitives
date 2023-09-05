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
        uint256 deployerPk = vm.envUint("DEPLOYER_PK");
        vm.startBroadcast(deployerPk);
        CreditToken cred = new CreditToken("Salt", "SALT", msg.sender);
        AssetToken avocado = new AssetToken("Avocado", "AVOC", msg.sender);
        AssetToken banana = new AssetToken("Banana", "BNNA", msg.sender);
        AssetToken tomato = new AssetToken("Tomato", "TMTO", msg.sender);

        BasicDex avocadoCred = new BasicDex(address(cred), address(avocado));
        console2.log("avocado Dex Address", address(avocadoCred));
        BasicDex bananaCred = new BasicDex(address(cred), address(banana));
        console2.log("banana Dex Address", address(bananaCred));
        BasicDex tomatoCred = new BasicDex(address(cred), address(tomato));
        console2.log("tomato Dex Address", address(tomatoCred));

        // approve dexes
        cred.approve(address(avocadoCred), type(uint256).max);
        cred.approve(address(bananaCred), type(uint256).max);
        cred.approve(address(tomatoCred), type(uint256).max);
        avocado.approve(address(avocadoCred), type(uint256).max);
        banana.approve(address(bananaCred), type(uint256).max);
        tomato.approve(address(tomatoCred), type(uint256).max);

        // Add initial liquidity to dexes;
        avocadoCred.init(100 ether);
        bananaCred.init(100 ether);
        tomatoCred.init(100 ether);

        vm.stopBroadcast();
    }
}
