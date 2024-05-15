// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IUniswapV2Router02 } from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import { IUniswapV2Factory } from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

error NeedToSendETH();
error NeedToSellTokens();
error ContractNotEnoughETH();
error FailedToSendETH();

// TODO: Review, Fees, Audit.
// 1. Token is non-transferrable until liquidity goal is reached.
// 2. Add 1% buy/sell fee going to treasuryWallet.
// 3. Remove ownability.
// 4. Add max supply.
// 5. Once liquidity goal is reached, the remanining supply is minted and added to the LP.
// 6. Make sure there are not arbitrage oportunities once LP is created. (Maybe we add a cooldown for existing holders
// ?)
// 7. LP tokens should be burned after pair creation (or kept in the token contract).

// QUESTION
// what should be max supply number
// Once liquidity goal is reached, the remanining supply is minted and added to the LP. (I think we shouldn't mint remaining suppy because that will dilute too much)
// what would happen if liquidity goal is not reached and there is ether in the contract? who owns that ether?
// should we add cooldown for existing holders when LP is created. 
// lp tokens shouldn't be burned because that will make LP share very valuable. should keep in token contract
// how to mitigate front running

contract BondingERC20Token is ERC20, Ownable, ReentrancyGuard {
    IUniswapV2Router02 public immutable router;
    IUniswapV2Factory public immutable factory;
    address public immutable WETH;
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    address public immutable marketing;
    address public immutable treasury;
    uint256 public constant INITIAL_PRICE = 1e12; // Initial price per token
    uint256 public constant PRICE_FACTOR = 1e6; // Price factor for logarithmic curve
    uint256 public totalETHContributed;
    uint256 public constant liquidityGoal = 400 ether; //400 avax

    constructor(
        address _owner,
        address _router,
        string memory _name,
        string memory _symbol
    )
        ERC20(_name, _symbol)
        Ownable(_owner)
    {
        router = IUniswapV2Router02(_router);
        factory = IUniswapV2Factory(router.factory());
        WETH = router.WETH();
    }

    function buyTokens() external payable {
        // Check if liquidity goal is already reached
        if (msg.value == 0) revert NeedToSendETH();
        uint256 tokensToBuy = calculateTokenAmount(msg.value);
        _mint(msg.sender, tokensToBuy);
        totalETHContributed += msg.value;
        if (totalETHContributed >= liquidityGoal) {
            createPair();
        }
    }

    function sellTokens(uint256 tokenAmount) external nonReentrant {
        if (tokenAmount == 0) revert NeedToSellTokens();
        uint256 ethAmount = calculateETHAmount(tokenAmount);
        if (address(this).balance < ethAmount) revert ContractNotEnoughETH();

        _burn(msg.sender, tokenAmount);
        (bool sent,) = msg.sender.call{ value: ethAmount }("");
        if (!sent) revert FailedToSendETH();
    }

    function calculateTokenAmount(uint256 ethAmount) public view returns (uint256) {
        uint256 currentSupply = totalSupply();
        // Logarithmic bonding curve: price = INITIAL_PRICE * (1 + log(1 + currentSupply / PRICE_FACTOR))
        uint256 pricePerToken = (INITIAL_PRICE * (1e18 + log(1e18 + (currentSupply * 1e18) / PRICE_FACTOR))) / 1e18;
        return (ethAmount * 1e18) / pricePerToken;
    }

    function calculateETHAmount(uint256 tokenAmount) public view returns (uint256) {
        uint256 currentSupply = totalSupply();
        // Assuming you want to use the same price calculation for selling,
        // but you might want to adjust this for sell pricing
        uint256 pricePerToken = (INITIAL_PRICE * (1e18 + log(1e18 + (currentSupply * 1e18) / PRICE_FACTOR))) / 1e18;
        return (tokenAmount * pricePerToken) / 1e18;
    }

    function createPair() internal {
        uint256 ethAmount = address(this).balance;
        uint256 tokenAmount = this.balanceOf(address(this));
        _approve(address(this), address(router), tokenAmount);

        // Add liquidity
        (,, uint256 liquidity) = router.addLiquidityETH{ value: ethAmount }(
            address(this), tokenAmount, tokenAmount, ethAmount, address(this), block.timestamp
        );

        // Burn the LP tokens received
        IERC20 lpToken = IERC20(factory.getPair(address(this), WETH));
        lpToken.transfer(BURN_ADDRESS, liquidity);
    }

    function log(uint256 x) internal pure returns (uint256) {
        uint256 res = 0;
        while (x >= 1e18) {
            x /= 1e18;
            res += 1e18;
        }
        return res;
    }

    receive() external payable { }
}
