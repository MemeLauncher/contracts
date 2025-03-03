factory is deployed at 0x0A4Acec0070E0833bBCc60319a93B4844cE9B7D1 token is deployed at
0x922030b8aE417ECb55c5253f929555F259d33Ab9

// verify token forge verify-contract --rpc-url https://curtis.rpc.caldera.xyz/http
0x922030b8aE417ECb55c5253f929555F259d33Ab9 src/ContinuosBondingERC20Token.sol:ContinuosBondingERC20Token --verifier
blockscout --verifier-url https://curtis.explorer.caldera.xyz/api/

// verify factory forge verify-contract --rpc-url https://curtis.rpc.caldera.xyz/http
0x0A4Acec0070E0833bBCc60319a93B4844cE9B7D1 src/BondingERC20TokenFactory.sol:BondingERC20TokenFactory --verifier
blockscout --verifier-url https://curtis.explorer.caldera.xyz/api/
