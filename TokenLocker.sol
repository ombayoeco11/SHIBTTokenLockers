pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TokenLocker is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Lock structure
    struct Lock {
        uint256 id;
        address token;
        address owner;
        uint256 amount;
        uint256 unlockDate;
        bool isLP;
        bool isVesting;
        uint256 vestingDuration;
        uint256 vestingCliff;
    }

    // Lock ID padding, as there is a lack of a pausing mechanism
    // as of now the lastest id from v1 is about 22K, so this is probably a safe padding value.
    uint256 private constant ID_PADDING = 1_000_000;

    Lock[] private _locks;
    mapping(address => uint256[]) private _userLockIds;
    mapping(address => bool) private _whitelistedTokens;
    mapping(address => bool) private _whitelistedLPs;

    event LockAdded(uint256 indexed id, address token, address owner, uint256 amount, uint256 unlockDate);
    event LockRemoved(uint256 indexed id, address token, address owner, uint256 amount, uint256 unlockedAt);
    event LockUpdated(uint256 indexed id, address token, address owner, uint256 newAmount, uint256 newUnlockDate);
    event WhitelistedTokenAdded(address indexed token);
    event WhitelistedTokenRemoved(address indexed token);
    event WhitelistedLPAdded(address indexed lp);
    event WhitelistedLPRemoved(address indexed lp);

    function addWhitelistedToken(address token) external;
    function removeWhitelistedToken(address token) external;
    function addWhitelistedLP(address lp) external;
    function removeWhitelistedLP(address lp) external;
    function lockTokens(address token, uint256 amount, uint256 unlockDate) external nonReentrant returns (uint256);
    function lockLP(address token, uint256 amount, uint256 unlockDate) external nonReentrant returns (uint256);
    function lockTokensWithVesting(address token, uint256 amount, uint256 unlockDate, uint256 vestingDuration, uint256 vestingCliff) external nonReentrant returns (uint256);
    function lockLPWithVesting(address lp, uint256 amount, uint256 unlockDate, uint256 vestingDuration, uint256 vestingCliff) external nonReentrant returns (uint256);
    function extendLock(uint256 lockId, uint256 newUnlockDate) external nonReentrant;
    function increaseLockAmount(uint256 lockId, uint256 amount) external nonReentrant;
    function releaseTokens(uint256 lockId) external nonReentrant;
    function releaseLP(uint256 lockId) external nonReentrant;
    function getLocksLength() external view returns (uint256);
    function getUserLocks(address user) external view returns (uint256[] memory);
    function getLock(uint256 lockId) external view returns (Lock memory);
}
