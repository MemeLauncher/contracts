// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import { BondingERC20TokenFactory } from "../src/BondingERC20TokenFactory.sol";
import { AMMFormula } from "../src/utils/AMMFormula.sol";
import { IBondingCurve } from "../src/interfaces/IBondingCurve.sol";

import { Script } from "forge-std/src/Script.sol";

import "forge-std/src/console.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract Deploy is Script  {
  address constant WETH = 0xC009a670E2B02e21E7e75AE98e254F467f7ae257; // CHANGE THIS
  address constant UNISWAP_V3_FACTORY = 0x62B672E531f8c11391019F6fba0b8B6143504169; // CHANGE THIS
  address constant NON_FUNGIBLE_POSITION_MANAGER = 0xC967b23826DdAB00d9AAd3702CbF5261B7Ed9a3a; // CHANGE THIS

  function run() public returns (BondingERC20TokenFactory tokenFactory) {
    vm.startBroadcast();
    IBondingCurve _bondingCurve = new AMMFormula();
    tokenFactory = new BondingERC20TokenFactory(
      0x4dAb467dB2480422566cD57eae9624c6c273220E,
      _bondingCurve,
      0x4dAb467dB2480422566cD57eae9624c6c273220E,
      0.125 ether,
      800_000_000 ether,
      100,
      100,
      0.01 ether, //// creation fee
      UNISWAP_V3_FACTORY,
      NON_FUNGIBLE_POSITION_MANAGER,
      WETH
    );
    address token = tokenFactory.deployBondingERC20TokenAndPurchase{value: 0.01 ether}("TestApe", "TestApe");
    console.log("factory is deployed at", address(tokenFactory));
    console.log("token is deployed at", token);
  }
}
