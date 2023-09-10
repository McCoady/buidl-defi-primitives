// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/AssetToken.sol";

contract SetUpBotWallet is Script {
    address public token = 0x1A778F645439b4DA23C6b0463EF160b16171A36B;
    address public asset = 0xFc7072b9d8c8941014f2047B42A9662ecaefA357;
    address public receiver = 0xa9240957dea34357b9CD73f1cffc7329eFee92C9;

    function run() public {
        uint256 deployerPk = vm.envUint("DEPLOYER_PK");
        vm.startBroadcast(deployerPk);

        AssetToken(token).airdropToWallet(receiver);
        AssetToken(asset).airdropToWallet(receiver);
        console2.log("Receiver Salt balance", AssetToken(token).balanceOf(receiver));
        console2.log("Receiver Asset balance", AssetToken(asset).balanceOf(receiver));
        
        vm.stopBroadcast();
    }
}
