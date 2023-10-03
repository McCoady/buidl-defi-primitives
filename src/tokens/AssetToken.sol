// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "lib/solmate/src/tokens/ERC20.sol";
import "lib/solmate/src/auth/Owned.sol";

contract AssetToken is ERC20, Owned{
    /* ========== CONSTRUCTOR ========== */
    constructor(string memory _name, string memory _symbol, address _owner) ERC20(_name, _symbol, 18) Owned(_owner) {
        _mint(msg.sender, 1000 ether);
    }

    /* ========== FUNCTIONS ========== */

    /// @notice allows contract owner to airdrop 100 tokens to an address
    /// @param _wallet address to send tokens to
    function airdropToWallet(address _wallet) external onlyOwner {
        _mint(_wallet, 100 ether);
    }

    /// @notice allows contract owner to airdrop 100 tokens to an array of addresses
    /// @param _wallets addresses to send tokens to
    function airdropToWallets(address[] calldata _wallets) external onlyOwner {
        uint256 walletsNo = _wallets.length;

        for(uint i; i < walletsNo; ++i) {
            _mint(_wallets[i], 100 ether);
        }
    }
}
