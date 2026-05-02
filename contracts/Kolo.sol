// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.24 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract KOLO is ERC20, ERC20Permit, Ownable, Pausable {

    uint256 private constant EURC_PER_KOL = 1525;
    uint256 private constant EUR_KOL_SCALE = 1000;

    address public immutable eurcAddress; // 0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42 maybe? (Mainnet EURc address)
    address public reserveVault;

    // --- CUSTOM ERRORS ---

    error Unauthorized();
    error ContractPaused();
    error InsufficientReserve(uint256 required, uint256 available);
    error InvalidVaultAddress();

    constructor(address _eurcAddress, address initialOwner)
        ERC20("KOLO", "KLO")
        ERC20Permit("KOLO")
        Ownable(initialOwner)
    {
        eurcAddress = _eurcAddress;
        reserveVault = initialOwner; // Reserve managed by the owner initially, can be migrated to a Multisig or Yield Contract later via setReserveVault()
    }

    // --- MODIFIERS ---

    modifier onlyOwnerWithCustomError() {
        if (msg.sender != owner()) revert Unauthorized();
        _;
    }

    modifier whenNotPausedWithCustomError() {
        if (paused()) revert ContractPaused();
        _;
    }

    modifier ensureEURcReserve(uint256 koloAmount) {
        uint256 requiredEurc = convertToEurc(koloAmount + totalSupply());
        uint256 availableEurc = IERC20(eurcAddress).balanceOf(reserveVault);
        if (availableEurc < requiredEurc) {
            revert InsufficientReserve(requiredEurc, availableEurc);
        }
        _;
    }

    // --- CORE FUNCTIONS ---

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) public onlyOwnerWithCustomError ensureEURcReserve(amount) {
        _mint(to, amount);
    }

    function burn(uint256 amount) public whenNotPausedWithCustomError {
        _burn(msg.sender, amount);
    }

    // Enabling burnFrom with allowance checks for Relayers or approved spenders
    function burnFrom(address account, uint256 amount) public whenNotPausedWithCustomError {
        _spendAllowance(account, msg.sender, amount);
        _burn(account, amount);
    }

    // Relayer-friendly transfer with permit, allowing users to approve and transfer in a single transaction
    function transferWithPermit(
        address owner,
        address to,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external whenNotPausedWithCustomError {
        permit(owner, msg.sender, value, deadline, v, r, s);
        transferFrom(owner, to, value);
    }

    // --- ADMIN FUNCTIONS ---

    function setReserveVault(address _vault) external onlyOwnerWithCustomError {
        if (_vault == address(0)) revert InvalidVaultAddress();
        reserveVault = _vault;
    }

    function pause() public onlyOwnerWithCustomError {
        _pause();
    }

    function unpause() public onlyOwnerWithCustomError {
        _unpause();
    }

    function _update(address from, address to, uint256 value)
        internal
        virtual
        override(ERC20)
        whenNotPausedWithCustomError
    {
        super._update(from, to, value);
    }

    // --- UTILS ---

    function convertFromEurc(uint256 eurcAmount) public pure returns (uint256) {
        return (eurcAmount * EUR_KOL_SCALE) / EURC_PER_KOL;
    }

    function convertToEurc(uint256 koloAmount) public pure returns (uint256) {
        return (koloAmount * EURC_PER_KOL) / EUR_KOL_SCALE;
    }
}
