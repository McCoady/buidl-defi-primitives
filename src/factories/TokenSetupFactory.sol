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
    /* ========== TYPES ========== */
    struct TokenInfo {
        address tokenAddress;
        address dexAddress;
    }

    /* ========== STATE VARS ========== */
    address public creditToken;    
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
    
    TokenInfo[] public deployedTokens;
    uint256 public tokensDeployed;
    mapping(address => address) public getDexFromToken;

    /* ========== CUSTOM ERRORS ========== */
    error InvalidIndex();

    /* ========== CONSTRUCTOR ========== */
    constructor(address _creditToken) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CREATOR_ROLE, msg.sender);
        creditToken = _creditToken;
    }

    /* ========== FUNCTIONS ========== */

    /// @notice allows addresses with CREATOR_ROLE to create a new token, token/credit dex pair and initialise that dex with liquidity
    /// @param name token name
    /// @param symbol token symbol
    /// @param owner owner of the new token contract
    /// @param dexLiquidity amount of liquidity to init the dex with
    /// @dev caller must own at least dexLiquidity amount of credit tokens to initialize the dex with that amount
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

    /// @notice allows the retreival of deployed token information by index
    /// @param index the index to return
    /// @return deployed token information of that index 
    function getTokenInfoByIndex(uint256 index) external view returns(TokenInfo memory) {
        if (index >= tokensDeployed) revert InvalidIndex();
        return deployedTokens[index];
    }
}
