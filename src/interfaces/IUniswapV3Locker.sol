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

    function positions(uint256 _tokenId)
        external
        view
        returns (address owner, uint256 tokenId, address token0, address token1, bool isLocked);

    struct Epoch {
        uint256 amountCollected;
        uint256 collectedAt;
    }

    function epochs(
        uint256 tokenId,
        uint256 epochId
    )
        external
        view
        returns (uint256 amountCollected, uint256 collectedAt);

    function collectFees(uint256 tokenId) external returns (uint256 amount0, uint256 amount1);
    function collectInterval() external view returns (uint256);
    function withdrawFees(uint256 tokenId, uint256 amount, bytes calldata signature) external;
    function claimedFees(uint256 tokenId) external view returns (uint256);
    function withdrawnFees(uint256 tokenId) external view returns (uint256);
    function lastEpoch(uint256 tokenId) external view returns (uint256);
    function nonces(address user) external view returns (uint256 nonce);
    function WETH() external view returns (address);
}
