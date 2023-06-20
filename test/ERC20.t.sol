// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/tokens/ERC20.sol";

contract ERC20BaseSetup is Test {
    ERC20 public token;

    address dummy = vm.addr(1);
    address dummy2 = vm.addr(2);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() public virtual {
        token = new ERC20("DUM", "DUM", 18);
    }
}

contract ERC20Test is ERC20BaseSetup {
    function testMint() public {
        vm.expectEmit();
        emit Transfer(address(0), address(this), 100);
        token.mint(address(this), 100);
        assertEq(token.balanceOf(address(this)), 100);
        assertEq(token.totalSupply(), 100);
    }

    function testApprove() public {
        token.approve(address(this), 100);
        assertEq(token.allowance(address(this), address(this)), 100);
        assertEq(token.allowance(address(this), dummy), 0);
    }
}

contract MintedState is ERC20BaseSetup {
    function setUp() public override {
        super.setUp();
        token.mint(address(this), 100);
    }

    function testTransfer() public {
        token.transfer(dummy, 100);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(dummy), 100);
    }

    function testTransferFrom() public {
        token.approve(dummy2, 100);

        vm.expectEmit();
        emit Transfer(address(this), dummy, 100);
        vm.startPrank(dummy2);
        token.transferFrom(address(this), dummy, 100);
        vm.stopPrank();

        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(dummy), 100);
    }
}
