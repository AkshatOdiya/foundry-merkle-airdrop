# Building an Advanced Merkle Airdrop with Foundry and Digital Signatures

An efficient system for token distribution that allows for eligibility verification via Merkle proofs and authorized, potentially gasless, claims using cryptographic signatures.

### What is an Airdrop?
In the blockchain ecosystem, an airdrop refers to the process where a token development team distributes their tokens to a multitude of different wallet addresses. This is a common strategy with several key purposes:

   * **Bootstrapping a Project:** Airdrops can help kickstart a new project by getting its tokens into the hands of a wide user base.

   * ***Rewarding Early Users:*** They serve as a way to acknowledge and reward early adopters, community members, or contributors.

   * **Increasing Token Distribution:** A wider distribution can lead to a more decentralized and robust token economy.

Airdrops can involve various token types, including ERC20 (fungible tokens), ERC721 (non-fungible tokens, or NFTs), and ERC1155 (multi-token standard). This project uses an **ERC20 airdrop**.

Typically, these tokens are gifted for free to eligible recipients. The only cost users might incur is the gas fee required to claim their tokens, a problem we aim to address. Eligibility for an airdrop is usually determined by specific criteria, such as being a developer on the protocol, an active community participant, or having interacted with a particular dApp. The core mechanism involves a list of addresses deemed eligible to claim a predetermined amount of tokens.

### Codebase Overview
`src/s1mpleToken.sol`
 This contract defines the ERC20 token that will be distributed through our airdrop. It's a very minimal ERC20 implementation.

**Key features of s1mpleToken.sol:**

   * **Imports:** It utilizes OpenZeppelin's battle-tested ERC20 contract for standard token functionality and `Ownable` for access control, restricting certain functions (like minting) to the contract owner.

   * **mint function:** An `onlyOwner` function that allows the contract owner to create new Bagel Tokens and assign them to a specified `account`.

`src/MerkleAirdrop.sol`

This is the heart of project – the main contract responsible for managing the airdrop. Its primary functionalities include:

1. **Merkle Proof Verification:** It uses Merkle proofs to efficiently verify if a given address is on the eligibility list without storing the entire list on-chain. This significantly saves gas and storage.

2. **`claim` Function:** Provides the mechanism for eligible users to claim their allotted tokens.

3. **Gasless Claims (for the recipient)**: A crucial feature is allowing anyone to call the claim function on behalf of an eligible address. This means the recipient doesn't necessarily have to pay gas for the claim transaction if a third-party (often called a relayer) submits it.

4. **Signature Verification:** To ensure that claims are authorized by the rightful owner of the eligible address, even if submitted by a third party, the contract implements digital signature verification. It checks the V, R, and S components of an ECDSA signature. This prevents unauthorized claims or individuals receiving tokens they might not want (e.g., for tax implications or to avoid spam tokens).

`script/` **Directory**
This directory contains several Foundry scripts to facilitate various development and interaction tasks:

* `GenerateInput.s.sol:` Likely used for preparing the data (list of eligible addresses and amounts) that will be used to generate the Merkle tree.

* `MakeMerkle.s.sol`: This script will be responsible for constructing the Merkle tree from the input data, generating the individual Merkle proofs for each eligible address, and computing the Merkle root hash (which will be stored in the MerkleAirdrop.sol contract).

* `DeployMerkleAirdrop.s.sol:` A deployment script for the MerkleAirdrop.sol contract.

* `Interact.s.sol:` Used for interacting with the deployed airdrop contract, primarily for making claims.

* `SplitSignature.s.sol:` A helper script or contract, possibly for dissecting a packed signature into its V, R, and S components for use in the smart contract.

## Exploring some Ruins
* **Merkle Trees and Merkle Proofs:** How they work and why they're essential for efficient data verification.

* **Digital Signatures:** The principles behind them and their role in authentication and authorization.

* **ECDSA (Elliptic Curve Digital Signature Algorithm):** The specific algorithm used by Ethereum for generating and verifying signatures.

* **Transaction Types:** Understanding different Ethereum transaction types can be relevant, especially when considering relayers.

--- 

### Vulnerability

A naive strategy might involve storing an array of all claimant addresses directly within the smart contract. The claim function would then iterate through this array to verify if a user is eligible.

```solidity
// In MerkleAirdrop.sol (illustrative, not the recommended approach)
// address[] public claimants;
// mapping(address => uint256) public claimAmounts; // Storing amounts
// mapping(address => bool) public hasClaimed;
​
// function claim() external {
//     bool isEligible = false;
//     // This loop is problematic
//     for (uint i = 0; i < claimants.length; i++) {
//         if (claimants[i] == msg.sender) {
//             isEligible = true;
//             break;
//         }
//     }
//     require(isEligible, "Not eligible for airdrop");
//     require(!hasClaimed[msg.sender], "Already claimed");
​
//     uint256 amount = claimAmounts[msg.sender];
//     hasClaimed[msg.sender] = true;
//     // Transfer ERC20 tokens (e.g., bagelToken.transfer(msg.sender, amount));
// }
```

This approach suffers from significant drawbacks:

* **High Gas Costs:** Iterating through an array on-chain (e.g., `for (uint i = 0; i < claimants.length; i++)`) consumes a large amount of gas. The cost scales linearly with the number of claimants. For airdrops with hundreds or thousands of participants, this becomes prohibitively expensive for users trying to claim.

* **Potential for Denial of Service (DoS):** If the `claimants` array is sufficiently large, the gas required to execute the loop within the `claim` function could exceed the Ethereum block gas limit. This would render the `claim` function unusable for all participants, effectively causing a denial of service.

These issues make the naive array-based approach unsuitable for large-scale airdrops.

## Merkle Tress and Proofs: The Scalable Airdrop Solution

To overcome the high gas costs and scalability limitations of the naive approach, we introduce **Merkle Trees** and **Merkle Proofs**. This cryptographic technique allows for efficient verification of data inclusion without storing the entire dataset on-chain.

**Core Idea**:
Instead of embedding the complete list of eligible addresses and their airdrop amounts directly into the smart contract, we perform the following:

1. **Off-Chain Construction:** A Merkle tree is constructed off-chain using the airdrop data (e.g., lists of `[address, amount]` pairs).

2. **On-Chain Root:** Only the Merkle root – a single 32-byte hash that uniquely represents the entire dataset – is stored on the smart contract.

#### Verification Process for Claiming:
When a user wishes to claim their tokens:

1. They submit their claim details (e.g., their address, the amount they are eligible for) to the smart contract.

2. Crucially, they also provide a Merkle proof. This proof consists of a small set of hashes from the Merkle tree.

3. The smart contract uses the user's submitted data and the provided Merkle proof to recalculate a Merkle root.

4. If this recalculated root matches the Merkle root stored in the contract, it cryptographically proves that the user's data (address and amount) was part of the original dataset used to generate the tree. This verification occurs without iterating through any lists on-chain.

**Benefits of Using Merkle Proofs for Airdrops:**

* **Significant Gas Efficiency:** Verifying a Merkle proof is vastly cheaper than iterating through an array. The gas cost is typically logarithmic (O(log N)) with respect to the number of items in the dataset, rather than linear (O(N)).

* **Enhanced Scalability:** This efficiency allows airdrops to be conducted for a very large number of recipients without hitting gas limits or incurring prohibitive transaction fees for claimants.

By employing Merkle proofs, the `MerkleAirdrop.sol` contract will store the Merkle root of the airdrop distribution and the address of the `s1mpleToken`. Its claim function will then accept the claimant's details along with a Merkle proof to verify eligibility before transferring tokens.

--- 

## Understanding Merkle Trees and Proofs in Web3

Merkle trees and their associated proofs are fundamental data structures in computer science, playing a crucial role in enhancing the security and efficiency of blockchain data. Invented in 1979 by Ralph Merkle, who also co-invented public key cryptography, these tools provide a powerful mechanism for verifying data integrity.

### The Structure of a Merkle Tree
A Merkle tree is a hierarchical structure built from hashed data. Imagine it as an inverted tree:

* **Leaf Nodes:** At the very bottom of the tree are the leaf nodes. Each leaf node represents a hash of an individual piece of data. For example, if we have four pieces of data, we would first hash each one separately to create "Hash 1", "Hash 2", "Hash 3", and "Hash 4".

* **Intermediate Nodes:** Moving up the tree, adjacent nodes are combined and hashed together to form parent nodes.

   * "Hash 1" and "Hash 2" would be concatenated and then hashed to create a parent node, say "Hash 1-2".

   * Similarly, "Hash 3" and "Hash 4" would be combined and hashed to form "Hash 3-4".

* **Root Hash:** This process of pairing and hashing continues up the levels of the tree. In our example, "Hash 1-2" and "Hash 3-4" would then be combined and hashed to produce the final, single hash at the top of the tree: the Root Hash.

The Root Hash is a critical component. It acts as a cryptographic summary, or fingerprint, of all the data contained in the leaf nodes. A key property is that if any single piece of data in any leaf node changes, the Root Hash will also change. This makes Merkle trees highly effective for verifying data integrity.

### What is a Merkle Proof?
A Merkle proof provides an efficient method for verifying that a specific piece of data (a leaf) is indeed part of a Merkle tree, given only the Root Hash of that tree. Instead of requiring access to the entire dataset within the tree, a Merkle proof allows this verification using only a small, select subset of hashes from the tree. This efficiency is paramount in resource-constrained environments like blockchains.

### Unpacking a Merkle Proof: A Club Membership Example
Let's illustrate how a Merkle proof works with a practical scenario. Imagine a club with various membership tiers, each potentially associated with a unique identifier or password. We want to prove that a specific member's identifier (which, when hashed, becomes a leaf node) is part of the club's official Merkle tree.

Suppose we want to prove that "Hash 1" (derived from our specific membership data) is part of a tree whose Root Hash is known. To do this, the prover needs to supply:

1. `Hash 2:` This is the sibling hash to "Hash 1".

2. `Hash 3-4:` This is the sibling hash to the node "Hash 1-2" (which is the parent of "Hash 1" and "Hash 2").

The Merkle proof, in this case, would be an array containing these necessary sibling hashes: `[Hash 2, Hash 3-4]`.

The verification process, performed by someone who knows the legitimate Root Hash, proceeds as follows:

1. The prover submits their original data (which the verifier hashes to confirm it yields "Hash 1") and the proof array `[Hash 2, Hash 3-4]`.
2. The verifier takes the derived "Hash 1" and the first element of the proof, `Hash 2`. They combine and hash these: `Hash(Hash 1 + Hash 2)` to calculate `Hash 1-2`.

3. Next, the verifier takes this calculated `Hash 1-2` and the next element of the proof, `Hash 3-4`. They combine and hash these: `Hash(Hash 1-2 + Hash 3-4)` to arrive at a `Computed Root Hash`.

4. Finally, the verifier compares this Computed Root Hash with the known, expected Root Hash. If they match, the proof is valid, confirming that the original data (which produced "Hash 1") is part of the Merkle tree.

Crucially, a valid Merkle proof must include all sibling nodes along the branch from the target leaf node up to the Root Hash.

### Security and Immutability in Merkle Trees
The security of Merkle trees hinges on the properties of the cryptographic hash functions used, such as Keccak256 (commonly used in Ethereum). These functions are designed to be:

* **One-way**: Easy to compute a hash from an input, but computationally infeasible to reverse the process (i.e., find the input given the hash).

* **Collision-resistant**: It is practically impossible to find two different inputs that produce the same hash output.

Given these properties, if a computed root hash (derived from a leaf and its proof) matches the expected root hash, there's an extremely high degree of confidence that the provided leaf data was genuinely part of the original dataset used to construct that Merkle tree. Any tampering with the leaf data or the proof elements would result in a mismatched root hash.

### Common Use Cases for Merkle Trees and Proofs
Merkle trees and proofs find diverse applications in the Web3 space due to their efficiency and security characteristics:

1. **Proving Smart Contract State:** They can be used to verify data that is stored or referenced by smart contracts without needing to load all the data on-chain.

2. **Blockchain Rollups:** Layer 2 scaling solutions like Arbitrum and Optimism utilize Merkle trees (or variations like Patricia Merkle Tries) to prove state changes committed from Layer 2 back to Layer 1. They can also help verify the order of transactions processed on Layer 2.

3. **Efficient Airdrops:** Merkle proofs are instrumental in managing airdrops of tokens. Instead of storing a potentially massive list of eligible addresses directly in a smart contract, only the Root Hash of a Merkle tree (where each leaf is a hash of an eligible address) is stored. Claimants then provide their address and a Merkle proof to demonstrate their eligibility, allowing for selective and gas-efficient claims.

### Leveraging OpenZeppelin's `MerkleProof.sol`

The OpenZeppelin Contracts library, a widely trusted resource for secure smart contract development, provides a helpful utility contract: MerkleProof.sol. This library simplifies the implementation of Merkle proof verification.

Key functions within MerkleProof.sol include:

   * `function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool):`
   This is the primary function for verification. It takes the proof (an array of sibling hashes), the known root hash (typically stored in your smart contract), and the leaf hash (representing the data being proven, e.g., `keccak256(abi.encodePacked(claimerAddress)))`. It internally calls processProof and returns true if the computed root matches the provided root.

   * `function processProof(bytes32[] memory proof, bytes32 leaf) internal pure returns (bytes32 computedHash):`
   This function reconstructs the root hash from the leaf and the proof. It initializes computedHash with the leaf value. Then, it iterates through each hash in the proof array, successively combining and hashing

   * `function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32):`
   This internal function is crucial for consistent hash generation. It takes two hashes, a and b. Before concatenating and hashing them (using keccak256), it sorts them. The smaller hash (lexicographically) is placed first. This ensures that the order in which sibling nodes are presented does not affect the resulting parent hash, simplifying proof construction and verification.

### Conclusion: The Power of Merkle Structures
In summary, Merkle trees are cryptographic data structures that use hashing to create a verifiable summary (the Root Hash) of a larger dataset. Merkle proofs offer an efficient and secure method to confirm that a specific piece of data is part of this dataset, using only the Root Hash and a small number of auxiliary hashes.

Their applications are widespread in the blockchain domain, notably for gas-efficient airdrops, verifying state changes in smart contracts, and underpinning the functionality of Layer 2 rollups. By understanding and utilizing Merkle trees and proofs, developers can build more scalable, secure, and efficient decentralized applications.

## Understanding Merkle Trees and Proofs for Airdrop Testing

To effectively test the `claim` function of our `MerkleAirdrop.sol` contract, which internally uses `MerkleProof.verify` from OpenZeppelin, our tests require several key components:

  * A valid **Merkle root**: This is the single hash stored in the smart contract that represents the entirety of the airdrop distribution data.

  * A list of **addresses and their corresponding airdrop amounts**: This data forms the "leaves" of the Merkle tree.

  * A **Merkle proof** for each specific address/amount pair: This proof allows an individual user to demonstrate that their address and amount are part of the Merkle tree, without revealing the entire dataset.

#### Introducing murky for Merkle Tree Generation:
To generate these Merkle roots and proofs within our Foundry project, we'll utilize the `murky` library by `dmfxyz` (available on GitHub: `https://github.com/dmfxyz/murky`). This library provides tools for constructing Merkle trees and generating proofs directly within Foundry scripts.

#### Data Structure for Merkle Tree Generation:
We will use two JSON files to manage the Merkle tree data: input.json for the raw data and output.json for the generated tree information including proofs.

1. `input.json`**(Raw Airdrop Data):**
This file serves as the input for our Merkle tree generation script. It defines the structure and values for each leaf node.

  * `types`: An array specifying the data types for each component of a leaf node (e.g., `["address", "uint"]` for an address and its corresponding airdrop amount).

  * `count`: The total number of leaf nodes (i.e., airdrop recipients).

  * `values:` An object where keys are zero-based indices. Each value is an object representing the components of a leaf. For types `["address", "uint"]`, the inner object would have keys `"0"` for the address and `"1"` for the amount.

Example snippet of `input.json`:
```json
{
  "types": [
    "address",
    "uint"
  ],
  "count": 4,
  "values": {
    "0": {
      "0": "0x6CA6d1e2D5347Bfab1d91e883F1915560e891290",
      "1": "2500000000000000000"
    },
    "1": {
      "0": "0xAnotherAddress...",
      "1": "1000000000000000000"
    }
    // ... other values up to count-1
  }
}
```
2. `output.json` **(Generated Merkle Tree Data)**:
This file will be produced by our script after processing `input.json`. It contains the complete Merkle tree information, including the root and individual proofs. Each entry in the JSON array corresponds to a leaf.

   * `inputs`: The original data for the leaf (e.g., `["address_value", "amount_value"]`).

   * `proof:` An array of `bytes32` hashes representing the Merkle proof required to verify this leaf against the root.

   * `root:` The `bytes32` Merkle root of the entire tree. This value will be the same for all entries.

   * `leaf:` The `bytes32` hash of this specific leaf's data.

Example snippet of an entry in `output.json:`

```json
{
  "inputs": [
    "0x6CA6d1e2D5347Bfab1d91e883F1915560e891290",
    "2500000000000000000"
  ],
  "proof": [
    "0xfd7c981d30bece61f7499702bf5903114a0e06b51ba2c53abdf7b62986c00aef",
    "0x46f4c7c1c21e8a0c03949be8a51d2d02d1ec75b55d97a9993c3dbaf3a5a1e2f4"
  ],
  "root": "0x474d994c59e37b12805fd7bcbbcd046cf1907b90de3b7fb083cf3636c0ebfb1a",
  "leaf": "0xd1445c931158119d00449ffcac3c947d828c359c34a6646b995962b35b5c6adc"
}
// This structure is repeated for each leaf in the airdrop.
```

### Scripting Merkle Tree Generation with Foundry and Murky
 
Scripts to generate input.json and then use murky to produce output.json.

1. Generating `input.json` with `GenerateInput.s.sol`
```bash
forge script script/GenerateInput.s.sol:GenerateInput
```
2. Generating `output.json` with `MakeMerkle.s.sol`:
This script reads `input.json`, utilizes the `murky` library to compute the Merkle root and proofs for each entry, and then writes this comprehensive data to `output.json`
```bash
forge script script/MakeMerkle.s.sol:MakeMerkle
```
Upon successful execution, `script/target/output.json` will be created, containing all the data necessary for your tests.

>**_!NOTE_**:  
you can't immediately cast straight to 32 bytes as an address is 20 bytes so first cast to uint160 (20 bytes) cast up to uint256 which is 32 bytes and finally to bytes32  
`address` -> `uint160` -> `uint256` -> `bytes32`

---

## A Simpler Approach: Recipient-Initiated Claims and Its Limitations
A straightforward way to ensure the recipient's consent and direct involvement is to modify the claim function. By removing the account parameter and consistently using msg.sender to identify the claimant, we achieve two things:

1. **Direct Consent**: Only the rightful owner of the address (the one controlling the private key for msg.sender) can initiate the claim for their tokens.

2. **Recipient Pays Gas**: The account calling claim (i.e., msg.sender) would inherently be responsible for paying the transaction's gas fees.

While this modification effectively addresses the consent problem, it introduces a new **limitation**. *It removes the flexibility of allowing a third party to cover the gas fees for the claim*. This can be a desirable feature in scenarios where a project wishes to sponsor gas costs for its users, or when a user prefers to delegate the transaction submission to a specialized service to manage gas.

## Advanced Solution: Enabling Gasless Claims with Digital Signatures
A more sophisticated and flexible solution involves leveraging digital signatures. This method allows an account to explicitly consent to receiving their airdrop while still permitting another party to submit the transaction and pay the associated gas fees. This effectively makes the claim "gasless" from the recipient's perspective.

Here's how the workflow would operate:

1. **Recipient's Intent (User A)**: User A is eligible for an airdrop and wishes to claim it. However, they want User B (the Payer) to submit the actual blockchain transaction and cover the gas costs.

2. **Message Creation (User A):** User A constructs a "message." This message essentially states their authorization, for example: "I, User A, authorize the claim of my airdrop entitlement of X amount. This claim can be submitted by User B (or, depending on the message design, by any authorized party)."

3. **Signing the Message (User A):** User A uses their private key to cryptographically sign this message. The resulting signature is a verifiable proof that User A, and only User A, authorized the contents of that specific message.

4. **Information Transfer:** User A provides the original message components (e.g., their address, the claim amount) and the generated signature to User B.

5. **Transaction Submission (User B):** User B calls the claim function on the MerkleAirdrop contract. They will pass the following parameters:

   * `account:` User A's address (the intended recipient).

   * `amount:` The airdrop amount User A is eligible for.

   * `merkleProof:` User A's Merkle proof, verifying their inclusion in the airdrop.

   * `signature:` The digital signature provided by User A.

6. **Smart Contract Verification:** The `claim` function must be updated to perform these crucial verification steps:

   * Confirm that `account` (User A) has not already claimed their airdrop.

   * Validate the `merkleProof` against the contract's `i_merkleRoot` for the given `account` and `amount`.

   * **Critically, verify that the `signature` is a valid cryptographic signature originating from account (User A) for a message authorizing this specific claim operation.** This involves reconstructing the message within the smart contract and using cryptographic functions to check the signature's validity against User A's public key (derived from their address).

7. **Token Transfer and Gas Payment:** If all verifications pass, the airdrop tokens are transferred to account (User A). The gas fees for this transaction are paid by `msg.sender` (User B).

## Benefits of Implementing Signature-Based Airdrop Claims
This signature-based approach offers several compelling advantages:

   * **Explicit Consent:** The recipient (User A) directly and verifiably authorizes the claim by signing a message specific to that action. This eliminates ambiguity about their willingness to receive the tokens at that time.

   * **Gas Abstraction**: It allows a third party (User B) to pay the transaction fees. This enables "gasless" claims for the end-user, potentially improving user experience and adoption, especially for users less familiar with gas mechanics or those with insufficient native currency for fees.

   * **Enhanced Security:** The smart contract can cryptographically confirm that the intended recipient genuinely authorized the claim. This prevents unauthorized claims made on behalf of others, even if the Merkle proof is valid.

---

## Understanding Ethereum Signatures: EIP-191 & EIP-712
These standards enhance security by preventing replay attacks and improve the user experience by making signed data human-readable.

### The Need for EIP-191 and EIP-712: Solving Unreadable Messages and Replay Attacks

Before the advent of EIP-191 and EIP-712, interacting with decentralized applications often involved signing messages that appeared as long, inscrutable hexadecimal strings in wallets like MetaMask. For instance, a user might be presented with a "Sign Message" prompt showing data like `0x1257deb74be69e9c464250992e09f18b478fb8fa247dcb....` This "unreadable nonsense" made it extremely difficult, and risky, for users to ascertain what they were actually approving. There was no easy way to verify if the data was legitimate or malicious.

This highlighted two critical needs:

1. **Readability:** A method was required to present data for signing in a clear, understandable format.

2. **Replay Protection:** A mechanism was needed to prevent a signature, once created, from being maliciously reused in a different context (a replay attack).

EIP-191 and EIP-712 were introduced as Ethereum Improvement Proposals to directly address these challenges. Modern wallet prompts, leveraging EIP-712, now display structured, human-readable data. For example, signing an "Ether Mail" message might clearly show domain information and mail details with fields like "from Person," "to Person," and "contents," allowing users to confidently verify what they are authorizing.

## Basic Signature Verification: The Fundamentals
Before diving into the EIP standards, let's understand the basic process of signature verification in Ethereum. The core concept involves taking a message, hashing it, and then using the signature (comprising `v`, `r`, and `s` components) along with this hash to recover the signer's Ethereum address. This recovered address is then compared against an expected signer's address.

Ethereum provides a built-in precompiled contract for this: `ecrecover`.
Its signature is: `ecrecover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) returns (address)`
`ecrecover` takes the keccak256 hash of the message and the three ECDSA signature components (`v`, `r`, `s`) as input. It then returns the address of the account that signed the message hash to produce that specific signature.

```solidity
// Simple function to recover a signer's address
function getSignerSimple(uint256 message, uint8 _v, bytes32 _r, bytes32 _s) public pure returns (address) {
    // Note: Hashing is simplified here for demonstration.
    // For a string, one would typically use keccak256(abi.encodePacked(string)).
    bytes32 hashedMessage = bytes32(message); 
    address signer = ecrecover(hashedMessage, _v, _r, _s);
    return signer;
}
​
// Simple function to verify if the recovered signer matches an expected signer
function verifySignerSimple(
    uint256 message,
    uint8 _v,
    bytes32 _r,
    bytes32 _s,
    address signer // The expected signer's address
)
    public
    pure
    returns (bool)
{
    address actualSigner = getSignerSimple(message, _v, _r, _s);
    require(signer == actualSigner, "Signer verification failed"); // Check if recovered signer matches expected
    return true;
}
```

In `getSignerSimple`, a `uint256` message is directly cast to `bytes32` for simplicity. In real-world scenarios, especially with strings or complex data, you would use `keccak256(abi.encodePacked(...))` or `keccak256(abi.encode(...))` to generate the `hashedMessage`. The `verifySignerSimple` function then uses `getSignerSimple` to recover the address and `require` to ensure it matches the `signer` address provided as an argument.

## The Problem with Simple Signatures and the Genesis of EIP-191

The simple signature verification method described above has a significant flaw: it lacks context. A signature created for one specific purpose or smart contract could potentially be valid for another if only the raw message hash is signed. This ambiguity opens the door for replay attacks, where a malicious actor could take a signature intended for contract A and use it to authorize an action on contract B, if contract B expects a similarly structured message.

Consider use cases like sponsored transactions or elements of account abstraction. Here, one party (Bob) might pre-sign a message or transaction data, which another party (Alice) then submits to a contract, with Alice paying the gas fees. The contract must reliably verify Bob's signature. Without a standard, ensuring this signature is only valid for the intended transaction and contract is challenging. This led to the development of EIP-191.

## EIP-191: The Signed Data Standard
EIP-191 was introduced to standardize the format for data that is signed off-chain and intended for verification, often within smart contracts. Its primary goal is to ensure that signed data cannot be misinterpreted as a regular Ethereum transaction, thereby preventing a class of replay attacks.

The EIP-191 specification defines the following format for data to be signed:
`0x19 <1 byte version> <version specific data> <data to sign>`

Let's break down these components:

* `0x19` **(Prefix)**: A single byte prefix (decimal 25). This specific byte was chosen because it's not a valid starting byte for RLP-encoded data used in standard Ethereum transactions. This prefix ensures that an EIP-191 signed message cannot be accidentally or maliciously submitted as a valid Ethereum transaction.

* `<1 byte version>` **(Version Byte)**: This byte specifies the structure and purpose of the data that follows. Key versions include:

   * `0x00`: "Data with intended validator." For this version, the `<version specific data>` is the 20-byte address of the contract or entity intended to validate this signature.

   * `0x01`: "Structured data." This version is closely associated with EIP-712 and is the most commonly used in production for signing complex data structures. The `<version specific data>` is the EIP-712 `domainSeparator`.

   * `0x45`: "personal_sign messages." This is often used by wallets for simple message signing (e.g., `eth_personalSign`).

* `<version specific data>`: This data segment is defined by the <1 byte version>. For 0x00, it's the validator's address; for `0x01`, it's the EIP-712 `domainSeparator`.

* `<data to sign>`: This is the actual arbitrary message payload the user intends to sign (e.g., a string, or a hash of more complex data).

For a smart contract to verify an EIP-191 signature, it must reconstruct this exact byte sequence (`0x19` || `version` || `version_data` || `data_to_sign`), hash it using keccak256, and then use this resulting hash with the provided `v`, `r`, and `s` components in the `ecrecover` function.

Here's a Solidity example implementing EIP-191 version `0x00`:

```solidity
function getSigner191(uint256 message, uint8 _v, bytes32 _r, bytes32 _s) public view returns (address) {
    bytes1 prefix = bytes1(0x19);
    bytes1 eip191Version = bytes1(0x00); // Using version 0x00
    address intendedValidatorAddress = address(this); // Validator is this contract
    bytes32 applicationSpecificData = bytes32(message); // The message payload (simplified)
​
    // Construct the EIP-191 formatted message: 0x19 <1 byte version> <version specific data> <data to sign>
    bytes32 hashedMessage = keccak256(
        abi.encodePacked(prefix, eip191Version, intendedValidatorAddress, applicationSpecificData)
    );
​
    address signer = ecrecover(hashedMessage, _v, _r, _s);
    return signer;
}
```
In this `getSigner191` function, we define the `prefix` (`0x19`), `eip191Version` (`0x00`), and `intendedValidatorAddress` (which is the address of the current contract, `address(this)`). The `applicationSpecificData` is our message. These components are concatenated using `abi.encodePacked` and then hashed with `keccak256`. The resulting hash is used with `ecrecover`.

While EIP-191 standardizes the signing format and adds a layer of domain separation (e.g., with the validator address in version `0x00`), version `0x00` itself doesn't inherently solve the problem of displaying complex `<data to sign>` in a human-readable way in wallets. This is where EIP-712 comes into play.

## EIP-712: Typed Structured Data Hashing and Signing
EIP-712 builds upon EIP-191, specifically utilizing EIP-191 version 0x01, to achieve two primary objectives:

1. **Human-Readable Signatures:** Enable wallets to display complex, structured data in an understandable format to users before signing.

2. **Robust Replay Protection:** Provide strong protection against replay attacks by incorporating domain-specific information into the signature.

The EIP-712 signing format, under EIP-191 version `0x01`, is:
`0x19 0x01 <domainSeparator> <hashStruct(message)>`

Let's dissect these components:

1. `0x19 0x01`: The EIP-191 prefix (`0x19`) followed by the EIP-191 version byte (`0x01`), indicating that the signed data adheres to the EIP-712 structured data standard.

2. `<domainSeparator>`: This is the "version specific data" for EIP-191 version 0x01. It's a bytes32 hash that is unique to the specific application domain. This makes a signature valid only for this particular domain (e.g., a specific DApp, contract, chain, and version of the signing structure).
The `domainSeparator` is calculated as `hashStruct(eip712Domain)`. The `eip712Domain` is a struct typically defined as:

```solidity
struct EIP712Domain {
    string  name;                // Name of the DApp or protocol
    string  version;             // Version of the signing domain (e.g., "1", "2")
    uint256 chainId;             // EIP-155 chain ID (e.g., 1 for Ethereum mainnet)
    address verifyingContract;   // Address of the contract that will verify the signature
    bytes32 salt;                // Optional unique salt for further domain separation
}
```
The `domainSeparator` is the `keccak256` hash of the ABI-encoded instance of this `EIP712Domain` struct. Crucially, including `chainId` and `verifyingContract` ensures that a signature created for one DApp on one chain cannot be replayed on another DApp or another chain

* `<hashStruct(message)>`: This is the "data to sign" part of the EIP-191 structure. It's a bytes32 hash representing the specific structured message the user is signing.
Its calculation involves two main parts: `hashStruct(structData) = keccak256(typeHash || encodeData(structData))`.

   * `typeHash`: This is a `keccak256` hash of the definition of the message's struct type. It includes the struct name and the names and types of its members, formatted as a string. For example, for a struct `Message { uint256 amount; address to; }`, the type string would be `"Message(uint256 amount,address to)"`, and the `typeHash` would be `keccak256("Message(uint256 amount,address to)")`.

   * `encodeData(structData)`: This is the ABI-encoded data of the struct instance itself. The EIP-712 specification details how different data types within the struct should be encoded before hashing. For Solidity, this typically involves `abi.encode(...)` where the first argument is the `typeHash` of the primary type, followed by the values of the struct members in their defined order.

The **final `bytes32` digest** that is actually passed to `ecrecover` (or a safer alternative) for EIP-712 compliant signatures is:
`digest = keccak256(abi.encodePacked(bytes1(0x19), bytes1(0x01), domainSeparator, hashStruct(message)))`

#### Conceptual Code Walkthrough for EIP-712 Hash Construction:

1. **Define your message struct:**

```solidity
struct Message {
    uint256 number;
}
// Or for a string message:
// struct Message {
//     string message;
// }
```
2. **Calculate the `MESSAGE_TYPEHASH` (the `typeHash` for your message struct):**

```solidity
// For uint256 number:
bytes32 public constant MESSAGE_TYPEHASH = keccak256(bytes("Message(uint256 number)"));
// For string message:
// bytes32 public constant MESSAGE_TYPEHASH = keccak256(bytes("Message(string message)"));
```

3. **Calculate `hashStruct(message)` (hash of the specific message instance):**

```solidity
// Assume 'messageValue' is the uint256 value for the 'number' field
// bytes32 hashedMessagePayload = keccak256(abi.encode(MESSAGE_TYPEHASH, messageValue));
​
// For a struct instance Message myMessage = Message({number: messageValue});
// bytes32 hashedMessagePayload = keccak256(abi.encode(MESSAGE_TYPEHASH, myMessage.number));
// More generally, for a struct 'Mail { string from; string to; string contents; }'
// MAIL_TYPEHASH = keccak256(bytes("Mail(string from,string to,string contents)"));
// hashStructMail = keccak256(abi.encode(MAIL_TYPEHASH, mail.from, mail.to, mail.contents));
```
It's `keccak256(abi.encode(MESSAGE_TYPEHASH, actual_value_of_number_field))`. If the struct has multiple fields, they are all included in abi.encode in order.

4. **Calculate** `domainSeparator`: This is typically done once, often in the contract's constructor. It involves hashing an instance of the `EIP712Domain` struct.

```solidity
// Pseudo-code for domain separator calculation
// EIP712DOMAIN_TYPEHASH = keccak256(bytes("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)"));
// domainSeparator = keccak256(abi.encode(
//     EIP712DOMAIN_TYPEHASH,
//     "MyDAppName",
//     "1",
//     block.chainid, // or a specific chainId
//     address(this),
//     MY_SALT // some bytes32 salt
// ));
```
5. **Calculate the final `digest`**:

```solidity
// bytes32 digest = keccak256(abi.encodePacked(
//     bytes1(0x19),
//     bytes1(0x01),
//     domainSeparator, // Calculated in step 4
//     hashedMessagePayload  // Calculated in step 3
// ));
```
6. **Recover the signer:**

```solidity
// address signer = ecrecover(digest, _v, _r, _s);
```
## Leveraging OpenZeppelin for Robust EIP-712 Implementation
Manually implementing EIP-712 hashing and signature verification can be complex and error-prone. It is highly recommended to use well-audited libraries like those provided by OpenZeppelin. Specifically, `EIP712.sol` and `ECDSA.sol` are invaluable.

* `EIP712.sol`: This utility contract simplifies the creation of EIP-712 compliant domains and the hashing of typed data.

   * Your contract inherits from `EIP712`.

   * The domain separator details (name, version string) are passed to the `EIP712` constructor. It automatically uses `block.chainid` and `address(this)` for `chainId` and `verifyingContract` respectively.

   * It provides an internal function `_hashTypedDataV4(bytes32 structHash)` which correctly computes the final EIP-712 digest. This function internally calculates or retrieves the `domainSeparator` and combines it with the provided `structHash` (your `hashStruct(message)`) using the `0x19 0x01` prefix.

* `ECDSA.sol`: This library provides safer alternatives to the raw `ecrecover` precompile.

   * The key function is `ECDSA.tryRecover(bytes32 digest, uint8 v, bytes32 r, bytes32 s) returns (address, RecoverError)`.

   * **Signature Malleability Protection**: `tryRecover` (and `recover`) checks that the `s` value of the signature is in the lower half of the elliptic curve order. This prevents certain signature malleability attacks where a third party could slightly alter a valid signature (e.g., by changing s to `secp256k1n - s`) to create a different signature that still validates for the same message and key, potentially causing issues in some contract logic. If s is not canonical, it causes a revert.

   * `Safe Error Handling`: `tryRecover` returns a zero address and an error code if the signature is invalid (e.g., `v` is incorrect, or point decompression fails), instead of `ecrecover`'s behavior which can sometimes revert or return garbage for certain invalid inputs.

**Example using OpenZeppelin libraries:**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
​
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
​
contract MyEIP712Contract is EIP712 {
    // Define the struct for the message
    struct Message {
        string message;
    }
​
    // Calculate the TYPEHASH for the Message struct
    // keccak256("Message(string message)")
    bytes32 public constant MESSAGE_TYPEHASH = 0xf30f2840588e47605f8476d894c1d95d7220f7eda638ebb2e21698e5013de90a; // Precompute this
​
    constructor(string memory name, string memory version) EIP712(name, version) {}
​
    function getMessageHash(string memory _message) public view returns (bytes32) {
        // Calculate hashStruct(message)
        bytes32 structHash = keccak256(abi.encode(
            MESSAGE_TYPEHASH,
            keccak256(bytes(_message)) // EIP-712 requires hashing string/bytes members
        ));
        
        // _hashTypedDataV4 constructs the final EIP-712 digest:
        // keccak256(abi.encodePacked(0x19, 0x01, domainSeparator, structHash))
        return _hashTypedDataV4(structHash);
    }
​
    function getSignerOZ(bytes32 digest, uint8 _v, bytes32 _r, bytes32 _s) public pure returns (address) {
        // Use ECDSA.tryRecover for safer signature recovery
        (address signer, ECDSA.RecoverError error) = ECDSA.tryRecover(digest, _v, _r, _s);
        
        // Optional: Handle errors explicitly
        // require(error == ECDSA.RecoverError.NoError, "ECDSA: invalid signature");
        if (error != ECDSA.RecoverError.NoError) {
            // Handle specific errors or revert
            if (error == ECDSA.RecoverError.InvalidSignatureLength) revert("Invalid sig length");
            if (error == ECDSA.RecoverError.InvalidSignatureS) revert("Invalid S value");
            // ... etc. or a generic revert
            revert("ECDSA: invalid signature");
        }
        
        return signer;
    }
​
    function verifySignerOZ(
        string memory _message,
        uint8 _v,
        bytes32 _r,
        bytes32 _s,
        address expectedSigner
    )
        public
        view
        returns (bool)
    {
        bytes32 digest = getMessageHash(_message);
        address actualSigner = getSignerOZ(digest, _v, _r, _s);
        require(actualSigner == expectedSigner, "Signer verification failed");
        require(actualSigner != address(0), "Invalid signer recovered"); // Additional check
        return true;
    }
}
```
**Note**: For EIP-712, dynamic types like `string` and `bytes` within your struct are themselves hashed before being included in the abi.encode for `structHash`. So, `Message({ message: _message })` becomes `abi.encode(MESSAGE_TYPEHASH, keccak256(bytes(_message)))`.

#### Replay Protection Summary with EIP-712:
EIP-712 provides robust replay protection primarily through the domainSeparator. Since the domainSeparator includes the `chainId` and the `verifyingContract` address (among other details like the DApp name and version), a signature generated for a specific message on one contract (e.g., `ContractA` on Mainnet) will not be valid for:

* The same message on a different contract (e.g., `ContractB` on Mainnet).

* The same message on the same contract deployed to a different chain (e.g., `ContractA` on Sepolia).

* A different version of the signing domain if the `version` string in `EIP712Domain` changes.

### Conclusion
EIP-191 established a foundational standard for formatting signed data in Ethereum, ensuring signed messages are distinct from transactions. Building upon this, EIP-712 revolutionized how structured data is handled for signing, introducing human-readable formats in wallets and, critically, strong replay protection mechanisms through the `domainSeparator` and `hashStruct` concepts.

While the underlying mechanics of constructing these hashes and verifying signatures can be intricate, leveraging libraries like OpenZeppelin's` EIP712.sol `and `ECDSA.sol` significantly simplifies implementation and enhances security. Understanding these standards is crucial for any developer building applications that require off-chain message signing and on-chain verification, common in scenarios like meta-transactions, gasless transactions, and various off-chain agreement protocols. Mastering these concepts takes practice, but they are fundamental to secure and user-friendly Web3 development.

---

## Unveiling ECDSA: Understanding Digital Signatures and v, r, s Values

### Decoding ECDSA: Elliptic Curve Digital Signature Algorithm
ECDSA stands for Elliptic Curve Digital Signature Algorithm. As the name suggests, it is an algorithm built upon the principles of Elliptic Curve Cryptography (ECC). Its primary functions are crucial for digital security and identity:

  * **Generating Key Pairs**: ECDSA is used to create pairs of cryptographic keys – a public key and a private key.

  * **Creating Digital Signatures**: It allows for the generation of unique digital signatures for messages or data.

  * **Verifying Digital Signatures**: It provides a mechanism to confirm the authenticity and integrity of a signed message.

### The Role of Signatures in Blockchain Authentication

In blockchain technology, particularly in systems like Ethereum, digital signatures serve as a critical means of **authentication**. They provide verifiable proof that a transaction or message genuinely originates from the claimed sender and has not been tampered with.

Think of an ECDSA signature as a **digital fingerprint** – unique to each user and their specific message. This is analogous to needing to present identification to withdraw money from a bank; the signature verifies your identity and authority. This system of proof of ownership is achieved through public and private key pairs, which are the tools used to create these digital signatures. The entire process is underpinned by **Public Key Cryptography (PKC)**, which uses asymmetric encryption (different keys for encrypting/signing and decrypting/verifying).

### Essentials of Public-Key Cryptography (PKC)
Public-Key Cryptography involves a pair of keys: a private key and a public key.

* **Private Key:**

   * This key is kept secret by the owner.

   * It is used to **sign messages** or transactions. For example, a message combined with a private key, when processed by the signing algorithm, produces a unique signature.

   * Crucially, the private key is also used to mathematically **derive the public key**.

* **Public Key:**

   * This key can be shared openly.

   * It is used to verify that a message was indeed signed by the owner of the corresponding private key.

   * While the public key is derived from the private key, it is computationally infeasible to reverse this process and obtain the private key from the public key. This is a property of one-way functions (at least with current classical computing capabilities; quantum computing presents theoretical challenges to this).

**Security Implications:**

  * Sharing your public key is generally safe. It's like sharing your bank account number for receiving payments or your home address for receiving mail. For instance, giving someone your public Ethereum address allows them to send you tokens but doesn't grant them access to your funds.

  * Conversely, **sharing your private key is catastrophic.** It's equivalent to handing over the keys to your house or the combination to your safe. Anyone with your private key can control your assets and sign messages on your behalf.

**Ethereum Context:**

  * **Externally Owned Accounts (EOAs):** In Ethereum, user accounts (EOAs) are defined by these public-private key pairs. They provide the means for users to interact with the blockchain, such as signing data and sending transactions securely.

  * **Ethereum Address:** Your Ethereum address, the identifier you share to receive funds, is derived from your public key. Specifically, it is the last 20 bytes of the Keccak-256 hash of the public key.


### How ECDSA Works: A Closer Look at the Algorithm
ECDSA is a specific type of digital signature algorithm that leverages the mathematical properties of elliptic curves.

**The `secp256k1` Elliptic Curve**:
Ethereum and Bitcoin, among other cryptocurrencies, utilize a specific elliptic curve known as `secp256k1`. This curve was chosen for several reasons, including:

  * **Interoperability**: Its widespread adoption promotes compatibility across different systems.

  * **Efficiency**: It offers a good balance between security and computational performance.

  * **Security**: It is believed to offer robust security against known cryptanalytic attacks.

A key property of the `secp256k1` curve (and many elliptic curves used in cryptography) is that it is **symmetrical about its x-axis**. This means that for any point (x, y) on the curve, the point (x, -y) is also on the curve.

**The (v, r, s) Signature Components:**
An ECDSA signature consists of three components: `v`, `r`, and `s`. These are essentially derived from coordinates of a point on the chosen elliptic curve (`secp256k1` in Ethereum's case). Each such point represents a unique signature.

  * Due to the x-axis symmetry of the curve, for any given x-coordinate (which relates to r), there are two possible y-coordinates (one positive, one negative). This means there can be two valid signatures for the same message and private key using the same r value.

  * **Signature Malleability:** This property leads to what's known as signature malleability. If an attacker obtains one valid signature (v, r, s), they can potentially compute the other valid signature (v', r, s') for the same message and private key, even without knowing the private key itself. This can be a concern in certain contexts, potentially enabling a form of replay attack if not handled correctly. Further resources on replay attacks and malleability are often available in blockchain development documentation.

**Key Constants for `secp256k1`:**
Two important constants are defined for the `secp256k1` curve:

  * **Generator Point (G):** This is a predefined, fixed point on the elliptic curve. It's a publicly known value used as a starting point for cryptographic operations.

  * **Order (n)**: This is a large prime number that represents the order of the subgroup generated by G. Essentially, it defines the range of possible private keys; private keys are integers between 0 and n-1.

**Understanding v, r, s as Integers:**
The signature components `v`, `r`, and `s` are integers with specific meanings:

  * `r`: This value represents the x-coordinate of a point on the `secp256k1` curve. This point is derived from a cryptographically secure random number (a "nonce") k and the generator point `G`.

  * `s`: This value serves as cryptographic proof that the signer possesses the private key. Its calculation involves the hash of the message, the private key, the `r` value, the random nonce `k`, and the order `n` of the curve. The nonce `k` is critical because it ensures that s (and thus the entire signature) is unique each time a message is signed, even if the message and private key are identical.

  * `v`: Known as the "recovery ID" or "parity/polarity indicator." It's a small integer (typically 27 or 28 in Ethereum, or 0 or 1 in some raw contexts before an offset is added). Its purpose is to help efficiently recover the correct public key from the `r` and `s` components of the signature. Since there are two possible y-coordinates for a given `r` (due to the curve's symmetry), `v` indicates which of these two y-values (and thus which of the two possible public keys) was used in generating the signature

### Generating Your Digital Identity: ECDSA Key Pairs
The process of generating an ECDSA key pair is straightforward:

1. **Private Key (p or sk)**: A private key is generated by choosing a cryptographically secure random integer. This integer must fall within the range of `0 to n-1`, where n is the order of the `secp256k1` curve.

2. **Public Key (pubKey or P)**: The public key is an elliptic curve point. It is calculated by performing elliptic curve point multiplication (also known as scalar multiplication) of the private key `p` with the generator point `G`. This is represented by the formula:
`pubKey = p * G`
The `*` here denotes a special type of multiplication defined for elliptic curves, not standard integer multiplication.

### The Unbreakable Lock: Security of ECDSA Private Keys
The security of ECDSA, and specifically the inability to derive the private key from the public key, rests upon a mathematical problem called the **Elliptic Curve Discrete Logarithm Problem (ECDLP)**.

ECDLP states that given a `public` key pubKey and the generator point `G`, it is computationally infeasible to find the private key p in the equation `pubKey = p * G`.

An analogy helps illustrate this: Imagine you are given the number 96,673 and told it's the product of two large prime numbers, `x` and `y`. Finding `x` and `y` from 96,673 is very difficult (factorization). However, if you were given x and y, multiplying them to get 96,673 is easy. Similarly, it's easy to compute pubKey from p and G, but extremely hard to compute `p` given only `pubKey` and `G`. This one-way property is the bedrock of ECDSA's security.

### Crafting a Digital Signature: The ECDSA Signing Process
Creating an ECDSA signature involves combining a hash of the message with the private key, using the ECDSA algorithm. Here's a simplified overview of the steps:

1. **Hash the Message:** The message (e.g., a transaction payload) is first hashed using a cryptographic hash function like SHA-256. Let's call this hash `h`. Hashing ensures that even large messages are condensed into a fixed-size, unique fingerprint.

2. **Generate a Nonce (k)**: A cryptographically secure, random, and unique number k (the nonce) is generated. This number must be in the range `1` to `n-1` (where `n` is the order of the curve). The uniqueness and unpredictability of `k` are critical for security; reusing `k` with the same private key for different messages can lead to private key exposure.

3. **Calculate Point R:** An elliptic curve point `R` is calculated by multiplying the nonce k with the generator point `G`: `R = k * G`. Let the coordinates of point R be `(x_R, y_R)`.

4. **Calculate `r`:** The r component of the signature is derived from the x-coordinate of point `R`: `r = x_R mod n`. If `r` happens to be 0, a new nonce `k` must be generated (Step 2), and the process repeated.

5. **Calculate `s`**: The `s` component of the signature is calculated using the formula: `s = k⁻¹ * (h + p * r) mod n`.

  * `k⁻¹` is the modular multiplicative inverse of `k` modulo `n` (i.e., `(k * k⁻¹) mod n = 1`).

  * `h` is the hash of the message.

  * `p` is the private key.

  * `r` is the component calculated in the previous step.
    If `s` happens to be 0, a new nonce `k` must be generated (Step 2), and the process repeated.

6. **Determine `v`**: The recovery identifier `v` is determined. Its value (e.g., 27 + `y_R` % 2, or related to the parity of `y_R` and potentially other factors depending on the specific implementation) helps in the public key recovery process during verification.

The resulting (`v`, `r`, `s`) tuple is the digital signature for the message.

### Validating Authenticity: The ECDSA Signature Verification Process
The ECDSA verification algorithm confirms whether a signature is authentic and was generated by the holder of a specific private key, corresponding to a given public key. The process takes the following inputs:

  * The (hashed) signed message (`h`).

  * The signature components (`v`, `r`, `s`).

  * The public key (`pubKey`) of the alleged signer.

The algorithm outputs a boolean value: `true` if the signature is valid for the given message and public key, and `false` otherwise.

The verification process, in simplified terms, involves a series of mathematical operations that essentially try to reconstruct a value related to the signature's `r` component using the public key, the message hash, and the `s` component. If the reconstructed value matches the original `r` from the signature, the signature is considered valid.

A common set of verification steps involves:

1. Calculate `S1 = s⁻¹ (mod n)`.

2. Calculate an elliptic curve point `R' = (h * S1) * G + (r * S1) * pubKey`. This involves elliptic curve scalar multiplication and point addition.

3. Let the coordinates of `R'` be `(x', y')`.

4. Calculate `r' = x' mod n`.

5. The signature is valid if `r' == r`.

#### Ethereum's `ecrecover` Precompile:
Ethereum provides a built-in function (a precompile, meaning it's implemented at a lower level for efficiency) called `ecrecover`. The function `ecrecover(hashedMessage, v, r, s)` performs signature verification.

  * Instead of just returning true/false, if the signature (`v`, `r`, `s`) is valid for the hashedMessage, `ecrecover` returns the Ethereum address of the signer.

  * This is extremely useful for smart contracts, as it allows them to verify signatures on-chain and reliably retrieve the address of the account that signed a particular piece of data.

### Securely Using `ecrecover` in Ethereum Smart Contracts
While `ecrecover` is a powerful tool, using it directly in smart contracts requires careful consideration to avoid potential security vulnerabilities.

1. **Signature Malleability:**
As previously discussed, the `secp256k1` curve's symmetry allows for two valid `s` values (and corresponding v values) for a given `r` and message. An attacker, given one valid signature, can often compute the other valid signature for the same message and private key.

   * **Problem:** If a smart contract uses the hash of the signature itself as a unique identifier (e.g., as a nonce to prevent replay attacks, or to mark a message as processed), an attacker could submit the alternative valid signature to bypass such checks or cause unintended behavior.

   * **Mitigation:** A common mitigation is to restrict the accepted `s` value to only one of the two possibilities. Typically, contracts enforce that s must be in the "lower half" of its possible range (i.e., `s <= n/2`, where `n` is the curve order). Libraries like OpenZeppelin's ECDSA library (versions greater than 4.7.3) incorporate mitigations for signature malleability.

   * **Vulnerable Code Example**: Audit reports, such as one from a Lava Labs Code4rena contest, have highlighted instances where `ecrecover` was used directly without restricting s values or checking the return value properly, for example: `address signer = ecrecover(hashedMessage, _v, _r, _s);`. This line, if s is not constrained, could be vulnerable to malleability issues.

2. `ecrecover` **Returns Zero Address for Invalid Signatures**:
If an invalid signature (one that doesn't correspond to the message or where `v`, `r`, `s` are malformed) is passed to `ecrecover`, the function returns the zero address (`address(0)`).

   * **Problem:** If a smart contract calls `ecrecover` and then proceeds to use the returned `signer` address without explicitly checking if it's `address(0)`, it can lead to critical vulnerabilities. For instance, if `address(0)` unintentionally has special privileges or if actions are taken assuming a valid signer was recovered, an attacker could exploit this by providing a malformed signature.

   * **Mitigation**: Always check if the signer returned by `ecrecover` is `address(0)`. If it is, the signature should be treated as invalid, and the transaction should typically revert. OpenZeppelin's ECDSA library includes checks for this, reverting if ecrecover returns `address(0)`. For example, their `recover` function might include logic similar to: i`f (signer == address(0)) { revert ECDSAInvalidSignature(); }`.

**Recommendation:**
Due to these complexities and potential pitfalls, it is **highly recommended to always use a well-vetted and audited library**, such as OpenZeppelin's ECDSA library, for signature verification in smart contracts rather than implementing the logic or using `ecrecover` directly without proper safeguards.

### ECDSA Signatures: A Recap of Key Concepts
ECDSA is a cornerstone of modern digital security, especially in blockchain systems. It provides the mechanisms to:

  * **Generate public and private key pairs**, forming the basis of digital identity.

  * **Generate unique digital signatures** for messages or transactions, proving authorship and integrity.

  * **Verify these signatures**, allowing anyone with the public key to confirm authenticity.

Understanding the components (`v`, `r`, `s`), the generation and verification processes, and the security considerations like signature malleability and `ecrecover`'s behavior is crucial for anyone developing or interacting with Web3 applications. While the underlying mathematics can be intricate, the high-level principles enable secure and trustworthy interactions in decentralized environments.

---

## Shared Transaction Types: Ethereum and zkSync
Ethereum and zkSync share several fundamental transaction types. These form the bedrock of how interactions are structured on both L1 and L2.

### Transaction Type 0 (Legacy Transactions / 0x0)
Type 0, also known as Legacy Transactions or identified by the prefix `0x0`, represents the original transaction format used on Ethereum. This was the standard before the formal introduction of distinct, typed transactions. It embodies the initial method for structuring and processing transactions on the network.

A practical example for developers using Foundry zkSync is the explicit specification of this transaction type during smart contract deployment. By including the `--legacy` flag in your deployment command, you instruct the tool to use this original format. For instance:
`forge create src/MyContract.sol:MyContract --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast --legacy --zksync`
The `--legacy` flag highlighted here directly indicates the use of a Type 0 transaction.

### Transaction Type 1 (Optional Access Lists / 0x01 / EIP-2930)

Transaction Type 1, denoted as `0x01`, was introduced by EIP-2930, titled "Optional Access Lists." Its primary purpose was to mitigate potential contract breakage risks associated with EIP-2929, an earlier proposal that repriced certain storage-accessing opcodes (SLOAD and EXT*).

Type 1 transactions maintain the same fields as legacy (Type 0) transactions but introduce a significant addition: an `accessList` parameter. This parameter is an array containing addresses and storage keys that the transaction plans to access during its execution. The main benefit of including an access list is the potential for gas savings on cross-contract calls. By pre-declaring the intended contracts and storage slots, users can offset some of the gas cost increases introduced by EIP-2929, leading to more efficient transactions.

### Transaction Type 2 (EIP-1559 Transactions / 0x02)
Transaction Type 2, or `0x02`, was introduced by EIP-1559 as part of Ethereum's "London" hard fork. This EIP was a major overhaul of Ethereum's fee market, aiming to tackle issues like high network fees, improve the user experience around gas payments, and reduce network congestion.

The key change introduced by EIP-1559 was the replacement of the simple `gasPrice` (used in Type 0 and Type 1 transactions) with two new components:

  * A `baseFee`: This fee is algorithmically determined per block based on network demand and is burned, reducing ETH supply.

  * A `maxPriorityFeePerGas`: This is an optional tip paid directly to the validator (formerly miner) to incentivize transaction inclusion.

Consequently, Type 2 transactions include new parameters:

  * `maxPriorityFeePerGas`: The maximum tip the sender is willing to pay per unit of gas.

  * `maxFeePerGas`: The absolute maximum total fee (baseFee + priorityFee) the sender is willing to pay per unit of gas.

Block explorers like Etherscan often display these as "Txn Type: 2 (EIP-1559)".

**zkSync Note**: While zkSync supports Type 2 transactions, its handling of the fee parameters differs from Ethereum L1. Currently, zkSync does not actively use the `maxPriorityFeePerGas` and `maxFeePerGas` parameters to prioritize or price transactions in the same way as Ethereum, due to its distinct gas mechanism and fee structure.

### Transaction Type 3 (Blob Transactions / 0x03 / EIP-4844 / Proto-Danksharding)
Transaction Type 3, also `0x03`, was introduced by EIP-4844, commonly known as "Proto-Danksharding," and implemented during Ethereum's "Dencun" hard fork. This EIP represents an initial, significant step towards scaling Ethereum, particularly for rollups like zkSync. It introduces a new, more cost-effective way for Layer 2 solutions to submit data to Layer 1 via "blobs."

Key features of Type 3 transactions include:

* A separate fee market specifically for blob data, distinct from regular transaction gas fees.

* Additional fields on top of those found in Type 2 transactions:

    * `max_fee_per_blob_gas`: The maximum fee the sender is willing to pay per unit of gas for the blob data.

    * `blob_versioned_hashes`: A list of versioned hashes corresponding to the data blobs carried by the transaction.

A crucial aspect of the blob fee mechanism is that this fee is deducted from the sender's account and burned before the transaction itself is executed. This means that if the transaction fails for any reason during execution, the blob fee is **non-refundable**.

## zkSync-Specific Transaction Types
Beyond the shared types, zkSync introduces its own transaction types to enable unique functionalities and optimizations specific to its Layer 2 environment.

### Type 113 (EIP-712 Transactions / 0x71)
Type 113, or `0x71`, transactions on zkSync utilize the EIP-712 standard, "Ethereum typed structured data hashing and signing." EIP-712 standardizes the way structured data is hashed and signed, making messages more human-readable and verifiable within wallets like MetaMask.

On zkSync, Type 113 transactions are pivotal for accessing advanced, zkSync-specific features such as native Account Abstraction (AA) and Paymasters.

  * **Account Abstraction**: Allows accounts to have custom validation logic, effectively turning user accounts into smart contracts.

  * **Paymasters**: Smart contracts that can sponsor transaction fees for users, enabling gasless transactions or payment in custom tokens.

A critical requirement for developers is that smart contracts must be deployed on zkSync using a Type 113 (0x71) transaction. For example, when deploying a smart contract to zkSync via Remix, the signature request presented by your wallet (e.g., MetaMask) will typically indicate "TxType: 113".

In addition to standard Ethereum transaction fields, Type 113 transactions on zkSync include several custom fields:

  * `gasPerPubData`: The maximum gas the sender is willing to pay for each byte of "pubdata." Pubdata refers to L2 state data that needs to be published to L1 for data availability.

  * `customSignature`: This field is used when the transaction signer is not a standard Externally Owned Account (EOA), such as a smart contract wallet leveraging account abstraction. It allows for custom signature validation logic.

  * `paymasterParams`: Parameters for configuring a custom Paymaster smart contract, detailing how it will cover the transaction fees.

  * `factory_deps`: An array of bytecodes for contracts that the deployed contract might, in turn, deploy. This is crucial for deploying contracts that have dependencies on other contracts or create new contract instances.

### Type 255 (Priority Transactions / 0xff)
Type 255, or `0xff`, transactions on zkSync are known as "Priority Transactions." Their primary purpose is to enable the sending of transactions directly from Ethereum L1 to the zkSync L2 network.

These transactions are essential for facilitating communication and operations that originate on L1 but need to be executed on L2. Common use cases include:

   * Depositing assets from Ethereum L1 to zkSync L2.

   * Triggering L2 smart contract calls or functions from an L1 transaction.

Priority transactions bridge the two layers, ensuring that L1-initiated actions can be reliably processed and reflected on the zkSync rollup.

## EIP-4844: Revolutionizing Layer 2 Scaling with Blob Transactions

The Dencun network upgrade, activated on March 13, 2024, marked a significant milestone in Ethereum's scalability roadmap by introducing EIP-4844, also known as Proto-Danksharding. This pivotal upgrade brought forth a new transaction type: Blob Transactions (Type 3). The primary objective of these transactions is to drastically lower the costs for Layer 2 (L2) rollups to post their data to the Ethereum Layer 1 (L1) mainnet, ultimately making transactions on L2 solutions significantly cheaper for end-users.

### Understanding Blob Transactions: The Core Innovation
To appreciate the impact of EIP-4844, it's essential to distinguish between traditional Ethereum transactions and the new blob-carrying transactions:

   * **Normal Transactions (Type 2 - EIP-1559)**: In standard Ethereum transactions, all associated data, including input data (known as `calldata`), is permanently stored on the Ethereum blockchain. Every Ethereum node is required to store this data indefinitely.

   * **Blob Transactions (Type 3 - EIP-4844)**: These transactions introduce a novel component: "blobs." Blobs are large, additional chunks of data carried by the transaction. Crucially, this blob data is not stored permanently by the L1 execution layer (the Ethereum Virtual Machine - EVM). Instead, it's guaranteed to be available on the consensus layer for a temporary period—approximately 18 days (or 4096 epochs)—after which it is pruned (deleted) by the nodes. The core transaction details (such as sender, recipient, value, etc.) remain permanently stored on-chain.

Think of a blob as a temporary "sidecar" attached to a motorcycle (the transaction). The motorcycle and its essential components are kept, but the sidecar, after serving its purpose of temporary data transport, is eventually detached and discarded.

**What are Blobs?**
The term "blob" is a common shorthand for Binary Large Object. In the context of EIP-4844:

   * Blobs are substantial, fixed-size data packets, each precisely 128 Kilobytes (KiB). This size is composed of 4096 individual fields, each 32 bytes long.

   * They provide a dedicated and more economical data space for L2 rollups to post their transaction batches, compared to the previously used, more expensive `calldata`.

## The Problem Solved: Why Blob Transactions Were Needed
Ethereum's L1 has historically faced high transaction fees due to its limited block space and substantial demand. This is a direct consequence of the blockchain trilemma, which posits a trade-off between scalability, security, and decentralization.

Layer 2 rollups (such as ZK Sync, Arbitrum, and Optimism) have emerged as the primary scaling solution for Ethereum. They work by:

1. Executing transactions off-chain (on the L2).

2. Batching many transactions together.

3. Compressing this batch.

4. Posting the compressed batch data back to the L1 mainnet for security and data availability.

**The Pre-Blob Bottleneck:**
Before EIP-4844, rollups posted their compressed transaction batches to L1 using the `calldata` field of a standard L1 transaction. This approach was a significant cost driver because:

  * `Calldata` consumes valuable and limited L1 block space.

  * This `calldata` had to be stored permanently by all L1 nodes. This was inefficient because the L1 primarily needed to verify the availability of this data temporarily, not store it forever.

  * The requirement for permanent storage of large data volumes increases hardware and computational demands on node operators, which directly translates into higher gas fees for all users. Imagine being forced to carry around every exam paper you ever passed, indefinitely; this is analogous to the burden of permanent calldata storage for data that only needed short-term verifiability.

Consequently, rollups were incurring substantial fees for this permanent calldata storage, a feature they didn't strictly require for their long-term operational integrity.

## How EIP-4844 Works: The Mechanics of Blobs
EIP-4844, or Proto-Danksharding, provides an elegant solution by allowing rollups to post their data as blobs instead of relying solely on calldata.

* **Temporary Data Availability:** Blobs are designed for short-term data availability. After the defined window (around 18 days), this data is pruned from the consensus layer. This significantly lessens the long-term storage burden on L1 nodes.

* **A New, Cheaper Data Market:** Blobs introduce their own independent fee market, distinct from the gas market for computation and standard calldata. This is a form of "multidimensional gas pricing." Blob gas is priced differently and, at present, is substantially cheaper than using an equivalent amount of calldata.

* **Verification Without EVM Access:** A cornerstone of EIP-4844's design is that the L1 can verify the availability and integrity of blob data without the EVM needing to directly access or process the contents of the blobs themselves. In fact, the EVM cannot directly access blob data. This efficient verification is achieved through:

   * **KZG Commitments**: For each blob, a KZG (Kate-Zaverucha-Goldberg) commitment is generated. This is a type of polynomial commitment, serving as a small, fixed-size cryptographic proof (akin to a hash) that represents the entire blob.

   * `BLOBHASH` **Opcode**: A new EVM opcode, `BLOBHASH`, was introduced. This opcode allows smart contracts on L1 to retrieve the KZG commitment (the hash) of a blob associated with the current transaction.

   * **Point Evaluation Precompile:** A new precompiled contract enables the verification of blob data. A smart contract can call this precompile, providing a KZG commitment and a proof (submitted as part of the L1 transaction). The precompile then cryptographically verifies that the provided proof is valid for the given commitment, thereby confirming the integrity and availability of the original blob data without the EVM ever needing to "see" the raw blob.

### Blobs in Action: A Practical Walkthrough
The introduction of blob transactions has streamlined how L2 rollups interact with the L1.

**The Rollup Process with Blobs**:

1. The L2 rollup executes transactions, batches them, and compresses the data.

2. The rollup submits a Type 3 (blob) transaction to the L1. This transaction includes:

   * Standard transaction fields (sender, recipient, value, gas fees, etc.).

   * The KZG commitments (hashes) for each accompanying blob.

   * Proofs related to these commitments (for verification via the Point Evaluation Precompile).

   * References to the actual blob data, which is propagated through the consensus layer network, not the execution layer.

3. On L1, the rollup's smart contract (often an "inbox" contract) uses the BLOBHASH opcode to get the expected KZG commitment for a blob.

4. It then calls the Point Evaluation Precompile, passing the KZG commitment and the proof supplied in the transaction's `calldata`.

5. The precompile verifies the proof against the commitment. A successful verification confirms that the blob data referenced by the commitment was indeed available and unaltered when the transaction was included in a block.

6. After the data availability window expires, the blob data itself is pruned by L1 nodes, while the record of its commitment and successful verification remains permanent.

**Etherscan Example: Witnessing Blobs in the Wild**
Block explorers like Etherscan provide visibility into these new transaction types. For instance, examining a transaction from a rollup like ZK Sync that utilizes EIP-4844 would reveal:

   * `Txn Type: 3 (EIP-4844)` clearly indicated.

   * A "Blobs" tab or section, listing the KZG commitments (often displayed as hashes) of the blobs associated with the transaction.

   * Viewing the raw data of a blob would show a large hexadecimal string, representing the 128 KiB of data.

   * Crucially, Etherscan often provides a gas cost comparison, showing `Blob Gas Used` versus what the cost would have been if the same data had been posted as `Calldata Gas`. This frequently demonstrates massive cost savings, potentially reducing data posting costs by orders of magnitude compared to the old calldata method.

Transaction debugging tools like Tenderly can offer even deeper insights, showing internal function calls within the L1 contracts, such as those interacting with the `BLOBHASH` opcode and the Point Evaluation Precompile.

### Proto-Danksharding vs. Full Danksharding: The Path Ahead
EIP-4844, or Proto-Danksharding, is a critical foundational step. It implements the necessary transaction format, fee market mechanics, and verification logic (KZG commitments, precompiles) for blobs.

However, it is an intermediate stage. The "full" vision of Danksharding, planned for future Ethereum upgrades, aims to:

  * Significantly increase the number of blobs that can be included per block (e.g., from a target of 3 and max of 6 in Proto-Danksharding to potentially 64 or more).
 
  * Likely incorporate advanced techniques like Data Availability Sampling (DAS), allowing nodes to verify blob availability even more efficiently without needing to download all blob data.

Proto-Danksharding lays all the groundwork, allowing the ecosystem to adapt to blob transactions while the full scaling solution is developed.

## Conclusion
Key Takeaways: What to Remember About EIP-4844
EIP-4844 and blob transactions represent a paradigm shift in how Ethereum handles large data payloads, especially for L2 rollups. Here are the essential points:

   * **Temporary & Pruned:** Blob data is not stored permanently on L1; it's available for a limited time (approx. 18 days) and then pruned.

   * **EVM Inaccessible**: The EVM cannot directly read or process the contents of blobs. Verification happens via cryptographic commitments (KZGs).

   * **Fixed Size**: Blobs have a strict, fixed size of 128 KiB. Data must be padded if smaller.

   * **Type 3 Transactions**: Blob-carrying transactions are designated as Type 3.

   * **Separate Fee Market**: Blobs utilize a distinct fee market with `maxFeePerBlobGas`, enabling cheaper data posting than traditional `calldata`.

   * **Library Support**: Client libraries (like Web3.py) and nodes abstract away the complexity of KZG commitment and proof generation when sending blob transactions.

   * **Foundation for Full Danksharding:** Proto-Danksharding (EIP-4844) is the necessary precursor to achieving the more extensive scalability benefits promised by full Danksharding.

By dramatically reducing the cost of L1 data availability for rollups, EIP-4844 significantly enhances Ethereum's scalability, making L2 solutions more efficient and affordable, and paving the way for a more scalable and user-friendly Ethereum ecosystem. For further in-depth understanding, the official EIP-4844 specification and resources on Ethereum.org regarding Danksharding are highly recommended.

## What is Account Abstraction? Smart Contracts as Your User Account
Account Abstraction (AA) is a transformative concept in the blockchain space. At its core, AA allows users to **use smart contracts as their primary user accounts** instead of traditional Externally Owned Accounts (EOAs). This means your assets are stored and managed by the logic embedded within a smart contract, rather than being solely controlled by a private key.

The primary benefit of Account Abstraction is the enablement of **programmable accounts**. This unlocks a host of features and functionalities far beyond what standard EOAs can offer. Think of it with this slogan: "Use smart contracts as a user account!"

## Traditional Ethereum Accounts: EOAs vs. Smart Contracts
To appreciate the innovation of Account Abstraction on zkSync, let's quickly recap the traditional types of accounts on Ethereum:

1. Externally Owned Accounts (EOAs):

  * These are controlled by a private key.

  * Users directly initiate and sign transactions from their EOAs.

  * A standard MetaMask account is a prime example of an EOA.

2. Smart Contract Accounts (or Contract Accounts):

  * These are essentially pieces of code deployed on the blockchain.

  * On traditional Ethereum, smart contract accounts cannot initiate transactions on their own. They only react to transactions sent to them.

  * They can house arbitrary logic, enabling complex systems like multisig wallets or Decentralized Autonomous Organizations (DAOs).

The key distinction here is that, traditionally, only EOAs could start a transaction sequence.

## zkSync's Native Account Abstraction: A Paradigm Shift
zkSync fundamentally changes this dynamic with its native Account Abstraction. This isn't an add-on or a layer built on top; it's integrated into the core protocol of zkSync.

The most significant shift is that on zkSync, **all accounts are, by default, smart contract accounts**. This means that even if you're interacting with zkSync using what feels like your regular Ethereum EOA, on zkSync, that address represents a smart contract account.

These zkSync smart contract accounts uniquely blend the capabilities of both traditional account types:

   * They can **initiate transactions**, just like EOAs.

   * They can contain **arbitrary custom logic** for validation, execution, and more, just like smart contracts.

This inherent programmability at the account level unlocks powerful benefits:

   * **Custom Signature Schemes**: Go beyond the standard ECDSA; use different cryptographic signatures if needed.

   * **Native Multisig Capabilities**: Implement multi-signature requirements directly at the account level.

   * **Spending Limits**: Program your account to enforce daily or per-transaction spending limits.

   * **Social Recovery**: Design mechanisms for account recovery that don't solely rely on a seed phrase (e.g., through trusted friends or services).

   * **Gas Fee Abstraction (via Paymasters)**: Allow third parties (paymasters) to cover gas fees for users, enabling smoother onboarding and user experiences.

## Introducing Type 113 Transactions: zkSync's Engine for Account Abstraction
This brings us to **Type 113 transactions**. This is the specific transaction type that zkSync utilizes to enable its native Account Abstraction features.

Remember that scenario in Remix where you signed an EIP-712 message and a transaction was sent? Here's what happened:

1. Your Ethereum address, when used on the zkSync network, is already treated as a smart contract account.

2. Remix, understanding zkSync's architecture, took the EIP-712 signature you provided.

3. It then packaged this authorization into a **Type 113 transaction**.

4. This Type 113 transaction instructed your smart contract account on zkSync to perform the desired action, such as deploying another contract or interacting with an existing one.

The EIP-712 signature provides the necessary authorization for your smart contract account to act on your behalf.

## Decoding a Type 113 Transaction: A Look Inside the Remix Console
If you were to inspect the transaction details in the Remix console after such an operation (for instance, deploying a `SimpleStorage` contract on zkSync), you'd see a JSON object representing the transaction. This is an example of what a Type 113 transaction might look like:

```json
{
  "type": 113,
  "nonce": 1,
  "maxPriorityFeePerGas": "0x0ee7600",
  "maxFeePerGas": "0x0ee7600",
  "gasLimit": "0x00635c9e",
  "to": "0x0d55504000000000000000000000000000008126...",
  "value": "0x0",
  "data": "0x...",
  "from": "0x5b38da6a701c568545dcfcb03fcb873f829e051b97",
  "customData": {
    "gasPerPubdata": "0xBigNumber",
    "factoryDeps": [
      "0x..."
    ],
    "paymasterParams": null
  },
  "hash": "0x0e4c59d6a57f7c3ce83bffb2f26df902786b6bfb85dc2e5c6ec6885ba3",
  "confirmations": 0
}
```

Let's break down the key fields:

* `"type": 113`: This is the crucial identifier. It explicitly tells the zkSync network that this is a native Account Abstraction transaction.

* `"from"`: This address represents the EOA (e.g., your MetaMask account) that provided the signature which authorizes this transaction. Even though all accounts on zkSync are smart contracts, this field links the authorization back to an EOA's signature.

* `"customData"`: This object contains fields specific to zkSync's L2 functionality:

   * `"gasPerPubdata"`: A zkSync-specific field related to the cost of publishing data to Layer 1 (Ethereum).

   * `"factoryDeps"`: This array contains bytecodes of contracts that this transaction depends on or will deploy. For example, if this transaction deploys your account contract for the first time, its bytecode would be here. It can also include bytecodes of other contracts this transaction deploys or interacts with.

   * `"paymasterParams"`: null: This field indicates whether a paymaster is being used to cover gas fees for this transaction. In this example, null means no paymaster is involved; the user's account is paying the fees. If a paymaster were used, this field would contain parameters specifying the paymaster contract and any necessary input data for it.

 * Other fields like `nonce`, `maxPriorityFeePerGas`, `maxFeePerGas`, `gasLimit`, `to` (often a system address for contract deployment or interaction in AA contexts), `value`, `data`, and `hash` are similar to standard Ethereum transaction fields, adapted for zkSync's architecture.

### The Bigger Picture: Type 113 and Native AA

In essence, Type 113 transactions are zkSync's native mechanism for realizing the benefits of Account Abstraction, often compared to what EIP-4337 aims to achieve on Ethereum L1 but implemented directly at the protocol level on zkSync. They allow every user account to be a powerful, programmable smart contract, triggered by user signatures (like EIP-712) and capable of sophisticated custom logic.


## Crafting the Signature: Generating the Message Hash and Signing The Message Hash

A digital signature is created for a specific piece of data. To ensure security and efficiency, we don't sign the raw data directly but rather its cryptographic hash. The `MerkleAirdrop.sol` contract includes a helper function, `getMessageHash`, designed for this purpose, often adhering to the EIP-712 standard for typed data hashing.

The `getMessageHash` function in `MerkleAirdrop.sol` typically looks like this:

```solidity
// src/MerkleAirdrop.sol
function getMessageHash(address account, uint256 amount) public view returns (bytes32) {
    return _hashTypedDataV4(
        keccak256(abi.encode(MESSAGE_TYPEHASH, AirdropClaim({account: account, amount: amount})))
    );
}
```

This function constructs a unique, fixed-size hash based on the `account` eligible for the airdrop and the `amount` of tokens they can claim. The `_hashTypedDataV4` function implies an EIP-712 compliant structure, which provides context and domain separation for signatures, preventing replay attacks across different contracts or applications.

To obtain this message hash, you can use Foundry's `cast call` command to invoke `getMessageHash` on your deployed `MerkleAirdrop` contract. The command requires:

1. The `MerkleAirdrop` contract address (from the deployment step).

2. The function signature: `"getMessageHash(address,uint256)"`.

3. The arguments for the function: the claimant's address and the claimable amount (in wei).

4. The RPC URL of your Anvil node.

For example, to get the message hash for `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` claiming 25 tokens (assuming 18 decimals, so `25000000000000000000` wei):

```bash
cast call 0xe7f1725E7734CE288F83E7E1B143E90b3F0512 "getMessageHash(address,uint256)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 25000000000000000000 --rpc-url http://localhost:8545
```
This command will return the `bytes32` message hash, for instance:
`0x184e30c19f5e304a09352421dc58346dad61e12f9155b910e73fd856dc72`

This hash is the precise data that needs to be signed.

### Signing this Message Hash

Once you have the message hash, the next step is to sign it using a private key. This signature serves as cryptographic proof that the owner of the private key authorizes the action associated with the message hash (in this case, claiming tokens). Foundry's `cast wallet sign` command facilitates this.

The command requires the following:

1. The message hash obtained in the previous step.

2. The `--private-key` flag followed by the private key of the signing account. For this Merkle Airdrop scenario, this would be the private key of an account authorized to approve claims (e.g., an admin or the deployer, or for testing, one of Anvil's default accounts).

3. The `--no-hash` flag: This is critically important. Since the getMessageHash function already computed the cryptographic hash of the typed data, cast wallet sign must be instructed not to hash its input again. If `--no-hash` is omitted, `cast wallet sign` would hash the already-hashed input, leading to an incorrect signature that the smart contract will reject.

Using the example message hash from before and the first default Anvil private key (e.g., `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`, which Anvil prints on startup):

```bash
cast wallet sign --no-hash 0x184e30c19f5e304a09352421dc58346dad61e12f9155b910e73fd856dc72 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```
This command will output the digital signature as a hexadecimal string, for example:
`0xfbd277f062f5b1f52b40dfce9de460171bb0c4238b5c4d75b0d384ed3b6c46ceaeaa570afeecb671d4c11c`

It's worth noting that if you were operating on a testnet or mainnet and your private key was managed in an encrypted keystore file, you would use the `--account <ACCOUNT_ALIAS_OR_ADDRESS>` flag instead of `--private-key`. `cast` would then prompt for your keystore password.

## Splitting a Concatenated Signature (r, s, v) in Solidity
When working with cryptographic signatures in Web3, particularly within Solidity scripts for frameworks like Foundry, you'll often encounter signatures as a single, raw, concatenated hexadecimal string. This string typically represents the `r`, `s`, and `v` components of an ECDSA signature packed together. However, many smart contract functions, especially those designed for EIP-712 typed data verification or general signature recovery (e.g., `ecrecover`), require these `v`, `r`, and `s` values as separate arguments. 

### Storing the Raw Signature in Your Solidity Script
The first step is to incorporate the raw signature into your script. If you've generated a signature using a tool like `cast wallet sign` (e.g., `cast wallet sign --no-hash <hashed_message> --private-key <your_private_key>`), you'll receive a hexadecimal string.

This signature can be stored in a `bytes` variable within your Solidity script using the `hex` literal notation:

```solidity
// Example signature: 0xfb2270e6f23fb5fe924848c0f4be8a4e9b077c3ad0b1333cc60b5debc511602a2a06c24085d807c830bad8baedc536
bytes private SIGNATURE = hex"fb2270e6f23fb5fe924848c0f4be8a4e9b077c3ad0b1333cc60b5debc511602a2a06c24085d807c830bad8baedc536";
```
* `hex"..."` **Literal**: The `hex` keyword allows you to define byte literals directly from a hexadecimal string. Notice that the `0x` prefix, commonly seen in hexadecimal representations, is omitted when using this literal form.

* `private` **Visibility**: Declaring the variable as `private` (e.g., `bytes private SIGNATURE`) restricts its accessibility, preventing inheriting contracts or other scripts from directly accessing it if such access is not intended. This promotes encapsulation.

### Why abi.decode is Unsuitable for Packed Signatures
A common question is whether `abi.decode` can be used to parse the raw signature. For instance, one might intuitively try `abi.decode(SIGNATURE, (uint8, bytes32, bytes32))`. However, this approach will not work for typical concatenated signatures.

The reason lies in how these signatures are usually formed. They are generally the result of a direct concatenation, akin to `abi.encodePacked(r, s, v)`. `abi.encodePacked` concatenates the data directly without including any length or offset information for the encoded elements. In contrast, `abi.decode` is designed to work with data encoded using `abi.encode`, which includes metadata necessary to parse dynamically sized types or multiple elements. Since the raw signature lacks this metadata, `abi.decode` cannot correctly interpret its structure.

### Implementing the splitSignature Helper Function

```solidity
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
```
### Deep Dive: How the Assembly Code Splits the Signature
The core of the `splitSignature` function lies in its assembly block, which allows for precise low-level memory manipulation. Understanding this block is key to grasping how the signature is parsed.

**Signature Structure (Packed Bytes):**
A standard 65-byte ECDSA signature, as typically concatenated, is structured as follows:

1. `r` **component**: First 32 bytes.

2. `s` **component**: Next 32 bytes.

3. `v` **component**: Final 1 byte.

**Assembly Operations Explained**:

  * **Memory Layout of** `bytes memory sig`: When a `bytes memory` variable like `sig` is passed to an assembly block, the sig variable itself holds a pointer to the length of the byte array. The actual byte data begins 32 bytes (0x20 bytes) after this pointer.

     * `add(sig, 0x20)`: This expression calculates the memory address of the first byte of the actual signature data. `0x20` is hexadecimal for 32.

  * **Loading** `r`:
  ```assembly
  r := mload(add(sig, 0x20))
  ```
  The `mload` opcode loads 32 bytes from the specified memory address. Here, it loads the first 32 bytes of the signature data (which correspond to the `r` value) from `sig + 0x20` and assigns them to the `r` return variable.

  * **Loading** `s`
  ```assembly
  s := mload(add(sig, 0x40))
  ```
  This loads 32 bytes starting from the memory address `sig + 0x40`. `0x40` is hexadecimal for 64. This address effectively points to `start_of_data + 32_bytes_for_r`. Thus, it loads the 32 bytes representing the `s` value and assigns them to the `s` return variable.

  * **Loading** `v`
  ```assembly
  v := byte(0, mload(add(sig, 0x60)))
  ```
  This is a two-step process for the 1-byte v value:
 
  1. `mload(add(sig, 0x60))`: `0x60` is hexadecimal for 96. This address points to `start_of_data + 32_bytes_for_r + 32_bytes_for_s`. `mload` reads a full 32-byte word from this location. The v byte is the first byte within this 32-byte word.

  2. `byte(0, ...)`: The `byte` opcode extracts a single byte from a 32-byte word. `byte(N, word)` extracts the Nth byte (0-indexed from the most significant byte on the left). Since `v` is the first (and only relevant) byte in the loaded word, `byte(0, ...)` isolates it and assigns it to the `uint8 v` return variable.

## Understanding the Order of v, r, and s Components
It's important to distinguish between how the signature components are packed and how they are conventionally used in function arguments:

  * `Packed Signature Order (e.g., in `SIGNATURE` bytes variable)`:
   `r` (32 bytes), `s` (32 bytes), `v` (1 byte).
   This is the order assumed by the assembly code when reading from the `sig` byte array.

  * **Function Arguments/Return Values Convention**:
   The common convention for Solidity function arguments and return values (as seen in OpenZeppelin's ECDSA library and many contract interfaces that handle signatures) is `v, r, s`.
   The `splitSignature` function adheres to this by returning the components in the order `(uint8 v, bytes32 r, bytes32 s)`.


### Crucial Considerations for the 'v' Value
The `v` (recovery identifier) value can sometimes require adjustment depending on the signing library used and the specific Ethereum Improvement Proposals (EIPs) in effect.

* **Historical Context**: Originally, and in Bitcoin, v values were typically 27 or 28. Ethereum also used these values before EIP-155.

* **EIP-155**: With EIP-155 (transaction replay protection on different chains), v values became chain-specific: `chain_id * 2 + 35` or `chain_id * 2 + 36`.

* **Modern Libraries**: Some modern signing libraries or tools might return `v` as 0 or 1. In such cases, to make it compatible with `ecrecover` (which often expects 27 or 28 for non-EIP-155 signatures, or the EIP-155 compliant value), you might need to add 27 to the `v` value:
```solidity
// if (v < 27) {
//     v = v + 27;
// }
```
While the `splitSignature` function presented earlier doesn't include this adjustment, it's a critical point to be aware of. If signature verification fails, an incorrect `v` value is a common culprit. You may need to add this conditional adjustment based on the source of your signatures and the requirements of the contract function you're interacting with.

### Workflow Recap: From Raw Signature to Smart Contract Call
To summarize the process of using a raw signature with a smart contract in a Foundry script:

1. **Obtain Message Hash**: If you are signing a structured message (EIP-712) or a specific piece of data, first obtain the hash that needs to be signed. This might involve calling a contract function (e.g., via `cast call`) that prepares the hash.

2. **Sign the Message**: Use a wallet or tool like `cast wallet sign` to sign the hash. If you are providing an already hashed message to `cast wallet sign`, use the `--no-hash` flag:
`cast wallet sign --no-hash <message_hash_hex> --private-key <your_private_key>`
This will output the raw, concatenated signature as a hexadecimal string.

3. **Store Signature in Script**: Copy the output signature and store it in a `bytes private SIGNATURE = hex"..."` variable in your Solidity script.

4. **Split the Signature**: Call your `splitSignature(SIGNATURE)` helper function to retrieve the individual `v`, `r`, and `s` components.

5. **Utilize Components**: Pass the separated `v`, `r`, and `s` values (along with any other required parameters) to the target smart contract function that expects them for verification or other operations.

This methodical approach provides a robust and gas-efficient way to handle raw, concatenated signatures and prepare them for smart contract interactions directly within your Solidity and Foundry development workflow.

---

## Claiming Tokens from a Merkle Airdrop with Foundry Scripts on Anvil

To run this script, we use the `forge script` command:

```bash
forge script script/Interact.s.sol:ClaimAirdrop --rpc-url http://localhost:8545 --private-key <ANVIL_PRIVATE_KEY_FOR_GAS_PAYER> --broadcast
```
```bash
forge script script/Interact.s.sol:ClaimAirdrop --rpc-url http://localhost:8545 --private-key 0x59c6995e998f97c53dc0061b03a92d461a7b4d034017663132d705a80ac2da --broadcast
```
The output should confirm the success.

## Verifying the Token Claim
With the script executed successfully, the next step is to verify that the `CLAIMING_ADDRESS` (Anvil's first account: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`) has received the airdropped tokens. Let's assume our ERC20 token is named SimpleToken.

1. **Obtain the Token Contract Address**:
You'll need the deployed address of your `SimpleToken` contract. This address would typically be available from your deployment script's output (e.g., from a `DeployMerkleAirdrop.s.sol` script that also deploys the token). For this example, let's assume the `SimpleToken` contract was deployed to: `0x5FbDB2315678afecb367f032d93F642f64180aa3` (a common default address in local development environments if it's one of the first contracts deployed).

2. **Query Token Balance using cast call**:
Foundry's `cast call` command allows us to make a read-only call to a contract function without sending a transaction (and thus without incurring gas fees). We'll use it to call the standard ERC20 `balanceOf(address)` function on our SimpleToken contract.

```bash
cast call 0x5FbDB2315678afecb367f032d93F642f64180aa3 "balanceOf(address)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
```
* `0x5FbDB2315678afecb367f032d93F642f64180aa3`: Address of the `SimpleToken` contract.

* `"balanceOf(address)"`: The function signature we want to call.

* `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`: The `CLAIMING_ADDRESS` whose balance we're checking.

This command will output the balance in hexadecimal format:

```bash
0x000000000000000000000000000000000000000000000000000000015af1d78b58c40000
```
3. **Convert Hexadecimal Balance to Decimal**:
The hexadecimal output isn't very human-readable. We can use `cast --to-dec` to convert it to its decimal representation.

```bash
cast --to-dec 0x000000000000000000000000000000000000000000000000000000015af1d78b58c40000
```
This command will output:

```bash
2500000000000000000000
```
This decimal value is `25 * 10^18`, confirming that the `CLAIMING_ADDRESS` successfully received 25 `SimpleToken` (assuming 18 decimal places for the token), matching the `CLAIMING_AMOUNT` specified in our `Interact.s.sol` script.

---

## Deploying and Interacting with a Merkle Airdrop on zkSync Local Node

Due to certain limitations with full Foundry script support on zkSync local nodes at the time of this guide's creation, we will utilize a bash script (`interactZK.sh`) to orchestrate a series of `cast` and `forge script` commands. This approach effectively automates the entire workflow from deployment to claiming.

1. **Install or Update zkSync-Compatible Foundry**
```bash
foundryup -zksync
```
2. In one terminal run anvil chain
```bash
anvil-zksync
```

3. Run that `interactZk.sh`

```bash
chmod +x interactZK.sh
```
then 

```bash
./interactZK.sh
```

---

## Manually Deploying a Merkle Airdrop on zkSync Sepolia with Foundry

### Core Concepts: Understanding the Building Blocks
Before diving into the deployment, let's clarify the key technologies and concepts involved:

  * **Merkle Airdrops**: This is an efficient technique for distributing ERC20 tokens to a large list of recipients. Instead of individual transactions for each user, claims are verified against a Merkle root. This cryptographic proof significantly reduces gas costs and transaction overhead.

  * **zkSync**: A Layer 2 (L2) scaling solution for Ethereum, zkSync utilizes ZK-rollups to offer higher throughput and lower transaction fees while maintaining Ethereum's security. Our deployment targets the zkSync Sepolia testnet.

  * **Foundry** (`forge` **and** `cast`): A blazing fast, portable, and Solidity-native toolkit for Ethereum application development.

     * `forge create`: Deploys smart contracts to a specified network.

     * `cast call`: Executes read-only (view/pure) functions on deployed contracts without sending a transaction or consuming gas (beyond RPC node interaction).

     * `cast send`: Sends transactions that modify the blockchain state, such as calling state-changing functions in a smart contract.

     * `cast wallet sign`: Signs a message or data hash using a locally managed keystore, crucial for interactions requiring cryptographic signatures.

  * **Keystores in Foundry**: Foundry allows importing accounts (e.g., from MetaMask) as local keystores. This enhances security and convenience by enabling commands like `--account <alias>` (e.g., `someAccount`, `someAccount2`) instead of exposing private keys directly in terminal commands.

  * **Environment Variables:** Sensitive or configurable data, such as RPC URLs, are best managed using an `.env` file. The `source .env` command loads these variables into the current terminal session, making them accessible to scripts and commands.

  * **Legacy Transactions (Type 0) & `--zksync` Flag**: When interacting with zkSync networks via Foundry, the --legacy flag is often necessary to specify a Type 0 transaction. The --zksync flag explicitly tells Foundry that the target network is a zkSync-based chain, enabling specific handling.

  * **EIP-712 Signatures (Implied) and Signature Splitting (V, R, S)**: The claim process involves generating a message hash specific to the user and claim details, signing this hash, and then providing the signature components (V, R, S) to the smart contract. This pattern is common for secure off-chain message signing and on-chain verification, similar to EIP-712. An ECDSA signature (typically 65 bytes) is split into:

     * `V`: The recovery identifier.

     * `R`: The first 32 bytes of the signature.

     * `S`: The second 32 bytes of the signature.
       These components are passed as separate arguments to contract functions that verify signatures, such as the `claim` function in our airdrop contract.

## Prerequisites: Setting Up Your Environment

Ensure you have the following configured before proceeding:

1. Foundry Installed: Verify your Foundry installation (`forge --version`, `cast --version`).

2. MetaMask Accounts Imported: Import the Ethereum accounts you intend to use for deployment (e.g., someAccount) and claiming (e.g., someAccount2) into Foundry's keystore.

3. `.env` File: Create an `.env` file in your project root with the zkSync Sepolia RPC URL:

```solidity
ZKSYNC_SEPOLIA_RPC_URL=https://sepolia.era.zksync.dev
```
Load these variables into your terminal session by running:

```bash
source .env
```
4. **Merkle Tree Data** (`input.json`, `output.json`): These files contain the airdrop recipient data, individual Merkle proofs, and the overall Merkle root. They are typically generated by a script (e.g., using `make merkle` if your project is set up that way). Ensure these files are up-to-date, especially the Merkle root in `output.json`

## Step-by-Step Deployment and Interaction Guide
Follow these steps to deploy and interact with your Merkle airdrop contracts.

**Step 1: Deploying the ERC20 Token Contract (`SimpleToken.sol`)**

First, deploy the `SimpleToken.sol` contract, which represents the ERC20 token to be airdropped.

```bash
forge create src/BagelToken.sol:BagelToken \
    --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} \
    --account someAccount \
    --legacy \
    --zksync
```
This command uses the someAccount account (as defined in your Foundry keystore) to deploy `SimpleToken`. After successful deployment, the terminal will output the deployed contract address. Capture this address and set it as an environment variable for easy use in subsequent steps:

```bash
export TOKEN_ADDRESS=<deployed_token_address>
```

Replace `<deployed_token_address>` with the actual address output by `forge create`.

**Step 2: Deploying the Merkle Airdrop Contract (`MerkleAirdrop.sol`)**

Next, deploy the `MerkleAirdrop.sol` contract. Its constructor requires the Merkle root (which defines the set of eligible claimers and amounts) and the address of the token being airdropped.

Retrieve the Merkle root from your `output.json` file.

```bash
# Example: MERKLE_ROOT_VAL=$(jq -r '.merkleRoot' output.json)
# Ensure MERKLE_ROOT_VAL contains the correct root from your output.json
​
forge create src/MerkleAirdrop.sol:MerkleAirdrop \
    --constructor-args <merkle_root_from_output.json> ${TOKEN_ADDRESS} \
    --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} \
    --account someAccount \
    --legacy \
    --zksync
```

Replace `<merkle_root_from_output.json>` with the actual Merkle root.
Important: If you modify the script that generates your `input.json` and `output.json` (e.g., `GenerateInput.s.sol`), remember to regenerate these files (e.g., via `make merkle`) to ensure the Merkle root is current.

Capture the deployed airdrop contract address:

```bash
export AIRDROP_ADDRESS=<deployed_airdrop_address>
```
Replace `<deployed_airdrop_address>` with the actual address.

You might observe compiler warnings related to `ecrecover` on zkSync. This is due to zkSync's native account abstraction. For Externally Owned Accounts (EOAs) or smart contract accounts relying on ECDSA signatures, `ecrecover` generally functions as expected.

**Step 3: Retrieving the Message Hash for Claiming**
To claim tokens, a recipient (e.g., someAccount2) must sign a unique message. The hash of this message is generated by the `getMessageHash` function in the `MerkleAirdrop` contract. This function typically takes the claimant's address and the amount they are eligible to claim.

Obtain these values (address of someAccount2, claim amount) from your `input.json` or `output.json` file corresponding to the someAccount2 recipient.

```bash
cast call ${AIRDROP_ADDRESS} "getMessageHash(address,uint256)" \
    <address_of_someAccount2_from_input.json> \
    <claim_amount_from_input.json> \
    --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL}

```
This command will output a `bytes32` message hash. Save this hash for the next step.

**Step 4: Signing the Message Hash with Foundry Keystore**
The `someAccount2` account (the claimant) now signs the message hash obtained in Step 3.

```bash
# Let's say MESSAGE_HASH=<message_hash_from_step_3>
cast wallet sign --no-hash ${MESSAGE_HASH} --account someAccount2
```
* The `--no-hash` flag is critical here because `getMessageHash` already returned a pre-hashed message. `cast wallet sign` by default hashes its input; `--no-hash` prevents double-hashing.

* `--account someAccount2` specifies that the someAccount2 keystore entry should be used for signing.

This command will output the raw 65-byte signature.

**Step 5: Splitting the Signature into V, R, S Components**
The raw signature must be split into its V, R, and S components to be used in the `claim` function. A helper Solidity script, `SplitSignature.s.sol`, can automate this.

1. Copy the raw signature output from Step 4 (remove the "0x" prefix) and paste it into a new file named `signature.txt`.

2. The `SplitSignature.s.sol` script might look like this:

```solidity
// script/SplitSignature.s.sol
pragma solidity ^0.8.0;
​
import "forge-std/Script.sol";
import "forge-std/console.sol";
​
contract SplitSignature is Script {
    function splitSignature(bytes memory sig) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        require(sig.length == 65, "invalid signature length");
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96))) // Loads the 65th byte
        }
        // Adjust v for Ethereum's convention (27 or 28) if it's 0 or 1
        if (v < 27) {
            v += 27;
        }
    }
​
    function run() external {
        string memory sigHex = vm.readFile("signature.txt");
        bytes memory sigBytes = vm.parseBytes(sigHex); // Assumes sigHex does NOT have "0x" prefix
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(sigBytes);
        console.log("v value:");
        console.log(v);
        console.log("r value:");
        console.logBytes32(r);
        console.log("s value:");
        console.logBytes32(s);
    }
}
```
3. Run the script:
```bash
forge script script/SplitSignature.s.sol:SplitSignature
```
4. The script will print the V, R, and S values. Capture these and set them as environment variables:

```bash
export V_VAL=<v_value_output_by_script>
export R_VAL=<r_value_output_by_script>
export S_VAL=<s_value_output_by_script>
```
**Step 6: Funding the Airdrop Contract with Tokens**
The `MerkleAirdrop` contract needs to hold enough `SimpleTokens` to cover all potential claims.

1. **Mint Tokens**: The owner of `SimpleToken` (the someAccount account in this case) mints the total supply required for the airdrop to itself. Determine the `<total_airdrop_supply>` by summing all claimable amounts.
```bash
# <my_metamask_address_for_someAccount> is the deployer's EOA address
cast send ${TOKEN_ADDRESS} "mint(address,uint256)" \
    <my_metamask_address_for_someAccount> \
    <total_airdrop_supply> \
    --account someAccount \
    --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} \
    --legacy --zksync
```
2. **Transfer Tokens to Airdrop Contract**: Transfer the minted tokens from the someAccount account to the `MerkleAirdrop` contract.

```bash
cast send ${TOKEN_ADDRESS} "transfer(address,uint256)" \
    ${AIRDROP_ADDRESS} \
    <total_airdrop_supply> \
    --account someAccount \
    --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} \
    --legacy --zksync
```

**Step 7: Executing the Token Claim**
Now, anyone (here, `someAccount` acts as the transaction sender, though it could be anyone) can call the `claim` function on the `MerkleAirdrop` contract, providing the necessary proof and signature for someAccount2 to receive their tokens.

The arguments for the claim function typically are:

  * Claimant's address (`<address_of_someAccount2>`)

  * Claim amount (`<claim_amount>`)

  * Merkle proof (an array of `bytes32` hashes, specific to someAccount2, found in `output.json`)

  * Signature components (`V_VAL`, `R_VAL`, `S_VAL`)

```bash
# Retrieve Merkle proof elements for someAccount2 from output.json
# Example: "[0xproofelement1...,0xproofelement2...]"
cast send ${AIRDROP_ADDRESS} \
    "claim(address,uint256,bytes32[],uint8,bytes32,bytes32)" \
    <address_of_someAccount2> \
    <claim_amount> \
    "[<proof_element_1_for_someAccount2>,<proof_element_2_for_someAccount2>,...]" \
    ${V_VAL} \
    ${R_VAL} \
    ${S_VAL} \
    --account someAccount \
    --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} \
    --legacy --zksync

```
Ensure the proof array is correctly formatted as a string for the command line.

**Step 8: Verifying the Airdrop Claim**
After the claim transaction is confirmed, verify that someAccount2 received the tokens.

1. **Check Token Balance**:
```bash
cast call ${TOKEN_ADDRESS} "balanceOf(address)" <address_of_someAccount2> \
    --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL}
```

This will output the balance in hexadecimal format.

2. **Convert to Decimal**:

```bash
cast --to-dec <hex_balance_output_from_above>
```
Confirm this matches the expected claim amount (e.g., 25 tokens, considering decimals).

3. **Block Explorer**: You can also verify the transaction and token balance on the zkSync Sepolia block explorer.

## Key Considerations and Best Practices
* **Prioritize Scripting:** For any real-world or even frequent testnet deployments, use deployment scripts (e.g., Foundry scripts). Manual steps are error-prone and can lead to wasted gas or misconfigurations.

* **zkSync RPC URL**: Use official RPC URLs like `https://sepolia.era.zksync.dev`. At times, third-party RPCs might have compatibility issues or lag with newer zkSync features.

* **Merkle Data Integrity**: Always ensure your `input.json` and `output.json` files (or however you manage airdrop data) are current and the Merkle root used in the `MerkleAirdrop` contract deployment matches the root derived from your intended recipient list.

* `--no-hash` with `cast wallet sign`: This flag is crucial when the input message to `cast wallet sign` is already a hash (e.g., output from a contract's `getMessageHash` function). Omitting it would lead to signing the hash of the hash, resulting in an invalid signature.

* **Signature Schemes on zkSync**: Be aware of account types (EOA vs. smart contract accounts) and their supported signature verification methods, especially concerning `ecrecover` in the context of zkSync's native Account Abstraction.

* **Transaction Finality**: Transactions on zkSync (L2) are processed quickly. However, for full finality on Ethereum (L1), the transaction batch containing your L2 transaction must be finalized on L1. For testnet verification, L2 confirmation is usually sufficient.

### Useful Resources
* **zkSync Era Sepolia Testnet Explorer:** Essential for visually inspecting transactions, contract deployments, and token balances.

* **zkSync Account Abstraction Documentation:** `https://v2-docs.zksync.io/dev/developer-guides/aa.html` (Provides more context on `ecrecover` warnings and zkSync's account model).

By following these steps, you can manually deploy and interact with a Merkle airdrop contract on the zkSync Sepolia testnet, gaining a deeper understanding of the underlying processes. Remember to transition to scripted deployments for robustness and efficiency in your projects.