pragma solidity ^0.8.0;

interface INFT {
    function init(string calldata name , string calldata symbol, address payable _owner) external;
}