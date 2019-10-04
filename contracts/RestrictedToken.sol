pragma solidity ^0.5.8;

import "./ITransferRules.sol";
import "./TransferRules.sol";
import "@openzeppelin/contracts/access/Roles.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract RestrictedToken {
  using SafeMath for uint256;

  string public symbol;
  string public name;
  uint8 public decimals;
  uint256 public totalSupply;
  ITransferRules public transferRules;

  using Roles for Roles.Role;
  Roles.Role private contractAdmins;
  Roles.Role private transferAdmins;

  mapping(address => uint256) private balances;
  mapping(address => mapping(address => uint256)) private allowed;
  mapping(address => mapping(address => uint8)) private approvalNonces;  

  // transfer restriction storage
  uint256 public constant MAX_UINT = ((2 ** 255 - 1) * 2) + 1; // get max uint256 without overflow
  mapping(address => uint256) public maxBalances;
  mapping(address => uint256) public timeLocks; // unix timestamp to lock funds until
  mapping(address => uint256) public transferGroups; // restricted groups like Reg S, Reg D and Reg CF
  mapping(uint256 => mapping(uint256 => uint256)) private allowGroupTransfers; // approve transfers between groups: from => to => TimeLockUntil
  mapping(address => bool) public frozenAddresses;
  bool public isPaused = false;

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
  
  event RoleChange(address indexed grantor, address indexed grantee, string role, bool indexed status);
  event AddressMaxBalance(address indexed admin, address indexed account, uint256 indexed value);
  event AddressTimeLock(address indexed admin, address indexed account, uint256 indexed value);
  event AddressTransferGroup(address indexed admin, address indexed account, uint256 indexed value);
  event AddressFrozen(address indexed admin, address indexed account, bool indexed status);
  
  event AllowGroupTransfer(address indexed admin, uint256 indexed fromGroup, uint256 indexed toGroup, uint256 lockedUntil);

  event Mint(address indexed admin, address indexed account, uint256 indexed value);
  event Burn(address indexed admin, address indexed account, uint256 indexed value);
  event Pause(address admin, bool status);
  event Upgrade(address admin, address oldRules, address newRules);

  constructor(
    address _transferRules,
    address _contractAdmin,
    address _tokenReserveAdmin,
    string memory _symbol,
    string memory _name,
    uint8 _decimals,
    uint256 _totalSupply
  ) public {

    require(_contractAdmin != address(0), "Token owner address cannot be 0x0");

    // transfer rules can be swapped out
    // the storage stays in the ERC20
    transferRules = ITransferRules(_transferRules);
    symbol = _symbol;
    name = _name;
    decimals = _decimals;

    contractAdmins.add(_contractAdmin);

    balances[_tokenReserveAdmin] = _totalSupply;
    totalSupply = balances[_tokenReserveAdmin];
  }

  modifier onlyContractAdmin() {
    require(contractAdmins.has(msg.sender), "DOES NOT HAVE CONTRACT OWNER ROLE");
    _;
  }

   modifier onlyTransferAdmin() {
    require(transferAdmins.has(msg.sender), "DOES NOT HAVE TRANSFER ADMIN ROLE");
    _;
  }

  modifier onlyTransferAdminOrContractAdmin() {
    require((contractAdmins.has(msg.sender) || transferAdmins.has(msg.sender)),
    "DOES NOT HAVE TRANSFER ADMIN OR CONTRACT ADMIN ROLE");
    _;
  }

  function grantTransferAdmin(address account) onlyContractAdmin public {
    transferAdmins.add(account);
    emit RoleChange(msg.sender, account, "TransferAdmin", true);
  }

  function revokeTransferAdmin(address account) onlyContractAdmin public {
    transferAdmins.remove(account);
    emit RoleChange(msg.sender, account, "TransferAdmin", false);
  }

    function grantContractAdmin(address account) onlyContractAdmin public {
    contractAdmins.add(account);
    emit RoleChange(msg.sender, account, "ContractAdmin", true);
  }

  function revokeContractAdmin(address account) onlyContractAdmin public {
    contractAdmins.remove(account);
    emit RoleChange(msg.sender, account, "ContractAdmin", false);
  }

  function enforceTransferRestrictions(address from, address to, uint256 value) public view {
    uint8 restrictionCode = detectTransferRestriction(from, to, value);
    require(transferRules.checkSuccess(restrictionCode), transferRules.messageForTransferRestriction(restrictionCode));
  }

  function detectTransferRestriction(address from, address to, uint256 value) public view returns(uint8) {
    return transferRules.detectTransferRestriction(address(this), from, to, value);
  }

  function messageForTransferRestriction(uint8 restrictionCode) public view returns(string memory) {
    return transferRules.messageForTransferRestriction(restrictionCode);
  }

  function setMaxBalance(address account, uint256 updatedValue) public onlyTransferAdmin {
    maxBalances[account] = updatedValue;
    emit AddressMaxBalance(msg.sender, account, updatedValue);
  }

  function getMaxBalance(address account) public view returns(uint256) {
    return maxBalances[account];
  }

  function setTimeLock(address account, uint256 timestamp) public onlyTransferAdmin {
    timeLocks[account] = timestamp;
    emit AddressTimeLock(msg.sender, account, timestamp);
  }

  function removeTimeLock(address account) public onlyTransferAdmin {
    timeLocks[account] = 0;
    emit AddressTimeLock(msg.sender, account, 0);
  }

  function getTimeLock(address account) public view returns(uint256) {
    return timeLocks[account];
  }

  function setTransferGroup(address addr, uint256 groupID) public onlyTransferAdmin {
    transferGroups[addr] = groupID;
    emit AddressTransferGroup(msg.sender, addr, groupID);
  }

  function getTransferGroup(address addr) public view returns(uint256 groupID) {
    return transferGroups[addr];
  }

  function freeze(address addr, bool status) public onlyTransferAdminOrContractAdmin {
    frozenAddresses[addr] = status;
    emit AddressFrozen(msg.sender, addr, status);
  }

  function frozen(address addr) public view returns(bool) {
    return frozenAddresses[addr];
  }

  function setAddressPermissions(address addr, uint256 groupID, uint256 timeLockUntil, uint256 maxTokens, bool status) public onlyTransferAdmin {
    setTransferGroup(addr, groupID);
    setTimeLock(addr, timeLockUntil);
    setMaxBalance(addr, maxTokens);
    freeze(addr, status);
  }

  // TODO: if lockedUntil = 0 no transfer; update README
  // TODO: if lockedUntil = 1 any transfer works; update README
  function setAllowGroupTransfer(uint256 groupA, uint256 groupB, uint256 lockedUntil) public onlyTransferAdmin {
    allowGroupTransfers[groupA][groupB] = lockedUntil;
    emit AllowGroupTransfer(msg.sender, groupA, groupB, lockedUntil);
  }

  // note the transfer time default is 0 for transfers between all addresses
  // a transfer time of 0 is treated as not allowed
  function getAllowTransferTime(address from, address to) public view returns(uint timestamp) {
    return allowGroupTransfers[transferGroups[from]][transferGroups[to]];
  }

  function getAllowGroupTransferTime(uint from, uint to) public view returns(uint timestamp) {
    return allowGroupTransfers[from][to];
  }

  function burnFrom(address from, uint256 value) public onlyContractAdmin {
    require(value <= balances[from], "Insufficent tokens to burn");
    balances[from] = balances[from].sub(value);
    totalSupply = totalSupply.sub(value);
    emit Burn(msg.sender, from, value);
  }

  function mint(address to, uint256 value) public onlyContractAdmin  {
    balances[to] = balances[to].add(value);
    totalSupply = totalSupply.add(value);
    emit Mint(msg.sender, to, value);
  }

  function pause() public onlyContractAdmin() {
    isPaused = true;
    emit Pause(msg.sender, true);
  }

  function unpause() public onlyContractAdmin() {
    isPaused = false;
    emit Pause(msg.sender, false);
  }

  function upgradeTransferRules(ITransferRules newTransferRules) public onlyContractAdmin {
    address oldRules = address(transferRules);
    transferRules = newTransferRules;
    emit Upgrade(msg.sender, oldRules, address(newTransferRules));
  }

  /******* ERC20 FUNCTIONS ***********/

  function balanceOf(address owner) public view returns(uint256 balance) {
    return balances[owner];
  }

  function allowance(address owner, address spender) public view returns(uint256 remaining) {
    return allowed[owner][spender];
  }

  function transfer(address to, uint256 value) public returns(bool success) {
    enforceTransferRestrictions(msg.sender, to, value);
    _transfer(msg.sender, to, value);
    return true;
  }

  /*  IT IS RECOMMENDED THAT YOU USE THE safeApprove() FUNCTION INSTEAD OF approve() TO AVOID A TIMING ISSUES WITH THE ERC20 STANDARD.
      The approve function implements the standard to maintain backwards compatibility with ERC20.
      Read more about the race condition exploit of approve here https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   */
  function approve(address spender, uint256 value) public returns(bool success) {
    return _approve(spender, value);
  }

  // Use safeApprove() instead of approve() to avoid the race condition exploit which is a known security hole in the ERC20 standard
  function safeApprove(address spender, uint256 newApprovalValue, uint256 expectedApprovedValue, uint8 nonce) public
  returns(bool success) {
    require(expectedApprovedValue == allowed[msg.sender][spender],
      "The expected approved amount does not match the actual approved amount");
      
    require(nonce == approvalNonces[msg.sender][spender], "The nonce does not match the current transfer approval nonce");
    return _approve(spender, newApprovalValue);
  }

  // gets the current allowed transfers for a sender and receiver along with the spender's nonce
  function allowanceAndNonce(address spender) external view returns(uint256 spenderAllowance, uint8 nonce) {
    uint256 _allowance = allowed[msg.sender][spender];
    uint8 _nonce = approvalNonces[msg.sender][spender];
    return (_allowance, _nonce);
  }

  function transferFrom(address from, address to, uint256 value) public returns(bool success) {
    enforceTransferRestrictions(from, to, value);
    require(value <= allowed[from][to], "The approved allowance is lower than the transfer amount");
    allowed[from][msg.sender] = allowed[from][msg.sender].sub(value);
    _transfer(from, to, value);
    return true;
  }

  /********** INTERNAL FUNCTIONS **********/

  function _approve(address spender, uint256 value) internal returns(bool success) {
    // use a nonce to enforce expected approval amounts for the approve and safeApprove functions
    approvalNonces[msg.sender][spender]++; // intentional allowance for an overflow
    allowed[msg.sender][spender] = value;
    emit Approval(msg.sender, spender, value);
    return true;
  }

  // if you call this function call forceRestriction before it
  function _transfer(address from, address to, uint256 value) internal {
    require(value <= balances[from], "Insufficent tokens");
    balances[from] = balances[from].sub(value);
    balances[to] = balances[to].add(value);
    emit Transfer(from, to, value);
  }
}