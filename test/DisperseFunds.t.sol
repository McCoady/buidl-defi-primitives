// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {DisperseFunds} from "../src/DisperseFunds.sol";
import {CreditToken} from "../src/CreditToken.sol";

interface Ownable {
    error OwnableUnauthorizedAccount();
}

contract DisperseFundsTest is Test {
    DisperseFunds public disperser;
    CreditToken public salt;
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public chad = makeAddr("chad");
    address public dave = makeAddr("dave");
    address public edgar = makeAddr("edgar");
    address public canDisperse = makeAddr("can disperse");

    function setUp() public {
        salt = new CreditToken("Salt", "SALT", address(this));
        disperser = new DisperseFunds(address(salt));
        disperser.grantRole(keccak256("DISPENSER_ROLE"), address(this));
    }

    function initContractFunds() public {
        salt.transfer(address(disperser), 1000 ether);
        address(disperser).call{value: 2 ether}("");
    }

    function testAddRole() public {
        initContractFunds();
        disperser.grantRole(keccak256("DISPENSER_ROLE"), canDisperse);
        vm.startPrank(canDisperse);
        address[] memory addrs = new address[](5);
        addrs[0] = alice;
        addrs[1] = bob;
        addrs[2] = chad;
        addrs[3] = dave;
        addrs[4] = edgar;

        disperser.disperseBatch(addrs);
    }

    function testSetupContracts() public {
        initContractFunds();
        assertEq(address(disperser).balance, 2 ether);
        assertEq(salt.balanceOf(address(disperser)), 1000 ether);
    }

    function testDisperseBatch() public {
        initContractFunds();
        address[] memory addrs = new address[](5);
        addrs[0] = alice;
        addrs[1] = bob;
        addrs[2] = chad;
        addrs[3] = dave;
        addrs[4] = edgar;

        disperser.disperseBatch(addrs);
        for (uint256 i; i < addrs.length; ++i) {
            uint256 daiBalance = addrs[i].balance;
            uint256 saltBalance = salt.balanceOf(addrs[i]);
            assertEq(daiBalance, disperser.DAI_FAUCET_AMOUNT());
            assertEq(saltBalance, disperser.SALT_FAUCET_AMOUNT());
        }
    }

    function testDisperseBatchTwiceNoEffect() public {
        initContractFunds();
        address[] memory addrs = new address[](5);
        addrs[0] = alice;
        addrs[1] = bob;
        addrs[2] = chad;
        addrs[3] = dave;
        addrs[4] = edgar;

        disperser.disperseBatch(addrs);
        // disperse again to same addresses
        disperser.disperseBatch(addrs);

        for (uint256 i; i < addrs.length; ++i) {
            uint256 daiBalance = addrs[i].balance;
            uint256 saltBalance = salt.balanceOf(addrs[i]);
            assertEq(daiBalance, disperser.DAI_FAUCET_AMOUNT());
            assertEq(saltBalance, disperser.SALT_FAUCET_AMOUNT());
        }
    }

    function testDisperseBatchOneRepeatAddress() public {
        initContractFunds();
        address[] memory addrsOne = new address[](3);
        addrsOne[0] = alice;
        addrsOne[1] = bob;
        addrsOne[2] = chad;
        // alice passed into function a second time
        address[] memory addrsTwo = new address[](3);
        addrsTwo[0] = alice;
        addrsTwo[1] = dave;
        addrsTwo[2] = edgar;

        disperser.disperseBatch(addrsOne);

        // check members of addrOne received correct funds
        for (uint256 i; i < addrsOne.length; ++i) {
            uint256 daiBalance = addrsOne[i].balance;
            uint256 saltBalance = salt.balanceOf(addrsOne[i]);
            assertEq(daiBalance, disperser.DAI_FAUCET_AMOUNT());
            assertEq(saltBalance, disperser.SALT_FAUCET_AMOUNT());
        }

        disperser.disperseBatch(addrsTwo);

        // check dave & edgar still received funds & alice didn't receive extra
        for (uint256 i = 1; i < addrsOne.length; ++i) {
            uint256 daiBalance = addrsOne[i].balance;
            uint256 saltBalance = salt.balanceOf(addrsOne[i]);
            assertEq(daiBalance, disperser.DAI_FAUCET_AMOUNT());
            assertEq(saltBalance, disperser.SALT_FAUCET_AMOUNT());
        }
    }

    function testCannotDisperseBatchWithInsufficientFunds() public {
        address[] memory addrs = new address[](3);
        addrs[0] = alice;
        addrs[1] = bob;
        addrs[2] = chad;

        vm.expectRevert(DisperseFunds.InsufficientDai.selector);
        disperser.disperseBatch((addrs));
    }

    function testCannotNonOwnerDisperseBatch() public {
        initContractFunds();
        address[] memory addrs = new address[](5);
        addrs[0] = alice;
        addrs[1] = bob;
        addrs[2] = chad;
        addrs[3] = dave;
        addrs[4] = edgar;

        vm.startPrank(alice, alice);
        vm.expectRevert();
        disperser.disperseBatch(addrs);
    }
}
