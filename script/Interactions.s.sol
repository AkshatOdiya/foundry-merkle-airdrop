// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";

contract ClaimAirdrop is Script {
    error Interactions__InvalidSignatureLength();

    /**
     * @notice If you need to claim for different addresses, you must ensure they were part of the original dataset used to generate the Merkle tree. Modifying the eligible addresses requires:
     * 1. Updating your input generation mechanism (e.g., a GenerateInput.s.sol script).
     *
     * 2. Re-running the input generation script to create a new input.json.
     *
     * 3. Re-running your Merkle tree generation script (e.g., MakeMerkle.s.sol) to create a new output.json containing the new proofs.
     */
    // Hard coded to anvil default account (included in input.json)
    address public constant CLAIMING_ADDRESS = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // Signer of the message(receiver of airdrop)
    uint256 public constant CLAIMING_AMOUNT = 25 * 1e18;
    bytes32[] public PROOF = [
        bytes32(0xd1445c931158119b00449ffcac3c947d028c0c359c34a6646d95962b3b55c6ad),
        bytes32(0xe5ebd1e1b5a5478a944ecab36a9a954ac3b6b8216875f6524caa7a1d87096576)
    ]; // proofs corresponding to CLAIMING_ADDRESS
    bytes private SIGNATURE =
        hex"12e145324b60cd4d302bfad59f72946d45ffad8b9fd608e672fd7f02029de7c438cfa0b8251ea803f361522da811406d441df04ee99c3dc7d65f8550e12be2ca1c"; // hard coded

    function claimAirdrop(address airdrop) public {
        vm.startBroadcast();
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(SIGNATURE);
        MerkleAirdrop(airdrop).claim(CLAIMING_ADDRESS, CLAIMING_AMOUNT / 4, PROOF, v, r, s);
        vm.stopBroadcast();
    }

    /**
     * @notice Splits a 65-byte concatenated signature (r, s, v) into its components
     * @param sig The concatenated signature as bytes.
     * @return v The recovery identifier (1 byte)
     * @return r The r value of the signature (32 bytes)
     * @return s The s value of the signature (32 bytes)
     */
    // Besides vm.sign, we can generate v,r,s from signature by this mechanism
    function splitSignature(bytes memory sig) public pure returns (uint8 v, bytes32 r, bytes32 s) {
        // Standard ECDSA signatures are 65 bytes long:
        // r (32 bytes) + s (32 bytes) + v (1 byte)
        if (sig.length != 65) {
            revert Interactions__InvalidSignatureLength();
        }

        // Accessing bytes data in assembly requires careful memory management.
        // `sig` in assembly points to the length of the byte array.
        // The actual data starts 32 bytes after this pointer.
        assembly {
            // Load the first 32 bytes (r)
            r := mload(add(sig, 32))
            // Load the next 32 bytes (s)
            s := mload(add(sig, 64))
            // Load the last byte (v)
            // v is the first byte of the 32-byte word starting at offset 96 (0x60)
            v := byte(0, mload(add(sig, 96)))
        }
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("MerkleAirdrop", block.chainid);
        claimAirdrop(mostRecentlyDeployed);
    }
}
