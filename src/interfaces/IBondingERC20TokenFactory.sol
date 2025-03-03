// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IBondingCurve } from "./IBondingCurve.sol";

interface IBondingERC20TokenFactory {
  // Events
  event BondingCurveUpdated(address indexed newBondingCurve, address indexed oldBondingCurve);
  event TreasuryUpdated(address indexed newTreasury, address indexed oldTreasury);
  event AvailableTokenUpdated(uint256 indexed newAvailableToken, uint256 indexed oldAvailableToken);
  event InitialTokenBalanceUpdated(uint256 indexed newInitialTokenBalance, uint256 indexed oldInitialTokenBalance);
  event BuyFeeUpdated(uint256 indexed newBuyFee, uint256 indexed oldBuyFee);
  event SellFeeUpdated(uint256 indexed newSellFee, uint256 indexed oldSellFee);
  event TokenDeployed(address indexed token, address indexed deployer);
  event UniswapV3FactoryUpdated(address indexed newUniswapV3Factory, address indexed oldUniswapV3Factory);
  event NonfungiblePositionManagerUpdated(
    address indexed newNonfungiblePositionManager,
    address indexed oldNonfungiblePositionManager
  );
  event FeeRecipientUpdated(address indexed newFeeRecipient, address indexed oldFeeRecipient);
  event CreationFeeUpdated(uint256 indexed newCreationFee, uint256 indexed oldCreationFee);
  event FeesSent(uint256 fees);

  // Public view functions
  function bondingCurve() external view returns (IBondingCurve);

  function WETH() external view returns (address);

  function treasury() external view returns (address);

  function uniswapV3Factory() external view returns (address);

  function nonfungiblePositionManager() external view returns (address);

  function feeRecipient() external view returns (address);

  function initialTokenBalance() external view returns (uint256);

  function availableTokenBalance() external view returns (uint256);

  function buyFee() external view returns (uint256);

  function sellFee() external view returns (uint256);

  // Public functions
  function deployBondingERC20TokenAndPurchase(string memory _name, string memory _symbol, bool _isAntiWhaleFlagEnabled) external payable returns (address);

  function updateBuyFee(uint256 _newBuyFee) external;

  function updateSellFee(uint256 _newSellFee) external;

  function updateTreasury(address _newTreasury) external;

  function updateAvailableTokenBalance(uint256 _newAvailableTokenBalance) external;

  function updateInitialTokenBalance(uint256 _newInitialTokenBalance) external;

  function updateBondingCurve(IBondingCurve _newBondingCurve) external;

  function updateUniswapV3Factory(address _newUniswapV3Factory) external;

  function updateNonfungiblePositionManager(address _newNonfungiblePositionManager) external;

  function updateFeeRecipient(address _newFeeRecipient) external;
}
