// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract MultiSigWallet{

    event Deposit(address sender, uint256 value);
    event SubmitTransaction(
        address indexed owner,
        uint indexed txIndex,
        address indexed to,
        uint value,
        bytes data
    );

    event ConfirmTransaction(
        address indexed owner,
        uint indexed txIndex
    );

    event ExecuteTransaction(
        address indexed owner,
        uint indexed txIndex
    );

    event RevokeTransaction(
        address indexed owner,
        uint indexed txIndex
    );

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint numConfirmations;
    }

    Transaction[] public transactions;
    uint numConfirmationRequired;
    address[] public owners;
    mapping(address=>bool) isOwner;
    mapping(uint=>mapping(address=>bool)) public approved;

    modifier onlyOwner(){
        require(isOwner[msg.sender],"Callable for Owner only");
        _;
    }

    modifier txExists(uint _txId){
        require(_txId<transactions.length,"Transaction does not exist");
        _;
    }

    modifier notApproved(uint _txId){
        require(!approved[_txId][msg.sender], "Transaction is already approved");
        _;
    }

    modifier notExecuted(uint _txId){
        require(!transactions[_txId].executed, "Transaction is already executed");
        _;
    }

    modifier sufficientApproved(uint _txId){
        require(transactions[_txId].numConfirmations >= numConfirmationRequired, "Not Enough approvals for execution");
        _;
    }

    constructor(address[] memory _owners, uint _numConfirmationRequired){
        require(_owners.length>0,"Owners required");
        require(_owners.length>=_numConfirmationRequired && _numConfirmationRequired>0, "number of confirmations need to be more than Owners");
        numConfirmationRequired = _numConfirmationRequired;
        for (uint256 index = 0; index < _owners.length; index++) {
            address owner = _owners[index];
            require(owner!=address(0),"Can not be Null address");
            require(!isOwner[owner],"Owner addresses should be unique");


            owners.push(owner);
            isOwner[owner]=true;    
        }
    }

    receive() external payable{
        emit Deposit(msg.sender,msg.value);
    }

    function submitTransaction(address _to, uint _value, bytes calldata _data) external onlyOwner {
        uint txIndex = transactions.length;

        // isConfirmed[msg.sender]=true;
        transactions.push(Transaction({
            to:_to,
            value:_value,
            data:_data,
            executed:false,
            numConfirmations:1
        }));

        emit SubmitTransaction(msg.sender, txIndex-1, _to, _value, _data);
    }
    function confirmTransaction(uint _txId) external onlyOwner txExists(_txId) notApproved(_txId) notExecuted(_txId){
        transactions[_txId].numConfirmations+=1;
        approved[_txId][msg.sender]=true;
        emit ConfirmTransaction(msg.sender, _txId);
    }
    function executeTransaction(uint _txId) external txExists(_txId) notExecuted(_txId) sufficientApproved(_txId){
        Transaction storage transaction = transactions[_txId];
        transaction.executed=true;
        (bool success, ) = transaction.to.call{value:transaction.value}(transaction.data);
        require(success, "tx Failed");
        emit ExecuteTransaction(msg.sender, _txId);
    }

    function revokeTransaction(uint _txId) external txExists(_txId) notExecuted(_txId){
        require(approved[_txId][msg.sender], "tx not approved");
        approved[_txId][msg.sender]=false;
        emit RevokeTransaction(msg.sender, _txId);
    }
}
