// SPDX-License-Identifier:  MIT

pragma solidity >= 0.6.0;
pragma experimental ABIEncoderV2;

contract ScriptRunner {
    struct Call {
        address target;
        uint256 value;
        bytes callData;
    }

    function runScript(Call[] memory calls) public payable returns (bytes[] memory returnData) {

        returnData = new bytes[](calls.length);
        for(uint8 i = 0; i < calls.length; i++) {
            (bool success, bytes memory data) = calls[i].target.call{value:calls[i].value}(calls[i].callData);
            require(success, string(data));
            returnData[i] = data;
        }
    }
}
