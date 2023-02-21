pragma solidity ^0.8.4;


interface IDeposit{


    function deposit(uint256 tokenId) external;
    function withdraw(uint256 tokenId, address to) external; 
    function setOperator(address operator) external;

}