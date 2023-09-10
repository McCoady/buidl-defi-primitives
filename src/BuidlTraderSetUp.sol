// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IERC20 {
    function transfer(address, uint256) external returns(bool);
}
contract BuidlTraderSetUp {
    error AddressClaimed();

    address public salt;

    mapping(address => bool) addressClaimed;

    function claim(address _to) external {
        if (addressClaimed[to]) revert AddressClaimed();

        payable(_to).call{value: 0.01 ether}("");
        IERC20(salt).transfer(_to, 25 ether);

        addressClaimed[_to] = true;
    }

    function receive() external payable {}
}