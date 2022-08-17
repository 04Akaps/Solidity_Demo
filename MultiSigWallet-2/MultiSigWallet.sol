pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;

contract MultiSigWallet {
 
    mapping(address => bool) proposer;

    address[] totalProposer;
    address payable private master;

    struct Transaction {
        address payable destination;
        uint256 value;
        bytes data;
        bool executed;
    }

    Transaction[] public transactions;

    modifier onlyProposer() {
        require(proposer[msg.sender], "Error : Not Owner!");
        _;
    }

    modifier txExists(uint256 _txId) {
        require(
            _txId < transactions.length,
            "Error : Transcation is Not Exist"
        );
        _;
    }

    modifier notExcuted(uint256 _txId) {
        require(!transactions[_txId].executed, "Error: tx already Excuted");
        _;
    }

    modifier onlyMaster() {
        require(msg.sender == master, "Error : msg.sender is Not Master");
        _;
    }

    modifier onlyMultiSig() {
        require(msg.sender == address(this), "Error : Not MultiSig Contract");
        _;
    }

    modifier checkTransaction(
        address _destination,
        bytes memory _data,
        uint256 _value
    ) {
        require(
            _destination != address(0x0),
            "Error : destination is Zero Address"
        );

        if (_data.length < 1) {
            require(
                _value > 1,
                "Error : transaction is Send klay But data is Existed"
            );
        }

        _;
    }

    constructor(address[] memory _proposerList) public {
        for (uint256 i = 0; i < _proposerList.length; i++) {
            require(
                !proposer[_proposerList[i]] && _proposerList[i] != address(0x0),
                "Error : ownerList Error"
            );
            proposer[_proposerList[i]] = true;
        }

        totalProposer = _proposerList;
        master = msg.sender;
    }

    function() external payable {}

    function deposit() public payable {
        address(this).transfer(msg.value);
    }

    function addProposer(address _newOwner) public onlyMaster {
        require(!proposer[_newOwner], "Error : already in OwnerMap");
        proposer[_newOwner] = true;
    }

    function deleteProposer(address _deletedOwner) public onlyMaster {
        require(proposer[_deletedOwner], "Error : Not In OwnerMap");
        proposer[_deletedOwner] = false;
    }

    function submit(
        address payable _destination,
        bytes calldata _data,
        uint256 _value
    ) external onlyProposer checkTransaction(_destination, _data, _value) {
        transactions.push(
            Transaction({
                destination: _destination,
                value: _value,
                data: _data,
                executed: false
            })
        );
    }

    function excute(uint256 _txIndex)
        external
        txExists(_txIndex)
        notExcuted(_txIndex)
        onlyMaster
    {
        Transaction storage transaction = transactions[_txIndex];

        if (transaction.data.length < 1) {
            // 일반적인 Klay를 다른 Pool에 전송 하는 경우
            uint256 beforeBalance = address(this).balance;

            require(
                beforeBalance >= transaction.value,
                "Error : Not Enough Klay"
            );

            transaction.destination.transfer(transaction.value);
        } else {
            // data가 있는 경우
            bool success = _external_call(
                transaction.destination,
                transaction.value,
                transaction.data.length,
                transaction.data
            );
            require(success, "Error : Failed Transaction");
        }

        transaction.executed = true;
    }

    function putToDeath(uint256 _txId)
        external
        txExists(_txId)
        notExcuted(_txId)
        onlyMaster
    {
        delete transactions[_txId];
        // transaction을 제거하면 배열을 정렬 해주면 됩니다.
    }

    function submitByMaster(
        address payable _destination,
        bytes calldata _data,
        uint256 _value
    ) external onlyMaster checkTransaction(_destination, _data, _value) {
        if (_data.length < 1) {
            // data를 0x를 넣어주었을떄 작동하는 경우
            //  Klay를 다른 Pool에 전송
            uint256 beforeBalance = address(this).balance;

            require(beforeBalance >= _value, "Error : Not Enough Klay");

            _destination.transfer(_value);
        } else {
            bool success = _external_call(
                _destination,
                _value,
                _data.length,
                _data
            );
            require(success, "Error : Failed Transaction");
        }
    }

    function _external_call(
        address destination,
        uint256 value,
        uint256 dataLength,
        bytes memory data
    ) internal returns (bool) {
        bool result;
        assembly {
            let x := mload(0x40)
            let d := add(data, 32)
            result := call(
                sub(gas, 34710),
                destination,
                value,
                d,
                dataLength,
                x,
                0
            )
        }
        return result;
    }

    function viewTransaction(uint256 _txIndex)
        external
        view
        returns (Transaction memory)
    {
        return transactions[_txIndex];
    }

    function viewTotalTransactions()
        external
        view
        returns (Transaction[] memory)
    {
        return transactions;
    }

    function viewbalance() external view returns (uint256) {
        return address(this).balance;
    }
}
