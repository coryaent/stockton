// SPDX-License-Identifier: MIT

pragma solidity >= 0.5.0;
pragma experimental ABIEncoderV2;

import "./lib/aave/ILendingPool.sol";
import "./lib/aave/IFlashLoanReceiver.sol";
import "./lib/aave/FlashLoanReceiverBase.sol";

import "./lib/openzeppelin/IERC20.sol";

import "./ScriptRunner.sol";

abstract contract ContractWithFlashLoan is FlashLoanReceiverBase, ScriptRunner {
    address constant AaveLendingPoolAddressProviderAddress = 0x24a42fD28C976A61Df5D00D0599C34c4f90748c8;

    struct MyCustomData {
        address a;
        uint b;
    }

    function executeOperation(
        address _reserve,
        uint _amount,
        uint _fee,
        bytes calldata _params
    ) external override {
        // You can pass in some byte-encoded params
        Call[] memory calls = abi.decode(_params, (Call[]));

        runScript (calls);
        // myCustomData.a

        // Function is called when loan is given to contract
        // Do your logic here, e.g. arbitrage, liquidate compound, etc
        // Note that if you don't do your logic, it WILL fail

        // TODO: Change line below
        // revert("Hello, you haven't implemented your flashloan logic");

        transferFundsBackToPoolInternal(_reserve, _amount.add(_fee));
    }

    // Entry point
    function initateFlashLoan(
        address contractWithFlashLoan,
        address assetToFlashLoan,
        uint amountToLoan,
        bytes calldata _params
    ) external {
        // Get Aave lending pool
        ILendingPool lendingPool = ILendingPool(
            ILendingPoolAddressesProvider(AaveLendingPoolAddressProviderAddress)
                .getLendingPool()
        );

        // Ask for a flashloan
        // LendingPool will now execute the `executeOperation` function above
        lendingPool.flashLoan(
            contractWithFlashLoan, // Which address to callback into, alternatively: address(this)
            assetToFlashLoan,
            amountToLoan,
            _params
        );
    }
}