// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {BasicDex} from "../src/dex/BasicDex.sol";
import {AssetToken} from "../src/tokens/AssetToken.sol";
import {AssetToken} from "../src/tokens/AssetToken.sol";
import {AssetToken} from "../src/tokens/AssetToken.sol";
import {CreditToken} from "../src/tokens/CreditToken.sol";
import {CreditNetWorthCalc} from "../src/utils/CreditNetWorthCalc.sol";

contract CreditNetWorthCalcTest is Test {
    CreditNetWorthCalc public calc;
    CreditToken public credit;
    AssetToken public avocado;
    BasicDex public avocadoDex;
    AssetToken public banana;
    BasicDex public bananaDex;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        credit = new CreditToken("Credit", "CRED", address(this));
        avocado = new AssetToken("Avocado", "AVO", address(this));
        avocadoDex = new BasicDex(address(credit), address(avocado));
        banana = new AssetToken("Banana", "BNNA", address(this));
        bananaDex = new BasicDex(address(credit), address(banana));
        calc = new CreditNetWorthCalc(address(credit));


        credit.approve(address(avocadoDex), 200 ether);
        avocado.approve(address(avocadoDex), 200 ether);
        avocadoDex.init(200 ether);

        credit.approve(address(bananaDex), 200 ether);
        banana.approve(address(bananaDex), 200 ether);
        bananaDex.init(200 ether);

        credit.transfer(alice, 10 ether);
    }

    function testNoTokens() public {
        address[] memory tokens = new address[](1);
        tokens[0] = address(avocadoDex);
        uint256 bobNetWorth = calc.getNetWorth(bob, tokens);
        assertEq(bobNetWorth, 0);
    }

    function testOnlyCredits() public {
        address[] memory tokens = new address[](1);
        tokens[0] = address(avocadoDex);
        uint256 aliceNetWorth = calc.getNetWorth(alice, tokens);
        assertEq(aliceNetWorth, 10 ether);   
    }

    function testOnlyTokens() public {
        avocado.transfer(bob, 10 ether);
        address[] memory tokens = new address[](1);
        tokens[0] = address(avocadoDex);
        uint256 bobNetWorth = calc.getNetWorth(bob, tokens);
        console2.log("bob net worth", bobNetWorth);
        assert(bobNetWorth > 9 ether);
    }

    function testBothCreditsAndTokens() public {
        avocado.transfer(alice, 10 ether);
        address[] memory tokens = new address[](1);
        tokens[0] = address(avocadoDex);
        uint256 aliceNetWorth = calc.getNetWorth(alice, tokens);
        console2.log("alice net worth", aliceNetWorth);
        assert(aliceNetWorth > 19 ether);
    }
    
    function testTwoTokensWithBalance() public {
        avocado.transfer(alice, 10 ether);
        banana.transfer(alice, 10 ether);
        address[] memory tokens = new address[](2);
        tokens[0] = address(avocadoDex);
        tokens[1] = address(bananaDex);
        uint256 aliceNetWorth = calc.getNetWorth(alice, tokens);
        console2.log("alice net worth", aliceNetWorth);
        assert(aliceNetWorth > 28 ether);
    }

    function testTwoTokensNoBalance() public {
        address[] memory tokens = new address[](2);
        tokens[0] = address(avocadoDex);
        tokens[1] = address(bananaDex);
        uint256 bobNetWorth = calc.getNetWorth(bob, tokens);
        assertEq(bobNetWorth,0);
    }

    function testBatchGet() public {
        address[] memory tokens = new address[](2);
        tokens[0] = address(avocadoDex);
        tokens[1] = address(bananaDex);

        address[] memory users = new address[](2);
        users[0] = alice;
        users[1] = bob;

        avocado.transfer(alice, 10 ether);
        credit.transfer(bob, 10 ether);

        uint256[] memory result = calc.getNetWorths(users, tokens);
        assert(result[0] > 9 ether);
        assertEq(result[1],10 ether);
        console2.log("Alice net worth", result[0]);
        console2.log("Bob net worth", result[1]);
    }
}