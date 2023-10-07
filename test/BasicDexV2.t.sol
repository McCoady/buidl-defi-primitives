// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {AssetToken} from "../src/tokens/AssetToken.sol";
import {CreditToken} from "../src/tokens/CreditToken.sol";
import {BasicDexV2} from "../src/dex/BasicDexV2.sol";
import {ERC20} from "lib/solmate/src/tokens/ERC20.sol";

contract BasicDexV2Test is Test {
    CreditToken public credit;
    AssetToken public asset;
    BasicDexV2 public dex;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        // Create the systems ERC20 tokens
        credit = new CreditToken("credit", "CRED", address(this));
        asset = new AssetToken("asset", "ASS", address(this));
        dex = new BasicDexV2(ERC20(credit), ERC20(asset));
    }

    function basicInitDex() public {
        credit.approve(address(dex), 100 ether);
        asset.approve(address(dex), 100 ether);

        dex.init(100 ether);
    }

    function testInit() public {
        basicInitDex();
        assertEq(dex.balanceOf(address(this)), 100 ether);
        assertEq(credit.balanceOf(address(dex)), 100 ether);
        assertEq(asset.balanceOf(address(dex)), 100 ether);
    }

    function testName() public {
        console2.log("LP token name", dex.name());
        console2.log("LP token symbol", dex.symbol());
        assertEq(dex.name(), "CREDASSLP");
        assertEq(dex.symbol(), "CREDASSLP");
    }

    function testCannotInitTwice() public {
        basicInitDex();
        vm.expectRevert(BasicDexV2.InitError.selector);
        dex.init(100 ether);
    }

    function testWithdrawLiq() public {
        basicInitDex();
        dex.withdraw(50 ether);
        assertEq(dex.balanceOf(address(this)), 50 ether);
        assertEq(credit.balanceOf(address(dex)), 50 ether);
        assertEq(asset.balanceOf(address(dex)), 50 ether);
    }

    function testDepositLiqAfterInit() public {
        basicInitDex();

        credit.transfer(alice, 50 ether);
        asset.transfer(alice, 50 ether);

        vm.startPrank(alice, alice);
        credit.approve(address(dex), 100 ether);
        asset.approve(address(dex), 100 ether);
        dex.deposit(50 ether);
        assertEq(dex.balanceOf(alice), 50 ether);
        assertEq(credit.balanceOf(address(dex)), 150 ether);
        assertEq(asset.balanceOf(address(dex)), 150 ether);
    }

    function testWithdrawLiqAfterMultipleDeposits() public {
        basicInitDex();

        credit.transfer(alice, 50 ether);
        asset.transfer(alice, 50 ether);

        vm.startPrank(alice, alice);
        credit.approve(address(dex), 100 ether);
        asset.approve(address(dex), 100 ether);
        dex.deposit(50 ether);

        dex.withdraw(50 ether);
        assertEq(dex.balanceOf(alice), 0);
        assertEq(credit.balanceOf(address(dex)), 100 ether);
        assertEq(asset.balanceOf(address(dex)), 100 ether);
    }

    function testInitializerWithdrawAfterDeposits() public {
        basicInitDex();

        credit.transfer(alice, 50 ether);
        asset.transfer(alice, 50 ether);

        vm.startPrank(alice, alice);
        credit.approve(address(dex), 100 ether);
        asset.approve(address(dex), 100 ether);
        dex.deposit(50 ether);

        vm.stopPrank();
        dex.withdraw(50 ether);
        assertEq(dex.balanceOf(alice), 50 ether);
        assertEq(dex.balanceOf(address(this)), 50 ether);
        assertEq(credit.balanceOf(address(dex)), 100 ether);
        assertEq(asset.balanceOf(address(dex)), 100 ether);
    }

    function testLiquidityProviderReceiveFees() public {
        credit.transfer(alice, 100 ether);
        asset.transfer(alice, 100 ether);
        credit.transfer(bob, 10 ether);

        vm.startPrank(alice, alice);
        basicInitDex();
        vm.stopPrank();

        vm.startPrank(bob, bob);
        credit.approve(address(dex), 10 ether);
        dex.creditToAsset(10 ether, 0);
        vm.stopPrank();

        // check alice withdrew more than 20 ether combined (she got fees)
        console2.log("New dex cred balance", credit.balanceOf(address(dex)));
        console2.log("New dex asset balance", asset.balanceOf(address(dex)));

        vm.startPrank(alice, alice);
        dex.withdraw(10 ether);
        uint256 aliceCredits = credit.balanceOf(alice);
        uint256 aliceAssets = asset.balanceOf(alice);
        assert(aliceCredits + aliceAssets > 20 ether);
    }

    function testWithdrawalsAfterFeesGenerated() public {
        credit.transfer(alice, 100 ether);
        asset.transfer(alice, 100 ether);
        credit.transfer(bob, 10 ether);

        basicInitDex();

        vm.startPrank(alice, alice);
        credit.approve(address(dex), 100 ether);
        asset.approve(address(dex), 100 ether);
        dex.deposit(100 ether);
        vm.stopPrank();

        vm.startPrank(bob, bob);
        credit.approve(address(dex), 10 ether);
        dex.creditToAsset(10 ether, 0);
        vm.stopPrank();

        dex.withdraw(100 ether);

        vm.startPrank(alice, alice);
        dex.withdraw(100 ether);

        assertEq(credit.balanceOf(address(dex)), 0);
        assertEq(asset.balanceOf(address(dex)), 0);
        assertEq(dex.totalSupply(), 0);
        assertEq(dex.balanceOf(alice), 0);
        assertEq(dex.balanceOf(address(this)), 0);
    }

    function testAssetInPriceZeroReturnsZero() public {
        basicInitDex();
        assertEq(dex.assetInPrice(0), 0);
    }

    function testCreditInPriceZeroReturnsZero() public {
        basicInitDex();
        assertEq(dex.creditInPrice(0), 0);
    }

    function testPriceXInputZeroReturnsZero() public {
        basicInitDex();
        uint256 xRes = credit.balanceOf(address(dex));
        uint256 yRes = asset.balanceOf(address(dex));
        assertEq(dex.price(0, xRes, yRes), 0);
        assertEq(dex.price(0, yRes, xRes), 0);
    }
}
