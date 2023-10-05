// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {AssetToken} from "../src/tokens/AssetToken.sol";
import {BasicDexV2} from "../src/dex/BasicDexV2.sol";
import {CreditToken} from "../src/tokens/CreditToken.sol";
import {LPStakerLock} from "../src/staking/LPStakerLock.sol";
import {ERC20} from "lib/solmate/src/tokens/ERC20.sol";

contract LPStakerLockTest is Test {
    CreditToken public credit;
    AssetToken public asset;
    BasicDexV2 public dex;
    LPStakerLock public staker;

    address public alice = makeAddr("alice");

    function setUp() public {
        credit = new CreditToken("Credit", "CRED", address(this));
        asset = new AssetToken("Asset", "ASS", address(this));
        dex = new BasicDexV2(ERC20(credit), ERC20(asset));
        staker = new LPStakerLock(ERC20(dex), ERC20(asset));
    }

    function testStake() public {
        credit.transfer(alice, 100 ether);
        asset.transfer(alice, 100 ether);

        vm.startPrank(alice, alice);
        credit.approve(address(dex), 100 ether);
        asset.approve(address(dex), 100 ether);
        dex.init(100 ether);

        dex.approve(address(staker), 100 ether);
        staker.lockLp(100 ether);
        assertEq(dex.balanceOf(address(staker)), 100 ether);
        assertEq(dex.balanceOf(alice), 0);
    }

    function testRedeemLp() public {
        // send staker asset to give as rewards
        asset.transfer(address(staker), 10 ether);

        credit.transfer(alice, 100 ether);
        asset.transfer(alice, 100 ether);

        vm.startPrank(alice, alice);

        credit.approve(address(dex), 100 ether);
        asset.approve(address(dex), 100 ether);
        dex.init(100 ether);

        dex.approve(address(staker), 100 ether);
        staker.lockLp(100 ether);

        vm.warp(7 days + 1);
        staker.redeemUnlockedLp(1);
        assertEq(dex.balanceOf(alice), 100 ether);
        assertEq(dex.balanceOf(address(staker)), 0);
        assertEq(staker.claimableRewards(alice), 5 ether);
    }

    function testCannotRedeemEarly() public {
        // send staker asset to give as rewards
        asset.transfer(address(staker), 10 ether);

        credit.transfer(alice, 100 ether);
        asset.transfer(alice, 100 ether);

        vm.startPrank(alice, alice);

        credit.approve(address(dex), 100 ether);
        asset.approve(address(dex), 100 ether);
        dex.init(100 ether);

        dex.approve(address(staker), 100 ether);
        staker.lockLp(100 ether);

        vm.expectRevert(LPStakerLock.LpNotUnlockedYet.selector);
        staker.redeemUnlockedLp(1);
    }

    function testRedeemRewards() public {
        testRedeemLp();
        staker.redeemRewards();
        assertEq(staker.claimableRewards(alice), 0);
        assertEq(asset.balanceOf(alice), 5 ether);
    }

    function testCannotRedeemRewardsTwice() public {
        testRedeemLp();
        staker.redeemRewards();
        assertEq(staker.claimableRewards(alice), 0);
        assertEq(asset.balanceOf(alice), 5 ether);
        vm.expectRevert(LPStakerLock.NoRewardsClaimable.selector);
        staker.redeemRewards();
    }

    function testExpiryTimestamp() public {
        credit.transfer(alice, 100 ether);
        asset.transfer(alice, 100 ether);

        vm.startPrank(alice, alice);

        credit.approve(address(dex), 100 ether);
        asset.approve(address(dex), 100 ether);
        dex.init(100 ether);

        dex.approve(address(staker), 100 ether);
        staker.lockLp(100 ether);

        uint256 unlockTimestamp = staker.checkIdExpiryTimestamp(1);
        assertEq(unlockTimestamp, block.timestamp + 7 days);
    }

    function testExpiryCountdownBeforeUnlock(uint256 timePassed) public {
        vm.assume(timePassed < 7 days);

        credit.transfer(alice, 100 ether);
        asset.transfer(alice, 100 ether);

        vm.startPrank(alice, alice);

        credit.approve(address(dex), 100 ether);
        asset.approve(address(dex), 100 ether);
        dex.init(100 ether);

        dex.approve(address(staker), 100 ether);
        staker.lockLp(100 ether);

        vm.warp(timePassed + 1);
        uint256 unlockCountdown = staker.checkIdExpiryCountdown(1);
        assertEq(unlockCountdown, 7 days - timePassed);
    }

        function testExpiryCountdownAfterUnlock(uint256 timePassed) public {
        vm.assume(timePassed > 7 days);
        vm.assume(timePassed < 10_000 weeks);

        credit.transfer(alice, 100 ether);
        asset.transfer(alice, 100 ether);

        vm.startPrank(alice, alice);

        credit.approve(address(dex), 100 ether);
        asset.approve(address(dex), 100 ether);
        dex.init(100 ether);

        dex.approve(address(staker), 100 ether);
        staker.lockLp(100 ether);

        vm.warp(timePassed + 1);
        uint256 unlockCountdown = staker.checkIdExpiryCountdown(1);
        assertEq(unlockCountdown, 0);
    }

    function testSingleGetActiveUserIds() public {
        credit.transfer(alice, 100 ether);
        asset.transfer(alice, 100 ether);

        vm.startPrank(alice, alice);

        credit.approve(address(dex), 100 ether);
        asset.approve(address(dex), 100 ether);
        dex.init(100 ether);

        dex.approve(address(staker), 100 ether);
        staker.lockLp(100 ether);

        uint256[] memory aliceIds = staker.getUserActiveLockIds(alice);
        uint256[] memory matchIds = new uint256[](1);
        matchIds[0] = 1;

        assertEq(aliceIds, matchIds);
    }

    function testMultipleGetActiveUserIds() public {
        credit.transfer(alice, 100 ether);
        asset.transfer(alice, 100 ether);

        vm.startPrank(alice, alice);

        // lock lp as alice (id 1)
        credit.approve(address(dex), 100 ether);
        asset.approve(address(dex), 100 ether);
        dex.init(100 ether);
        dex.approve(address(staker), 100 ether);
        staker.lockLp(50 ether);
        vm.stopPrank();

        // lock lp as address(this) (id 2)
        credit.approve(address(dex), 100 ether);
        asset.approve(address(dex), 100 ether);
        dex.deposit(100 ether);
        dex.approve(address(staker), 100 ether);
        staker.lockLp(100 ether);

        // lock lp again as alice (id 3)
        vm.startPrank(alice, alice);
        staker.lockLp(50 ether);

        uint256[] memory aliceIds = staker.getUserActiveLockIds(alice);
        uint256[] memory matchIds = new uint256[](2);
        matchIds[0] = 1;
        matchIds[1] = 3;

        assertEq(aliceIds, matchIds);
    }

    function testMultipleGetActiveUserIdsAfterExpiry() public {
        // send staker asset to give as rewards
        asset.transfer(address(staker), 10 ether);

        credit.transfer(alice, 100 ether);
        asset.transfer(alice, 100 ether);

        vm.startPrank(alice, alice);

        credit.approve(address(dex), 100 ether);
        asset.approve(address(dex), 100 ether);
        dex.init(100 ether);

        dex.approve(address(staker), 100 ether);
        staker.lockLp(50 ether);
        staker.lockLp(50 ether);
        vm.warp(8 days);
        staker.redeemUnlockedLp(1);

        uint256[] memory aliceIds = staker.getUserActiveLockIds(alice);
        uint256[] memory matchIds = new uint256[](2);
        // claimed id array should now reutrn 0 for the claimed id
        matchIds[0] = 0;
        matchIds[1] = 2;

        assertEq(aliceIds, matchIds);
    }
}
