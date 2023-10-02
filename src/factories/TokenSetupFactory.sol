// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {AssetTokenV2} from "../tokens/AssetTokenV2.sol";
import {BasicDex} from "../dex/BasicDex.sol";
import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

interface CreditToken {
    function transferFrom(address, address, uint256) external returns(bool);
    function approve(address, uint256) external returns(bool);
}

contract TokenSetupFactory is AccessControl {
    struct TokenInfo {
        address tokenAddress;
        address dexAddress;
    }

    error InvalidIndex();

    address public creditToken;
    
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
    TokenInfo[] public deployedTokens;
    uint256 public tokensDeployed;
    mapping(address => address) public getDexFromToken;

    constructor(address _creditToken) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CREATOR_ROLE, msg.sender);
        creditToken = _creditToken;
    }

    function setupNewTokenDexCombo(string calldata name, string calldata symbol, address owner, uint256 dexLiquidity) external onlyRole(CREATOR_ROLE) {
        AssetTokenV2 newToken = new AssetTokenV2(name, symbol, owner, dexLiquidity);
        BasicDex newDex = new BasicDex(creditToken, address(newToken));
        CreditToken(creditToken).transferFrom(msg.sender, address(this), dexLiquidity);
        CreditToken(creditToken).approve(address(newDex), dexLiquidity);
        newToken.approve(address(newDex), dexLiquidity);
        newDex.init(dexLiquidity);
        
        ++tokensDeployed;
        deployedTokens.push(TokenInfo(address(newToken), address(newDex)));
        getDexFromToken[address(newToken)] = address(newDex);
    }

    function getTokenInfoByIndex(uint256 index) external view returns(TokenInfo memory) {
        if (index >= deployedTokens.length) revert InvalidIndex();
        return deployedTokens[index];
    }
}
