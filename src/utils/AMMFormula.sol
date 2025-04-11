// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.25;

import { IBondingCurve } from "../interfaces/IBondingCurve.sol";

contract AMMFormula is IBondingCurve {
    function calculatePurchaseReturn(
        uint256 _inputAmount,
        uint256 _inputReserve,
        uint256 _outputReserve,
        bytes memory
    )
        external
        pure
        returns (uint256)
    {
        require(_inputReserve > 0 && _outputReserve > 0, "Reserves must be greater than 0");

        uint256 numerator = _inputAmount * _outputReserve;
        uint256 denominator = _inputReserve + _inputAmount;

        return numerator / denominator;
    }

    function calculateSaleReturn(
        uint256 _inputAmount,
        uint256 _inputReserve,
        uint256 _outputReserve,
        bytes memory
    )
        external
        pure
        returns (uint256)
    {
        require(_inputReserve > 0 && _outputReserve > 0, "Reserves must be greater than 0");

        uint256 numerator = _inputAmount * _outputReserve;
        uint256 denominator = _inputReserve + _inputAmount;

        return numerator / denominator;
    }

    function getOutputPrice(
        uint256 outputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    )
        public
        pure
        returns (uint256)
    {
        require(inputReserve > 0 && outputReserve > 0, "Reserves must be greater than 0");
        uint256 numerator = inputReserve * outputAmount;
        uint256 denominator = (outputReserve - outputAmount);
        return numerator / denominator + 1;
    }
}
