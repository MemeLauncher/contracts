// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ContinuosBondingERC20Token } from "./ContinuosBondingERC20Token.sol";
import { IBondingCurve } from "./interfaces/IBondingCurve.sol";

event BondingCurveUpdated(address indexed newBondingCurve, address indexed oldBondingCurve);

event TreasuryUpdated(address indexed newTreasury, address indexed oldTreasury);

event AvailableTokenUpdated(uint256 indexed newAvailableToken, uint256 indexed oldAvailableToken);

event InitialTokenBalanceUpdated(uint256 indexed newInitialTokenBalance, uint256 indexed oldInitialTokenBalance);

event BuyFeeUpdated(uint256 indexed newBuyFee, uint256 indexed oldBuyFee);

event SellFeeUpdated(uint256 indexed newSellFee, uint256 indexed oldSellFee);

event TokenDeployed(address indexed token, address indexed deployer);

event RouterUpdated(address indexed router, bool allowed);

event CreationFeeUpdated(uint256 indexed newCreationFee, uint256 indexed oldCreationFee);

event FeesSent(uint256 fees);

error RouterNotSet();

error InvalidCreationFee();

error FeeSendingFailed();

enum LP_POOL {
    Uniswap,
    TraderJoe
}

contract BondingERC20TokenFactory is Ownable {
    IBondingCurve public bondingCurve;
    address public treasury;
    uint256 public initialTokenBalance;
    uint256 public availableTokenBalance;
    uint256 public buyFee;
    uint256 public sellFee;
    uint256 public creationFee;
    mapping(address router => bool allowed) public allowedRouter;

    constructor(
        address _owner,
        IBondingCurve _bondingCurve,
        address _treasury,
        uint256 _initialTokenBalance,
        uint256 _availableTokenBalance,
        uint256 _buyFee,
        uint256 _sellFee,
        uint256 _creationFee
    )
        Ownable(_owner)
    {
        bondingCurve = _bondingCurve;
        treasury = _treasury;
        initialTokenBalance = _initialTokenBalance;
        availableTokenBalance = _availableTokenBalance;
        buyFee = _buyFee;
        sellFee = _sellFee;
        creationFee = _creationFee;
    }

    function deployBondingERC20Token(
        address _router,
        string memory _name,
        string memory _symbol,
        LP_POOL _poolType
    )
        public
        payable
        returns (address)
    {
        if (!allowedRouter[_router]) {
            revert RouterNotSet();
        }
        if (msg.value < creationFee) {
            revert InvalidCreationFee();
        }
        ContinuosBondingERC20Token _bondingERC20Token = new ContinuosBondingERC20Token(
            _router,
            _name,
            _symbol,
            treasury,
            buyFee,
            sellFee,
            bondingCurve,
            initialTokenBalance,
            availableTokenBalance,
            _poolType
        );
        emit TokenDeployed(address(_bondingERC20Token), msg.sender);

        return address(_bondingERC20Token);
    }

    function claimFees() public onlyOwner {
        emit FeesSent(address(this).balance);
        (bool success, ) = treasury.call{value: address(this).balance}("");
        if (!success) {
            revert FeeSendingFailed();
        }
    }

    function updateRouter(address _router, bool _allowed) public onlyOwner {
        emit RouterUpdated(_router, _allowed);
        allowedRouter[_router] = _allowed;
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

    function updateCreationFee(uint256 newCreationFee) public onlyOwner {
        emit CreationFeeUpdated(newCreationFee, creationFee);
        creationFee = newCreationFee;
    }
}
