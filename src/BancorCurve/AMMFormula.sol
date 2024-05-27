pragma solidity ^0.8.25;

import { IBondingCurve } from "../interfaces/IBondingCurve.sol";

contract AMMFormula is IBondingCurve {
  function calculatePurchaseReturn(
    uint256 _inputAmount,
    uint256 _inputReserve,
    uint256 _outputReserve,
    bytes memory _extraData
  ) external view returns (uint256) {
    require(_inputReserve > 0 && _outputReserve > 0, "Reserves must be greater than 0");

    uint256 numerator = _inputAmount * _outputReserve;
    uint256 denominator = _inputReserve + _inputAmount;

    return numerator / denominator;
  }

  function calculateSaleReturn(
    uint256 _inputAmount,
    uint256 _inputReserve,
    uint256 _outputReserve,
    bytes memory _extraData
  ) external view returns (uint256) {
    require(_inputReserve > 0 && _outputReserve > 0, "Reserves must be greater than 0");

    uint256 numerator = _inputAmount * _outputReserve;
    uint256 denominator = _inputReserve + _inputAmount;

    return numerator / denominator;
  }
}
