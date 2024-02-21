// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}

contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        _transferOwnership(_msgSender());
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "New owner is the zero address"
        );
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IERC20Errors {
    error ERC20InsufficientBalance(
        address sender,
        uint256 balance,
        uint256 needed
    );
    error ERC20InvalidSender(address sender);
    error ERC20InvalidReceiver(address receiver);
    error ERC20InsufficientAllowance(
        address spender,
        uint256 allowance,
        uint256 needed
    );
    error ERC20InvalidApprover(address approver);
    error ERC20InvalidSpender(address spender);
}

contract ERC20 is Context, IERC20, IERC20Metadata, IERC20Errors {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        virtual
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 value)
        public
        virtual
        returns (bool)
    {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal virtual {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual {
        if (from == address(0)) {
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                _totalSupply -= value;
            }
        } else {
            unchecked {
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    function _approve(
        address owner,
        address spender,
        uint256 value
    ) internal {
        _approve(owner, spender, value, true);
    }

    function _approve(
        address owner,
        address spender,
        uint256 value,
        bool emitEvent
    ) internal virtual {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 value
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(
                    spender,
                    currentAllowance,
                    value
                );
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}

abstract contract Pausable is Context {
    bool private _paused;
    event Paused(address account);
    event Unpaused(address account);
    error EnforcedPause();
    error ExpectedPause();

    constructor() {
        _paused = false;
    }

    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    modifier whenPaused() {
        _requirePaused();
        _;
    }

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    function _requireNotPaused() internal view virtual {
        if (paused()) {
            revert EnforcedPause();
        }
    }

    function _requirePaused() internal view virtual {
        if (!paused()) {
            revert ExpectedPause();
        }
    }

    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

contract MyVoltToken is ERC20, Ownable, Pausable {

    uint256 public constant MAX_SUPPLY = 1000000000 * 10**18;
    mapping(address => bool) public _isBlacklisted;
    mapping(bytes32 => uint256) public timelock;

    uint256 public constant MIN_DELAY = 60; 
    event ActionScheduled(bytes32 indexed actionId, uint256 targetTime);
    event ActionExecuted(bytes32 indexed actionId);

    address public vestingContract;
    address public stakingContract;
    
    event TokensMintedForEcosystem(address indexed to, uint256 amount);


    constructor(address vestingContract_) ERC20("MyVolt Token", "MVOLT") {
        require(vestingContract_ != address(0), "Invalid Address!");
        vestingContract = vestingContract_;

        _distributeTokens(vestingContract_);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override whenNotPaused {
        require(
            !_isBlacklisted[from] && !_isBlacklisted[to],
            "To Or From Address: Blacklisted!"
        );
        super._transfer(from, to, amount);
    }

    function scheduleAction(bytes32 actionId, uint256 delay)
        internal
        onlyOwner
    {
        require(delay >= MIN_DELAY, "Delay too short");
        uint256 targetTime = block.timestamp + delay;
        timelock[actionId] = targetTime;
        emit ActionScheduled(actionId, targetTime);
    }

    modifier executable(bytes32 actionId) {
        require(
            timelock[actionId] != 0 && timelock[actionId] <= block.timestamp,
            "Action not ready or unknown"
        );
        _;
        delete timelock[actionId];
        emit ActionExecuted(actionId);
    }

    function schedulePause(uint256 delay) external onlyOwner {
        scheduleAction(keccak256("pause"), delay);
    }

    function executePause() external onlyOwner executable(keccak256("pause")) {
        _pause();
    }

    function scheduleUnpause(uint256 delay) external onlyOwner {
        scheduleAction(keccak256("unpause"), delay);
    }

    function executeUnpause()
        external
        onlyOwner
        executable(keccak256("unpause"))
    {
        _unpause();
    }

    function scheduleSetBlacklist(
        address account,
        bool value,
        uint256 delay
    ) external onlyOwner {
        bytes32 actionId = keccak256(
            abi.encodePacked("setBlacklist", account, value)
        );
        scheduleAction(actionId, delay);
    }

    function executeSetBlacklist(address account, bool value)
        external
        onlyOwner
        executable(keccak256(abi.encodePacked("setBlacklist", account, value)))
    {
        _isBlacklisted[account] = value;
    }

    function burn(uint256 amount) public {
        _burn(_msgSender(), amount);
    }

    function burnFrom(address account, uint256 amount) public {
        _spendAllowance(account, _msgSender(), amount);
        _burn(account, amount);
    }

    function getVestingContractAddress() external view returns (address) {
        return vestingContract;
    }

    function setVestingContract(address newContract) external onlyOwner {
        require(newContract != address(0), "Invalid Address!");
        vestingContract = newContract;
    }

    function setStakingContract(address _stakingContract) external onlyOwner {
        require(_stakingContract != address(0), "Invalid Address!");
        stakingContract = _stakingContract;
    }

    function withdraw(address recipient, uint256 amount) external onlyOwner {
        require(recipient != address(0), "Invalid Address!");
        (bool sent, ) = recipient.call{value: amount}("");
        require(sent, "Failed to send Ether");
    }

    function _distributeTokens(address vestingContractAddress) private {
        //uint256 theToken = 1e18;

        // Seed Sale
        _mint(vestingContractAddress, 30000000 * 10 ** 18);

        // Public Sale
        _mint(vestingContractAddress, 90000000 * 10 ** 18);

        // Team
        _mint(vestingContractAddress, 100000000 * 10 ** 18);

        // Treasury
        _mint(vestingContractAddress, 280000000 * 10 ** 18);

        // Marketing
        _mint(vestingContractAddress, 85000000 * 10 ** 18);

        // Advisors
        _mint(vestingContractAddress, 55000000 * 10 ** 18);

        // Liquidity Pool
        _mint(vestingContractAddress, 105000000 * 10 ** 18);
    }

    function _mintForEcosystem() private onlyOwner {
        require(
            stakingContract != address(0),
            "Staking address not set"
        );
        uint256 ecosystemAmount = 255000000 * 10 ** 18; 
        _mint(stakingContract, ecosystemAmount);
        emit TokensMintedForEcosystem(stakingContract, ecosystemAmount);
    }

    function mintTokensForEcosystem() external onlyOwner {
        _mintForEcosystem();
    }
}
