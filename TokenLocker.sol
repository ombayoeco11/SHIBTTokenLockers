// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./SafeERC20.sol";
import "./SafeMath.sol";
import "./Ownable.sol";
import "./ReentrancyGuard.sol";

contract TokenLocker is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct TokenLock {
        uint256 lockId;
        address tokenAddress;
        uint256 amount;
        uint256 unlockTime;
        bool released;
    }

    mapping(address => TokenLock[]) private _userLocks;
    mapping(address => mapping(address => uint256[])) private _tokenLocks;
    uint256 private _lockIdCounter;

    event TokensLocked(uint256 lockId, address indexed tokenAddress, address indexed locker, uint256 amount, uint256 unlockTime);
    event TokensReleased(uint256 lockId, address indexed tokenAddress, address indexed locker, uint256 amount);

    function lockTokens(address tokenAddress, uint256 amount, uint256 unlockTime) external nonReentrant {
        require(amount > 0, "TokenLocker: amount should be greater than 0");
        require(unlockTime > block.timestamp, "TokenLocker: unlockTime should be in the future");
        require(IERC20(tokenAddress).balanceOf(msg.sender) >= amount, "TokenLocker: insufficient balance");

        IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), amount);

        uint256 lockId = _getNextLockId();
        TokenLock memory lock = TokenLock({
            lockId: lockId,
            tokenAddress: tokenAddress,
            amount: amount,
            unlockTime: unlockTime,
            released: false
        });

        _userLocks[msg.sender].push(lock);
        _tokenLocks[tokenAddress][msg.sender].push(lockId);

        emit TokensLocked(lockId, tokenAddress, msg.sender, amount, unlockTime);
    }

    function releaseTokens(uint256 lockId) external nonReentrant {
        TokenLock storage lock = _getLock(lockId);

        require(lock.unlockTime <= block.timestamp, "TokenLocker: tokens are still locked");
        require(!lock.released, "TokenLocker: tokens already released");

        lock.released = true;

        IERC20(lock.tokenAddress).safeTransfer(msg.sender, lock.amount);

        emit TokensReleased(lockId, lock.tokenAddress, msg.sender, lock.amount);
    }

    function getLocksByUser(address user) external view returns (TokenLock[] memory) {
        return _userLocks[user];
    }

    function getLockIdsByToken(address tokenAddress, address user) external view returns (uint256[] memory) {
        return _tokenLocks[tokenAddress][user];
    }

    function getLockById(uint256 lockId) external view returns (TokenLock memory) {
        return _getLock(lockId);
    }

    function _getNextLockId() private returns (uint256) {
        _lockIdCounter++;
        return _lockIdCounter;
    }

    function _getLock(uint256 lockId) private view returns (TokenLock storage) {
        uint256 locksLength = _userLocks[msg.sender].length;
        for (uint256 i = 0; i < locksLength; i++) {
            if (_userLocks[msg.sender][i].lockId == lockId) {
                return _userLocks[msg.sender][i];
            }
        }
        revert("TokenLocker: lock not found");
    }
}
