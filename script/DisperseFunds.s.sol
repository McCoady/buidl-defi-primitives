// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Script, console2} from "forge-std/Script.sol";
import {DisperseFunds} from "../src/DisperseFunds.sol";

interface IERC20 {
    function transfer(address, uint256) external returns(bool);
}
contract DisperseFundsScript is Script {
    address public saltAddr = 0x1A778F645439b4DA23C6b0463EF160b16171A36B;

    function run() public {
        uint256 deployerPk = vm.envUint("DEPLOYER_PK");
        vm.startBroadcast(deployerPk);

        DisperseFunds disperser = new DisperseFunds(saltAddr);
        address disperserAddr = address(disperser);
        console2.log("Disperser Address", disperserAddr);
        disperserAddr.call{value: 0.2 ether}("");
        IERC20(saltAddr).transfer(disperserAddr, 250 ether);
        vm.stopBroadcast();
    }
}
