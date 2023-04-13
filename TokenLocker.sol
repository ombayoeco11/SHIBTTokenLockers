// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract TokenLocker is Context {
    using EnumerableSet for EnumerableSet.UintSet;

    struct TokenLock {
        address owner;
        address token;
        uint256 amount;
        uint256 unlockTime;
    }

    event TokensLocked(address indexed owner, address indexed token, uint256 amount, uint256 unlockTime);
    event TokensWithdrawn(address indexed owner, address indexed token, uint256 amount);

    uint256 public nextLockId;
    mapping (uint256 => TokenLock) public tokenLocks;
    mapping (address => EnumerableSet.UintSet) private userLocks;

    function lockTokens(address _token, uint256 _amount, uint256 _unlockTime) external returns (uint256 lockId) {
        require(_unlockTime > block.timestamp, "TokenLocker: unlock time must be in the future");
        require(_amount > 0, "TokenLocker: amount must be greater than 0");

        lockId = nextLockId;
        nextLockId++;

        TokenLock storage tokenLock = tokenLocks[lockId];
        tokenLock.owner = _msgSender();
        tokenLock.token = _token;
        tokenLock.amount = _amount;
        tokenLock.unlockTime = _unlockTime;

        userLocks[_msgSender()].add(lockId);

        IERC20(_token).transferFrom(_msgSender(), address(this), _amount);

        emit TokensLocked(_msgSender(), _token, _amount, _unlockTime);
    }

    function withdrawTokens(uint256 _lockId) external {
        TokenLock storage tokenLock = tokenLocks[_lockId];
        require(tokenLock.owner == _msgSender(), "TokenLocker: sender is not the lock owner");
        require(tokenLock.unlockTime <= block.timestamp, "TokenLocker: tokens are still locked");

        userLocks[_msgSender()].remove(_lockId);

        uint256 amount = tokenLock.amount;
        tokenLock.amount = 0;

        IERC20(tokenLock.token).transfer(tokenLock.owner, amount);

        emit TokensWithdrawn(tokenLock.owner, tokenLock.token, amount);
    }

    function getUserLockIds(address _user) external view returns (uint256[] memory lockIds) {
        uint256 userLockCount = userLocks[_user].length();
        lockIds = new uint256[](userLockCount);

        for (uint256 i = 0; i < userLockCount; i++) {
            lockIds[i] = userLocks[_user].at(i);
        }
    }

    function getLock(uint256 _lockId) external view returns (TokenLock memory tokenLock) {
        return tokenLocks[_lockId];
    }

    function getLockIdsLength() external view returns (uint256) {
        return nextLockId;
    }
}
