// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IBondingCurve {
  function calculatePurchaseReturn(
    uint256 _supply,
    uint256 _connectorBalance,
    uint32 _connectorWeight,
    uint256 _depositAmount,
    bytes memory _extraData
  ) external view returns (uint256);

  function calculateSaleReturn(
    uint256 _supply,
    uint256 _connectorBalance,
    uint32 _connectorWeight,
    uint256 _sellAmount,
    bytes memory _extraData
  ) external view returns (uint256);
}
