pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IDeposit.sol";

contract DepositInMumbai is Ownable, IDeposit{
    mapping (uint256 => bool) Depositlist;
    mapping (address => bool) Whitelist;
    IERC721 public base;
    constructor(address _base){
        base = IERC721(_base);
    }

    modifier OnlyWhitelist(){
        require(Whitelist[msg.sender],"not in whitelist");
        _;
    }

    function setWhitelist(address whiteaddress, bool op) external onlyOwner{
        Whitelist[whiteaddress] = op;
    }
    function deposit(uint256 tokenId) external OnlyWhitelist{
        require(base.ownerOf(tokenId) == address(this));
        Depositlist[tokenId] = true;
    }


    function withdraw(uint256 tokenId, address to) external OnlyWhitelist{
        require(base.ownerOf(tokenId) == address(this)&&checkdeposit(tokenId));
        base.transferFrom(address(this), to, tokenId);
        Depositlist[tokenId] = false;
    }


    function checkdeposit(uint256 tokenId) public view returns(bool) {
        return Depositlist[tokenId];
    }


    function setOperator(address operator) external onlyOwner{
        base.setApprovalForAll(operator, true);
    }


}