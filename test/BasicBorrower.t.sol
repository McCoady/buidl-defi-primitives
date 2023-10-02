// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {BasicBorrower} from "../src/BasicBorrower.sol";
import {CreditToken} from "../src/CreditToken.sol";
import {ERC20} from "lib/solmate/src/tokens/ERC20.sol";

contract BasicBorrowerTest is Test {
    BasicBorrower public borrower;
    CreditToken public credit;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        credit = new CreditToken("CRED", unicode"💸", address(this));
        borrower = new BasicBorrower(ERC20(credit), "BasicBorrower", "BBRRW");
    }


    function testDepositLiquidity() public {
        credit.transfer(alice, 100 ether);

        vm.startPrank(alice, alice);
        credit.approve(address(borrower), 100 ether);
        borrower.deposit(100 ether, alice);
        uint256 userLiquidityDeposited = borrower.getUserLpShare(alice);
        uint256 totalLiquidity = credit.balanceOf(address(borrower));
        assertEq(userLiquidityDeposited, 100 ether);
        assertEq(totalLiquidity, 100 ether);
    }

    function testDepositLiquidityTwice() public {
        credit.transfer(alice, 200 ether);

        vm.startPrank(alice, alice);
        credit.approve(address(borrower), 200 ether);
        borrower.deposit(100 ether, alice);
        borrower.deposit(100 ether, alice);
        uint256 userLiquidityDeposited = borrower.getUserLpShare(alice);
        uint256 totalLiquidity = credit.balanceOf(address(borrower));
        assertEq(userLiquidityDeposited, 200 ether);
        assertEq(totalLiquidity, 200 ether);
    }

    function testWithdrawLiquidity() public {
        credit.transfer(alice, 100 ether);

        vm.startPrank(alice, alice);
        credit.approve(address(borrower), 100 ether);
        borrower.deposit(100 ether, alice);
        borrower.withdraw(100 ether, alice, alice);
        uint256 userLiquidityDeposited = borrower.getUserLpShare(alice);
        uint256 totalLiquidity = credit.balanceOf(address(borrower));
        assertEq(credit.balanceOf(alice), 100 ether);
        assertEq(userLiquidityDeposited, 0);
        assertEq(totalLiquidity, 0);
    }

    function testWithdrawAfterOthersDeposit() public {
        credit.transfer(bob, 300 ether);
        credit.transfer(alice, 100 ether);

        vm.startPrank(bob, bob);
        credit.approve(address(borrower), 300 ether);
        borrower.deposit(300 ether, bob);

        vm.startPrank(alice, alice);
        credit.approve(address(borrower), 100 ether);
        borrower.deposit(100 ether, alice);
        borrower.withdraw(100 ether, alice, alice);
        uint256 userLiquidityDeposited = borrower.getUserLpShare(alice);
        uint256 totalLiquidity = credit.balanceOf(address(borrower));
        assertEq(credit.balanceOf(alice), 100 ether);
        assertEq(userLiquidityDeposited, 0);
        assertEq(totalLiquidity, 300 ether);
    }

    // TODO: reuse this test when withdrawAmount functionality is working
    // function testWithdrawPartialLiquidity() public {

    //  
    //     credit.transfer(alice, 100 ether);

    //     vm.startPrank(alice, alice);
    //     credit.approve(address(borrower), 100 ether);
    //     borrower.deposit(100 ether);
    //     borrower.withdraw();

    //     uint256 userLiquidityDeposited = borrower.getUserLpShare(alice);
    //     console2.log("User Liq left", userLiquidityDeposited);
    //     uint256 totalLiquidity = credit.balanceOf(address(borrower));
    //     console2.log("Contract credits", totalLiquidity);
    //     assertEq(userLiquidityDeposited, 0);
    //     assertEq(totalLiquidity, 0);
    // }

    // TODO: reuse this test when withdrawAmount functionality is working
    // function testCannotWithdrawAboveBalance() public {
    //  
    //     credit.transfer(alice, 100 ether);
    //     credit.transfer(bob, 100 ether);

    //     // deposit as bob
    //     vm.startPrank(bob, bob);
    //     credit.approve(address(borrower), 100 ether);
    //     borrower.deposit(100 ether);
    //     vm.stopPrank();

    //     // deposit as alice
    //     vm.startPrank(alice, alice);
    //     credit.approve(address(borrower), 100 ether);
    //     borrower.deposit(100 ether);

    //     // attempt to withdraw all funds as alice
    //     vm.expectRevert(BasicBorrower.InsufficientBalance.selector);
    //     borrower.withdraw();
    // }

    function testCannotWithdrawFundsUsedAsCollateral(uint256 bobIn) public {
        vm.assume(bobIn >= 1 ether);
        vm.assume(bobIn <= 9900 ether);
        credit.transfer(alice, 100 ether);
        credit.transfer(bob, bobIn);

        // deposit 100 tokens as bob
        vm.startPrank(bob, bob);
        credit.approve(address(borrower), bobIn);
        borrower.deposit(bobIn, bob);
        vm.stopPrank();

        // deposit 100 tokens as alice
        vm.startPrank(alice, alice);
        credit.approve(address(borrower), 100 ether);
        borrower.deposit(100 ether, alice);

        // borrow 60 tokens as alice
        borrower.borrowFunds(80 ether);

        // try to withdraw collateral
        console2.log("Total contract funds", borrower.totalAssets());
        console2.log("alice lp", borrower.getUserLpShare(alice));
        vm.expectRevert(BasicBorrower.FundsRequiredForCollateral.selector);
        borrower.withdraw(100 ether, alice, alice);
    }

    function testBorrow(uint256 aliceBorrow) public {
        vm.assume(aliceBorrow < 83 ether);
        vm.assume(aliceBorrow >= 1 ether);

        credit.transfer(alice, 100 ether);

        // deposit 100 tokens as alice
        vm.startPrank(alice, alice);
        credit.approve(address(borrower), 100 ether);
        borrower.deposit(100 ether, alice);

        // borrow tokens eth as alice
        borrower.borrowFunds(aliceBorrow);
        uint256 aliceCredits = credit.balanceOf(alice);
        uint256 borrowerCredits = credit.balanceOf(address(borrower));
        assertEq(aliceCredits, aliceBorrow);
        assertEq(borrowerCredits, 100 ether - aliceBorrow);
    }

    function testCannotBorrowOverLimit(uint256 aliceBorrow) public {
        vm.assume(aliceBorrow > 83.5 ether);
        vm.assume(aliceBorrow <= 100_000 ether);
        credit.transfer(alice, 100 ether);

        // deposit 100 tokens as alice
        vm.startPrank(alice, alice);
        credit.approve(address(borrower), 100 ether);
        borrower.deposit(100 ether, alice);

        // borrow 90 tokens as alice
        vm.expectRevert(BasicBorrower.InsufficientCollateral.selector);
        borrower.borrowFunds(aliceBorrow);
    }

    function testCannotBorrowOverLimitWithTwoTx() public {
        credit.transfer(alice, 100 ether);

        // deposit 100 tokens as alice
        vm.startPrank(alice, alice);
        credit.approve(address(borrower), 100 ether);
        borrower.deposit(100 ether, alice);

        // borrow 90 tokens as alice over 2 txs (80 tokens, then 10 tokens)
        borrower.borrowFunds(80 ether);
        vm.expectRevert(BasicBorrower.InsufficientCollateral.selector);
        borrower.borrowFunds(10 ether);
    }

    function testCannotBorrowDust() public {
        credit.transfer(alice, 100 ether);

        // deposit 100 tokens as alice
        vm.startPrank(alice, alice);
        credit.approve(address(borrower), 100 ether);
        borrower.deposit(100 ether, alice);

        // borrow dust (0.5 tokens)
        vm.expectRevert(BasicBorrower.InsufficientBorrowAmount.selector);
        borrower.borrowFunds(0.5 ether);
    }

    function testReturnFunds() public {
        credit.transfer(alice, 100 ether);

        // deposit 100 tokens as alice
        vm.startPrank(alice, alice);
        credit.approve(address(borrower), 100 ether);
        borrower.deposit(100 ether, alice);

        // borrow 80 tokens
        borrower.borrowFunds(80 ether);
        vm.stopPrank();

        //send alice extra credits to pay fee
        credit.transfer(alice, 1 ether);

        // return tokens same block
        vm.startPrank(alice, alice);
        credit.approve(address(borrower), 100 ether);
        borrower.returnFunds(0);
        assert(credit.balanceOf(alice) < 100 ether);
        assertEq(borrower.userBorrowedAmount(alice), 0);
    }

    function testReturnFundsInterestGoesUp() public {
        credit.transfer(alice, 100 ether);

        // deposit 100 tokens as alice
        vm.startPrank(alice, alice);
        credit.approve(address(borrower), 100 ether);
        borrower.deposit(100 ether, alice);

        // borrow 80 tokens
        borrower.borrowFunds(80 ether);
        vm.stopPrank();

        //send alice extra credits to pay fee
        credit.transfer(alice, 2 ether);

        // return tokens same block
        vm.startPrank(alice, alice);
        credit.approve(address(borrower), 100 ether);
        vm.warp(10 hours);
        borrower.returnFunds(0);
        assert(credit.balanceOf(alice) < 100 ether);
        assertEq(borrower.userBorrowedAmount(alice), 0);
    }

    function testLiquidateBadDebt() public {
        credit.transfer(alice, 100 ether);

        // deposit 100 tokens as alice
        vm.startPrank(alice, alice);
        credit.approve(address(borrower), 100 ether);
        borrower.deposit(100 ether, alice);

        // borrow 80 tokens
        borrower.borrowFunds(80 ether);
        vm.stopPrank();

        vm.startPrank(bob, bob);
        vm.warp(11 days);
        uint256 currentReturnFee = borrower.calculateReturnFee(0);
        console2.log("current return fee", currentReturnFee);
        borrower.liquidate(0);
        assertEq(borrower.getUserLpShare(alice), 0);
        assertEq(credit.balanceOf(address(borrower)), 19 ether);
        assertEq(credit.balanceOf(bob), 1 ether);
    }

    function testCannotLiquidateEarly() public {
        credit.transfer(alice, 100 ether);

        // deposit 100 tokens as alice
        vm.startPrank(alice, alice);
        credit.approve(address(borrower), 100 ether);
        borrower.deposit(100 ether, alice);

        // borrow 80 tokens
        borrower.borrowFunds(80 ether);
        vm.stopPrank();

        vm.startPrank(bob, bob);
        vm.warp(7 days);
        uint256 currentReturnFee = borrower.calculateReturnFee(0);
        console2.log("current return fee", currentReturnFee);
        vm.expectRevert(BasicBorrower.BorrowNotUnderwater.selector);
        borrower.liquidate(0);
    }

    //TODO: users can get longer to payback with multiple smaller borrows vs one larger one
    //TODO: is this an issue? batchLiquidate function?
    function testLiquidateSeparateBorrows() public {
        credit.transfer(alice, 100 ether);

        // deposit 100 tokens as alice
        vm.startPrank(alice, alice);
        credit.approve(address(borrower), 100 ether);
        borrower.deposit(100 ether, alice);

        // borrow 80 tokens (40 then 40)
        borrower.borrowFunds(40 ether);
        borrower.borrowFunds(40 ether);
        vm.stopPrank();

        vm.startPrank(bob, bob);
        vm.warp(10 days);
        uint256 currentReturnFee = borrower.calculateReturnFee(0);
        console2.log("current return fee", currentReturnFee);
        vm.expectRevert(BasicBorrower.BorrowNotUnderwater.selector);
        borrower.liquidate(0);
    }
}
