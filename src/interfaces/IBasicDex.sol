// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
interface IBasicDex{
    // price getter functions
    function creditIn(uint256 creditIn) external view returns(uint256 assetout);
    function assetIn(uint256 assetIn) external view returns(uint256 creditout);
    function creditOut(uint256 creditOut) external view returns(uint256 assetIn);
    function assetOut(uint256 assetOut) external view returns(uint256 creditIn);

    // trade functions   
    function creditToAsset(uint256 creditIn, uint256 minTokensBack) external returns(uint256 tokenOutput);
    function assetToCredit(uint256 assetIn, uint256 minTokensBack) external returns(uint256 tokenOutput);
}