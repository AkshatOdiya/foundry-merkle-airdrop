// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @notice The Off-Chain Signing Process
 *
 * With the smart contract ready, the user (or a frontend application acting on their behalf) needs to perform these steps:
 *
 * Determine Claim Details: Identify the user's account, the amount they are eligible for, and their merkleProof.
 *
 * Calculate the Digest: The frontend application will call the getMessage(account, amount) view function on your deployed MerkleAirdrop contract (or replicate its exact EIP-712 hashing logic client-side using libraries like ethers.js or viem). This produces the digest to be signed.
 *
 * Request Signature: The frontend will use a wallet provider (like MetaMask) to request the user to sign this typed data. Wallets that support EIP-712 (e.g., MetaMask via eth_signTypedData_v4) will display the structured AirdropClaim data (account and amount) and the domain information (contract name, version) to the user in a readable format.
 *
 * User Approves: The user reviews the information and approves the signing request in their wallet. The wallet then returns the signature components: v, r, and s.
 *
 * Submit to Relayer: The frontend sends the account, amount, merkleProof, and the signature (v, r, s) to a relayer service.
 *
 * Relayer Executes Claim: The relayer calls the MerkleAirdrop.claim(account, amount, merkleProof, v, r, s) function on the smart contract, paying the gas fee for the transaction.
 */
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

    /**
     * @notice Explanation of getMessage
     *
     * MESSAGE_TYPEHASH: This is keccak256 of the string defining the structure of our AirdropClaim message (e.g., "AirdropClaim(address account,uint256 amount)"). This hash identifies the type of data being signed.
     *
     * AirdropClaim struct: Defines the fields that constitute the message: the claimant's account and the amount they are claiming.
     *
     * constructor: When deploying the contract, we call the EIP712 constructor with a name (e.g., "MerkleAirdrop") and a version (e.g., "1"). This, along with the current chain ID and contract address, forms the domain separator. The domain separator ensures that a signature intended for this contract on this chain cannot be replayed on a different contract or chain.
     *
     * getMessage(address account, uint256 amount):
     *
     * 1. It first creates an instance of AirdropClaim and encodes it along with its MESSAGE_TYPEHASH using abi.encode. The keccak256 of this is the structHash.
     *
     * 2. It then calls _hashTypedDataV4() (a helper from OpenZeppelin's EIP712 contract). This function takes the structHash and combines it with the pre-computed _domainSeparatorV4() (also from EIP712), prefixing it with \x19\x01 as per the EIP-712 specification, to produce the final digest that the user must sign.
     *
     * This function is public view so that off-chain applications (like a frontend) can call it (or replicate its logic) to know exactly what digest the user needs to sign.
     */
    // Function to compute the EIP-712 digest
    function getMessageHash(address account, uint256 amount) public view returns (bytes32) {
        // 1. Hash the struct instance according to EIP-712 struct hashing rules
        // 2. Combine with domain separator using _hashTypedDataV4 from EIP712 contract
        // _hashTypedDataV4 constructs the EIP-712 digest i.e,
        // keccak256(abi.encodePacked("\x19\x01", _domainSeparatorV4(), structHash))
        return
            _hashTypedDataV4(keccak256(abi.encode(MESSAGE_TYPEHASH, AirdropClaim({account: account, amount: amount}))));
    }

    function getMerkleRoot() external view returns (bytes32) {
        return i_merkleRoot;
    }

    function getAirdropToken() external view returns (IERC20) {
        return i_airdropToken;
    }

    /**
     * @notice Explanation of _isValidSignature
     * It takes the expectedSigner (which is the account parameter passed to the claim function), the digest (from getMessage), and the signature components v, r, s.
     *
     * ECDSA.tryRecover(digest, v, r, s): This function from OpenZeppelin's library attempts to recover the public key that produced the signature (v,r,s) for the given digest, and then derives the Ethereum address from that public key.
     *
     * * It's safer than the native ecrecover precompile because it includes checks against certain forms of signature malleability.
     *
     * * If recovery fails (e.g., invalid signature), tryRecover returns address(0) instead of reverting the transaction. This allows our contract to handle the failure gracefully with our custom MerkleAirdrop_InvalidSignature error.
     *
     * The function returns true if and only if a valid signer address was recovered and this recovered address matches the expectedSigner.
     */
    function _isValidSignature(address account, bytes32 digest, uint8 v, bytes32 r, bytes32 s)
        internal
        pure
        returns (bool)
    {
        (address actualSigner,,) = ECDSA.tryRecover(digest, v, r, s);
        return actualSigner == account;
    }
}
