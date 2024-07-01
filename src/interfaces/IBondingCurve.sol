// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IBondingCurve {
    function calculatePurchaseReturn(
        uint256 _inputAmount,
        uint256 _inputReserve,
        uint256 _outputReserve,
        bytes memory _extraData
    )
        external
        view
        returns (uint256);

    function calculateSaleReturn(
        uint256 _outputAmount,
        uint256 _inputReserve,
        uint256 _outputReserve,
        bytes memory _extraData
    )
        external
        view
        returns (uint256);

    function getOutputPrice(
        uint256 outputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    )
        external
        pure
        returns (uint256);
}
