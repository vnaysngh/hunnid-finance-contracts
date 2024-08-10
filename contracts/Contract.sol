// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

enum LoanStatus { Pending, Active, Repaid }

contract HunnidFinance {
    // constructor() {}
    struct Loan {
        uint256 id;
        address owner;
        address lender; 
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
            uint256 loanId = generateUniqueId();
            // is everything ok?
            require(_endDate > block.timestamp, 'The endDate should be a date in future');

            // Check allowance for collateral token
            IERC20 collateralToken = IERC20(_collateralToken);
            uint256 allowance = collateralToken.allowance(msg.sender, address(this));
            require(allowance >= _collateralAmount, "Insufficient allowance for collateral");

            // Transfer collateral to the contract
            require(collateralToken.transferFrom(msg.sender, address(this), _collateralAmount), "Collateral transfer failed");

            Loan storage loan = loans[totalLoanCount];
            
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

   function approveAndPayLoan(uint256 _id, address _owner, uint256 _amount) public {
        Loan storage loan = loans[_id];

        require(loan.status == LoanStatus.Pending, "Loan is not pending");

        IERC20 borrowToken = IERC20(loan.borrowToken);

        // Check lender's balance
        uint256 balance = borrowToken.balanceOf(msg.sender);
        require(balance >= _amount, "Insufficient balance to fund the loan");

        // Ensure that allowance is sufficient
        uint256 allowance = borrowToken.allowance(msg.sender, address(this));
        require(allowance >= _amount, "Insufficient allowance to transfer tokens");

        // Attempt the transfer
        require(borrowToken.transferFrom(msg.sender, _owner, _amount), "Failed to transfer borrow tokens");

        loan.lender = msg.sender; // Set the lender's address
        loan.status = LoanStatus.Active;
        activeLoanCount++;
        pendingLoanCount = totalLoanCount - activeLoanCount - repaidLoanCount;
    }


    //repay loan
    function repayLoan(uint256 _id) public payable {
        Loan storage loan = loans[_id];

        require(loan.status == LoanStatus.Active, "Loan is not active");

        IERC20 borrowToken = IERC20(loan.borrowToken);
        require(borrowToken.transferFrom(msg.sender, loan.lender, loan.borrowAmount), "Failed to transfer borrow tokens");

        loan.status = LoanStatus.Repaid;
        repaidLoanCount++;
        activeLoanCount --;

              // Unlock collateral and return it to the borrower
        IERC20 collateralToken = IERC20(loan.collateralToken);
        require(collateralToken.transfer(loan.owner, loan.collateralAmount), "Failed to return collateral");
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
        Loan storage loan = loans[_id];

        require(loans[_id].status != LoanStatus.Repaid, "Cannot delete a repaid loan");
        require(loans[_id].status == LoanStatus.Pending, "Loan is not pending");
        require(loans[_id].owner == _owner, "Only the loan owner can delete this loan");

        // Return collateral to the borrower
        IERC20 collateralToken = IERC20(loan.collateralToken);
        require(collateralToken.transfer(loan.owner, loan.collateralAmount), "Failed to return collateral");

        delete loans[_id];

        // Update loan counts
        pendingLoanCount--;
        totalLoanCount--;
    }

}