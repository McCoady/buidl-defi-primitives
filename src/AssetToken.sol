// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "lib/solmate/src/tokens/ERC20.sol";
import "lib/solmate/src/auth/Owned.sol";

contract AssetToken is ERC20 {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol, 18) {
        _mint(msg.sender, 1000 ether);
    }
}