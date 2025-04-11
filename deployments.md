factory is deployed at 0xA136749da067fA50e70d2d1Aa48c25FC38D7c92F token is deployed at
0xA0F1A52A42E310AaBCc49369dc62f4289693468A

// verify token forge verify-contract --rpc-url https://curtis.rpc.caldera.xyz/http
0xA0F1A52A42E310AaBCc49369dc62f4289693468A src/ContinuosBondingERC20Token.sol:ContinuosBondingERC20Token --verifier
blockscout --verifier-url https://curtis.explorer.caldera.xyz/api/

// verify factory forge verify-contract --rpc-url https://curtis.rpc.caldera.xyz/http
0xA136749da067fA50e70d2d1Aa48c25FC38D7c92F src/BondingERC20TokenFactory.sol:BondingERC20TokenFactory --verifier
blockscout --verifier-url https://curtis.explorer.caldera.xyz/api/
