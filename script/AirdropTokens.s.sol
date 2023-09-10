// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/AssetToken.sol";

contract AirdropTokens is Script {
    address public token = 0x1A778F645439b4DA23C6b0463EF160b16171A36B;
    address public receiver = 0x3401d8caD48445c534ea74Bb0a05a49Fc3BCD81c;

    function run() public {
        uint256 deployerPk = vm.envUint("DEPLOYER_PK");
        vm.startBroadcast(deployerPk);

        AssetToken(token).airdropToWallet(receiver);
        console2.log("Receiver balance", AssetToken(token).balanceOf(receiver));
        
        vm.stopBroadcast();
    }
}
