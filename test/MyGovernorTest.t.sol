// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {Box} from "../src/Box.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {GovToken} from "../src/GovToken.sol";

contract MyGovernorTest is Test {
	MyGovernor governor;
	Box box;
	TimeLock timelock;
	GovToken govToken;

	address public USER = makeAddr("user");
	uint256 public constant INITIAL_SUPPLY = 100 ether;
	uint256 public constant MIN_DELAY = 3600;	    // 1 hour - after a vote passes (nobody can execute to pass a proposal until an hour goes by)
    uint256 public constant VOTING_DELAY = 1;       // how many blocks till a voting is active (we decided this value on Contract Wizard of Zeppelin)
    uint256 public constant VOTING_PERIOD = 50400;  // 1 week (we decided this value on Contract Wizard of Zeppelin)

	address[] proposers;
	address[] executors;
    uint256[] values;
    bytes[] calldatas;
    address[] targets;

	function setUp() public {
        // To generate governer, we need 1-Token 2-Timelock
		govToken = new GovToken();
		govToken.mint(USER, INITIAL_SUPPLY);	// Having 100 ether doesnt mean that much of voting power yet

		vm.startPrank(USER);
		govToken.delegate(USER);				// Delegate those 100 ether voting power to USER
		timelock = new TimeLock(MIN_DELAY, proposers, executors);
		governor = new MyGovernor(govToken, timelock);

		// These ..._ROLE are hashes in the timelock [https://docs.openzeppelin.com/defender/v2/guide/timelock-roles]
		bytes32 proposerRole = timelock.PROPOSER_ROLE();		// this is in charge of queueing operations
		bytes32 executorRole = timelock.EXECUTOR_ROLE();		// an address (smart contract or EOA) that is in charge of executing operations once the timelock has expired
        //bytes32 adminRole = timelock.TIMELOCK_ADMIN_ROLE();	// this can grant and revoke the two above roles

		timelock.grantRole(proposerRole, address(governor));	// only the Governor can propose stuff to the timelock 
		timelock.grantRole(executorRole, address(0));			// assign this role to the special zero address to allow anyone to execute
		//timelock.revokeRole(adminRole, USER);					// this is a very sensitive role that will be granted automatically to the timelock itself
		vm.stopPrank();

		box = new Box(address(timelock));		// It's the timelock that gets the ultimate say on where all stuff goes
	}

	function testCantUpdateBoxWithoutGovernance() public {
		vm.expectRevert();
		// it will revert because timelock is the owner of the box and there is no vm.prank(address(timelock)) called
        box.store(1);
	}

    function testGovernanceUpdatesBox() public {
        /* We are going to propose that the box updates the stored value to 888. */

        uint256 valueToStore = 888;
        string memory description = "store 1 in Box";
        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);

        values.push(0);
        calldatas.push(encodedFunctionCall);    // function call -> store(888)
        targets.push(address(box));             // the contract from which the function will be called -> box.store(888)

        /* 1. Propose to the DAO */
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        // View the state of the proposal
        console.log("Proposal State: ", uint256(governor.state(proposalId)));
        vm.warp(block.timestamp + VOTING_DELAY + 1);    // Time required for your vote is visible passed
        vm.roll(block.number + VOTING_DELAY + 1);
        console.log("Proposal State: ", uint256(governor.state(proposalId)));

        /* 2. Vote */
        string memory reason = "cuz blue frog is cool";
        uint8 voteWay = 1;  // voting yes
        vm.prank(USER);     // our voter is USER
        governor.castVoteWithReason(proposalId, voteWay, reason);

        vm.warp(block.timestamp + VOTING_PERIOD + 1);   // Time required for the voting is open passed
        vm.roll(block.number + VOTING_PERIOD + 1);

        /* 3. Queue the TX  */
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queue(targets, values, calldatas, descriptionHash);    // Must be the same variables used for proposal

        vm.warp(block.timestamp + MIN_DELAY + 1);   // After a vote passes, we need to wait MIN_DELAY before we can execute
        vm.roll(block.number + MIN_DELAY + 1);

        /* 4. Execute   */
        governor.execute(targets, values, calldatas, descriptionHash);  // Must be the same variables used for proposal

        assert(box.getNumber() == valueToStore);
        console.log("Box value: ", box.getNumber());
    }
}