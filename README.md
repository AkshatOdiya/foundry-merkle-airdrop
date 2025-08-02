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

