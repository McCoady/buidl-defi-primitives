// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {CreditToken} from "../src/CreditToken.sol";
import {AssetToken} from "../src/AssetToken.sol";
import {BasicDex} from "../src/BasicDex.sol";
import {FruitBasket} from "../src/FruitBasket.sol";

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
}
