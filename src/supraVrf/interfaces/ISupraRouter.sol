// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ISupraRouter {
	  function generateRequest(
	      string memory _functionSig, 
	      uint8 _rngCount, 
	      uint256 _numConfirmations, 
	      uint256 _clientSeed, 
	      address _clientWalletAddress
    ) external returns(uint256);
	  function generateRequest(
	      string memory _functionSig, 
	      uint8 _rngCount, 
	      uint256 _numConfirmations, 
	      address _clientWalletAddress
    ) external returns(uint256);
}
