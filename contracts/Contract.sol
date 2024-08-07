// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

enum LoanStatus { Pending, Active, Repaid }

contract PigPigFinance {
    // constructor() {}
    struct Loan {
        uint256 id;
        address owner;
        address borrowToken;
        address collateralToken;
        uint256 borrowAmount;
        uint256 collateralAmount;
        uint rate;
        uint duration;
        uint256 startDate;
        uint256 endDate;
        LoanStatus status;
    }

    mapping(uint256 => Loan) public loans;

    uint256 public totalLoanCount = 0;
    uint256 public activeLoanCount = 0;
    uint256 public pendingLoanCount = 0;
    uint256 public repaidLoanCount = 0;

    function generateUniqueId() private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, address(this))));
    }


    //create loan
    function createLoan( address _owner,
        address _borrowToken,
        address _collateralToken,
        uint256 _borrowAmount,
        uint256 _collateralAmount,
        uint _rate,
        uint _duration,
        uint256 _startDate,
        uint256 _endDate) public returns (uint256) {
            Loan storage loan = loans[totalLoanCount];
            uint256 loanId = generateUniqueId(); // Unique ID for the new loan

            //is everything ok?
            require(loan.endDate < block.timestamp, 'The endDate should be a date in future');
            
            loan.id = loanId;
            loan.owner = _owner;
            loan.borrowToken = _borrowToken;
            loan.collateralToken = _collateralToken;
            loan.borrowAmount = _borrowAmount;
            loan.collateralAmount = _collateralAmount;
            loan.rate = _rate;
            loan.duration = _duration;
            loan.startDate = _startDate;
            loan.endDate = _endDate;
            loan.status = LoanStatus.Pending;

            totalLoanCount++;
            pendingLoanCount++;

            return loanId;
        }

    //approve and pay loan
    function approveAndPayLoan(uint256 _id) public payable {
            Loan storage loan = loans[_id];
            uint256 amount = loan.borrowAmount;

            require(loan.status == LoanStatus.Pending, "Loan is not pending");

            (bool sent,) = payable(loan.owner).call{value: amount}("");
            require(sent, "Failed to send Ether");

            if(sent) {
                loan.status = LoanStatus.Active;
                activeLoanCount++;
                pendingLoanCount = totalLoanCount -  activeLoanCount - repaidLoanCount;
            }
        }


    //repay loan
    function repayLoan(uint256 _id) public payable {
        uint256 amount = msg.value;
        Loan storage loan = loans[_id];

        require(loan.status == LoanStatus.Active, "Loan is not active");

        (bool sent,) = payable(loan.owner).call{value: amount}("");
        require(sent, "Failed to send Ether");

        if(sent){
            loan.status = LoanStatus.Repaid;
            repaidLoanCount++;
            activeLoanCount --;
        }
    }

     //  all loan counts
    function getLoanCounts() public view returns (uint256, uint256, uint256, uint256) {
        return (totalLoanCount, activeLoanCount, pendingLoanCount, repaidLoanCount);
    }

    // fetch all loans
    function getLoans() public view returns (Loan[] memory){
        Loan[] memory allLoans = new Loan[](totalLoanCount);

        for(uint i=0; i< totalLoanCount; i++){
            Loan storage item = loans[i];
            allLoans[i] = item;
        }

        return allLoans;
    }

    // Get all user loans
    function getUserLoans(address _owner) public view returns (Loan[] memory) {
        
        // First, count the number of loans for the user
        uint userLoanCount = 0;
        for (uint i = 0; i < totalLoanCount; i++) {
            if (loans[i].owner == _owner) {
                userLoanCount++;
            }
        }

        // Create an array of the correct size
        Loan[] memory userLoans = new Loan[](userLoanCount);
        uint index = 0;

        // Populate the userLoans array with the user's loans
        for (uint i = 0; i < totalLoanCount; i++) {
            if (loans[i].owner == _owner) {
                userLoans[index] = loans[i];
                index++;
            }
        }

        return userLoans;
    }

    function deleteLoan(uint256 _id, address _owner) public {
        require(loans[_id].status != LoanStatus.Repaid, "Cannot delete a repaid loan");
        require(loans[_id].status == LoanStatus.Pending, "Loan is not pending");
        require(loans[_id].owner == _owner, "Only the loan owner can delete this loan");

        delete loans[_id];

        // Update loan counts
        pendingLoanCount--;
        totalLoanCount--;
    }

}