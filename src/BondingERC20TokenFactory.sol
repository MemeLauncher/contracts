// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ContinuosBondingERC20Token } from "./ContinuosBondingERC20Token.sol";
import { IBondingCurve } from "./interfaces/IBondingCurve.sol";

event BondingCurveUpdated(address indexed newBondingCurve, address indexed oldBondingCurve);

event TreasuryUpdated(address indexed newTreasury, address indexed oldTreasury);

event AvailableTokenUpdated(uint256 indexed newAvailableToken, uint256 indexed oldAvailableToken);

event InitialTokenBalanceUpdated(uint256 indexed newInitialTokenBalance, uint256 indexed oldInitialTokenBalance);

event TokenDeployed(address indexed token);

contract BondingERC20TokenFactory is Ownable {
  IBondingCurve public bondingCurve;
  address public treasury;
  uint256 public initialTokenBalance;
  uint256 public availableTokenBalance;

  constructor(
    address _owner,
    IBondingCurve _bondingCurve,
    address _treasury,
    uint256 _initialTokenBalance,
    uint256 _availableTokenBalance
  ) Ownable(_owner) {
    bondingCurve = _bondingCurve;
    treasury = _treasury;
    initialTokenBalance = _initialTokenBalance;
    availableTokenBalance = _availableTokenBalance;
  }

  function deployBondingERC20Token(
    address _router,
    string memory _name,
    string memory _symbol,
    uint256 _buyFee,
    uint256 _sellFee
  ) public returns (address) {
    ContinuosBondingERC20Token _bondingERC20Token = new ContinuosBondingERC20Token(
      _router,
      _name,
      _symbol,
      treasury,
      _buyFee,
      _sellFee,
      bondingCurve,
      initialTokenBalance,
      availableTokenBalance
    );
    emit TokenDeployed(address(_bondingERC20Token));

    return address(_bondingERC20Token);
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
}
