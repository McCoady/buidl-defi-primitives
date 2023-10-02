// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// hardhat
//import "@openzeppelin/contracts/access/AccessControl.sol";

// foundry
import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

interface IERC20 {
    function transfer(address, uint256) external returns (bool);

    function balanceOf(address) external view returns (uint256);
}

contract DisperseFunds is AccessControl {
    error InsufficientDai();
    error InsufficientSalt();

    address public saltAddr;
    bytes32 public constant DISPENSER_ROLE = keccak256("DISPENSER_ROLE");
    uint256 public constant SALT_FAUCET_AMOUNT = 25 ether;
    uint256 public constant DAI_FAUCET_AMOUNT = 0.02 ether;
    mapping(address => bool) addressClaimed;

    constructor(address _saltAddr) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        saltAddr = _saltAddr;
    }

    function transferOwnership(address newOwner) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!hasRole(DEFAULT_ADMIN_ROLE, newOwner), "Ownable: new owner already have admin role");

        grantRole(DEFAULT_ADMIN_ROLE, newOwner);
        renounceRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function disperseBatch(address[] calldata users) external onlyRole(DISPENSER_ROLE) {
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