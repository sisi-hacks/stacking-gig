// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Staking} from "src/Staking.sol";
import {DummyERC20} from "./mocks/DummyERC20.sol";

contract StakingTest is Test {
    Staking public staking;
    uint256 public amount;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       STAKING CONFIG                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    uint256 public duration;
    uint256 public rewardPoints;
    uint256 public stakingProgramEndsBlock;
    uint256 public stakingFundAmount;
    uint256 public rewardTokenAmount;
    uint256 public vestingDuration;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ASSETS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    DummyERC20 public rewardToken;
    DummyERC20 public poolToken;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ACTORS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    address public owner;
    address public recipient;
    address public recipient2;

    address stakingFund;

    modifier prank(address who) {
        vm.startPrank(who);
        _;
        vm.stopPrank();
    }

    function setUp() public {
        owner = makeAddr("owner");
        recipient = makeAddr("recipient");
        recipient2 = makeAddr("recipient2");

        vm.startPrank(owner);
        rewardToken = new DummyERC20("REWARD", "REWARD", 18);
        poolToken = new DummyERC20("POOL", "POOL", 18);

        stakingFundAmount = 1_000_000;
        stakingProgramEndsBlock = 7 days;
        vestingDuration = 7 days;

        stakingFund = makeAddr("stakingFund");

        poolToken.mint(stakingFund, stakingFundAmount);
        rewardToken.mint(stakingFund, stakingFundAmount);

        poolToken.mint(recipient, 1_000_000);

        rewardToken.approve(stakingFund, type(uint256).max);

        staking = new Staking(address(rewardToken), stakingProgramEndsBlock, stakingFundAmount, vestingDuration, owner);

        console.log("Staking contract deployed at", address(staking));

        vm.stopPrank();

        vm.prank(stakingFund);
        rewardToken.approve(address(staking), type(uint256).max);

        vm.prank(owner);
        staking.setPoolToken(address(poolToken), stakingFund);
    }

    function test_owner_address_is_set_correctly_during_contract_deployement() public {
        // Assert
        assertEq(staking.owner(), owner);
    }

    function test_lock_tokens_successfully_when_pool_is_set() public prank(recipient) {
        // Arrange
        uint72 tokenAmount = 1000;
        uint24 lockingPeriodInBlocks = 2;
        // Act
        poolToken.approve(address(staking), type(uint256).max);
        staking.lockTokens(tokenAmount, lockingPeriodInBlocks);
        // Assert

        // check on state afterwards.
        assertLt(poolToken.balanceOf(recipient), 1_000_000);
    }

    function test_lock_token_when_pool_is_set_with_zero_amount_fails() public prank(recipient) {
        // Arrange
        uint72 tokenAmount = 0;
        uint24 lockingPeriodInBlocks = 2;
        // Act
        poolToken.approve(address(staking), type(uint256).max);

        vm.expectRevert("Neither tokenAmount nor lockingPeriod couldn't be 0");
        staking.lockTokens(tokenAmount, lockingPeriodInBlocks);
    }

    function test_unlock_tokens_after_locking_period_ends() public prank(recipient) {
        // Arrange
        uint72 tokenAmount = 1000;
        uint24 lockingPeriodInBlocks = 2;

        poolToken.approve(address(staking), type(uint256).max);

        staking.lockTokens(tokenAmount, lockingPeriodInBlocks);

        // Act
        vm.roll(block.number + lockingPeriodInBlocks);
        staking.unlockTokens();
    }

    function test_unlock_tokens_before_locking_period_ends() public prank(recipient) {
        // Arrange
        uint72 tokenAmount = 1000;
        uint24 lockingPeriodInBlocks = 2;

        poolToken.approve(address(staking), type(uint256).max);

        staking.lockTokens(tokenAmount, lockingPeriodInBlocks);

        vm.expectRevert("You can't withdraw the stake in the same block it was locked");
        staking.unlockTokens();
    }

    function test_calculate_staking_reward_correctly() public {
        // Arrange
        uint72 tokenAmount = 100 ether;
        uint24 lockingPeriodinBlocks = 2;

        //Act
        uint128 expectedStakingRewardPoints = staking.calculateStakingRewardPoints(tokenAmount, lockingPeriodinBlocks);

        // Assert
        assertEq(expectedStakingRewardPoints, tokenAmount * lockingPeriodinBlocks * lockingPeriodinBlocks);
    }

    function test_get_rewards_after_staking_ends_with_no_stake_locked() public prank(recipient) {
        // Arrange
        vm.roll(1_000_000);
        staking.getRewards();
    }

    function test_get_rewards_after_staking_ends_with_no_reward_points() public prank(recipient) {
        // Arrange
        vm.roll(vestingDuration + stakingProgramEndsBlock);
        // Act
        vm.expectRevert("You don't have any rewardPoints");
        staking.getRewards();
    }

    function test_get_rewards_before_staking_ends_with_no_stake_locked() public prank(recipient) {
        // Arrange
        vm.expectRevert("You can only get Rewards after Staking Program ends");
        staking.getRewards();
    }

    function test_release_vested_tokens_after_vesting_duration_ends() public prank(recipient) {
        // Arrange
        uint72 tokenAmount = 1000;
        uint24 lockingPeriodInBlocks = 2;

        poolToken.approve(address(staking), type(uint256).max);
        staking.lockTokens(tokenAmount, lockingPeriodInBlocks);

        vm.roll(vestingDuration + stakingProgramEndsBlock);

        // Act
        staking.release();
        // Assert
    }

    function test_set_pool_token_again_fails() public prank(owner) {
        // Arrange
        vm.expectRevert("poolToken was already set");
        staking.setPoolToken(address(poolToken), stakingFund);
    }

    function test_early_withdrawal_punishment() public prank(recipient) {
        // Arrange
        uint72 tokenAmount = 1000;
        uint24 lockingPeriodInBlocks = 2;

        poolToken.approve(address(staking), type(uint256).max);
        staking.lockTokens(tokenAmount, lockingPeriodInBlocks);

        // Act
        staking.unlockTokens();
    }

    function test_attempts_to_lock_tokens_when_already_staking() public prank(recipient) {
        // Arrange
        uint72 tokenAmount = 1000;
        uint24 lockingPeriodInBlocks = 2;
        uint72 tokenAmount2 = 1000;
        // Act
        poolToken.approve(address(staking), type(uint256).max);
        staking.lockTokens(tokenAmount, lockingPeriodInBlocks);
        vm.expectRevert("Already staking");
        staking.lockTokens(tokenAmount2, lockingPeriodInBlocks);
    }

    function test_transfer_reward_success_during_release() public prank(recipient) {
        // Act
        staking.getRewards();
        staking.release();

        // Assert
        assertEq(rewardToken.balanceOf(recipient), 1000);
    }
}
