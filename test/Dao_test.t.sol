// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Cat} from "src/Cat.sol";
import {GovToken} from "src/GovToken.sol";
import {TimeLock} from "src/TimeLock.sol";
import {MyGovernor} from "src/MyGovernor.sol";

contract DaoTest is Test {
    /* State Variables */
    uint256 public constant INITIAL_SUPPLY = 100 ether;
    uint256 public constant MIN_DELAY = 3600; // 1 hour
    uint256 public constant MIN_VOTING_DELAY = 1; // 1 block
    uint256 public constant MIN_VOTING_PERIOD = 50400; // 1 week
    uint256 [] public values;

    address public immutable i_user = makeAddr("user");
    address [] proposers;
    address [] executors;
    address [] targets;

    bytes [] public calldatas;

    Cat private cat;
    GovToken private govToken;
    TimeLock private timeLock;
    MyGovernor private governor;

    /* Functions */
    /* Public Functions */
    function setUp() public {
        govToken = new GovToken();
        govToken.mint(i_user, INITIAL_SUPPLY);

        vm.startPrank(i_user);
        govToken.delegate(i_user);
        timeLock = new TimeLock(MIN_DELAY, proposers, executors);
        governor = new MyGovernor(govToken, timeLock);

        bytes32 proposerRole = timeLock.PROPOSER_ROLE();
        bytes32 executorRole = timeLock.EXECUTOR_ROLE();
        bytes32 adminRole = timeLock.DEFAULT_ADMIN_ROLE();

        timeLock.grantRole(proposerRole, address(governor));
        timeLock.grantRole(executorRole, address(0));
        timeLock.revokeRole(adminRole, i_user);
        vm.stopPrank();

        cat = new Cat();
        cat.transferOwnership(address(timeLock));
    }

    /* Test Functions */
    function test_CantUpdateBoxWithoutGovernance() public {
        vm.expectRevert();
        cat.store(1);
    }

    function test_GovernanceUpdatesBox() public {
        uint256 valueToStore = 888;
        string memory discription = "Store 888 in the Cat";
        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);

        values.push(0);
        calldatas.push(encodedFunctionCall);
        targets.push(address(cat));

        // 1. Propose to the DAO
        uint256 proposalId = governor.propose(targets, values, calldatas, discription);

        // 2. View the proposal state
        console.log("----------------------------------------------------------------------------------------------");
        console.log("   Proposal State: ", uint256(governor.state(proposalId)));
        console.log("----------------------------------------------------------------------------------------------");

        vm.warp(block.timestamp + MIN_VOTING_DELAY + 1);
        vm.roll(block.number + MIN_VOTING_DELAY + 1);

        // 3. Vote on the proposal
        /**
         * @dev Vote type is [Against, For, Abstain] thier uint8 values are [0, 1, 2]
         */
        uint8 voteType = 1; // For
        string memory reason = "LLoymen...";
        
        vm.prank(i_user);
        governor.castVoteWithReason(proposalId, voteType, reason);

        vm.warp(block.timestamp + MIN_VOTING_PERIOD + 1);
        vm.roll(block.number + MIN_VOTING_PERIOD + 1);
        console.log("----------------------------------------------------------------------------------------------");
        console.log("   Proposal State: ", uint256(governor.state(proposalId)));
        console.log("----------------------------------------------------------------------------------------------");

        // 4. Queue the proposal
        bytes32 descriptionHash = keccak256(abi.encodePacked(discription));
        governor.queue(targets, values, calldatas, descriptionHash);

        console.log("----------------------------------------------------------------------------------------------");
        console.log("   Proposal State: ", uint256(governor.state(proposalId)));
        console.log("----------------------------------------------------------------------------------------------");

        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        // 5. Execute the proposal
        governor.execute(targets, values, calldatas, descriptionHash);

        console.log("----------------------------------------------------------------------------------------------");
        console.log("   Proposal State: ", uint256(governor.state(proposalId)));
        console.log("----------------------------------------------------------------------------------------------");

        // ASSERT
        assertEq(cat.getNumber(), valueToStore);
        console.log("----------------------------------------------------------------------------------------------");
        console.log("   Cat Number      : ", cat.getNumber());
        console.log("   Expected Number : ", valueToStore);
        console.log("----------------------------------------------------------------------------------------------");

    }

}