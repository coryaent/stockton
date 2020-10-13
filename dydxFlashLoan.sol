// SPDX-License-Identifier: MIT

pragma solidity >= 0.5.0;
pragma experimental ABIEncoderV2;

import "./lib/dydx/DydxFlashloanBase.sol";
import "./lib/dydx/ICallee.sol";

import "./lib/openzeppelin/IERC20.sol";

import "./ScriptRunner.sol";


contract DydxFlashloaner is ICallee, DydxFlashloanBase, ScriptRunner {
    struct MyCustomData {
        address token;
        uint256 repayAmount;
    }

    // This is the function that will be called postLoan
    // i.e. Encode the logic to handle your flashloaned funds here
    function callFunction(
        address sender,
        Account.Info memory account,
        bytes memory data
    ) public override {
        Call[] memory calls = abi.decode(data, (Call[]));

        runScript (calls);
        // uint256 balOfLoanedToken = IERC20(mcd.token).balanceOf(address(this));

        // Note that you can ignore the line below
        // if your dydx account (this contract in this case)
        // has deposited at least ~2 Wei of assets into the account
        // to balance out the collaterization ratio
        // require(
        //     balOfLoanedToken >= mcd.repayAmount,
        //     "Not enough funds to repay dydx loan!"
        // );

        // TODO: Encode your logic here
        // E.g. arbitrage, liquidate accounts, etc
        // revert("Hello, you haven't encoded your logic");
    }

    function initiateFlashLoan(address _solo, address _token, uint256 _amount, bytes calldata _params)
        external
    {
        ISoloMargin solo = ISoloMargin(_solo);

        // Get marketId from token address
        uint256 marketId = _getMarketIdFromTokenAddress(_solo, _token);

        // Calculate repay amount (_amount + (2 wei))
        // Approve transfer from
        uint256 repayAmount = _getRepaymentAmountInternal(_amount);
        IERC20(_token).approve(_solo, repayAmount);

        // 1. Withdraw $
        // 2. Call callFunction(...)
        // 3. Deposit back $
        Actions.ActionArgs[] memory operations = new Actions.ActionArgs[](3);

        operations[0] = _getWithdrawAction(marketId, _amount);
        operations[1] = _getCallAction(
            // Encode MyCustomData for callFunction
            _params
        );
        operations[2] = _getDepositAction(marketId, repayAmount);

        Account.Info[] memory accountInfos = new Account.Info[](1);
        accountInfos[0] = _getAccountInfo();

        solo.operate(accountInfos, operations);
    }
}
