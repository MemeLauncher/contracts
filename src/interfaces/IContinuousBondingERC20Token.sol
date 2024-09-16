// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { LP_POOL } from "../BondingERC20TokenFactory.sol";

interface IContinuousBondingERC20Token {
    function bondingCurve() external returns (address);
    function TREASURY_ADDRESS() external returns (address);
    function availableTokenBalance() external returns (uint256);
    function initialTokenBalance() external returns (uint256);
    function totalEthContributed() external returns (uint256);
    function isLpCreated() external returns (bool);
    function poolType() external returns (LP_POOL);
    function updateRouter(address _router, bool _allowed) external;
}
