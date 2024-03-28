// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract Degen is ERC20, ERC20Permit {
    constructor() ERC20("Degen", "DEGEN") ERC20Permit("Degen") {
        _mint(msg.sender, 42000008453 * 10 ** decimals());
    }
}
