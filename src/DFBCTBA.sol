// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import "./erc6551/ERC6551Account.sol";
import "./erc6551/TokenCallbackHandler.sol";
import "./erc6551/interfaces/IERC6551Executable.sol";


contract DFBCTBA is TokenCallbackHandler, ERC6551Account, IERC6551Executable {    
    function execute(address to, uint256 value, bytes calldata data, uint8 operation)
        external
        payable
        returns (bytes memory result)
    {
        require(_isValidSigner(msg.sender, bytes("")), "Invalid signer");
        require(operation == 0, "Only call operations are supported");

        ++_state;

        bool success;
        (success, result) = to.call{value: value}(data);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }
    
    function owner() public view returns (address) {
        (uint256 chainId, address tokenContract, uint256 tokenId) = token();
        if (chainId != block.chainid) return address(0);

        return IERC721(tokenContract).ownerOf(tokenId);
    }   

    function _isValidSigner(address signer, bytes memory) internal view override returns (bool) {
        return signer == owner();
    }
    
    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        override(TokenCallbackHandler, ERC6551Account) 
        returns (bool) 
    {
        return 
            interfaceId == type(IERC6551Executable).interfaceId || super.supportsInterface(interfaceId);  
    }
    
    receive() external payable override {}
}
