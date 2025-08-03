// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";
import {SimpleToken} from "../src/s1mpleToken.sol";
import {ZkSyncChainChecker} from "lib/foundry-devops/src/ZkSyncChainChecker.sol";
import {DeployMerkleAirdrop} from "../script/DeployMerkleAirdrop.s.sol";

contract MerkleAirdropTest is ZkSyncChainChecker, Test {
    MerkleAirdrop public airdrop;
    SimpleToken public token;

    bytes32 public ROOT = 0xaa5d581231e596618465a56aa0f5870ba6e20785fe436d5bfb82b08662ccc7c4;
    uint256 public AMOUNT = 25 * 1e18;
    bytes32[] public PROOF = [
        bytes32(0x0fd7c981d39bece61f7499702bf59b3114a90e66b51ba2c53abdf7b62986c00a),
        bytes32(0xe5ebd1e1b5a5478a944ecab36a9a954ac3b6b8216875f6524caa7a1d87096576)
    ]; // these proofs are corresponding to the address by makeAddrAndKey('user'), see in output.json
    // we cleverly formulated the address like so that Proofs and address can be used in testing

    address public gasPayer;
    address user;
    uint256 userPrivKey;

    /**
     * @notice Important Note on ZKsync Compatibility (why we need conditional statements in setUp())
     * It's worth noting that Foundry script functionalities, particularly for deployments, might have limitations or behave differently on specialized
     * Layer 2 environments like ZKsync, especially at certain points in their development lifecycle. The conditional logic (isZkSyncChain()) in the test setup
     * serves as a practical workaround, allowing the use of scripts for standard EVM environments while falling back to manual deployment methods for ZKsync.
     * If your project exclusively targets standard EVM-compatible chains, this conditional logic might not be necessary, and the deployment script can be used directly in all test setups.
     */
    function setUp() public {
        if (!isZkSyncChain()) {
            // This check is from ZkSyncChainChecker

            // Deploy with the script
            DeployMerkleAirdrop deployer = new DeployMerkleAirdrop();
            (airdrop, token) = deployer.run();
        } else {
            // Original manual deployment for ZKsync environments (or other specific cases)
            token = new SimpleToken();
            // Ensure 'ROOT' here is consistent with s_merkleRoot in the script
            airdrop = new MerkleAirdrop(ROOT, token);
            token.mint(token.owner(), AMOUNT * 4); // This contract is owner as it is deploying token, airdrop
            token.transfer(address(airdrop), AMOUNT * 4); // transfer to airdrop so that claimers can claim from it
        }
        (user, userPrivKey) = makeAddrAndKey("user");
        gasPayer = makeAddr("gasPayer");
    }

    function testUsersCanClaim() public {
        uint256 startingBalance = token.balanceOf(user);
        bytes32 digest = airdrop.getMessageHash(user, AMOUNT);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivKey, digest);
        vm.prank(gasPayer);
        airdrop.claim(user, AMOUNT, PROOF, v, r, s);

        uint256 endingBalance = token.balanceOf(user);
        assertEq(endingBalance - startingBalance, AMOUNT);
    }
}
