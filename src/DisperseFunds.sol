// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// hardhat 
//import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
// foundry
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

interface IERC20 {
    function transfer(address, uint256) external returns (bool);

    function balanceOf(address) external view returns (uint256);
}

contract DisperseFunds is Ownable {
    error InsufficientDai();
    error InsufficientSalt();

    address public saltAddr;
    uint256 public constant SALT_FAUCET_AMOUNT = 25 ether;
    uint256 public constant DAI_FAUCET_AMOUNT = 0.02 ether;
    mapping(address => bool) addressClaimed;

    constructor(address _saltAddr) {
        saltAddr = _saltAddr;
    }

    function disperseBatch(address[] calldata users) external onlyOwner {
        uint256 userLen = users.length;
        if (address(this).balance < userLen * DAI_FAUCET_AMOUNT)
            revert InsufficientDai();
        if (
            IERC20(saltAddr).balanceOf(address(this)) <
            userLen * SALT_FAUCET_AMOUNT
        ) revert InsufficientSalt();
        
        for (uint256 i; i < userLen; i++) {
            address user = users[i];
            // check address hasn't claimed
            if (!addressClaimed[user]) {
                addressClaimed[user] = true;
                // send xDAI & SALT
                payable(user).call{value: DAI_FAUCET_AMOUNT}("");
                IERC20(saltAddr).transfer(user, SALT_FAUCET_AMOUNT);
            }
        }
    }

    receive() external payable {}
}
