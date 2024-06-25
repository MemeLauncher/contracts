// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IUniswapV2Router02 {
  function factory() external pure returns (address);
  function WETH() external pure returns (address);

  function addLiquidityETH(
    address token,
    uint amountTokenDesired,
    uint amountTokenMin,
    uint amountETHMin,
    address to,
    uint deadline
  ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}
