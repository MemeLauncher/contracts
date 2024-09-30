// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import { BondingERC20TokenFactory } from "../src/BondingERC20TokenFactory.sol";
import { AMMFormula } from "../src/utils/AMMFormula.sol";
import { IBondingCurve } from "../src/interfaces/IBondingCurve.sol";

import { BaseScript } from "./Base.s.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract Deploy is BaseScript {
  address constant WETH = 0x4dAb467dB2480422566cD57eae9624c6c273220E; // CHANGE THIS
  address constant UNISWAP_V3_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984; // CHANGE THIS
  address constant NON_FUNGIBLE_POSITION_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88; // CHANGE THIS

  function run() public broadcast returns (BondingERC20TokenFactory tokenFactory) {
    IBondingCurve _bondingCurve = new AMMFormula();
    tokenFactory = new BondingERC20TokenFactory(
      0x4dAb467dB2480422566cD57eae9624c6c273220E,
      _bondingCurve,
      0x4dAb467dB2480422566cD57eae9624c6c273220E,
      50 ether,
      800_000_000 ether,
      100,
      100,
      UNISWAP_V3_FACTORY,
      NON_FUNGIBLE_POSITION_MANAGER,
      WETH
    );
  }
}
