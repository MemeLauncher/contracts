// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

interface IUniswapV3Pool {
  /// @notice Sets the initial price for the pool
  /// @dev Price is represented as a sqrt(amountToken1/amountToken0) Q64.96 value
  /// @param sqrtPriceX96 the initial sqrt price of the pool as a Q64.96
  function initialize(uint160 sqrtPriceX96) external;

  function tickSpacing() external returns(int24);
}
