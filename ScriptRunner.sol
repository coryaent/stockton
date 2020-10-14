// SPDX-License-Identifier:  MIT

pragma solidity >= 0.6.0;
pragma experimental ABIEncoderV2;

contract ScriptRunner {
    struct Call {
        address _target;
        uint256 _value;
        bytes _callData;
    }

    function runScript(Call[] memory calls) public payable returns (bytes[] memory returnData) {

        returnData = new bytes[](calls.length);
        for(uint8 i = 0; i < calls.length; i++) {
            (bool success, bytes memory data) = calls[i]._target.call.value(calls[i]._value)(calls[i]._callData);
            require(success, string(data));
            returnData[i] = data;
        }
    }
}
