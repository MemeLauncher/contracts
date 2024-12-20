// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IBondingCurve } from "./IBondingCurve.sol";

interface IContinuousBondingERC20Token  {
  function bondingCurve() external returns (IBondingCurve);

  function TREASURY_ADDRESS() external returns (address);

  function availableTokenBalance() external returns (uint256);

  function initialTokenBalance() external returns (uint256);

  function totalEthContributed() external returns (uint256);

  function isLpCreated() external returns (bool);

  function buyTokens(uint256 minExpectedAmount, address recipient) external payable returns (uint256);

}
