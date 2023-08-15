// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/AssetToken.sol";
import "../src/CreditToken.sol";
import "../src/BasicDex.sol";

contract CounterTest is Test {
    CreditToken public credit;
    AssetToken public wood;
    AssetToken public oil;
    AssetToken public water;
    AssetToken public gold;
    AssetToken public stone;
    BasicDex public creditWood;
    BasicDex public creditOil;
    BasicDex public creditWater;
    BasicDex public creditGold;
    BasicDex public creditStone;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public colin = makeAddr("colin");

    function setUp() public {
        // Create the systems ERC20 tokens
        credit = new CreditToken("Scaffold Dollars", "SCAFF", address(this));
        wood = new AssetToken("Wood", "WD");
        oil = new AssetToken("Oil", "OIL");
        water = new AssetToken("Water", "WTR");
        gold = new AssetToken("Gold", "GLD");
        stone = new AssetToken("Stone", "STN");

        // Create the Dexes
        creditWood = new BasicDex(address(credit), address(wood));
        creditOil = new BasicDex(address(credit), address(oil));
        creditWater = new BasicDex(address(credit), address(water));
        creditGold = new BasicDex(address(credit), address(gold));
        creditStone = new BasicDex(address(credit), address(stone));

        // approve dexes
        credit.approve(address(creditWood), type(uint256).max);
        credit.approve(address(creditOil), type(uint256).max);
        credit.approve(address(creditWater), type(uint256).max);
        credit.approve(address(creditGold), type(uint256).max);
        credit.approve(address(creditStone), type(uint256).max);
        wood.approve(address(creditWood), type(uint256).max);
        oil.approve(address(creditOil), type(uint256).max);
        water.approve(address(creditWater), type(uint256).max);
        gold.approve(address(creditGold), type(uint256).max);
        stone.approve(address(creditStone), type(uint256).max);

        // Add initial liquidity to dexes;
        creditWood.init(100 ether);
        creditOil.init(100 ether);
        creditWater.init(100 ether);
        creditGold.init(100 ether);
        creditStone.init(100 ether);

        // Send some credits to alice
        credit.airdropToWallet(alice);
    }

    function testSetUp() public {
        assertEq(credit.balanceOf(alice), 100 ether);
        vm.startPrank(alice, alice);
        // approve credit dexes
        credit.approve(address(creditWood), type(uint256).max);
        credit.approve(address(creditOil), type(uint256).max);
        credit.approve(address(creditWater), type(uint256).max);
        credit.approve(address(creditGold), type(uint256).max);
        credit.approve(address(creditStone), type(uint256).max);

        // make a small trade to each
        creditWood.creditToAsset(10 ether, 0);
        creditOil.creditToAsset(10 ether, 0);
        creditWater.creditToAsset(10 ether, 0);
        creditGold.creditToAsset(10 ether, 0);
        creditStone.creditToAsset(10 ether, 0);

        // check alice received some of each token
        assert(wood.balanceOf(alice) > 9);
        assert(oil.balanceOf(alice) > 9);
        assert(water.balanceOf(alice) > 9);
        assert(gold.balanceOf(alice) > 9);
        assert(stone.balanceOf(alice) > 9);
    }

    function testFundWallets() public {
        address[] memory wallets = new address[](3);
        wallets[0] = alice;
        wallets[1] = bob;
        wallets[2] = colin;

        credit.airdropToWallets(wallets);

        assertEq(credit.balanceOf(alice), 200 ether);
        assertEq(credit.balanceOf(bob), 100 ether);
        assertEq(credit.balanceOf(colin), 100 ether);
    }

    function testCannotFundWalletsNonOwner() public {
        address[] memory wallets = new address[](3);
        wallets[0] = alice;
        wallets[1] = bob;
        wallets[2] = colin;

        vm.startPrank(alice, alice);
        vm.expectRevert(bytes("UNAUTHORIZED"));
        credit.airdropToWallets(wallets);
    }
}