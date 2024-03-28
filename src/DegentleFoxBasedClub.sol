// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;
///////////////////////////
//  DEGENTLEFOX BASEDCLUB
///////////////////////////////////////////////////////////////
//
//  ░▒▓███████▓▒░░▒▓████████▓▒░▒▓███████▓▒░ ░▒▓██████▓▒░  
//  ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ 
//  ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░        
//  ░▒▓█▓▒░░▒▓█▓▒░▒▓██████▓▒░ ░▒▓███████▓▒░░▒▓█▓▒░        
//  ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░        
//  ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ 
//  ░▒▓███████▓▒░░▒▓█▓▒░      ░▒▓███████▓▒░ ░▒▓██████▓▒░ 
//
///////////////////////////////////////////////////////////////
//  BY DEGENS FOR DEGENS
///////////////////////////
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./erc6551/interfaces/IERC6551Registry.sol";


contract DegentleFoxBasedClub is ERC721, ERC721Enumerable, ERC721Burnable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 private _nextTokenId = 1;
    uint256 public constant MAX_SUPPLY = 420 + 1;
    
    IERC6551Registry _registry;
    address public _tbaImpl;
    
    event OneOfUs(address indexed newMember, uint256 tokenId, address indexed tba);

    constructor(address defaultAdmin, address minter, address tbaImpl, address registry) 
        ERC721("DegentleFoxBasedClub", "DFBC") {
            _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
            _grantRole(MINTER_ROLE, minter);
            
            _tbaImpl = tbaImpl;
            _registry = IERC6551Registry(registry);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://QmaURNL1bhzoWdf1MkvbuM1UUgudFbF1Y4oTUSQkENd8cE/";
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
      return tokenId != 0 && tokenId <= totalSupply() ? string.concat(
          _baseURI(),
          Strings.toString(tokenId),
          ".json"
      ) : "";
    }

    function safeMint(address to) public onlyRole(MINTER_ROLE) {
        _mint(to);
    }
    
    function adminMint(address to, uint amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint i = 0; i < amount; i++) {
            _mint(to);
        }
    }
    
    function _mint(address to) internal {
        uint256 tokenId = _nextTokenId++;
        require(tokenId < MAX_SUPPLY, "SoldOut");
        _safeMint(to, tokenId);
        address tba = _createTBA(tokenId);
        
        emit OneOfUs(to, tokenId, tba);
    }
    
    function _createTBA(uint tokenId) internal returns (address) {
        return _registry.createAccount(
            _tbaImpl,
            keccak256(abi.encodePacked(address(this), tokenId, uint(420))),
            block.chainid,
            address(this),
            tokenId
        );
    }
    
    function tbaOf(uint tokenId) public view returns (address) {
        return _registry.account(
            _tbaImpl,
            keccak256(abi.encodePacked(address(this), tokenId, uint(420))),
            block.chainid,
            address(this),
            tokenId        
        );
    }
    
    function tbaOf(address owner, uint index) public view returns (address) {
        uint tokenId = tokenOfOwnerByIndex(owner, index);
        return tbaOf(tokenId);
    }
    
    function isAdminOrRole(address account, bytes32 role) public view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, account) || hasRole(role, account);
    }

    // The following functions are overrides required by Solidity.

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {   
        require(to != tbaOf(tokenId), "OwnershipCycle");
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
