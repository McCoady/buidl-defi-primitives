// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {DisperseFunds} from "../src/DisperseFunds.sol";

interface IERC20 {
    function transfer(address, uint256) external returns(bool);
}
contract DisperseFundsScript is Script {
    address public saltAddr = 0x1A778F645439b4DA23C6b0463EF160b16171A36B;
    address public toad =0xD26536C559B10C5f7261F3FfaFf728Fe1b3b0dEE;
    address public damu = 0x0051a983dCf67AdaC14b0A6dC2f8a8670e8a3475; 
    address public austin = 0x25072DD8fC2eCA27717cedC3288D59d16b632BBB;

    function run() public {
        uint256 deployerPk = vm.envUint("DEPLOYER_PK");

        vm.startBroadcast(deployerPk);

        // deploy contract
        DisperseFunds disperser = new DisperseFunds(saltAddr);

        // log address
        address disperserAddr = address(disperser);
        console2.log("Disperser Address", disperserAddr);

        // send contract funds to disperse to 200 addresses
        disperserAddr.call{value: 4 ether}("");
        IERC20(saltAddr).transfer(disperserAddr, 5000 ether);
        
        // give 3 address DISPENSER_ROLE;
        disperser.grantRole(keccak256("DISPENSER_ROLE"), toad);
        disperser.grantRole(keccak256("DISPENSER_ROLE"), damu);
        disperser.grantRole(keccak256("DISPENSER_ROLE"), austin);
        vm.stopBroadcast();
    }
}
