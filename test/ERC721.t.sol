// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/tokens/ERC721.sol";

abstract contract BaseSetup is Test {
    ERC721 public token;
    address public dummy = address(0xdeadbeef);

    function setUp() public virtual {
        token = new ERC721(
            "DUM",
            "DUM",
            "https://example.com/asdfasdfasdfasdfasdfasdfasdfa/"
        );
    }
}

abstract contract MintedState is BaseSetup {
    function setUp() public override {
        super.setUp();
        token._mint(address(this), 0);
    }
}

contract TestBasics is BaseSetup {
    function testMETADATA() public {
        assertEq(
            token.tokenURI(0),
            "https://example.com/asdfasdfasdfasdfasdfasdfasdfa/0"
        );
        assertEq(token.name(), "DUM");
        assertEq(token.symbol(), "DUM");
    }

    function testMINT() public {
        token._mint(address(this), 0);
        assertEq(token.ownerOf(0), address(this));
        assertEq(token.balanceOf(address(this)), 1);
    }

    function testBURN() public {
        token._mint(address(this), 1);
        token._burn(1);
        assertEq(token.balanceOf(address(this)), 0);
    }
}

contract TestApprovals is MintedState {
    function testAPPROVE() public {
        token.approve(address(this), 0);
        assertEq(token.getApproved(0), address(this));
    }

    function testCLEARAPPROVAL() public {
        token.approve(address(this), 0);
        token.approve(address(0), 0);
        assertEq(token.getApproved(0), address(0));
    }

    function testSETAPPROVALFORALL() public {
        token.setApprovalForAll(dummy, true);
        assertEq(token.isApprovedForAll(address(this), dummy), true);
    }

    function testCLEARAPPROVALFORALL() public {
        token.setApprovalForAll(address(this), true);
        token.setApprovalForAll(address(this), false);
        assertEq(token.isApprovedForAll(address(this), address(this)), false);
    }
}

contract TestTransfer is MintedState {
    function testTRANSFER() public {
        token.transferFrom(address(this), dummy, 0);
        assertEq(token.ownerOf(0), dummy);
    }

    function testSAFETRANSFER() public {
        token.safeTransferFrom(address(this), dummy, 0);
        assertEq(token.ownerOf(0), dummy);
    }

    function testSAFETRANSFERFROM() public {
        token.safeTransferFrom(address(this), dummy, 0, "");
        assertEq(token.ownerOf(0), dummy);
    }
}
