// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ContinuosBondingERC20Token } from "./ContinuosBondingERC20Token.sol";
import { IBondingCurve } from "./interfaces/IBondingCurve.sol";

event BondingCurveUpdated(address indexed newBondingCurve, address indexed oldBondingCurve);

event TreasuryUpdated(address indexed newTreasury, address indexed oldTreasury);

event TokenDeployed(address indexed token);

contract BondingERC20TokenFactory is Ownable {
  IBondingCurve public bondingCurve;
  address public treasury;

  constructor(address _owner, IBondingCurve _bondingCurve, address _treasury) Ownable(_owner) {
    bondingCurve = _bondingCurve;
    treasury = _treasury;
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
      bondingCurve
    );
    emit TokenDeployed(address(_bondingERC20Token));

    return address(_bondingERC20Token);
  }

  function updateTreasury(address _newTreasury) public onlyOwner {
    emit TreasuryUpdated(_newTreasury, treasury);
    treasury = _newTreasury;
  }

  function updateBondingCurve(IBondingCurve _newBondingCurve) public onlyOwner {
    emit BondingCurveUpdated(address(_newBondingCurve), address(bondingCurve));
    bondingCurve = _newBondingCurve;
  }
}
