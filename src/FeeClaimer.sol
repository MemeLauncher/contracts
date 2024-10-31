// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import { INonfungiblePositionManager } from "./interfaces/INonfungiblePositionManager.sol";

contract FeeClaimer is Ownable, EIP712, ReentrancyGuard {
    using ECDSA for bytes32;

    INonfungiblePositionManager public immutable nonfungiblePositionManager;
    address public signer;
    address public wNative;
    mapping(address holder => mapping(address token => uint256 claimed)) claimed;

    constructor(
        address _owner,
        address _nonfungiblePositionManager,
        address _signer,
        address _wNative
    )
        Ownable(_owner)
        EIP712("ApeRushFeeClaimer", "1")
    {
        nonfungiblePositionManager = INonfungiblePositionManager(_nonfungiblePositionManager);
        signer = _signer;
        wNative = _wNative;
    }

    function claimFees(
        uint256[] calldata tokenIds, //// array of positionId
        address[] calldata candyTokens, //// array of candyToken addresses
        uint256[] calldata candyTokenAmounts, //// amount of candyToken to be claimed by caller
        uint256 apeTokenAmount, //// amount of apeToken to be claimed by caller
        bytes calldata signature //// signature of above data signed by trusted signer
    )
        external
        nonReentrant
    {
        require(tokenIds.length == candyTokenAmounts.length, "length mismatch");

        bytes32 digest = getDigest(msg.sender, candyTokens, tokenIds, candyTokenAmounts, apeTokenAmount);

        require(SignatureChecker.isValidSignatureNow(signer, digest, signature), "invalid signature");
        uint256 amountOfWNativeClaimable = apeTokenAmount - claimed[msg.sender][wNative];
        uint256 balanceOfWNative = IERC20(wNative).balanceOf(address(this));
        claimed[msg.sender][wNative] = apeTokenAmount;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            address candyToken = candyTokens[i];
            uint256 amountOfCandyToClaim = candyTokenAmounts[i];
            uint256 tokenId = tokenIds[i];
            uint256 amountOfCandyAlreadyClaimed = claimed[msg.sender][candyToken];

            require(amountOfCandyToClaim > amountOfCandyAlreadyClaimed, "Nothing to claim");

            uint256 claimableCandyAmount = amountOfCandyToClaim - amountOfCandyAlreadyClaimed;

            claimed[msg.sender][candyToken] = amountOfCandyToClaim;

            if (
                IERC20(candyToken).balanceOf(address(this)) < claimableCandyAmount
                    || amountOfWNativeClaimable > balanceOfWNative
            ) {
                INonfungiblePositionManager.CollectParams memory params = INonfungiblePositionManager.CollectParams({
                    tokenId: tokenId,
                    recipient: address(this),
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
                });
                nonfungiblePositionManager.collect(params);
            }

            IERC20(candyToken).transfer(msg.sender, claimableCandyAmount);
        }
        IERC20(wNative).transfer(msg.sender, amountOfWNativeClaimable);
    }

    function getDigest(
        address claimer,
        address[] calldata candyTokens,
        uint256[] calldata tokenIds,
        uint256[] calldata candyTokenAmounts,
        uint256 apeTokenAmounts
    )
        public
        view
        returns (bytes32)
    {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256(
                        "Claimer(address claimer,address[] candyTokens,uint256[] tokenIds,uint256[] candyTokenAmounts,uint256 apeTokenAmounts)"
                    ),
                    claimer,
                    keccak256(abi.encode(candyTokens)),
                    keccak256(abi.encode(tokenIds)),
                    keccak256(abi.encode(candyTokenAmounts)),
                    apeTokenAmounts
                )
            )
        );
        return digest;
    }

    function updateWNative(address newWNative) external onlyOwner {
        wNative = newWNative;
    }

    function updateSigner(address newSigner) external onlyOwner {
        signer = newSigner;
    }

    function rescuePositions(uint256[] calldata tokenIds, address to) external onlyOwner {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            nonfungiblePositionManager.safeTransferFrom(address(this), to, tokenIds[i]);
        }
    }
}
