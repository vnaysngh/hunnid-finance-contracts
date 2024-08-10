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
    uint256[] public loanIds;

    uint256 public totalLoanCount = 0;
    uint256 public activeLoanCount = 0;
    uint256 public pendingLoanCount = 0;
    uint256 public repaidLoanCount = 0;

    function generateUniqueId() private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, address(this))));
    }

    function createLoan(
        address _owner,
        address _borrowToken,
        address _collateralToken,
        uint256 _borrowAmount,
        uint256 _collateralAmount,
        uint _rate,
        uint _duration,
        uint256 _startDate,
        uint256 _endDate
    ) public returns (uint256) {
        uint256 loanId = generateUniqueId();
        
        require(_endDate > block.timestamp, 'The endDate should be a date in future');

        // Check allowance for collateral token
        IERC20 collateralToken = IERC20(_collateralToken);
        uint256 allowance = collateralToken.allowance(msg.sender, address(this));
        require(allowance >= _collateralAmount, "Insufficient allowance for collateral");

        // Transfer collateral to the contract
        require(collateralToken.transferFrom(msg.sender, address(this), _collateralAmount), "Collateral transfer failed");

        // Create and store the loan directly
        loans[loanId] = Loan(
            loanId,
            _owner,
            address(0), // lender not set yet
            _borrowToken,
            _collateralToken,
            _borrowAmount,
            _collateralAmount,
            _rate,
            _duration,
            _startDate,
            _endDate,
            LoanStatus.Pending
        );

        loanIds.push(loanId);
        totalLoanCount++;
        pendingLoanCount++;

        return loanId;
    }

   function approveAndPayLoan(uint256 _id, address _owner, uint256 _amount) public {
        Loan storage loan = loans[_id];

        require(loan.id != 0, "Loan does not exist");
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

    function repayLoan(uint256 _id) public payable {
        Loan storage loan = loans[_id];

        require(loan.id != 0, "Loan does not exist");
        require(loan.status == LoanStatus.Active, "Loan is not active");

        IERC20 borrowToken = IERC20(loan.borrowToken);
        require(borrowToken.transferFrom(msg.sender, loan.lender, loan.borrowAmount), "Failed to transfer borrow tokens");

        loan.status = LoanStatus.Repaid;
        repaidLoanCount++;
        activeLoanCount--;

        // Unlock collateral and return it to the borrower
        IERC20 collateralToken = IERC20(loan.collateralToken);
        require(collateralToken.transfer(loan.owner, loan.collateralAmount), "Failed to return collateral");
    }

    function getLoanCounts() public view returns (uint256, uint256, uint256, uint256) {
        return (totalLoanCount, activeLoanCount, pendingLoanCount, repaidLoanCount);
    }

    function getLoans() public view returns (Loan[] memory){
         Loan[] memory allLoans = new Loan[](totalLoanCount);

        for(uint i = 0; i < loanIds.length; i++) {
            allLoans[i] = loans[loanIds[i]];
        }

        return allLoans;
    }

    function getUserLoans(address _owner) public view returns (Loan[] memory) {
        uint userLoanCount = 0;
        for (uint i = 0; i < loanIds.length; i++) {
            if (loans[loanIds[i]].owner == _owner) {
                userLoanCount++;
            }
        }

        Loan[] memory userLoans = new Loan[](userLoanCount);
        uint index = 0;

        for (uint i = 0; i < loanIds.length; i++) {
            if (loans[loanIds[i]].owner == _owner) {
                userLoans[index] = loans[loanIds[i]];
                index++;
            }
        }

        return userLoans;
    }

    function deleteLoan(uint256 _id, address _owner) public {
         Loan storage loan = loans[_id];

        require(loan.id != 0, "Loan does not exist");
        require(loan.status == LoanStatus.Pending, "Loan is not pending");
        require(loan.owner == _owner, "Only the loan owner can delete this loan");

        // Return collateral to the borrower
        IERC20 collateralToken = IERC20(loan.collateralToken);
        require(collateralToken.transfer(loan.owner, loan.collateralAmount), "Failed to return collateral");

        // Remove the loan ID from the loanIds array
        for (uint i = 0; i < loanIds.length; i++) {
            if (loanIds[i] == _id) {
                loanIds[i] = loanIds[loanIds.length - 1];
                loanIds.pop();
                break;
            }
        }

        delete loans[_id];

        // Update loan counts
        pendingLoanCount--;
        totalLoanCount--;
    }
}