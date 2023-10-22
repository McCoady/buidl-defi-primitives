// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {SimpleStaker} from "../src/staking/SimpleStaker.sol";
import {CreditToken} from "../src/tokens/CreditToken.sol";

contract SimpleStakerTest is Test {
    CreditToken public cred;
    SimpleStaker public staker;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        cred = new CreditToken("Cred", "CRED", address(this));
        staker = new SimpleStaker();
        cred.approve(address(staker), 200 ether);
        staker.init(address(cred), address(cred), 10 days, 200 ether);

        cred.transfer(alice, 10 ether);
    }

    function stakeUser(address _user, uint256 _amount) internal {
        vm.startPrank(_user, _user);
        cred.approve(address(staker), _amount);
        staker.stake(_amount);
    }

    function testInit() public {
        assertEq(address(staker.stakingToken()), address(cred));
        assertEq(address(staker.rewardsToken()), address(cred));
        assertEq(cred.balanceOf(address(staker)), 200 ether);
        assertEq(staker.duration(), 10 days);
        uint256 expectedRate = 200 ether / uint256(10 days);
        assertEq(staker.rewardRate(), expectedRate);
    }

    function testRewardPerToken() public {
        cred.transfer(bob, 10 ether);
        uint256 rewardPerToken = staker.rewardPerToken();
        assertEq(rewardPerToken, 0);

        stakeUser(alice, 10 ether);
        console2.log(
            "alice rewards per token",
            staker.userRewardPerTokenPaid(alice)
        );
        vm.stopPrank();
        vm.warp(10);
        stakeUser(bob, 10 ether);
        console2.log(
            "bob rewards per token",
            staker.userRewardPerTokenPaid(bob)
        );

        uint256 newRewardPerToken = staker.rewardPerToken();
        console2.log("new reward per token", newRewardPerToken);
    }

    function testStake() public {
        stakeUser(alice, 10 ether);
        assertEq(cred.balanceOf(address(staker)), 210 ether);
        assertEq(cred.balanceOf(alice), 0);
    }

    function testWithdraw() public {
        stakeUser(alice, 10 ether);

        staker.withdraw(10 ether);
        assertEq(cred.balanceOf(address(staker)), 200 ether);
        assertEq(cred.balanceOf(alice), 10 ether);
    }

    function testEarned() public {
        stakeUser(alice, 10 ether);

        vm.warp(block.timestamp + 60);
        uint256 aliceEarned = staker.earned(alice);
        console2.log("1 min rewards", aliceEarned);
        assert(aliceEarned != 0);
    }

    function testEarnedTwoStakers() public {
        cred.transfer(bob, 10 ether);

        stakeUser(alice, 10 ether);
        vm.stopPrank();

        stakeUser(bob, 10 ether);

        vm.warp(block.timestamp + 60);
        uint256 aliceEarned = staker.earned(alice);
        console2.log("1 min rewards", aliceEarned);
    }

    function testEarnedTwoStakersDiffTimes() public {
        cred.transfer(bob, 10 ether);

        stakeUser(alice, 10 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 20);
        stakeUser(bob, 10 ether);

        vm.warp(block.timestamp + 60);
        uint256 aliceEarned = staker.earned(alice);
        uint256 bobEarned = staker.earned(bob);

        console2.log("1 min rewards alice", aliceEarned);
                console2.log("40 sec rewards bob", bobEarned);
        
    }

    function testRewardAmountSameAfterClaim() public {
        cred.transfer(bob, 10 ether);

        stakeUser(alice, 10 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 20);
        stakeUser(bob, 10 ether);

        vm.warp(block.timestamp + 30);
        uint256 aliceBeforeEarned = staker.earned(alice);
        staker.withdraw(10 ether);
        staker.getReward();
        uint256 aliceAfterEarned = staker.earned(alice);
        assertEq(aliceBeforeEarned, aliceAfterEarned);
    }

    function testGetReward() public {
        stakeUser(alice, 10 ether);
        vm.warp(block.timestamp + 1);
        staker.withdraw(10 ether);
        staker.getReward();
        assert(cred.balanceOf(alice) > 10 ether);
    }
}
