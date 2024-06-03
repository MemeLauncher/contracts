// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IJoeRouter02 {
  function factory() external pure returns (address);

  function WAVAX() external pure returns (address);

  function addLiquidityAVAX(
    address token,
    uint256 amountTokenDesired,
    uint256 amountTokenMin,
    uint256 amountAVAXMin,
    address to,
    uint256 deadline
  ) external payable returns (uint256 amountToken, uint256 amountAVAX, uint256 liquidity);
}
