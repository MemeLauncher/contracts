\*\* BondingERC20TokenFactory

The `BondingERC20TokenFactory` contract is a factory contract responsible for deploying instances of
`ContinuosBondingERC20Token`. It includes functionality to manage and update critical parameters related to bonding
curves, treasury, initial parameters for bonding curves, and buy/sell fees. The contract is owned and can only be
modified by the owner.

\*\* ContinuosBondingERC20Token

The `ContinuosBondingERC20Token` contract is an ERC-20 token with a bonding curve mechanism for buying and selling
tokens directly with Native tokens. It integrates with the JoeRouter for creating the pool and includes various
safeguards to ensure proper functionality and security. The contract manages fees, a treasury balance, and enforces
conditions to achieve a liquidity goal before allowing transfers between holders.

The contract is expected to have following functionalities/properties:

- Users can buy token with Native token until liquidity goal is reached. The amount is decided by bonding curve.
- Users can sell token to get Native token until liquidity goal is reached. The amount is decided by bonding curve.
- Fee is incured to treasury during buy/sell.
- Liquidity goal is considered to be reached once decided amount of token is bought.
- The traderjoe pair is created once token reaches liquidity goal. The native tokens received from the buyers and fixed
  supply of token is used to ignite liquidity.
- Buying/selling with contract shouldn't happen after liquidity goal is reached.
