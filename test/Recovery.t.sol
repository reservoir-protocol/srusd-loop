// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ReservoirLooper} from "../src/ReservoirLooper.sol";

// openzeppelin
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock ERC20", "MRC") {}
}

contract RecoveryTest is Test {
    ReservoirLooper public looper;
    ERC20 public testToken;

    function setUp() external {
        looper = new ReservoirLooper();
        testToken = new MockERC20();
    }

    function testFuzz_recover(uint256 _amount, address _to) external {
        vm.assume(_to != address(looper) && _to != address(0));

        deal(address(testToken), address(looper), _amount);

        assertEq(testToken.balanceOf(_to), 0);
        assertEq(testToken.balanceOf(address(looper)), _amount);

        looper.recover(testToken, _to);

        assertEq(testToken.balanceOf(_to), _amount);
        assertEq(testToken.balanceOf(address(looper)), 0);
    }

    function testFuzz_recover_amount(
        uint256 _lockedAmount,
        address _to,
        uint256 _recoveredAmount
    ) external {
        vm.assume(_to != address(looper) && _to != address(0));
        vm.assume(_recoveredAmount <= _lockedAmount);

        deal(address(testToken), address(looper), _lockedAmount);

        assertEq(testToken.balanceOf(_to), 0);
        assertEq(testToken.balanceOf(address(looper)), _lockedAmount);

        looper.recover(testToken, _to, _recoveredAmount);

        assertEq(testToken.balanceOf(_to), _recoveredAmount);
        assertEq(
            testToken.balanceOf(address(looper)),
            _lockedAmount - _recoveredAmount
        );
    }

    function testFuzz_approve(uint256 _amount, address _to) external {
        vm.assume(_to != address(0) && _to != address(looper));

        assertEq(testToken.allowance(address(looper), _to), 0);

        looper.approve(testToken, _to, _amount);

        assertEq(testToken.allowance(address(looper), _to), _amount);
    }

    function testFuzz_recover_eth(
        uint256 _lockedAmount,
        uint256 _recoveredAmount
    ) external {
        vm.assume(_lockedAmount < 1_000_000_000_000_000e18);
        vm.assume(_recoveredAmount <= _lockedAmount);

        deal(address(looper), _lockedAmount);

        assertEq(address(looper).balance, _lockedAmount);

        uint256 balanceBefore = address(this).balance;

        looper.recoverETH(payable(this), _recoveredAmount);

        assertEq(address(looper).balance, _lockedAmount - _recoveredAmount);

        assertEq(address(this).balance, balanceBefore + _recoveredAmount);
    }

    function testFuzz_recover_unauthorized(address user) external {
        vm.assume(user != address(this));

        vm.prank(user);
        vm.expectRevert();
        looper.recover(testToken, user);
    }

    function testFuzz_recover_amount_unauthorized(address user) external {
        vm.assume(user != address(this));

        vm.prank(user);
        vm.expectRevert();
        looper.recover(testToken, user, 1);
    }

    function testFuzz_approve_unauthorized(address user) external {
        vm.assume(user != address(this));

        vm.prank(user);
        vm.expectRevert();
        looper.approve(testToken, user, 1);
    }

    function test_recover_eth_unauthorized(address user) external {
        vm.assume(user != address(this));

        vm.prank(user);
        vm.expectRevert();
        looper.recoverETH(payable(this), 1);
    }

    receive() external payable {}
}
