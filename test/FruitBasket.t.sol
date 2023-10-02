// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {AssetToken} from "../src/tokens/AssetToken.sol";
import {BasicDex} from "../src/dex/BasicDex.sol";
import {CreditToken} from "../src/tokens/CreditToken.sol";
import {FruitBasket} from "../src/index-vault/FruitBasket.sol";

contract FruitBasketTest is Test {
    CreditToken public credit;
    AssetToken public avocado;
    AssetToken public banana;
    AssetToken public tomato;

    BasicDex public avocadoDex;
    BasicDex public bananaDex;
    BasicDex public tomatoDex;

    FruitBasket public fruitBasket;

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

        fruitBasket = new FruitBasket(
            address(avocado),
            address(banana),
            address(tomato),
            address(credit),
            address(avocadoDex),
            address(bananaDex),
            address(tomatoDex)
        );
        credit.transfer(alice, 1 ether);
    }

    function testBuy() public {
        vm.startPrank(alice, alice);
        credit.approve(address(fruitBasket), 1 ether);
        fruitBasket.buy(1 ether);
        assertEq(fruitBasket.balanceOf(alice), 1 ether);
        assertEq(credit.balanceOf(alice), 0);
        assert(avocado.balanceOf(address(fruitBasket)) != 0);
        assert(banana.balanceOf(address(fruitBasket)) != 0);
        assert(tomato.balanceOf(address(fruitBasket)) != 0);
    }

    function testSell() public {
        vm.startPrank(alice, alice);
        credit.approve(address(fruitBasket), 1 ether);
        fruitBasket.buy(1 ether);

        fruitBasket.claim(1 ether);
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
        fruitBasket.buy(1 ether);
        fruitBasket.buy(1 ether);
        assertEq(fruitBasket.balanceOf(alice), 2 ether);

        fruitBasket.claim(2 ether);
        assertEq(fruitBasket.balanceOf(alice), 0);
        assertEq(avocado.balanceOf(address(fruitBasket)), 0);
        assertEq(banana.balanceOf(address(fruitBasket)), 0);
        assertEq(tomato.balanceOf(address(fruitBasket)), 0);
        assert(credit.balanceOf(alice) != 0);
    }

    function testSellPartial() public {
        vm.startPrank(alice, alice);
        credit.approve(address(fruitBasket), 1 ether);
        fruitBasket.buy(1 ether);

        fruitBasket.claim(0.5 ether);
        assertEq(fruitBasket.balanceOf(alice), 0.5 ether);
        assert(credit.balanceOf(alice) != 0);
        assert(avocado.balanceOf(address(fruitBasket)) != 0);
        assert(banana.balanceOf(address(fruitBasket)) != 0);
        assert(tomato.balanceOf(address(fruitBasket)) != 0);
    }

    function testBuySetMin() public {
        vm.startPrank(alice, alice);
        credit.approve(address(fruitBasket), 1 ether);
        fruitBasket.buySetMin(1 ether, 0.33 ether, 0.33 ether, 0.33 ether);
        assertEq(fruitBasket.balanceOf(alice), 1 ether);
        assertEq(credit.balanceOf(alice), 0);
        assert(avocado.balanceOf(address(fruitBasket)) != 0);
        assert(banana.balanceOf(address(fruitBasket)) != 0);
        assert(tomato.balanceOf(address(fruitBasket)) != 0);
    }
    function testCannotClaimWithoutTokens() public {
        vm.startPrank(alice, alice);
        credit.approve(address(fruitBasket), 1 ether);
        fruitBasket.buy(1 ether);
        vm.stopPrank();

        vm.startPrank(bob, bob);
        vm.expectRevert();
        fruitBasket.claim(1 ether);
    }
    function testClaimAfterTransferTokens() public {
        credit.approve(address(fruitBasket), 1 ether);
        fruitBasket.buy(1 ether);
        fruitBasket.transfer(alice, 1 ether);

        vm.startPrank(alice, alice);
        fruitBasket.claim(1 ether);
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
        fruitBasket.buy(1 ether);
        vm.stopPrank();

        // buy tokens as bob
        vm.startPrank(bob, bob);
        credit.approve(address(fruitBasket), 1 ether);
        fruitBasket.buy(1 ether);
        vm.stopPrank();

        // sell tokens as alice
        vm.startPrank(alice, alice);
        fruitBasket.claim(1 ether);
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
        fruitBasket.buy(1 ether);
        vm.stopPrank();

        // buy tokens as bob
        vm.startPrank(bob, bob);
        credit.approve(address(fruitBasket), 1 ether);
        fruitBasket.buy(1 ether);
        fruitBasket.claim(1 ether);
        assertEq(fruitBasket.balanceOf(bob), 0);
        assert(credit.balanceOf(bob) > 0.95 ether);
        assertEq(fruitBasket.totalSupply(), 1 ether);
        vm.stopPrank();

        // sell tokens as alice
        vm.startPrank(alice, alice);
        fruitBasket.claim(1 ether);
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
        fruitBasket.buy(1 ether);
        vm.stopPrank();
        
        // drop the price of fruit tokens
        avocadoDex.assetToCredit(5 ether, 0);
        bananaDex.assetToCredit(5 ether, 0);
        tomatoDex.assetToCredit(5 ether, 0);
        
        vm.startPrank(alice, alice);
        fruitBasket.claim(1 ether);

        uint256 aliceCreditsAfter = credit.balanceOf(alice);
        console2.log("Alice Credits Out:", aliceCreditsAfter);
        assert(aliceCreditsAfter < 1 ether);
    }
    
    function testCreditOutWhenFruitPriceRises() public {
        vm.startPrank(alice, alice);
        credit.approve(address(fruitBasket), 1 ether);
        fruitBasket.buy(1 ether);
        vm.stopPrank();
        
        // raise the price of fruit tokens
        avocadoDex.creditToAsset(5 ether, 0);
        bananaDex.creditToAsset(5 ether, 0);
        tomatoDex.creditToAsset(5 ether, 0);
        
        vm.startPrank(alice, alice);
        fruitBasket.claim(1 ether);
        
        uint256 aliceCreditsAfter = credit.balanceOf(alice);
        console2.log("Alice Credits Out:", aliceCreditsAfter);
        assert(aliceCreditsAfter > 1 ether);
    }
}
