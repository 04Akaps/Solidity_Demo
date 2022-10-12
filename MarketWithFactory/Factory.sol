pragma solidity 0.8.4;

import "./customInterface/INFT.sol";
import "./utils/Ownable.sol";

contract MarketWithFactory is Ownable{

    mapping(address => bool) private company;
    // 너가 말한 엔터 회사들을 기록하는 변수
    // 방향은 설정된 엔터 회사들만 NFTCollection을 만들 수 있음

    mapping(address => address[]) private companyNFTCollection;
    // 엔터 회사들이 가지고 있을 NFT 주소들

    address private basicNFTAddress;

    constructor(address _basicNFTAddress) public {
        // basicNFTAddress는 NFT컨트랙트를 말함
        // 반드시 NFT를 먼저 배포하고, 해당 CA를 통해서 배포하면 됨
        // 이후 처음에 배포한 NFT Contract는 버림
        basicNFTAddress = _basicNFTAddress;
    }

    modifier onlyCompany() {
        require(company[msg.sender], "Not Authorized");
        _;
    }


    function addCompany(address _newCompany) external onlyOwner {
        require(!company[_newCompany], "already registed");

        company[_newCompany] = true;
    }


    function createNewNFT(string calldata _name, string calldata _symbol) external onlyCompany {
        address newNFTAddress = _createClone(basicNFTAddress);
        INFT newNFT = INFT(newNFTAddress);

        newNFT.init(_name, _symbol, payable(msg.sender));

        companyNFTCollection[msg.sender].push(newNFTAddress);
    }

    function _createClone(address target) internal returns (address result) {
        // 새로운 Contract를 만들어 낼 코드
        bytes20 targetBytes = bytes20(target);
        assembly {
            let clone := mload(0x40)
            mstore(
                clone,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            mstore(add(clone, 0x14), targetBytes)
            mstore(
                add(clone, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            result := create(0, clone, 0x37)
        }
    }
}