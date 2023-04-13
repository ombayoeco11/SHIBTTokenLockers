// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract TokenLocker is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // Define _lockIdCounter as a state variable
    uint256 private _lockIdCounter;
    

    // Lock structure
    struct TokenLock {
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
    
    TokenLock[] private _locks;
    mapping(address => uint256[]) private _userLockIds;
    mapping(address => bool) private _whitelistedTokens;
    mapping(address => bool) private _whitelistedLPs;
    mapping(address => bool) public whitelistedTokens;
    address public owner;

    modifier onlyOwner {
    require(msg.sender == owner, "Only the contract owner can call this function");
    _;
    }
    modifier onlyWhitelistedToken(address token) {
    require(whitelistedTokens[token], "TokenLocker: Token not whitelisted");
    _;
    }
    modifier onlyWhitelistedLP(address lp) {
    require(_whitelistedLPs[lp], "TokenLocker: LP token not whitelisted");
    _;
}
function _getNextLockId() internal returns (uint256) {
    return _lockIdCounter.current();
}
    
    constructor() {
    owner = msg.sender;
    }
    event LockAdded(uint256 indexed id, address token, address owner, uint256 amount, uint256 unlockDate);
    event LockRemoved(uint256 indexed id, address token, address owner, uint256 amount, uint256 unlockedAt);
    event LockUpdated(uint256 indexed id, address token, address owner, uint256 newAmount, uint256 newUnlockDate);
    event WhitelistedTokenAdded(address indexed token);
    event WhitelistedTokenRemoved(address indexed token);
    event WhitelistedLPAdded(address indexed lp);
    event WhitelistedLPRemoved(address indexed lp);




    /**
* @dev Adds a token to the whitelist.
* Can only be called by the owner.
* @param token Address of the token to be added.
*/
function addWhitelistedToken(address token) external onlyOwner {
    require(token != address(0), "TokenLocker: Token address cannot be zero.");
    require(!whitelistedTokens[token], "TokenLocker: Token is already whitelisted.");
    
    whitelistedTokens[token] = true;
    emit WhitelistedTokenAdded(token);
}
   /**
* @dev Removes a token from the whitelist.
* Can only be called by the owner.
* @param token Address of the token to be removed.
*/
function removeWhitelistedToken(address token) external onlyOwner {
    require(whitelistedTokens[token], "TokenLocker: Token is not whitelisted.");
    whitelistedTokens[token] = false;
    delete whitelistedTokens[token];
    emit WhitelistedTokenRemoved(token);
}
    /**
* @dev Adds an LP token to the whitelist.
* Can only be called by the owner.
* @param lp Address of the LP token to be added.
*/
function addWhitelistedLP(address lp) external onlyOwner {
    require(lp != address(0), "TokenLocker: LP address cannot be zero.");
    require(!_whitelistedLPs[lp], "TokenLocker: LP token is already whitelisted.");
    
    _whitelistedLPs[lp] = true;
    emit WhitelistedLPAdded(lp);
}
    /**
* @dev Removes an LP token from the whitelist.
* Can only be called by the owner.
* @param lp Address of the LP token to be removed.
*/
function removeWhitelistedLP(address lp) external onlyOwner {
    require(_whitelistedLPs[lp], "TokenLocker: LP token is not whitelisted.");
    
    delete _whitelistedLPs[lp];
    emit WhitelistedLPRemoved(lp);
}
    function lockTokens(address token, uint256 amount, uint256 unlockDate) external onlyWhitelistedToken(token) whenNotPaused nonReentrant returns (uint256) {
    require(amount > 0, "TokenLocker: cannot lock 0 amount");
    require(unlockDate > block.timestamp, "TokenLocker: unlock date must be in the future");

    uint256 lockId = _getNextLockId();
    uint256 lockAmount = IERC20(token).balanceOf(address(this));
    IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

    _locks[lockId] = TokenLock({
        id: lockId,
        token: token,
        owner: msg.sender,
        amount: amount,
        unlockDate: unlockDate,
        unlocked: false,
        vestingDuration: 0,
        vestingCliff: 0,
        lastClaimedAt: 0
    });

    _userLockIds[msg.sender].push(lockId);
    _tokenLocks[token].push(lockId);
    emit LockAdded(lockId, token, msg.sender, amount, unlockDate);

    _lockIdCounter.increment();
    return lockId;
}

function lockLP(address lp, uint256 amount, uint256 unlockDate) external onlyWhitelistedLP(lp) whenNotPaused nonReentrant returns (uint256) {
    require(amount > 0, "TokenLocker: cannot lock 0 amount");
    require(unlockDate > block.timestamp, "TokenLocker: unlock date must be in the future");

    uint256 lockId = _getNextLockId();
    uint256 lockAmount = IERC20(lp).balanceOf(address(this));
    IERC20(lp).safeTransferFrom(msg.sender, address(this), amount);

    _locks[lockId] = Lock({
        id: lockId,
        token: lp,
        owner: msg.sender,
        amount: amount,
        unlockDate: unlockDate,
        unlocked: false,
        vestingDuration: 0,
        vestingCliff: 0,
        lastClaimedAt: 0
    });

    _userLockIds[msg.sender].push(lockId);
    _tokenLocks[lp].push(lockId);
    emit LockAdded(lockId, lp, msg.sender, amount, unlockDate);

    _lockIdCounter.increment();
    return lockId;
}
    function lockTokensWithVesting(address token, uint256 amount, uint256 unlockDate, uint256 vestingDuration, uint256 vestingCliff) external nonReentrant returns (uint256) {
    require(whitelistedTokens[token], "Token not whitelisted");
    require(unlockDate > block.timestamp, "Unlock date must be in the future");
    require(amount > 0, "Amount must be greater than zero");
    require(vestingDuration > 0, "Vesting duration must be greater than zero");
    require(vestingCliff <= unlockDate, "Vesting cliff must be less than or equal to unlock date");

    uint256 id = nextLockId;
    nextLockId++;

    TokenLock memory lock = TokenLock({
        id: id,
        token: token,
        owner: msg.sender,
        amount: amount,
        unlockDate: unlockDate,
        vestingDuration: vestingDuration,
        vestingCliff: vestingCliff,
        lockedAt: block.timestamp,
        withdrawnAmount: 0
    });

    locks.push(lock);
    userLocks[msg.sender].push(id);

    // Transfer the tokens to this contract
    require(IERC20(token).transferFrom(msg.sender, address(this), amount), "Transfer failed");

    emit LockAdded(id, token, msg.sender, amount, unlockDate);
    return id;
}

function lockLPWithVesting(address lp, uint256 amount, uint256 unlockDate, uint256 vestingDuration, uint256 vestingCliff) external nonReentrant returns (uint256) {
    require(whitelistedLPs[lp], "LP not whitelisted");
    require(unlockDate > block.timestamp, "Unlock date must be in the future");
    require(amount > 0, "Amount must be greater than zero");
    require(vestingDuration > 0, "Vesting duration must be greater than zero");
    require(vestingCliff <= unlockDate, "Vesting cliff must be less than or equal to unlock date");

    uint256 id = nextLockId;
    nextLockId++;

    TokenLock memory lock = TokenLock({
        id: id,
        token: lp,
        owner: msg.sender,
        amount: amount,
        unlockDate: unlockDate,
        vestingDuration: vestingDuration,
        vestingCliff: vestingCliff,
        lockedAt: block.timestamp,
        withdrawnAmount: 0
    });

    locks.push(lock);
    userLocks[msg.sender].push(id);

    // Transfer the LP tokens to this contract
    require(IERC20(lp).transferFrom(msg.sender, address(this), amount), "Transfer failed");

    emit LockAdded(id, lp, msg.sender, amount, unlockDate);
    return id;
}
    function extendLock(uint256 lockId, uint256 newUnlockDate) external nonReentrant {
    require(newUnlockDate > block.timestamp, "New unlock date must be in the future");
    require(lockId < nextLockId, "Invalid lock ID");

    TokenLock storage lock = locks[lockId];
    require(lock.owner == msg.sender, "Only the lock owner can extend the unlock date");
    require(lock.unlockDate < newUnlockDate, "New unlock date must be after the current unlock date");

    lock.unlockDate = newUnlockDate;

    emit LockUpdated(lockId, lock.token, lock.owner, lock.amount, newUnlockDate);
}
    function increaseLockAmount(uint256 lockId, uint256 amount) external nonReentrant {
        require(_locks[lockId].id != 0, "TokenLockers: lock does not exist");

        Lock storage lock = _locks[lockId];
        require(msg.sender == lock.owner, "TokenLockers: sender is not lock owner");

        uint256 newAmount = lock.amount.add(amount);
        require(newAmount <= IERC20(lock.token).balanceOf(address(this)), "TokenLockers: insufficient balance");

        lock.amount = newAmount;

        emit LockUpdated(lock.id, lock.token, lock.owner, lock.amount, lock.unlockDate);
    }

    function releaseTokens(uint256 lockId) external nonReentrant {
        require(_locks[lockId].id != 0, "TokenLockers: lock does not exist");

        Lock storage lock = _locks[lockId];
        require(msg.sender == lock.owner, "TokenLockers: sender is not lock owner");
        require(block.timestamp >= lock.unlockDate, "TokenLockers: lock is not expired");

        uint256 amount = lock.amount;
        lock.amount = 0;

        IERC20(lock.token).safeTransfer(msg.sender, amount);

        emit LockRemoved(lock.id, lock.token, lock.owner, amount, block.timestamp);
    }

    function releaseLP(uint256 lockId) external nonReentrant {
        require(_locks[lockId].id != 0, "TokenLockers: lock does not exist");

        Lock storage lock = _locks[lockId];
        require(msg.sender == lock.owner, "TokenLockers: sender is not lock owner");
        require(block.timestamp >= lock.unlockDate, "TokenLockers: lock is not expired");

        uint256 amount = lock.amount;
        lock.amount = 0;

        ILPToken(lock.token).burn(amount);
        IERC20(lock.token).safeTransfer(msg.sender, amount);

        emit LockRemoved(lock.id, lock.token, lock.owner, amount, block.timestamp);
    }

    function getLocksLength() external view returns (uint256) {
        return _locks.length;
    }

    function getUserLocks(address user) external view returns (uint256[] memory) {
        uint256[] memory userLocks = new uint256[](getUserLocksCount(user));
        uint256 counter = 0;
        for (uint256 i = 0; i < _locks.length; i++) {
            if (_locks[i].owner == user) {
                userLocks[counter] = _locks[i].id;
                counter++;
            }
        }
        return userLocks;
    }

    function getLock(uint256 lockId) external view returns (TokenLock memory) {
        require(_locks[lockId].id != 0, "TokenLockers: lock does not exist");
        return _locks[lockId];
    }
}
