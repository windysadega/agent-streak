// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice Test double for the SPACE ID Agent ID contract.
contract MockAgentID {
    mapping(address => uint256) private _bal;
    mapping(address => string) private _handles;

    function setHolder(address who, string calldata handle) external {
        _bal[who] = 1;
        _handles[who] = handle;
    }

    function revoke(address who) external {
        _bal[who] = 0;
    }

    function balanceOf(address owner) external view returns (uint256) {
        return _bal[owner];
    }

    function handleOf(address owner) external view returns (string memory) {
        return _handles[owner];
    }

    function ownerOfHandle(string calldata) external pure returns (address) {
        return address(0);
    }
}
