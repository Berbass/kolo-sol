// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/Kolo.sol";

contract KOLOTest is Test {
    KOLO kolo;
    address owner = address(0xB0B);
    address alice = address(0xA11CE);
    address bob = address(0xB0B1);

    function setUp() public {
        // Deploy KOLO with `owner` as the contract deployer
        vm.prank(owner);
        kolo = new KOLO(address(0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42), owner);

        // Mock the external EURc balance check so `ensureEURcReserve` passes up to a finite limit.
        // Provide EURc equivalent for 5,000 KOL.
        uint256 eurcReserveKolo = 5000;
        uint256 eurcReserve = kolo.convertToEurc(eurcReserveKolo);

        vm.mockCall(
            kolo.eurcAddress(),
            abi.encodeWithSelector(bytes4(keccak256("balanceOf(address)")), owner),
            abi.encode(eurcReserve)
        );
    }

    function testDecimals() public {
        assertEq(kolo.decimals(), 6);
    }

    function testOwnerCanMint() public {
        uint256 amount = 1_000; // sample amount within the mocked reserve
        vm.prank(owner);
        kolo.mint(alice, amount);
        assertEq(kolo.balanceOf(alice), amount);
    }

    function testNonOwnerCannotMint() public {
        vm.expectRevert(bytes("KOLO: Only owner allowed"));
        vm.prank(alice);
        kolo.mint(alice, 1);
    }

    function testBurnWhenNotPaused() public {
        uint256 amount = 500;
        vm.prank(owner);
        kolo.mint(alice, amount);

        vm.prank(alice);
        kolo.burn(200);

        assertEq(kolo.balanceOf(alice), amount - 200);
    }

    function testBurnRevertsWhenPaused() public {
        uint256 amount = 300;
        vm.prank(owner);
        kolo.mint(alice, amount);

        vm.prank(owner);
        kolo.pause();

        vm.expectRevert(bytes("KOLO: Contract is paused"));
        vm.prank(alice);
        kolo.burn(100);
    }

    function testPauseUnpauseAccessControl() public {
        // Non-owner cannot pause
        vm.expectRevert(bytes("KOLO: Only owner allowed"));
        vm.prank(alice);
        kolo.pause();

        // Owner can pause and unpause
        vm.prank(owner);
        kolo.pause();
        assertTrue(kolo.paused());

        vm.prank(owner);
        kolo.unpause();
        assertFalse(kolo.paused());
    }

    function testTransfersBlockedWhenPaused() public {
        uint256 amount = 1_000;
        // Owner mints to owner and transfers to alice when not paused
        vm.prank(owner);
        kolo.mint(owner, amount);

        vm.prank(owner);
        kolo.transfer(alice, 100);
        assertEq(kolo.balanceOf(alice), 100);

        // Pause contract
        vm.prank(owner);
        kolo.pause();

        // Transfers should revert while paused
        vm.expectRevert(bytes("KOLO: Contract is paused"));
        vm.prank(owner);
        kolo.transfer(bob, 1);
    }

    function testConvertHelpers() public {
        // Using contract constants: EURC_PER_KOL = 1525, EUR_KOL_SCALE = 1000
        uint256 eurc = 1525;
        uint256 koloAmount = kolo.convertFromEurc(eurc);
        assertEq(koloAmount, 1000);

        uint256 eurcBack = kolo.convertToEurc(koloAmount);
        assertEq(eurcBack, 1525);

        // Additional check for non-trivial values (integer division)
        uint256 eurc2 = 7625; // 5 * 1525
        assertEq(kolo.convertFromEurc(eurc2), 5000); // 5 * 1000
    }

    function testMintRevertsWhenExceedEURcReserve() public {
        // The mocked EURc reserve supports up to 5000 KOL.
        uint256 amount = 5001; // exceeds mocked reserve
        vm.prank(owner);
        vm.expectRevert(bytes("KOLO: Insufficient EURc reserve"));
        kolo.mint(owner, amount);
    }
}
