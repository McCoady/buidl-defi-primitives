// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "lib/solmate/src/tokens/ERC20.sol";
import {Test, console2} from "forge-std/Test.sol";
import {CreditToken} from "../src/CreditToken.sol";
import {AssetToken} from "../src/AssetToken.sol";
import {BasicDex} from "../src/BasicDex.sol";
import {FruitBasketV2} from "../src/FruitBasketV2.sol";

contract FruitBasketV2Test is Test {
    CreditToken public credit;
    AssetToken public avocado;
    AssetToken public banana;
    AssetToken public tomato;

    BasicDex public avocadoDex;
    BasicDex public bananaDex;
    BasicDex public tomatoDex;

    FruitBasketV2 public fruitBasket;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        credit = new CreditToken("Credit", "CRED", address(this));
        avocado = new AssetToken("Avocado", "AVO", address(this));
        banana = new AssetToken("Banana", "BNN", address(this));
        tomato = new AssetToken("Tomato", "TOM", address(this));

        avocadoDex = new BasicDex(address(credit), address(avocado));
        bananaDex = new BasicDex(address(credit), address(banana));
        tomatoDex = new BasicDex(address(credit), address(tomato));

        avocado.approve(address(avocadoDex), type(uint256).max);
        banana.approve(address(bananaDex), type(uint256).max);
        tomato.approve(address(tomatoDex), type(uint256).max);
        credit.approve(address(avocadoDex), type(uint256).max);
        credit.approve(address(bananaDex), type(uint256).max);
        credit.approve(address(tomatoDex), type(uint256).max);

        avocadoDex.init(100 ether);
        bananaDex.init(100 ether);
        tomatoDex.init(100 ether);

        fruitBasket = new FruitBasketV2(
            address(avocado),
            address(banana),
            address(tomato),
            address(avocadoDex),
            address(bananaDex),
            address(tomatoDex),
            ERC20(credit),
            "FruitBasket",
            "FRT"
        );
        credit.transfer(alice, 1 ether);
    }

    function testDeposit() public {
        vm.startPrank(alice, alice);
        credit.approve(address(fruitBasket), 1 ether);
        fruitBasket.deposit(1 ether, alice);

        assertEq(fruitBasket.balanceOf(alice), 1 ether);
        assertEq(credit.balanceOf(alice), 0);

        assert(avocado.balanceOf(address(fruitBasket)) != 0);
        assert(banana.balanceOf(address(fruitBasket)) != 0);
        assert(tomato.balanceOf(address(fruitBasket)) != 0);
        assert(fruitBasket.totalAssets() > 0.9 ether);
    }

    function testMint() public {
        vm.startPrank(alice, alice);
        credit.approve(address(fruitBasket), 1 ether);
        fruitBasket.mint(1 ether, alice);

        assertEq(fruitBasket.balanceOf(alice), 1 ether);
        assertEq(credit.balanceOf(alice), 0);

        assert(avocado.balanceOf(address(fruitBasket)) != 0);
        assert(banana.balanceOf(address(fruitBasket)) != 0);
        assert(tomato.balanceOf(address(fruitBasket)) != 0);
        assert(fruitBasket.totalAssets() > 0.9 ether);
    }

    function testSell() public {
        vm.startPrank(alice, alice);
        credit.approve(address(fruitBasket), 1 ether);
        fruitBasket.deposit(1 ether, alice);

        fruitBasket.redeem(1 ether, alice, alice);
        assertEq(fruitBasket.balanceOf(alice), 0);
        assertEq(avocado.balanceOf(address(fruitBasket)), 0);
        assertEq(banana.balanceOf(address(fruitBasket)), 0);
        assertEq(tomato.balanceOf(address(fruitBasket)), 0);
        assert(credit.balanceOf(alice) != 0);
    }

    function testBuyTwiceAndClaimAll() public {
        credit.transfer(alice, 1 ether);
        vm.startPrank(alice, alice);

        credit.approve(address(fruitBasket), 2 ether);
        fruitBasket.mint(1 ether, alice);
        fruitBasket.mint(1 ether, alice);
        assertEq(fruitBasket.balanceOf(alice), 2 ether);

        fruitBasket.redeem(2 ether, alice, alice);
        assertEq(fruitBasket.balanceOf(alice), 0);
        assertEq(avocado.balanceOf(address(fruitBasket)), 0);
        assertEq(banana.balanceOf(address(fruitBasket)), 0);
        assertEq(tomato.balanceOf(address(fruitBasket)), 0);
        assert(credit.balanceOf(alice) != 0);
    }

    function testSellPartial() public {
        vm.startPrank(alice, alice);
        credit.approve(address(fruitBasket), 1 ether);
        fruitBasket.mint(1 ether, alice);

        fruitBasket.redeem(0.5 ether, alice, alice);
        assertEq(fruitBasket.balanceOf(alice), 0.5 ether);
        assert(credit.balanceOf(alice) != 0);
        assert(avocado.balanceOf(address(fruitBasket)) != 0);
        assert(banana.balanceOf(address(fruitBasket)) != 0);
        assert(tomato.balanceOf(address(fruitBasket)) != 0);
    }

    function testCannotClaimWithoutTokens() public {
        vm.startPrank(alice, alice);
        credit.approve(address(fruitBasket), 1 ether);
        fruitBasket.mint(1 ether, alice);
        vm.stopPrank();

        vm.startPrank(bob, bob);
        vm.expectRevert();
        fruitBasket.redeem(1 ether, bob, bob);
    }

    function testCannotClaimOthersTokens() public {
        vm.startPrank(alice, alice);
        credit.approve(address(fruitBasket), 1 ether);
        fruitBasket.mint(1 ether, alice);
        vm.stopPrank();

        vm.startPrank(bob, bob);
        vm.expectRevert();
        fruitBasket.redeem(1 ether, bob, alice);
    }

    function testClaimAfterTransferTokens() public {
        credit.approve(address(fruitBasket), 1 ether);
        fruitBasket.mint(1 ether, address(this));
        fruitBasket.transfer(alice, 1 ether);

        vm.startPrank(alice, alice);
        fruitBasket.redeem(1 ether, alice, alice);
        assertEq(fruitBasket.balanceOf(alice), 0);
        assertEq(avocado.balanceOf(address(fruitBasket)), 0);
        assertEq(banana.balanceOf(address(fruitBasket)), 0);
        assertEq(tomato.balanceOf(address(fruitBasket)), 0);
        assert(credit.balanceOf(alice) != 0);
    }

    function testClaimAfterMultipleBuys() public {
        // send bob 1 ether of credit tokens
        credit.transfer(bob, 1 ether);
        // buy tokens as alice
        vm.startPrank(alice, alice);
        credit.approve(address(fruitBasket), 1 ether);
        fruitBasket.mint(1 ether, alice);
        vm.stopPrank();

        // buy tokens as bob
        vm.startPrank(bob, bob);
        credit.approve(address(fruitBasket), 1 ether);
        fruitBasket.mint(1 ether, bob);
        vm.stopPrank();

        // sell tokens as alice
        vm.startPrank(alice, alice);
        fruitBasket.redeem(1 ether, alice, alice);
        assertEq(fruitBasket.balanceOf(alice), 0);
        assert(credit.balanceOf(alice) > 0.9 ether);
        assertEq(fruitBasket.totalSupply(), 1 ether);
        assert(avocado.balanceOf(address(fruitBasket)) != 0);
        assert(banana.balanceOf(address(fruitBasket)) != 0);
        assert(tomato.balanceOf(address(fruitBasket)) != 0);
    }

    function testMultipleBuysAndMultipleSells() public {
        // send bob 1 ether of credit tokens
        credit.transfer(bob, 1 ether);
        // buy tokens as alice
        vm.startPrank(alice, alice);
        credit.approve(address(fruitBasket), 1 ether);
        fruitBasket.mint(1 ether, alice);
        vm.stopPrank();

        // buy tokens as bob
        vm.startPrank(bob, bob);
        credit.approve(address(fruitBasket), 1 ether);
        fruitBasket.mint(1 ether, bob);
        fruitBasket.redeem(1 ether, bob, bob);
        assertEq(fruitBasket.balanceOf(bob), 0);
        assert(credit.balanceOf(bob) > 0.95 ether);
        assertEq(fruitBasket.totalSupply(), 1 ether);
        vm.stopPrank();

        // sell tokens as alice
        vm.startPrank(alice, alice);
        fruitBasket.redeem(1 ether, alice, alice);
        assertEq(fruitBasket.balanceOf(alice), 0);
        assert(credit.balanceOf(alice) > 0.9 ether);
        assertEq(fruitBasket.totalSupply(), 0 ether);
        assertEq(avocado.balanceOf(address(fruitBasket)), 0);
        assertEq(banana.balanceOf(address(fruitBasket)), 0);
        assertEq(tomato.balanceOf(address(fruitBasket)), 0);
    }

    function testCreditOutWhenFruitPriceDrops() public {
        vm.startPrank(alice, alice);
        credit.approve(address(fruitBasket), 1 ether);
        fruitBasket.mint(1 ether, alice);
        vm.stopPrank();

        // drop the price of fruit tokens
        avocadoDex.assetToCredit(5 ether, 0);
        bananaDex.assetToCredit(5 ether, 0);
        tomatoDex.assetToCredit(5 ether, 0);

        vm.startPrank(alice, alice);
        fruitBasket.redeem(1 ether, alice, alice);

        uint256 aliceCreditsAfter = credit.balanceOf(alice);
        console2.log("Alice Credits Out:", aliceCreditsAfter);
        assert(aliceCreditsAfter < 1 ether);
    }

    function testCreditOutWhenFruitPriceRises() public {
        vm.startPrank(alice, alice);
        credit.approve(address(fruitBasket), 1 ether);
        fruitBasket.mint(1 ether, alice);
        vm.stopPrank();

        // raise the price of fruit tokens
        avocadoDex.creditToAsset(5 ether, 0);
        bananaDex.creditToAsset(5 ether, 0);
        tomatoDex.creditToAsset(5 ether, 0);

        vm.startPrank(alice, alice);
        fruitBasket.redeem(1 ether, alice, alice);

        uint256 aliceCreditsAfter = credit.balanceOf(alice);
        console2.log("Alice Credits Out:", aliceCreditsAfter);
        assert(aliceCreditsAfter > 1 ether);
    }

    function testMintForOther() public {
        vm.startPrank(alice, alice);
        uint256 aliceStartCreds = credit.balanceOf(alice);
        credit.approve(address(fruitBasket), 1 ether);

        fruitBasket.mint(1 ether, bob);

        assertEq(aliceStartCreds - 1 ether, credit.balanceOf(alice));
        assertEq(fruitBasket.balanceOf(bob), 1 ether);
    }

    function testMintForOtherAndSell() public {
        vm.startPrank(alice, alice);
        uint256 aliceStartCreds = credit.balanceOf(alice);
        credit.approve(address(fruitBasket), 1 ether);

        fruitBasket.mint(1 ether, bob);
        vm.stopPrank();

        vm.startPrank(bob, bob);
        fruitBasket.redeem(1 ether, bob, bob);
        assert(credit.balanceOf(bob) > 0);
    }

    function testAmountSharesReceivedChange() public {
        vm.startPrank(alice, alice);
        credit.approve(address(fruitBasket), 1 ether);
        fruitBasket.mint(1 ether, alice);
        vm.stopPrank();

        // drop the price of fruit tokens
        avocadoDex.assetToCredit(5 ether, 0);
        bananaDex.assetToCredit(5 ether, 0);
        tomatoDex.assetToCredit(5 ether, 0);
        credit.transfer(bob, 1 ether);

        vm.startPrank(bob, bob);
        credit.approve(address(fruitBasket), 1 ether);
        fruitBasket.deposit(1 ether, bob);
        assert(fruitBasket.balanceOf(bob) > 1 ether);

        // redeem and confirm bob has more credits
        console2.log("Preview redeem", fruitBasket.previewRedeem((fruitBasket.balanceOf(bob))));
        fruitBasket.redeem(fruitBasket.balanceOf(bob), bob, bob);
        vm.stopPrank();
        
        vm.startPrank(alice, alice);
        fruitBasket.redeem(fruitBasket.balanceOf(alice), alice, alice);

        assert(credit.balanceOf(bob) > credit.balanceOf(alice));
        assertEq(fruitBasket.totalSupply(), 0);
        assertEq(fruitBasket.totalAssets(), 0);
    }

    function testAmountFuzzedBuyClaim(uint256 aliceIn, uint256 bobIn) public {
        vm.assume(aliceIn <= 10 ether);
        vm.assume(aliceIn >= 0.1 ether);
        vm.assume(bobIn <= 10 ether);
        vm.assume(bobIn >= 0.1 ether);

        // get alice and bob 10 eth
        credit.transfer(alice, 9 ether);
        credit.transfer(bob, 10 ether);
        
        vm.startPrank(alice, alice);
        credit.approve(address(fruitBasket), aliceIn);
        fruitBasket.mint(aliceIn, alice);
        vm.stopPrank();

        // drop the price of fruit tokens
        avocadoDex.assetToCredit(5 ether, 0);
        bananaDex.assetToCredit(5 ether, 0);
        tomatoDex.assetToCredit(5 ether, 0);

        vm.startPrank(bob, bob);
        credit.approve(address(fruitBasket), bobIn);
        fruitBasket.deposit(bobIn, bob);
        assert(fruitBasket.balanceOf(bob) > bobIn);

        // redeem and confirm bob has more credits
        console2.log("Preview redeem", fruitBasket.previewRedeem((fruitBasket.balanceOf(bob))));
        fruitBasket.redeem(fruitBasket.balanceOf(bob), bob, bob);
        vm.stopPrank();
        
        vm.startPrank(alice, alice);
        fruitBasket.redeem(fruitBasket.balanceOf(alice), alice, alice);

        //assert(credit.balanceOf(bob) > credit.balanceOf(alice));
        assertEq(fruitBasket.totalSupply(), 0);
        assertEq(fruitBasket.totalAssets(), 0);
    }
}
