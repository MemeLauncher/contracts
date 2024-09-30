// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ContinuosBondingERC20Token } from "./ContinuosBondingERC20Token.sol";
import { IBondingCurve } from "./interfaces/IBondingCurve.sol";
import { IBondingERC20TokenFactory } from "./interfaces/IBondingERC20TokenFactory.sol";

contract BondingERC20TokenFactory is IBondingERC20TokenFactory, Ownable {
  IBondingCurve public bondingCurve;
  address public immutable WETH;
  address public treasury;
  address public uniswapV3Factory;
  address public nonfungiblePositionManager;
  address public feeRecipient;
  uint256 public initialTokenBalance;
  uint256 public availableTokenBalance;
  uint256 public buyFee;
  uint256 public sellFee;

  constructor(
    address _owner,
    IBondingCurve _bondingCurve,
    address _treasury,
    uint256 _initialTokenBalance,
    uint256 _availableTokenBalance,
    uint256 _buyFee,
    uint256 _sellFee,
    address _uniswapV3Factory,
    address _nonfungiblePositionManager,
    address _WETH
  ) Ownable(_owner) {
    bondingCurve = _bondingCurve;
    treasury = _treasury;
    initialTokenBalance = _initialTokenBalance;
    availableTokenBalance = _availableTokenBalance;
    buyFee = _buyFee;
    sellFee = _sellFee;
    uniswapV3Factory = _uniswapV3Factory;
    nonfungiblePositionManager = _nonfungiblePositionManager;
    WETH = _WETH;
  }

  function deployBondingERC20Token(string memory _name, string memory _symbol) public returns (address) {
    ContinuosBondingERC20Token _bondingERC20Token = new ContinuosBondingERC20Token(
      address(this),
      _name,
      _symbol,
      treasury,
      buyFee,
      sellFee,
      bondingCurve,
      initialTokenBalance,
      availableTokenBalance,
      uniswapV3Factory,
      nonfungiblePositionManager,
      WETH
    );
    emit TokenDeployed(address(_bondingERC20Token), msg.sender);

    return address(_bondingERC20Token);
  }

  function updateBuyFee(uint256 _newBuyFee) public onlyOwner {
    emit BuyFeeUpdated(_newBuyFee, buyFee);
    buyFee = _newBuyFee;
  }

  function updateSellFee(uint256 _newSellFee) public onlyOwner {
    emit SellFeeUpdated(_newSellFee, sellFee);
    sellFee = _newSellFee;
  }

  function updateTreasury(address _newTreasury) public onlyOwner {
    emit TreasuryUpdated(_newTreasury, treasury);
    treasury = _newTreasury;
  }

  function updateAvailableTokenBalance(uint256 _newAvailableTokenBalance) public onlyOwner {
    emit AvailableTokenUpdated(_newAvailableTokenBalance, availableTokenBalance);
    availableTokenBalance = _newAvailableTokenBalance;
  }

  function updateInitialTokenBalance(uint256 _newInitialTokenBalance) public onlyOwner {
    emit InitialTokenBalanceUpdated(_newInitialTokenBalance, initialTokenBalance);
    initialTokenBalance = _newInitialTokenBalance;
  }

  function updateBondingCurve(IBondingCurve _newBondingCurve) public onlyOwner {
    emit BondingCurveUpdated(address(_newBondingCurve), address(bondingCurve));
    bondingCurve = _newBondingCurve;
  }

  function updateUniswapV3Factory(address _newUniswapV3Factory) public onlyOwner {
    emit UniswapV3FactoryUpdated(_newUniswapV3Factory, uniswapV3Factory);
    uniswapV3Factory = _newUniswapV3Factory;
  }

  function updateNonfungiblePositionManager(address _newNonfungiblePositionManager) public onlyOwner {
    emit NonfungiblePositionManagerUpdated(_newNonfungiblePositionManager, nonfungiblePositionManager);
    nonfungiblePositionManager = _newNonfungiblePositionManager;
  }

  function updateFeeRecipient(address _newFeeRecipient) public onlyOwner {
    emit FeeRecipientUpdated(_newFeeRecipient, feeRecipient);
    feeRecipient = _newFeeRecipient;
  }
}
