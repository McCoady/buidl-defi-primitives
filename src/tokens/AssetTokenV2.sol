// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "lib/solmate/src/tokens/ERC20.sol";
import "lib/solmate/src/auth/Owned.sol";

contract AssetTokenV2 is ERC20, Owned{
    constructor(string memory _name, string memory _symbol, address _owner, uint256 _amountOfLiquidity) ERC20(_name, _symbol, 18) Owned(_owner) {
        _mint(_owner, 1000 ether);
        _mint(msg.sender, _amountOfLiquidity);
    }

    function airdropToWallet(address _wallet) external onlyOwner {
        _mint(_wallet, 100 ether);
    }

    function airdropToWallets(address[] calldata _wallets) external onlyOwner {
        uint256 walletsNo = _wallets.length;

        for(uint i; i < walletsNo; ++i) {
            _mint(_wallets[i], 100 ether);
        }
    }
}
