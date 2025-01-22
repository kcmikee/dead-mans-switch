// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

contract DeadMansSwitch {
  struct Account {
    uint256 balance;
    uint256 lastCheckIn;
    uint256 checkInInterval;
    address[] beneficiaries;
  }

  mapping(address => Account) private accounts;
  mapping(address => mapping(address => bool)) private isBeneficiary;

  event CheckIn(address account, uint256 timestamp);
  event BeneficiaryAdded(address user, address beneficiary);
  event BeneficiaryRemoved(address user, address beneficiary);
  event Deposit(address depositor, uint256 amount);
  event Withdrawal(address beneficiary, uint256 amount);

  receive() external payable {
    deposit();
  }

  fallback() external payable {
    deposit();
  }

  function setCheckInInterval(
    uint256 interval
  ) external {
    require(interval != 0, " Interval must be greater than 0 ");
    accounts[msg.sender].checkInInterval = interval;
    checkIn();
  }

  function checkIn() public {
    accounts[msg.sender].lastCheckIn = block.timestamp;
    emit CheckIn(msg.sender, block.timestamp);
  }

  function addBeneficiary(
    address beneficiary
  ) external {
    require(beneficiary != address(0), " Invalid beneficiary address ");
    require(!isBeneficiary[msg.sender][beneficiary], " Already a beneficiary ");

    if (accounts[msg.sender].beneficiaries.length == 0) {
      accounts[msg.sender].beneficiaries = new address[](0);
    }

    accounts[msg.sender].beneficiaries.push(beneficiary);
    isBeneficiary[msg.sender][beneficiary] = true;

    emit BeneficiaryAdded(msg.sender, beneficiary);
    checkIn();
  }

  function removeBeneficiary(
    address beneficiary
  ) external {
    require(isBeneficiary[msg.sender][beneficiary], " Not a beneficiary ");

    address[] storage beneficiaries = accounts[msg.sender].beneficiaries;
    for (uint256 i = 0; i < beneficiaries.length; i++) {
      if (beneficiaries[i] == beneficiary) {
        beneficiaries[i] = beneficiaries[beneficiaries.length - 1];
        beneficiaries.pop();
        break;
      }
    }

    isBeneficiary[msg.sender][beneficiary] = false;

    emit BeneficiaryRemoved(msg.sender, beneficiary);
    checkIn();
  }

  function deposit() public payable {
    accounts[msg.sender].balance += msg.value;
    emit Deposit(msg.sender, msg.value);
    checkIn();
  }

  function withdraw(address account, uint256 amount) external {
    require(amount > 0, " Amount must be greater than 0 ");
    require(amount <= accounts[account].balance, " Insufficient balance ");

    bool isOwner = msg.sender == account;
    bool isBeneficiaryAndExpired = isBeneficiary[account][msg.sender]
      && accounts[account].checkInInterval > 0
      && block.timestamp - accounts[account].lastCheckIn
        > accounts[account].checkInInterval;

    require(isOwner || isBeneficiaryAndExpired, " Not authorized ");

    accounts[account].balance -= amount;

    (bool success,) = msg.sender.call{ value: amount }("");
    require(success, " Transfer failed ");

    emit Withdrawal(msg.sender, amount);

    if (isOwner) {
      checkIn();
    }
  }

  function balanceOf(
    address account
  ) external view returns (uint256) {
    return accounts[account].balance;
  }

  function lastCheckIn(
    address account
  ) external view returns (uint256) {
    return accounts[account].lastCheckIn;
  }

  function checkInInterval(
    address account
  ) external view returns (uint256) {
    return accounts[account].checkInInterval;
  }
}
