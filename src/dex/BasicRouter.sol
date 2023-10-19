// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

interface IBasicDex {
    function assetToCredit(uint256, uint256) external returns (uint256);

    function creditToAsset(uint256, uint256) external returns (uint256);

    function assetInPrice(uint256) external returns (uint256);

    function creditInPrice(uint256) external returns (uint256);
}

interface IERC20 {
    function approve(address, uint256) external returns (bool);

    function transfer(address, uint256) external returns (bool);

    function transferFrom(address, address, uint256) external returns (bool);
}

contract BasicRouter is AccessControl {
    address public creditToken;

    mapping(address => bool) public assetValid;
    mapping(address => address) public assetToDex;

    error InvalidAsset();
    error TokenTransferError();

    constructor(address _creditToken) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        creditToken = _creditToken;
    }

    function assetToAsset(
        address assetInAddr,
        uint256 assetInAmount,
        address assetOutAddr,
        uint256 minAssetOutAmount
    ) external returns (uint256) {
        if (!assetValid[assetInAddr] || !assetValid[assetOutAddr])
            revert InvalidAsset();

        address dexIn = assetToDex[assetInAddr];
        address dexOut = assetToDex[assetOutAddr];

        bool received = IERC20(assetInAddr).transferFrom(
            msg.sender,
            address(this),
            assetInAmount
        );
        if (!received) revert TokenTransferError();

        uint256 creditOut = IBasicDex(dexIn).assetToCredit(assetInAmount, 0);
        uint256 assetOut = IBasicDex(dexOut).creditToAsset(creditOut, minAssetOutAmount);

        bool sent = IERC20(assetOutAddr).transfer(msg.sender, assetOut);
        require(sent);
        return assetOut;
    }

    function getAssetsOut(
        address assetInAddr,
        address assetOutAddr,
        uint256 assetInAmount
    ) external returns (uint256) {
        if (!assetValid[assetInAddr] || !assetValid[assetOutAddr])
            revert InvalidAsset();

        address dexIn = assetToDex[assetInAddr];
        address dexOut = assetToDex[assetOutAddr];

        uint256 creditOut = IBasicDex(dexIn).assetInPrice(assetInAmount);
        return IBasicDex(dexOut).creditInPrice(creditOut);
    }

    function addValidAsset(
        address assetToken,
        address assetDex
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        assetValid[assetToken] = true;
        // only allows one dex per asset token
        assetToDex[assetToken] = assetDex;

        IERC20(assetToken).approve(assetDex, type(uint256).max);
        IERC20(creditToken).approve(assetDex, type(uint256).max);
    }

    function removeValidAsset(
        address assetToken
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        assetValid[assetToken] = false;
        assetToDex[assetToken] = address(0);
    }
}
