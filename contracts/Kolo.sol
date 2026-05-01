// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.24 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol"; // Added for Gasless (EIP-2612)
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // Interface to check EURc balance

contract KOLO is ERC20, ERC20Permit, Ownable, Pausable {

    uint256 private constant EURC_PER_KOL = 1525;
    uint256 private constant EUR_KOL_SCALE = 1000;

    address public immutable eurcAddress; // 0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42 maybe? (Mainnet EURc address)

    // Events for tracking
    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);

    constructor(address _eurcAddress, address initialOwner)
        ERC20("KOLO", "KLO")
        ERC20Permit("KOLO") // Initialize Permit with Token Name
        Ownable(initialOwner)
    {
        eurcAddress = _eurcAddress;
    }

    // --- MODIFIERS ---

    modifier onlyOwnerWithCustomError() {
        require(msg.sender == owner(), "KOLO: Only owner allowed");
        _;
    }

    modifier whenNotPausedWithCustomError() {
        require(!paused(), "KOLO: Contract is paused");
        _;
    }

    modifier ensureEURcReserve(uint256 koloAmount) {
        uint256 requiredEurc = convertToEurc(koloAmount + totalSupply());
        // We check the owner's balance as the reserve vault for the MVP
        require(
            IERC20(eurcAddress).balanceOf(owner()) >= requiredEurc,
            "KOLO: Insufficient EURc reserve"
        );
        _;
    }

    // --- CORE FUNCTIONS ---

    // Overriding decimals to match EURc (usually 6 decimals)
    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    // Minting logic with reserve check
    function mint(address to, uint256 amount) public onlyOwnerWithCustomError ensureEURcReserve(amount) {
        _mint(to, amount);
        emit Minted(to, amount);
    }

    function burn(uint256 amount) public whenNotPausedWithCustomError {
        _burn(msg.sender, amount);
        emit Burned(msg.sender, amount);
    }

    // --- ADMIN FUNCTIONS ---

    function pause() public onlyOwnerWithCustomError {
        _pause();
    }

    function unpause() public onlyOwnerWithCustomError {
        _unpause();
    }

    // Hook to prevent transfers when paused
    // This function is required by OpenZeppelin hooks
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
