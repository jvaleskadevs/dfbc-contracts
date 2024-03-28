// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./supraVrf/interfaces/ISupraRouter.sol";

contract WarpingMachine is AccessControl {
    bytes32 public constant GAMEMASTER_ROLE = keccak256("GAMEMASTER_ROLE");
    IERC20 private _mana;  // degen
    address public _manaPool; 
    
    uint256 public _warpCost; // 420 ether
    uint256 public _warpDelta; // 4.20 hours
    uint256 public _multiWarpDelta; // 4.20 days
    uint256 public _warpDust;    // 420 basicPoints
    uint256 public _currentRound; // 0,1,2,3...
      
    // warper or round warpData
    struct WarpData {
        // last warp timestamp for warper, or totalMana for round
        uint256 lastWarp;
        // n of warps per warper per round (warper) or per round (round)
        uint256 totalWarps;
        // warp (warper) or multiWarp (round) hash
        bytes32 warpHash;
        // claimed (warper) or resolved (round)
        bool claimed;
    }    
    // round => tba => warpData
    // tba == address(0) for round warpData
    // tba == tba for warper warpData
    mapping (uint => mapping(address => WarpData)) public warpData;
    
    // vrf variables
    ISupraRouter internal _supraRouter;
    address _clientWalletAddress;
    
    event onWarp(address indexed warper, uint256 seed, bytes32 warpHash);
    event onMultiWarpJoin(address indexed warper, uint256 seed, bytes32 userWarpHash);
    event onMultiWarpResult(uint indexed round, bool areWinners, uint multiHash, uint random);
        
    constructor(
        address defaultAdmin, 
        address gamemaster, 
        address mana, 
        address manaPool,
        uint warpCost, 
        uint warpDelta,
        uint multiWarpDelta,
        uint warpDust,
        address supraRouter,
        address clientWalletAddress
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(GAMEMASTER_ROLE, gamemaster);
        
        _mana = IERC20(mana);
        _manaPool = manaPool;
        _warpCost = warpCost;
        _warpDelta = warpDelta;
        _multiWarpDelta = multiWarpDelta;
        _warpDust = warpDust;
        
        _supraRouter = ISupraRouter(supraRouter);
        _clientWalletAddress = clientWalletAddress;
    }
    
    // just a safe warp powered with mana
    function warp(address warper, uint seed) public onlyRole(GAMEMASTER_ROLE) returns (bytes32) {
        require(isSafeWarp(warper), "WarpIsDangerous");
        _setLastWarpOf(warper, block.timestamp);
        
        require(_mana.transferFrom(warper, address(this), _warpCost));
        
        return _warp(warper, seed);
    }
    
    // only for degens, it is not a safe warp
    function degenWarp(address warper, uint seed) public onlyRole(GAMEMASTER_ROLE) returns (bytes32) {
        require(_mana.transferFrom(warper, address(this), _warpCost), "NotEnoughDegen");
        
        return _warp(warper, seed);
    }
    
    function _warp(address warper, uint seed) internal returns (bytes32 warpHash) {
        _setTotalWarpsOf(warper);
        warpHash = _updateUserWarpHash(warper, seed);
        emit onWarp(warper, seed, warpHash);
    }
    
    // add warper hash for the multiwarp event
    // resolves the multiwarp event if required
    function joinMultiWarp(address warper, uint seed) public {
        bytes32 userWarpHash = _updateMultiWarpHash(warper, seed);
        
        emit onMultiWarpJoin(warper, seed, userWarpHash);
        
        if (isSafeMultiWarp()) {
            _multiWarp();
        }
    }
    
    function _multiWarp() internal {
        _requestRandomNumber();
    }
    
    function _updateUserWarpHash(address warper, uint seed) internal returns (bytes32 newWarpHash) {
        newWarpHash = keccak256(abi.encodePacked(block.timestamp, warper, seed));
        _setWarpHashOf(warper, keccak256(
            abi.encodePacked(
                block.timestamp,
                newWarpHash, 
                warpHashOf(warper)
            )
        ));
    }
    
    function _updateMultiWarpHash(address warper, uint seed) internal returns (bytes32 userWarpHash) {
        userWarpHash = keccak256(abi.encodePacked(block.timestamp, warper, seed));
        _setWarpHashOf(address(0), keccak256(abi.encodePacked(userWarpHash, warpHashOf(address(0)))));
    }
    
    function _resolveMultiWarp(uint randomNumber) internal {
        uint256 multiWarpHash = uint(warpHashOf(address(0)));
        bool areWinners = multiWarpHash > randomNumber;
        
        emit onMultiWarpResult(_currentRound, areWinners, multiWarpHash, randomNumber);
        
        if (areWinners) {
            uint roundMana = _mana.balanceOf(address(this));
            uint manaDust = roundMana * _warpDust / 10000;
            require(_mana.transferFrom(address(this), _manaPool, manaDust), "NotEnoughDegen");
            
            _setLastWarpOf(address(0), roundMana - manaDust);
            _currentRound++;
        }
    }
    
    // anyone may claim last round mana for an specified warper
    function claimMana(address warper) public {
        bool claimedBefore = warpData[_currentRound-1][warper].claimed;
        require(claimedBefore == false, "AlreadyClaimed");
        warpData[_currentRound-1][warper].claimed = true;
        _mana.transfer(warper, manaOf(warper, _currentRound-1));
    }
    
    // VRF
    function _requestRandomNumber() internal {
        _supraRouter.generateRequest("vrfCallback(uint256,uint256[])", 1, 3, _clientWalletAddress);
    }
    
    function vrfCallback(uint256 nonce, uint256[] calldata rngList) external {
        require(msg.sender == address(_supraRouter), "Forbidden");
        _resolveMultiWarp(rngList[0]);
    }
    
    // INTERNAL SETTERS

    function _setWarpHashOf(address warper, bytes32 newWarpHash) internal {
        warpData[_currentRound][warper].warpHash = newWarpHash;
    }    
    
    function _setLastWarpOf(address warper, uint newLastWarp) internal {
        warpData[_currentRound][warper].lastWarp = newLastWarp;
    } 
    
    function _setTotalWarpsOf(address warper) internal {
        warpData[_currentRound][warper].totalWarps++;
        warpData[_currentRound][address(0)].totalWarps++;
    } 
    
    // VIEWERS

    function isSafeWarp(address warper) public view returns (bool) {
        return block.timestamp > _warpDelta + lastWarpOf(warper);
    }
    
    function isSafeMultiWarp() public view returns (bool) {
        return block.timestamp > _multiWarpDelta + lastWarpOf(address(0));
    }

    function warpHashOf(address warper) public view returns (bytes32) {
        return warpData[_currentRound][warper].warpHash;
    }    
    
    function lastWarpOf(address warper) public view returns (uint) {
        return warpData[_currentRound][warper].lastWarp;
    }
    
    function totalWarpsOf(address warper) public view returns (uint) {
        return warpData[_currentRound][warper].totalWarps;
    }
    
    function manaOf(address warper, uint round) public view returns (uint) {
        return warpData[round][warper].totalWarps / warpData[round][address(0)].totalWarps * warpData[round][address(0)].lastWarp;
    }
    
    // ADMIN only
    
    function setWarpCost(uint warpCost) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _warpCost = warpCost;
    }
    
    function setWarpDelta(uint warpDelta) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _warpDelta = warpDelta;
    }
    
    function setMultiWarpDelta(uint multiWarpDelta) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _multiWarpDelta = multiWarpDelta;
    }
    
    function setWarpDust(uint warpDust) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _warpDust = warpDust;
    }
    
    function setManaPool(address manaPool) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _manaPool = manaPool;
    }
    
    function setVrfData(address clientWalletAddress, address supraRouter) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _supraRouter = ISupraRouter(supraRouter);
        _clientWalletAddress = clientWalletAddress;
    }    
}
