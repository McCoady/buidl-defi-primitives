# Buidl Guidil Tradoor Contracts

This a set of contracts used to build the buidl guidl trade environment and includes stripped back versions of common defi concepts to help builders understand how they work and how they can be built.
View the current buidl guidl trading game repo [here](https://github.com/BuidlGuidl/event-wallet/tree/token-swap).

Contributions, including new contracts, code reviews, and further tests all welcome ❤️

## Contracts

### AssetToken & CreditToken

Both are basic ERC20 token implementations that allow the owner to airdrop new tokens to users.
Credit tokens are used as a defacto unit of account in the buidl game.
Asset tokens are the tokens that users trade credits for.

### BasicDex

BasicDex is an MVP exchange contract that allows ERC20-ERC20 trading pairs.
Users can provide liquidity and earn fees.
The contract also has slippage protection which, where minimum return amounts can be provided by the user.

### BasicDexV2

BasicDexV2 builds upon BasicDex but issues an ERC20 token to liquidity providers to track their share of the token pairs liquidity pool. 

### DisperseFunds

DisperseFunds is an airdropper contract that allows the gamesmaster to airdrop the chains gas token + CREDITs to players in the game.
The gamesmaster first sends some gas token + CREDITs to the contract and can then provide an array of addresses who will receive an amount of each.

### FruitBasket

FruitBasket is an on chain index fund contract which takes an amount of credits and uses it to buy the various fruit tokens.
Buyers are given an ERC20 which represents their share of the funds fruit tokens.
This token can be transferred, traded on DEXes or user can claim back their stake in the fruit basket fund.
Claiming involves burning the users FruitBasket tokens, selling their share of the funds fruit tokens and sending the user the CREDIT tokens their stake was worth.

### FruitBasketV2

As FruitBasket but now uses the ERC4626 vault standard for managing the contracts Credit tokens & the Shares ERC20 Token.


### FruitPrediction

FruitPrediction is a basic implementation of an onchain prediction market.
The user can bet whether a chosen token will be priced higher or lower 10 minutes from now.
The contract uses the tokens associated dex price to calculate it's changes in price.
If the users prediction is correct they have a further 10 minutes to claim their wager to return 2x their stake (minus a 5% fee)

### BasicBorrower

BasicBorrower is a stripped back implementation of a borrowing and lending contract.
Users can deposit liquidity which other users can then borrow from.
Users borrows must be overcollateralised (they must supply more liquidity than they borrow).
If users debt gets close to being unpayable by their remaining liquidity their borrow can be liquidated.
BasicBorrower's liquidity is managed using the ERC4626 vault standard.