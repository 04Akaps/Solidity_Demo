// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

interface MultiSig {
    // indexed를 추가하는 이유는 특정한 값을 가져오기 위해서 사용합니다.
    // 블록에 기록될떄에는 여러 이벤트들이 겹치기 떄문에 원하는 값을 가져오기 위해서 사용을 하고
    // indexed를 추가하여 필터링할 값을 선정하는 것 입니다.
    event Deposit(address indexed sender, uint256 amount);
    event Submit(uint256 indexed txId);
    event Approve(address indexed owner, uint256 indexed txid);
    event Revoke(address indexed owner, uint256 indexed txid);
    event Execute(uint256 indexed txid);
}

contract MultisigModifiers {
    mapping(address => bool) public isOwner;
    // 해당 주소값이 owner인지를 확인
    address[] public owners;
    // owner를 관리하기 위한 배열
    uint256 public required;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
    }

    Transaction[] public transactions;

    mapping(uint256 => mapping(address => bool)) public approved;

    modifier onlyOwner() {
        // isOwner의 modifier
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier notApproved(uint256 _txId) {
        require(!approved[_txId][msg.sender], "tx already approved");
        _;
    }

    modifier notExecuted(uint256 _txId) {
        require(transactions[_txId].executed, "tx already excuted");
        _;
    }

    modifier txExists(uint256 _txId) {
        require(_txId < transactions.length, " tx doex not exist");
        _;
    }
}

contract MultiSigWallet is MultiSig, MultisigModifiers {
    constructor(address[] memory _owners, uint256 _required) {
        // 일단 지갑을 관리할 owner들을 집어 넣는다.
        require(_owners.length > 0, "owners required!!");
        require(
            _required > 0 && _required <= _owners.length,
            "invalid required number!!"
        );
        for (uint256 i; i < _owners.length; i++) {
            require(_owners[i] != address(0), "invailed Owner!! in for");
            require(!isOwner[_owners[i]], "owner is not uniqued");
            isOwner[_owners[i]] = true;
            owners.push(_owners[i]);
        }
        required = _required;
    }

    /*
        constructor을 통해서 하나의 지갑에 owner들을 집어 넣습니다.
    */

    receive() external payable {
        //  fallback과 receive나뉘어 집니다.
        // fallback는 이더를 받고 실행시킨 함수가 없을떄에 적용이 되는 함수이며
        // receive는 순수하게 이더를 받을때만 작동이 됩니다.
        // 즉 이곳에서는 트랜잭션에서 이더를 전송할떄  모든 경우에 대해서 이벤트를 출력합니다.
        emit Deposit(msg.sender, msg.value);
    }

    // A B C
    // A  : 나는 저녁에 같이 치킨을 먹을거야;
    function submit(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external onlyOwner {
        // onlyOwner에 의해서 지갑에 있는 사용자들만 실행이 가능합니다.
        // 해당 지갑의 트랜잭션데이터를 집어 넣습니다.
        transactions.push(
            Transaction({to: _to, value: _value, data: _data, executed: false})
        );
        emit Submit(transactions.length - 1);
    }

    function approve(uint256 _txId)
        external
        onlyOwner
        txExists(_txId)
        notApproved(_txId)
        notExecuted(_txId)
    {
        // 트랜잭션에 서명을 하는 부분 입니다.
        // 일단 onlyOwner를 통해서 지갑를 구성하는 구성원인지를 확인하고
        // txExists를 통해서 해당 트랜잭션이 실존하는지를 확인합니다.
        // 이후 이전에 승인을 한 대상인지를 notApproved를 통해서 검증을 하고
        // notExcuted를 통해서 트랜잭션이 이미 승인이 되었는지를 확인합니다.
        approved[_txId][msg.sender] = true;
        emit Approve(msg.sender, _txId);
    }

    function _getApprovalCount(uint256 _txId) private view returns (uint256) {
        // 이 함수는 승인한 사용자들을 반환하는 함수 입니다.
        // 멀티시그 이기 떄문에 일정부분 이상의 사용자들이 승인을 하였는지 확인하기 위해서 사용합니다.
        uint256 count;
        for (uint256 i; i < owners.length; i++) {
            if (approved[_txId][owners[i]]) {
                count++;
            }
        }
        return count;
    }

    function execute(uint256 _txId)
        external
        txExists(_txId)
        notExecuted(_txId)
    {
        // 일단 먼저 트랜잭션이 조건에 맞는 수보다 더 많이 승인이 되었는지를 확인합니다.
        require(_getApprovalCount(_txId) > required, "approvals < required");
        // 이후 트랜잭션의 상태값을 변경하고
        Transaction storage transaction = transactions[_txId];
        transaction.executed = true;

        // 보통은 abi.encodeWithSignature를 통해서 특정 함수를 실행시키기도 하지만
        // 다른 함수를 실행시킬 부분이 없기 떄문에 따로 인코딩을 해주지 않습니다.
        // -> 즉 단순히 transcation.data를 실행시키는 방향으로 진행합니다.
        // 이 부분은 byte코드가 들어오기 떄문에 사실상 이미 인코딩 되어있다고 말할수 있습니다.
        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "tx falied");
        emit Execute(_txId);
    }

    function revoke(uint256 _txId)
        external
        onlyOwner
        txExists(_txId)
        notExecuted(_txId)
    {
        // 그후 트랜잭션이 처리가 되었으니깐 다시 상태르 바꿔줌으로써 동작합니다.
        require(approved[_txId][msg.sender], "tx not approved");
        approved[_txId][msg.sender] = false;
        emit Revoke(msg.sender, _txId);
    }
}
