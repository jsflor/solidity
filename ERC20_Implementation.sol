// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract MyCustomToken is IERC20 {
    string public name = "MyCustomToken";
    string public symbol = "MCT";
    uint public decimals = 0; // 18 is the common standard
    uint public override totalSupply;

    address public founder;

    mapping(address => uint) public balances;

    // 0x111... (owner) allows 0x222... (the spender) to use 100 tokens
    // allowed[0x111][0x222] = 100;
    mapping(address => mapping(address => uint)) public allowed;

    constructor() {
        totalSupply = 1000000;
        founder = msg.sender;
        balances[founder] = totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return balances[account];
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        require(balances[msg.sender] >= amount);

        balances[recipient] += amount;
        balances[msg.sender] -= amount;

        emit Transfer(msg.sender, recipient, amount);

        return true;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return allowed[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        require(balances[msg.sender] >= amount);
        require(amount > 0);

        allowed[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        require(allowed[sender][recipient] >= amount);
        require(balances[sender] >= amount);

        balances[sender] -= amount;
        balances[recipient] += amount;
        allowed[sender][recipient] -= amount;

        return true;
    }
}

contract MyCustomTokenICO is MyCustomToken {
    address public admin;
    address payable public deposit;
    uint public tokenPrice = 0.001 ether; // 1ETH = 1000MCT, 1MCT = 0.001ETH
    uint public hardCap = 300 ether;
    uint public raisedAmount;
    uint public saleStart = block.timestamp; // Will start when deployed
    uint public saleEnd = block.timestamp + 604800; // ICO ends in one week
    uint public tokenTradeStart = saleEnd + 604800; // transferable in a week after sales end
    uint public maxInvestment = 5 ether;
    uint public minInvestment = 0.1 ether;

    enum State {BeforeStart, Running, AfterEnd, Halted}
    State public icoState;

    constructor(address payable _deposit) {
      deposit = _deposit;
      admin = msg.sender;
      icoState = State.BeforeStart;
    }

    modifier onlyAdmin() {
      require(msg.sender == admin);
      _;
    }

    function halt() public onlyAdmin {
      icoState = State.Halted;
    }

    function resume() public onlyAdmin {
      icoState = State.Running;
    }

    function changeDepositAddress(address payable newDeposit) public onlyAdmin {
      deposit = newDeposit;
    }

    function getCurrentState() public view returns (State) {
      if (icoState == State.Halted) {
        return State.Halted;
      } else if (block.timestamp < saleStart) {
        return State.BeforeStart;
      } else if (block.timestamp >= saleStart && block.timestamp <= saleEnd) {
        return State.Running;
      } else {
        return State.AfterEnd;
      }
    }

    event Invest(address investor, uint value, uint tokens);

    function invest() public payable returns (bool) {
      icoState = getCurrentState();
      require(icoState == State.Running);
      require(msg.value >= minInvestment && msg.value <= maxInvestment);

      raisedAmount += msg.value;
      require(raisedAmount <= hardCap);

      uint tokens = msg.value / tokenPrice;

      balances[msg.sender] += tokens;
      balances[founder] -= tokens;
      deposit.transfer(msg.value);

      emit Invest(msg.sender, msg.value, tokens);

      return true;
    }

    receive() payable external {
      invest();
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
      require(block.timestamp > tokenTradeStart);
      MyCustomToken.transfer(recipient, amount); // same as super.transfer(recipient, amount)
      return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
      require(block.timestamp > tokenTradeStart);
      MyCustomToken.transferFrom(sender, recipient, amount); // same as super.transferFrom(sender, recipient, amount)
      return true;
    }

    function burn() public returns (bool) {
      icoState = getCurrentState();
      require(icoState == State.AfterEnd);
      balances[founder] = 0;
      return true;
    }
}
