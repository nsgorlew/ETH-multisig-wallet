//SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

contract MultiSigWallet {
    event Deposit(address indexed sender, uint amount);
    event Submit(uint indexed txId);
    event Approve(address indexed owner, uint indexed txId);
    event Revoke(address indexed owner, uint indexed txId);
    event Execute(uint indexed txId);

    //define transaction struct
    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
    }

    //owners will be in an array
    address[] public owners;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }
    
    //check that transaction exists

    modifier txExists(uint _txId) {
        require(_txId < transactions.length, "tx does not exist");
        _;
    }

    //keep track of transaction statuses
    
    modifier notApproved(uint _txId) {
        require(!approved[_txId][msg.sender],"tx already approved");
        _;
    }

    modifier notExecuted(uint _txId) {
        require(!transactions[_txId].executed,"tx already executed");
        _;
    }

    //mapping to see if owner
    mapping(address => bool) public isOwner;
    
    //number of approvers before transaction can be executed
    uint public required;

    //define array of transactions
    Transaction[] public transactions;
    
    //mapping of approved transactions
    mapping(uint => mapping(address => bool)) public approved;

	//constructor takes array of owner addresses and number of required owners for signing
    constructor(address[] memory _owners, uint _required) {
    
        //owner requirements
        require(_owners.length > 0, "owners required");
        require(_required > 0 && _required <= _owners.length, "not enough owners");

		//verify integrity of the array given to the constructor
        for (uint i; i < owners.length; i++) {
            address owner = _owners[i];
            //prevent repeats
            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner is not unique");

            //push to owners array
            isOwner[owner] = true;
            owners.push(owner);

            required = _required;
        }
    }

    //constructor(address[] memory _owners, uint _required) {
        //owners = _owners;
        //owners.push(msg.sender); 
        //required = _required;
    //}

	//receive funds in the wallet
    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

	//submit transaction to transactions array
	//only an owner can call
    function submit(address _to, uint _value, bytes calldata _data)
        external onlyOwner {
            transactions.push(Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false
            }));
            emit Submit(transactions.length - 1);
    }

	//approve a transaction, only callable by an owner
    function approve(uint _txId) external onlyOwner 
        txExists(_txId)
        notApproved(_txId)
        notExecuted(_txId)
    {
        approved[_txId][msg.sender] = true;
        emit Approve(msg.sender, _txId);
    }

	//get count of approved transactions from approved array
    function _getApprovalCount(uint _txId) private view returns(uint count) {
        for (uint i; i<owners.length; i++) {
            if (approved[_txId][owners[i]]) {
                count += 1;
            }
        }
    }

	//execute a transaction
	//transaction must exist (checked with txExists)
	//transaction must not have been already executed (checked with notExecuted)
    function execute(uint _txId) external txExists(_txId) notExecuted(_txId) {
        //the transaction must have been approved by the predetermined number of owners of the wallet
		require(_getApprovalCount(_txId) >= required, "approvals < required");
        Transaction storage transaction = transactions[_txId];

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);

        require(success, "tx failed");

        emit Execute(_txId);
    }

	//revoke a transaction that has not already been executed
    function revoke(uint _txId) external onlyOwner 
        txExists(_txId) 
        notExecuted(_txId) 
    {
        require(approved[_txId][msg.sender], "tx not approved");
        approved[_txId][msg.sender] = false;
        emit Revoke(msg.sender, _txId);
    }

} 
