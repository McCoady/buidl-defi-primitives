// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

contract SendCoins is Script {

    function run() public payable {
        address[] memory wallets = new address[](3);
        wallets[0] = 0x8dd2Ed4B1dfEfB7ec22E1b1364cB177968701885;
        wallets[1] = 0x71F3f9aF53EFF113c3d3601e7E44f5A1E3c23Ba0;
        wallets[2] = 0xa9240957dea34357b9CD73f1cffc7329eFee92C9;
        uint256 deployerPk = vm.envUint("DEPLOYER_PK");
        vm.startBroadcast(deployerPk);
        for (uint256 i; i < wallets.length; ++i) {
            (bool sent, ) = wallets[i].call{value:0.3 ether}("");
            require(sent, "FAILED TO SEND");
        }
        vm.stopBroadcast();
    }
}