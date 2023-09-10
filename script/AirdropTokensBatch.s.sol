// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/AssetToken.sol";

contract AirdropTokensBatch is Script {
    address public token = 0x1A778F645439b4DA23C6b0463EF160b16171A36B;

    function run() public {
        address[] memory receivers = new address[](2);
        receivers[0] = 0x3401d8caD48445c534ea74Bb0a05a49Fc3BCD81c;
        receivers[1] = 0x3401d8caD48445c534ea74Bb0a05a49Fc3BCD81c;

        uint256 deployerPk = vm.envUint("DEPLOYER_PK");
        vm.startBroadcast(deployerPk);

        AssetToken(token).airdropToWallets(receivers);
        for (uint256 i; i < receivers.length; ++i) {
        console2.log("Receiver balance", AssetToken(token).balanceOf(receivers[0]));
        }
        
        vm.stopBroadcast();
    }
}
