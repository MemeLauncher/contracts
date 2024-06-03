// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;
pragma experimental ABIEncoderV2;

interface IFactory {
  function getPair(address token0, address token1) external view returns (address);
}
