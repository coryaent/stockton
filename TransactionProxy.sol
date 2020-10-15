// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity >= 0.6.0 < 0.7.0;
pragma experimental ABIEncoderV2;

import "./lib/dapphub/auth.sol";
import "./lib/dapphub/note.sol";

// import "./lib/DSProxyCache.sol";
import "./lib/ChiGasSaver.sol";
import "./lib/TokenInterface.sol";

contract TransactionProxy is ChiGasSaver, DSAuth, DSNote {
    DSProxyCache public cache;
    address gasTank;

    // receive() external payable {
    // }

    fallback() external payable {
    }

    constructor (address _cacheAddr, address _gasTank) public {
        setCache(_cacheAddr);
        setGasTank(_gasTank);
    }

        // proxy actions
    function deploy(bytes memory _code)
        public
        payable
        returns (address target)
    {
        target = cache.read(_code);
        if (target == address(0)) {
            // deploy contract & store its address in cache
            target = cache.write(_code);
        }
        // return target;
    }


    // proxy actions
    function execute(bytes memory _code, bytes memory _data)
        public
        payable
        returns (address target, bytes memory response)
    {
        target = cache.read(_code);
        if (target == address(0)) {
            // deploy contract & store its address in cache
            target = cache.write(_code);
        }

        response = execute(target, _data);
    }

    function executeAndBurn(bytes memory _code, bytes memory _data)
        public
        payable
        saveGas(payable(gasTank))
        returns (address target, bytes memory response)
    {
        target = cache.read(_code);
        if (target == address(0)) {
            // deploy contract & store its address in cache
            target = cache.write(_code);
        }

        response = execute(target, _data);
    }

    function execute(address _target, bytes memory _data)
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
            // let succeeded := delegatecall(gas(), _target, add(_data, 0x20), mload(_data), 0, 0)

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
    function setCache (address _cacheAddr) public auth note returns (bool) {
        require (_cacheAddr != address(0), "ds-proxy-cache-address-required");
        cache = DSProxyCache(_cacheAddr);  // overwrite cache
        return true;
    }

    function setGasTank (address _gasTank) public auth note returns (bool) {
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

contract DSProxyCache {
    mapping(bytes32 => address) cache;

    function read(bytes memory _code) public view returns (address) {
        bytes32 hash = keccak256(_code);
        return cache[hash];
    }

    function write(bytes memory _code) public returns (address target) {
        assembly {
            target := create(0, add(_code, 0x20), mload(_code))
            switch iszero(extcodesize(target))
            case 1 {
                // throw if contract failed to deploy
                revert(0, 0)
            }
        }
        bytes32 hash = keccak256(_code);
        cache[hash] = target;
    }
}