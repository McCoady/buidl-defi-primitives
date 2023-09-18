// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {FruitPrediction} from "../src/FruitPrediction.sol";
import {AssetToken} from "../src/AssetToken.sol";
import {CreditToken} from "../src/CreditToken.sol";
import {BasicDex} from "../src/BasicDex.sol";

contract FruitPredictionTest is Test {
    CreditToken public credit;
    AssetToken public avocado;
    BasicDex public avocadoDex;
    FruitPrediction public fruitPrediction;

    address alice = makeAddr("alice");

    function setUp() public {
        credit = new CreditToken("Credit", "CRED", address(this));
        avocado = new AssetToken("Avocado", "AVO", address(this));
        avocadoDex = new BasicDex(address(credit), address(avocado));
        fruitPrediction = new FruitPrediction(
            address(credit),
            address(avocadoDex)
        );

        credit.approve(address(avocadoDex), type(uint256).max);
        avocado.approve(address(avocadoDex), type(uint256).max);
        avocadoDex.init(200 ether);

        credit.transfer(address(fruitPrediction), 1000 ether);
        credit.transfer(alice, 10 ether);
    }

    function testBetBull() public {
        vm.startPrank(alice, alice);
        credit.approve(address(fruitPrediction), 1 ether);
        uint256 thisId = fruitPrediction.betBull(1 ether);
        assertEq(credit.balanceOf(alice), 9 ether);
        assertEq(credit.balanceOf(address(fruitPrediction)), 1001 ether);
        assertEq(
            fruitPrediction.checkWagerExpiry(thisId),
            block.timestamp + 10 minutes
        );
    }

    function testCannotBetBullClaimNoPriceMove() public {
        vm.startPrank(alice, alice);
        credit.approve(address(fruitPrediction), 1 ether);
        uint256 thisId = fruitPrediction.betBull(1 ether);
        vm.warp(11 minutes);
        vm.expectRevert(FruitPrediction.UnsuccessfulClaim.selector);
        fruitPrediction.claim(thisId);
    }

    function testBetBullClaimPriceUp() public {
        vm.startPrank(alice, alice);
        credit.approve(address(fruitPrediction), 1 ether);
        uint256 thisId = fruitPrediction.betBull(1 ether);
        console2.log("Alice credit bal after bet", credit.balanceOf(alice));
        vm.stopPrank();
        vm.warp(11 minutes);

        // move avocado price up
        credit.approve(address(avocadoDex), 1 ether);
        avocadoDex.creditToAsset(1 ether, 0);

        // claim bet
        vm.startPrank(alice, alice);
        fruitPrediction.claim(thisId);
        console2.log("Alice credit bal after claim", credit.balanceOf(alice));
        assert(credit.balanceOf(address(fruitPrediction)) < 1000 ether);
        assert(credit.balanceOf(alice) > 10 ether);
    }

    function testCannotBetBullClaimPriceDown() public {
        vm.startPrank(alice, alice);
        credit.approve(address(fruitPrediction), 1 ether);
        uint256 thisId = fruitPrediction.betBull(1 ether);
        console2.log("Alice credit bal after bet", credit.balanceOf(alice));
        vm.stopPrank();
        vm.warp(11 minutes);

        // move avocado price down
        avocado.approve(address(avocadoDex), 1 ether);
        avocadoDex.assetToCredit(1 ether, 0);

        // claim bet
        vm.startPrank(alice, alice);
        vm.expectRevert(FruitPrediction.UnsuccessfulClaim.selector);
        fruitPrediction.claim(thisId);
    }

    function testCannotBetBearClaimNoPriceMove() public {
        vm.startPrank(alice, alice);
        credit.approve(address(fruitPrediction), 1 ether);
        uint256 thisId = fruitPrediction.betBear(1 ether);
        vm.warp(11 minutes);
        vm.expectRevert(FruitPrediction.UnsuccessfulClaim.selector);
        fruitPrediction.claim(thisId);
    }

    function testCannotBetBearClaimPriceUp() public {
        vm.startPrank(alice, alice);
        credit.approve(address(fruitPrediction), 1 ether);
        uint256 thisId = fruitPrediction.betBear(1 ether);
        console2.log("Alice credit bal after bet", credit.balanceOf(alice));
        vm.stopPrank();
        vm.warp(11 minutes);

        // move avocado price up
        credit.approve(address(avocadoDex), 1 ether);
        avocadoDex.creditToAsset(1 ether, 0);

        // claim bet
        vm.startPrank(alice, alice);
        vm.expectRevert(FruitPrediction.UnsuccessfulClaim.selector);
        fruitPrediction.claim(thisId);
    }

    function testBetBearClaimPriceDown() public {
        vm.startPrank(alice, alice);
        credit.approve(address(fruitPrediction), 1 ether);
        uint256 thisId = fruitPrediction.betBear(1 ether);
        console2.log("Alice credit bal after bet", credit.balanceOf(alice));
        vm.stopPrank();
        vm.warp(11 minutes);

        // move avocado price down
        avocado.approve(address(avocadoDex), 1 ether);
        avocadoDex.assetToCredit(1 ether, 0);

        // claim bet
        vm.startPrank(alice, alice);
        fruitPrediction.claim(thisId);
        console2.log("Alice credit bal after claim", credit.balanceOf(alice));
        assert(credit.balanceOf(address(fruitPrediction)) < 1000 ether);
        assert(credit.balanceOf(alice) > 10 ether);
    }

    function testCannotClaimTwice() public {
        vm.startPrank(alice, alice);
        credit.approve(address(fruitPrediction), 1 ether);
        uint256 thisId = fruitPrediction.betBull(1 ether);
        console2.log("Alice credit bal after bet", credit.balanceOf(alice));
        vm.stopPrank();
        vm.warp(11 minutes);

        // move avocado price up
        credit.approve(address(avocadoDex), 1 ether);
        avocadoDex.creditToAsset(1 ether, 0);

        // claim bet
        vm.startPrank(alice, alice);
        fruitPrediction.claim(thisId);
        console2.log("Alice credit bal after claim", credit.balanceOf(alice));
        assert(credit.balanceOf(address(fruitPrediction)) < 1000 ether);
        assert(credit.balanceOf(alice) > 10 ether);
        vm.expectRevert(FruitPrediction.WagerAlreadyClaimed.selector);
        fruitPrediction.claim(thisId);
    }

    function testCannotClaimFalseId() public {
        vm.expectRevert(FruitPrediction.NonExistantId.selector);
        fruitPrediction.claim(0);
    }
}
