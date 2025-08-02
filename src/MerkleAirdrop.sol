// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MerkleAirdrop is EIP712 {
    // To easily use the SafeERC20 library functions on our IERC20 token instance, we use the using for directive at the contract level:
    // This directive attaches the functions from SafeERC20 (like safeTransfer) to any variable of type IERC20.
    using SafeERC20 for IERC20;

    error MerkleAirdrop__InvalidProof();
    error MerkleAirdrop__AccountHasAlreadyClaimedOnce();
    error MerkleAirdrop__InvalidSignature();

    event AccountClaimed(address indexed user, uint256 indexed amount);

    address[] claimers;
    bytes32 private immutable i_merkleRoot; // storing the merkle root
    IERC20 private immutable i_airdropToken;
    mapping(address claimer => bool hasClaimed) private s_checkClaimed;

    bytes32 private constant MESSAGE_TYPEHASH = keccak256("AirdropClaim(address account,uint256 amount)");

    struct AirdropClaim {
        address account;
        uint256 amount;
    }

    constructor(bytes32 merkleRoot, IERC20 airdropToken) EIP712("MerkleAirdrop", "1") {
        i_merkleRoot = merkleRoot;
        i_airdropToken = airdropToken;
    }

    // CEI Pattern
    // This function allows eligible users to claim the token
    function claim(address account, uint256 amount, bytes32[] calldata merkleProof, uint8 v, bytes32 r, bytes32 s)
        external
    {
        // CHECK if already claimed
        if (s_checkClaimed[account]) {
            revert MerkleAirdrop__AccountHasAlreadyClaimedOnce();
        }
        if (!_isValidSignature(account, getMessageHash(account, amount), v, r, s)) {
            revert MerkleAirdrop__InvalidSignature();
        }

        /*
        To verify a claim, the contract must first reconstruct the leaf node hash that corresponds to the claimant's data (account and amount). 
        This on-chain calculated leaf hash will then be used with the provided merkleProof to see if it computes back to the known i_merkleRoot
         */
        /*
        keccak256 expects bytes as input. 
        The result of the first hash is bytes32. bytes.concat() is used to convert this bytes32 back into a bytes type suitable for the next hashing step
        When we are using merkle proofs, hashing two times prevents collision -->  Second Preimage Attack
        bytes.concat is used to convert bytes32 (fixed-size) into bytes (dynamic) for hashing.
        Direct bytes(...) casting is not allowed in Solidity, and abi.encode would add length-prefix data.
        */
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));

        // CHECK Merkle proof
        if (!MerkleProof.verify(merkleProof, i_merkleRoot, leaf)) {
            revert MerkleAirdrop__InvalidProof();
        }

        // EFFECT - update state
        s_checkClaimed[account] = true;

        // INTERACTION - external call

        //  Logging Claims with Events
        emit AccountClaimed(account, amount);

        // Securely Transferring Tokens with SafeERC20
        // safeTransfer ensure the underlying ERC20 call reverts if it's unsuccessful.
        i_airdropToken.safeTransfer(account, amount);
    }

    function getMessageHash(address account, uint256 amount) public view returns (bytes32) {
        return
            _hashTypedDataV4(keccak256(abi.encode(MESSAGE_TYPEHASH, AirdropClaim({account: account, amount: amount}))));
    }

    function getMerkleRoot() external view returns (bytes32) {
        return i_merkleRoot;
    }

    function getAirdropToken() external view returns (IERC20) {
        return i_airdropToken;
    }

    function _isValidSignature(address account, bytes32 digest, uint8 v, bytes32 r, bytes32 s)
        internal
        pure
        returns (bool)
    {
        (address actualSigner,,) = ECDSA.tryRecover(digest, v, r, s);
        return actualSigner == account;
    }
}
