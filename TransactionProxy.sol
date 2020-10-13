// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity >= 0.6.0;
pragma experimental ABIEncoderV2;

import "./lib/dapphub/auth.sol";
import "./lib/dapphub/note.sol";

import "./lib/DSProxyCache.sol";
import "./lib/ChiGasSaver.sol";
import "./lib/TokenInterface.sol";

contract TransactionProxy is ChiGasSaver, DSAuth, DSNote {
    DSProxyCache public cache;
    address gasTank;

    receive() external payable {
    }

    fallback() external payable {
    }

    constructor (address _cacheAddr, address _gasTank) public {
        setCache(_cacheAddr);
        setGasTank(_gasTank);
    }


    // proxy actions
    function execute(bytes memory _code, bytes memory _data)
        public
        payable
        auth
        returns (address target, bytes memory response)
    {
        target = cache.read(_code);
        if (target == address(0)) {
            // deploy contract & store its address in cache
            target = cache.write(_code);
        }

        response = _execute(target, _data);
    }

    function executeAndBurn(bytes memory _code, bytes memory _data)
        public
        payable
        auth
        saveGas(payable(gasTank))
        returns (address target, bytes memory response)
    {
        target = cache.read(_code);
        if (target == address(0)) {
            // deploy contract & store its address in cache
            target = cache.write(_code);
        }

        response = _execute(target, _data);
    }

    function _execute(address _target, bytes memory _data)
        public
        auth
        note
        payable
        returns (bytes memory response)
    {
        require(_target != address(0), "ds-proxy-target-address-required");

        // call contract in current context
        assembly {
            let succeeded := delegatecall(sub(gas(), 5000), _target, add(_data, 0x20), mload(_data), 0, 0)
            let size := returndatasize()

            response := mload(0x40)
            mstore(0x40, add(response, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            mstore(response, size)
            returndatacopy(add(response, 0x20), 0, size)

            switch iszero(succeeded)
            case 1 {
                // throw if delegatecall failed
                revert(add(response, 0x20), size)
            }
        }
    }


    // address updates
    function setCache (address _cacheAddr) public auth returns (bool) {
        require (_cacheAddr != address(0), "ds-proxy-cache-address-required");
        cache = DSProxyCache(_cacheAddr);  // overwrite cache
        return true;
    }

    function setGasTank (address _gasTank) public auth returns (bool) {
        require (_gasTank != address(0), "gasTank address required");
        gasTank = _gasTank;
        return true;
    }


    // token functions
    function transfer(address token, address guy, uint wad) public auth {
        require(TokenInterface(token).transfer(guy, wad), "Token transfer failed");
    }

    function approve(address token, address guy, uint wad) public auth {
        TokenInterface(token).approve(guy, wad);
    }

    function deposit(address token) public payable auth {
        TokenInterface(token).deposit{value: msg.value}();
    }

    function withdraw(address token, uint wad) public auth {
        TokenInterface(token).withdraw(wad);
    }
}

