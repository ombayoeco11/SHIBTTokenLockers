// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";


contract TokenLocker is Context, Ownable, Pausable {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct TokenLock {
        uint256 id;
        address owner;
        address token;
        uint256 amount;
        uint256 unlockDate;
        bool claimed;
    }


    
    event TokensLocked(address indexed owner, address indexed token, uint256 amount, uint256 unlockDate, uint256 id);
    event TokensClaimed(address indexed owner, address indexed token, uint256 amount, uint256 id);
    event LockExtended(address indexed owner, address indexed token, uint256 amount, uint256 unlockDate, uint256 id);
    event TokensRetrieved(address indexed owner, address indexed token, uint256 amount, uint256 id);
    event WrongTokensRetrieved(address indexed owner, address indexed token, uint256 amount);

    uint256 public nextLockId;

    mapping(address => EnumerableSet.AddressSet) private _userLocks;
    mapping(address => uint256[]) private _tokenLocks;
    mapping(uint256 => TokenLock) private _locks;

    constructor() {
        nextLockId = 1;
    }

    // Helper function to get the next lock ID
    function _getNextLockId() private returns (uint256) {
        return nextLockId++;
    }

    function lockTokens(address token, uint256 amount, uint256 unlockDate) public whenNotPaused returns (bool) {
        require(amount > 0, "TokenLocker: Amount must be greater than 0");
        require(unlockDate > block.timestamp, "TokenLocker: Unlock date must be in the future");

        IERC20 erc20 = IERC20(token);
        uint256 allowance = erc20.allowance(_msgSender(), address(this));
        require(allowance >= amount, "TokenLocker: Token allowance too small");

        uint256 lockId = _getNextLockId();
        TokenLock storage lock = _locks[lockId];

        lock.id = lockId;
        lock.owner = _msgSender();
        lock.token = token;
        lock.amount = amount;
        lock.unlockDate = unlockDate;
        lock.claimed = false;

        _userLocks[_msgSender()].add(token);
        _tokenLocks[token].push(lockId);

        erc20.transferFrom(_msgSender(), address(this), amount);

        emit TokensLocked(_msgSender(), token, amount, unlockDate, lockId);

        return true;
    }

    function extendLock(uint256 id, uint256 unlockDate) public whenNotPaused returns (bool) {
        require(_locks[id].owner == _msgSender(), "TokenLocker: Only the lock owner can extend the lock");
        require(unlockDate > _locks[id].unlockDate, "TokenLocker: New unlock date must be in the future");

        _locks[id].unlockDate = unlockDate;

        emit LockExtended(_msgSender(), _locks[id].token, _locks[id].amount, unlockDate, id);

        return true;
    }
    function claimTokens(uint256 id) public returns (bool) {
        require(_locks[id].owner == _msgSender(), "TokenLocker: Only the lock owner can claim the tokens");
        require(_locks[id].unlockDate <= block.timestamp, "TokenLocker: Tokens are still locked");
        require(!_locks[id].claimed, "TokenLocker: Tokens already claimed");

        _locks[id].claimed = true;

        IERC20 erc20 = IERC20(_locks[id].token);
        erc20.transfer(_msgSender(), _locks[id].amount);

        emit TokensClaimed(_msgSender(), _locks[id].token, _locks[id].amount, id);

        return true;
    }

    function retrieveTokens(address token, uint256 amount, uint256 id) public onlyOwner returns (bool) {
        require(_locks[id].token == token, "TokenLocker: Token address does not match lock id");
        require(amount > 0, "TokenLocker: Amount must be greater than 0");
        require(_locks[id].amount >= amount, "TokenLocker: Amount must be less than or equal to the locked amount");

        IERC20 erc20 = IERC20(token);
        erc20.transfer(owner(), amount);

        _locks[id].amount -= amount;

        emit TokensRetrieved(owner(), token, amount, id);

        return true;
    }

    function retrieveWrongTokens(address token, uint256 amount) public onlyOwner returns (bool) {
        IERC20 erc20 = IERC20(token);
        erc20.transfer(owner(), amount);

        emit WrongTokensRetrieved(owner(), token, amount);

        return true;
    }

    function lockLiquidity(uint256 amount, uint256 unlockDate) public {
    require(amount > 0, "Amount must be greater than 0");
    require(unlockDate > block.timestamp, "Unlock date must be in the future");

    // Approve the transfer of liquidity tokens to the TokenLocker contract
    require(IERC20(token).approve(address(this), amount), "Failed to approve transfer");

    // Lock the liquidity tokens
    lockTokens(amount, unlockDate);
}

    function getUserLocks(address user) external view returns (address[] memory) {
        uint256 length = _userLocks[user].length();
        address[] memory userLocks = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            userLocks[i] = _userLocks[user].at(i);
        }

        return userLocks;
    }

    function getUserTokenLocks(address user, address token) external view returns (uint256[] memory) {
        uint256 length = _userLocks[user].length();
        uint256[] memory userTokenLocks = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            uint256 lockId = uint256(uint160(_userLocks[user].at(i)));
            if (_locks[lockId].token == token) {
                userTokenLocks[i] = lockId;
            }
        }

        return userTokenLocks;
    }

    function getTokenLocks(address token) external view returns (uint256[] memory) {
        return _tokenLocks[token];
    }

    function getTokenLock(uint256 id) external view returns (TokenLock memory) {
        return _locks[id];
    }


    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

}
