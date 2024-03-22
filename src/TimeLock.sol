// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract TimeLock is TimelockController {
    // minDelay is how long you have to wait before executing
    // proposers is the list of addresses that can propose
    // executors is the list of address that can execute
    constructor(uint256 minDelay, address[] memory proposers, address[] memory executors)
        /**
         * - `minDelay`: initial minimum delay in seconds for operations
         * - `proposers`: accounts to be granted proposer and canceller roles
         * - `executors`: accounts to be granted executor role
         * - `admin`: optional account to be granted admin role; disable with zero address
         */
        TimelockController(minDelay, proposers, executors, msg.sender)
    {}
}
