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
        vm.expectRevert(KOLO.Unauthorized.selector);
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

        vm.expectRevert(KOLO.ContractPaused.selector);
        vm.prank(alice);
        kolo.burn(100);
    }

    function testPauseUnpauseAccessControl() public {
        // Non-owner cannot pause
        vm.expectRevert(KOLO.Unauthorized.selector);
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
        vm.expectRevert(KOLO.ContractPaused.selector);
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

        uint256 requiredEurc = kolo.convertToEurc(amount + kolo.totalSupply());
        uint256 availableEurc = 5000 * 1525 / 1000; // Mocked amount above

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(KOLO.InsufficientReserve.selector, requiredEurc, availableEurc));
        kolo.mint(owner, amount);
    }

    function testSetReserveVaultAccessAndLogic() public {
        vm.expectRevert(KOLO.Unauthorized.selector);
        vm.prank(alice);
        kolo.setReserveVault(bob);

        vm.expectRevert(KOLO.InvalidVaultAddress.selector);
        vm.prank(owner);
        kolo.setReserveVault(address(0));

        vm.prank(owner);
        kolo.setReserveVault(bob);
        assertEq(kolo.reserveVault(), bob);
    }

    function testMintCorrectlyAccountsForNewReserveVaultBalance() public {
        vm.prank(owner);
        kolo.setReserveVault(bob);

        // bob initially has 0 EURc in our mock (since we only mocked `owner`)
        vm.mockCall(
            kolo.eurcAddress(),
            abi.encodeWithSelector(bytes4(keccak256("balanceOf(address)")), bob),
            abi.encode(0)
        );

        uint256 req1 = kolo.convertToEurc(1000);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(KOLO.InsufficientReserve.selector, req1, 0));
        kolo.mint(alice, 1000);

        // Provide EURc equivalent for 2000 KOL to bob
        uint256 newReserve = kolo.convertToEurc(2000);
        vm.mockCall(
            kolo.eurcAddress(),
            abi.encodeWithSelector(bytes4(keccak256("balanceOf(address)")), bob),
            abi.encode(newReserve)
        );

        // Mint should succeed
        vm.prank(owner);
        kolo.mint(alice, 2000);
        assertEq(kolo.balanceOf(alice), 2000);

        // Exceeding the reserve should fail
        uint256 req2 = kolo.convertToEurc(2001);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(KOLO.InsufficientReserve.selector, req2, newReserve));
        kolo.mint(alice, 1);
    }

    function testBurnFromFunctionality() public {
        uint256 amount = 500;
        vm.prank(owner);
        kolo.mint(alice, amount);

        vm.prank(alice);
        kolo.approve(bob, 200);

        vm.prank(bob);
        kolo.burnFrom(alice, 150);

        assertEq(kolo.balanceOf(alice), amount - 150);
        assertEq(kolo.allowance(alice, bob), 50);

        // paused
        vm.prank(owner);
        kolo.pause();

        vm.expectRevert(KOLO.ContractPaused.selector);
        vm.prank(bob);
        kolo.burnFrom(alice, 50);
    }

    function testTransferWithPermitExecutesWithValidSignature() public {
        uint256 amount = 1000;
        vm.prank(owner);
        kolo.mint(alice, amount);

        // let's create a real wallet
        (address signer, uint256 pk) = makeAddrAndKey("signer");

        vm.prank(owner);
        kolo.mint(signer, amount);

        uint256 value = 200;
        uint256 deadline = block.timestamp + 1000;
        uint256 nonce = kolo.nonces(signer);

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                signer,
                bob,
                value,
                nonce,
                deadline
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", kolo.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);

        vm.prank(bob);
        kolo.transferWithPermit(signer, bob, value, deadline, v, r, s);

        assertEq(kolo.balanceOf(bob), value);
        assertEq(kolo.balanceOf(signer), amount - value);
    }
}
