// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IERC20 {
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
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
            "Ownable: new owner is the zero address"
        );
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract StakingContract is Ownable, ReentrancyGuard {
    IERC20 public stakingToken;
    bool public emergencyStop = false;

    struct Stake {
        uint256 amount;
        uint256 startTime;
        uint256 endTime;
        bool unstaked;
    }

    mapping(address => Stake) public stakes;
    uint256 public constant DAILY_RATE_6_MONTHS = 12 ether; //12% APY
    uint256 public constant DAILY_RATE_12_MONTHS = 14 ether; // 14% APY
    uint256 public constant UNSTAKING_PERIOD = 10 days;

    event Staked(
        address indexed user,
        uint256 amount,
        uint256 startTime,
        uint256 endTime
    );
    event Unstaked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event EmergencyStopToggled(bool emergencyState);

    constructor(IERC20 _stakingToken) {
        stakingToken = _stakingToken;
    }

    modifier whenNotStopped() {
        require(!emergencyStop, "Emergency stop is active!");
        _;
    }

    function toggleEmergencyStop() external onlyOwner {
        emergencyStop = !emergencyStop;
        emit EmergencyStopToggled(emergencyStop);
    }

    function restartContract() external onlyOwner {
        require(emergencyStop, "Emergency stop is not active");
        emergencyStop = false;
        emit EmergencyStopToggled(emergencyStop);
    }

    function stake(uint256 _amount, uint256 _duration) external whenNotStopped {
        require(_amount > 0, "Cannot stake 0");
        require(
            _duration == 180 days || _duration == 360 days,
            "Invalid staking duration"
        );

        stakingToken.transferFrom(msg.sender, address(this), _amount);

        stakes[msg.sender] = Stake({
            amount: _amount,
            startTime: block.timestamp,
            endTime: block.timestamp + _duration,
            unstaked: false
        });

        emit Staked(
            msg.sender,
            _amount,
            block.timestamp,
            block.timestamp + _duration
        );
    }

    function unstake() external nonReentrant whenNotStopped {
        Stake storage userStake = stakes[msg.sender];
        require(userStake.amount > 0, "No staked amount");
        require(
            block.timestamp >= userStake.endTime + UNSTAKING_PERIOD,
            "Stake is locked!"
        );
        require(!userStake.unstaked, "Already unstaked!");

        uint256 reward = calculateReward(msg.sender);
        userStake.unstaked = true;

        stakingToken.transfer(msg.sender, userStake.amount + reward);

        emit Unstaked(msg.sender, userStake.amount + reward);
    }

    function withdraw() external nonReentrant whenNotStopped {
        Stake storage userStake = stakes[msg.sender];
        require(userStake.amount > 0, "No staked amount");
        require(userStake.unstaked, "Stake is not unstaked");

        uint256 amountToWithdraw = userStake.amount;
        userStake.amount = 0;

        stakingToken.transfer(msg.sender, amountToWithdraw);

        emit Withdrawn(msg.sender, amountToWithdraw);
    }

    function calculateReward(address _user) public view returns (uint256) {
        Stake memory userStake = stakes[_user];
        if (userStake.unstaked) return 0;

        uint256 durationInDays = (
            block.timestamp > userStake.endTime
                ? userStake.endTime
                : block.timestamp
        ) - userStake.startTime / 1 days;
        uint256 rate = userStake.endTime - userStake.startTime <= 180 days
            ? DAILY_RATE_6_MONTHS
            : DAILY_RATE_12_MONTHS;

        uint256 reward = ((userStake.amount * rate) / 365 ether) *
            durationInDays;

        return reward;
    }
}
