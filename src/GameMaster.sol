// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract GameMaster is AccessControl {
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    uint256 public state;
 
    constructor(address defaultAdmin, address executor) {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(EXECUTOR_ROLE, executor);
    }
/*    
    function newPlayer(address player) public onlyRole(EXECUTOR_ROLE) {
        DFBC.safeMint(player);
    }
    
    function warp(address player, uint seed) public onlyRole(EXECUTOR_ROLE) {
        WarpMachine.warp(player, seed);
    }
    
    function degenWarp(address player, uint seed) public onlyRole(EXECUTOR_ROLE) {
        WarpMachine.degenWarp(player, seed);
    }
*/    
    
  
    function execute(address to, uint256 value, bytes calldata data, uint8 operation)
        external
        payable
        onlyRole(EXECUTOR_ROLE)
        returns (bytes memory result)
    {
        require(operation == 0, "Only call operations are supported");

        ++state;

        bool success;
        (success, result) = to.call{value: value}(data);

        _successOrRevert(success, result);
    }
    
    function multiCall(address[] calldata targets, bytes[] calldata data)
        external 
        view 
        onlyRole(EXECUTOR_ROLE)
        returns (bytes[] memory)
    {
        require(targets.length == data.length, "target length != data length");

        bytes[] memory results = new bytes[](data.length);

        for (uint i; i < targets.length; i++) {
            (bool success, bytes memory result) = targets[i].staticcall(data[i]);
             _successOrRevert(success, result);
            results[i] = result;
        }

        return results;
    }
    
    function _successOrRevert(bool success, bytes memory result) pure internal {
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }
}
