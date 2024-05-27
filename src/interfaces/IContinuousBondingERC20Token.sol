// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IContinuousBondingERC20Token {
  function bondingCurve() external returns (address);
  function TREASURY_ADDRESS() external returns (address);
  function availableTokenBalance() external returns (uint256);
  function initialTokenBalance() external returns (uint256);
  function totalEthContributed() external returns (uint256);
  function isLpCreated() external returns (bool);
}
