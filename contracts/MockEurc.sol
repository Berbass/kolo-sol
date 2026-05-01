// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockEURc is ERC20 {
    constructor(uint256 supply) ERC20("Euro Coin", "EURc") {
        _mint(msg.sender, supply);
    }

    // EURc specifically uses 6 decimals
    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}
