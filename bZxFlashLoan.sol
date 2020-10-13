pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;
// "SPDX-License-Identifier: Apache-2.0"

import "./lib/openzeppelin/IERC20.sol";
import "./lib/bzx/IToken.sol";

import "./ScriptRunner.sol";

contract BZxFlashLoaner {
    function initiateFlashLoan(
        address loanToken,
        address iToken,
        uint256 flashLoanAmount
    ) internal returns (bytes memory success) {
        IToken iTokenContract = IToken(iToken);
        return
            iTokenContract.flashBorrow(
                flashLoanAmount,
                address(this),
                address(this),
                "",
                abi.encodeWithSignature(
                    "executeOperation(address,address,uint256)",
                    loanToken,
                    iToken,
                    flashLoanAmount
                )
            );
    }

    function repayFlashLoan(
        address loanToken,
        address iToken,
        uint256 loanAmount
    ) internal {
        IERC20(loanToken).transfer(iToken, loanAmount);
    }

    function executeOperation(
        address loanToken,
        address iToken,
        uint256 loanAmount
    ) external returns (bytes memory success) {
        emit BalanceOf(IERC20(loanToken).balanceOf(address(this)));
        emit ExecuteOperation(loanToken, iToken, loanAmount);
        repayFlashLoan(loanToken, iToken, loanAmount);
        return bytes("1");
    }

    event ExecuteOperation(
        address loanToken,
        address iToken,
        uint256 loanAmount
    );

    event BalanceOf(uint256 balance);
}
