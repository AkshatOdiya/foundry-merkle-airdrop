// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {SimpleToken} from "../src/s1mpleToken.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DeployMerkleAirdrop is Script {
    bytes32 public ROOT = 0xaa5d581231e596618465a56aa0f5870ba6e20785fe436d5bfb82b08662ccc7c4;
    uint256 public constant AMOUNT_TO_TRANSFER = 4 * 25 * 1e18;

    function run() external returns (MerkleAirdrop airdrop, SimpleToken token) {
        vm.startBroadcast();
        token = new SimpleToken();
        airdrop = new MerkleAirdrop(ROOT, token);
        token.mint(token.owner(), AMOUNT_TO_TRANSFER); // This contract is owner as it is deploying token, airdrop
        token.transfer(address(airdrop), AMOUNT_TO_TRANSFER); // transfer to airdrop so that claimers can claim from it
        vm.stopBroadcast();
    }
}
