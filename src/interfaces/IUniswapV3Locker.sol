// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IUniswapV3Locker {
    struct LiquidityPosition {
        address owner;
        uint256 tokenId;
        address token0;
        address token1;
        bool isLocked;
    }

    struct Epoch {
        uint256 amountCollected;
        uint256 collectAt;
    }

    function collectFees(uint256 tokenId) external;
    function withdrawFees(uint256 tokenId, uint256 amount, bytes calldata signature) external;
    function positions(uint256 tokenId) external view returns (LiquidityPosition memory);
    function epochs(uint256 tokenId, uint256 epochId) external view returns (Epoch memory);
    function claimedFees(uint256 tokenId) external view returns (uint256);
    function withdrawnFees(uint256 tokenId) external view returns (uint256);
    function currentPeriod(uint256 tokenId) external view returns (uint256);
    function nonces(address user) external view returns (uint256);
    function WETH() external view returns (address);
}
