// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {AssetToken} from "../src/tokens/AssetToken.sol";
import {CreditToken} from "../src/tokens/CreditToken.sol";
import {BasicDexV2} from "../src/dex/BasicDexV2.sol";
import {BasicRouter} from "../src/dex/BasicRouter.sol";

contract BasicRouterTest is Test {
    CreditToken public credit;
    AssetToken public avocado;
    AssetToken public banana;
    AssetToken public tomato;
    BasicDexV2 public avocadoDex;
    BasicDexV2 public bananaDex;
    BasicDexV2 public tomatoDex;
    BasicRouter public router;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        credit = new CreditToken("Credit", "CRED", address(this));
        avocado = new AssetToken("Avocado", "AVO", address(this));
        banana = new AssetToken("Banana", "BNNA", address(this));
        tomato = new AssetToken("Tomato", "TMT", address(this));
        avocadoDex = new BasicDexV2(credit, avocado);
        bananaDex = new BasicDexV2(credit, banana);
        tomatoDex = new BasicDexV2(credit, tomato);

        credit.approve(address(avocadoDex), 200 ether);
        avocado.approve(address(avocadoDex), 200 ether);
        avocadoDex.init(200 ether);

        credit.approve(address(bananaDex), 200 ether);
        banana.approve(address(bananaDex), 200 ether);
        bananaDex.init(200 ether);

        router = new BasicRouter(address(credit));
        router.addValidAsset(address(avocado), address(avocadoDex));
        router.addValidAsset(address(banana), address(bananaDex));   

        avocado.transfer(alice, 10 ether);     
    }

    function testAssetsValid() public {
        assert(router.assetValid(address(avocado)));
        assert(router.assetValid(address(banana)));
        assertEq(router.assetToDex(address(avocado)), address(avocadoDex));
        assertEq(router.assetToDex(address(banana)), address(bananaDex));
    }

    function testAddValidAsset() public {
        router.addValidAsset(address(tomato), address(tomatoDex));

        assert(router.assetValid(address(tomato)));
        assertEq(router.assetToDex(address(tomato)), address(tomatoDex));
    }

    function testRemoveValidAsset() public {
        router.removeValidAsset(address(avocado));

        assert(!router.assetValid(address(avocado)));
        assertEq(router.assetToDex(address(avocado)), address(0));
    }

    function testGetTokensOut() public {
        uint256 tokensOutRouter = router.getAssetsOut(address(avocado), address(banana), 10 ether);
        
        uint256 creditOutDex = avocadoDex.assetInPrice(10 ether);
        uint256 tokensOutDex = bananaDex.creditInPrice(creditOutDex);

        assertEq(tokensOutRouter, tokensOutDex);
    }

    function testTradeAssets() public {
        uint256 tokensOut = router.getAssetsOut(address(avocado), address(banana), 10 ether);

        vm.startPrank(alice, alice);

        avocado.approve(address(router), 10 ether);
        router.assetToAsset(address(avocado), 10 ether, address(banana), tokensOut);
        assertEq(avocado.balanceOf(alice), 0);
        assert(banana.balanceOf(alice) > 0);
    }

    function testTradeZeroAssets() public {
        vm.startPrank(alice, alice);

        vm.expectRevert(BasicDexV2.ZeroQuantityError.selector);
        router.assetToAsset(address(avocado), 0, address(banana), 0);
        assertEq(avocado.balanceOf(alice), 10 ether);
    }

    function testCannotTradeInvalidAsset() public {
        tomato.transfer(bob, 10 ether);
        tomato.approve(address(router), 10 ether);
        vm.expectRevert(BasicRouter.InvalidAsset.selector);
        router.assetToAsset(address(tomato), 10 ether, address(banana), 0);
    }

    function testCannotTradeForInvalidAsset() public {
        vm.startPrank(alice);

        avocado.approve(address(router), 10 ether);
        vm.expectRevert(BasicRouter.InvalidAsset.selector);
        router.assetToAsset(address(avocado), 10 ether, address(tomato), 0);
    }
}
