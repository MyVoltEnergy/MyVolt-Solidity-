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

contract MyVoltVesting is Ownable {
    struct VestingSchedule {
        uint256[] tokensPerCliff;
        uint256[] cliffs;
        uint256 lastCliffClaimed;
    }

    mapping(address => VestingSchedule) private vestingSchedules;

    address public tokenContract;

    constructor() {}

    function getVestingSchedule(address beneficiary)
        external
        view
        returns (VestingSchedule memory)
    {
        return vestingSchedules[beneficiary];
    }

    function addVestingSchedule(
        address[] memory receivers,
        uint256[] memory tokens,
        uint256[] memory cliffs
    ) external onlyOwner {
        require(tokens.length == cliffs.length, "Array sizes do not match!");

        for (uint256 i = 0; i < receivers.length; i++) {
            require(
                vestingSchedules[receivers[i]].tokensPerCliff.length == 0 ||
                    vestingSchedules[receivers[i]].lastCliffClaimed ==
                    vestingSchedules[receivers[i]].cliffs.length,
                "Vesting Schedule already active!"
            );

            vestingSchedules[receivers[i]].tokensPerCliff = tokens;
            vestingSchedules[receivers[i]].cliffs = cliffs;
        }
    }

    function vestedTokensAvailable(address beneficiary)
        external
        view
        returns (uint256)
    {
        (uint256 availableTokens, ) = vestedTokensAvailable_(beneficiary);
        return availableTokens;
    }

    function vestedTokensAvailable_(address beneficiary)
        internal
        view
        returns (uint256, uint256)
    {
        VestingSchedule memory vestingSchedule_ = vestingSchedules[beneficiary];
        uint256 availableTokens;
        uint256 lastCliff = vestingSchedule_.cliffs.length;
        for (
            uint256 i = vestingSchedule_.lastCliffClaimed;
            i < lastCliff;
            i++
        ) {
            if (block.timestamp >= vestingSchedule_.cliffs[i]) {
                availableTokens += vestingSchedule_.tokensPerCliff[i];
            } else {
                lastCliff = i;
                break;
            }
        }

        return (availableTokens, lastCliff);
    }

    function claimVestedTokens(address claimer) external {
        (uint256 availableTokens, uint256 lastCliff) = vestedTokensAvailable_(
            claimer
        );
        require(availableTokens > 0, "No tokens available to claim!");

        vestingSchedules[claimer].lastCliffClaimed = lastCliff;
        require(
            IERC20(tokenContract).transfer(claimer, availableTokens),
            "Unsuccessful Transfer!"
        );
    }

    function setTokenContract(address newContract) external onlyOwner {
        require(newContract != address(0), "Invalid Address!");
        tokenContract = newContract;
    }

    function withdraw(address recipient, uint256 amount) external onlyOwner {
        require(recipient != address(0), "Invalid Address!");

        (bool sent, ) = recipient.call{value: amount}("");
        require(sent, "Failed to send Ether");
    }

    function withdraw(
        address recipient,
        uint256 amount,
        address token
    ) external onlyOwner {
        require(recipient != address(0), "Invalid Address!");
        require(amount > 0, "Invalid Amount!");
        require(token != address(0), "Invalid Token!");

        require(
            IERC20(token).transfer(recipient, amount),
            "Unsuccessful Transfer!"
        );
    }
}
