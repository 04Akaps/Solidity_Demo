pragma solidity 0.8.4;

import "./interfaces/ERC721.sol";

contract NFT is ERC721 {

    event WithDraw(address indexed sender, uint256 time, uint256 value);

    address payable private nftOwner;

    bool inited;

    function init(string calldata name , string calldata symbol, address payable _owner) external {
        require(!inited , "Not inited!");

        _init(name, symbol);
        nftOwner = _owner;

        inited = true;
    } 

    receive() external payable {}

    function mint()external {
        uint256 randomNumber = getRandom();
        // 랜덤한 값 가져와서 뭐 알아서 mint할지 말지 결정
    }

    function burn(uint256 tokenId) external {
        // 어차피 _burn 함수 내부에서 tokenOwner인지 체크하니 따로 없어도 됨
        _burn(tokenId);
    }

    function withDraw() external payable{
        // 폴리곤에 한다고 했으니 Conatract에 쌓여있는 matic을 가져가는 함수
        require(msg.sender == nftOwner, "Not Owner");

        uint256 value = address(this).balance;

        nftOwner.transfer(value);

        emit WithDraw(nftOwner, block.timestamp, value);
    }


    function getRandom() internal view returns(uint256) {
         return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        msg.sender,
                        block.difficulty,
                        blockhash(block.number - 1)
                    )
                )
            ) % 1000;
    }

    
}