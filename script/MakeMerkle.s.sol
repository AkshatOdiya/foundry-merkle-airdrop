/**
 * @notice logic overview:
 * The MakeMerkle.s.sol script performs the following main operations:
 *
 * a. Read and Parse input.json: Uses vm.readFile() to load the content of script/target/input.json. Then, it uses stdJson cheatcodes (e.g., stdJson.readStringArray(json, ".types"), stdJson.readUint(json, ".count")) to parse the JSON data into Solidity variables.
 *
 * b. Process Each Leaf Entry:
 *
 * Iterates count times (once for each leaf defined in input.json).
 *
 * For each leaf, it reads the constituent parts (e.g., address and amount) based on the types array.
 *
 * Address to bytes32 Conversion: Ethereum addresses are 20 bytes. For cryptographic hashing within the Merkle tree, they need to be converted to bytes32. This is typically done by casting: address -> uint160 -> uint256 -> bytes32. The amount (uint) is also cast to bytes32.
 *
 * These bytes32 values are stored temporarily for the current leaf.
 *
 * c. Leaf Hash Calculation:
 *
 * The bytes32 representations of the leaf's data (e.g., address and amount) are ABI-encoded together: abi.encode(data_part1_bytes32, data_part2_bytes32, ...).
 *
 * Trimming ABI Encoding: The ScriptHelper.ltrim64() function from murky is used. When dynamic types (like arrays) are declared in memory and then ABI-encoded, the encoding includes offsets and lengths. ltrim64 removes these, providing the tightly packed data bytes suitable for hashing.
 *
 * Double Hashing: The trimmed, ABI-encoded data is then hashed, typically twice: keccak256(bytes.concat(keccak256(trimmed_encoded_data))). This double hashing is a common practice in Merkle tree implementations to mitigate potential vulnerabilities like second-preimage attacks, especially if parts of the tree structure might be known or manipulated.
 *
 * The resulting bytes32 hash is the leaf hash for the current entry and is stored in an array of leaves.
 *
 * d. Generate Merkle Root and Proofs:
 *
 * After all leaf hashes are computed and collected in the leaves array:
 *
 * An instance of murky's Merkle library is used.
 *
 * For each leaf i:
 *
 * merkleInstance.getProof(leaves, i): Retrieves the Merkle proof for the i-th leaf.
 *
 * merkleInstance.getRoot(leaves): Retrieves the Merkle root of the entire tree (this will be the same for all leaves).
 *
 * e. Construct and Write output.json:
 *
 * For each leaf, the script gathers its original input values (as strings), its computed leaf hash, its proof, and the common root.
 *
 * This information is formatted into a JSON object structure as described earlier for output.json.
 *
 * All these individual JSON entry strings are collected and combined into a single valid JSON array string.
 *
 * vm.writeFile("script/target/output.json", finalJsonString) saves the complete Merkle tree data.
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {console} from "forge-std/console.sol";
import {Merkle} from "murky/src/Merkle.sol";
import {ScriptHelper} from "murky/script/common/ScriptHelper.sol";

// Merkle proof generator script
// To use:
// 1. Run `forge script script/GenerateInput.s.sol` to generate the input file
// 2. Run `forge script script/MakeMerkle.s.sol`
// 3. The output file will be generated in /script/target/output.json

/**
 * Original Work by:
 * @author kootsZhin
 * @notice https://github.com/dmfxyz/murky
 */
contract MakeMerkle is Script, ScriptHelper {
    using stdJson for string; // enables us to use the json cheatcodes for strings

    Merkle private m = new Merkle(); // instance of the merkle contract from Murky to do shit

    string private inputPath = "/script/target/input.json";
    string private outputPath = "/script/target/output.json";

    string private elements = vm.readFile(string.concat(vm.projectRoot(), inputPath)); // get the absolute path
    string[] private types = elements.readStringArray(".types"); // gets the merkle tree leaf types from json using forge standard lib cheatcode
    uint256 private count = elements.readUint(".count"); // get the number of leaf nodes

    // make three arrays the same size as the number of leaf nodes
    bytes32[] private leafs = new bytes32[](count);

    string[] private inputs = new string[](count);
    string[] private outputs = new string[](count);

    string private output;

    /// @dev Returns the JSON path of the input file
    // output file output ".values.some-address.some-amount"
    function getValuesByIndex(uint256 i, uint256 j) internal pure returns (string memory) {
        return string.concat(".values.", vm.toString(i), ".", vm.toString(j));
    }

    /// @dev Generate the JSON entries for the output file
    function generateJsonEntries(string memory _inputs, string memory _proof, string memory _root, string memory _leaf)
        internal
        pure
        returns (string memory)
    {
        string memory result = string.concat(
            "{",
            "\"inputs\":",
            _inputs,
            ",",
            "\"proof\":",
            _proof,
            ",",
            "\"root\":\"",
            _root,
            "\",",
            "\"leaf\":\"",
            _leaf,
            "\"",
            "}"
        );

        return result;
    }

    /// @dev Read the input file and generate the Merkle proof, then write the output file
    function run() public {
        console.log("Generating Merkle Proof for %s", inputPath);

        for (uint256 i = 0; i < count; ++i) {
            string[] memory input = new string[](types.length); // stringified data (address and string both as strings)
            bytes32[] memory data = new bytes32[](types.length); // actual data as a bytes32

            for (uint256 j = 0; j < types.length; ++j) {
                if (compareStrings(types[j], "address")) {
                    address value = elements.readAddress(getValuesByIndex(i, j));
                    // you can't immediately cast straight to 32 bytes as an address is 20 bytes so first cast to uint160 (20 bytes) cast up to uint256 which is 32 bytes and finally to bytes32
                    data[j] = bytes32(uint256(uint160(value)));
                    input[j] = vm.toString(value);
                } else if (compareStrings(types[j], "uint")) {
                    uint256 value = vm.parseUint(elements.readString(getValuesByIndex(i, j)));
                    data[j] = bytes32(value);
                    input[j] = vm.toString(value);
                }
            }
            // Create the hash for the merkle tree leaf node
            // abi encode the data array (each element is a bytes32 representation for the address and the amount)
            // Helper from Murky (ltrim64) Returns the bytes with the first 64 bytes removed
            // ltrim64 removes the offset and length from the encoded bytes. There is an offset because the array
            // is declared in memory
            // hash the encoded address and amount
            // bytes.concat turns from bytes32 to bytes
            // hash again because preimage attack
            leafs[i] = keccak256(bytes.concat(keccak256(ltrim64(abi.encode(data)))));
            // Converts a string array into a JSON array string.
            // store the corresponding values/inputs for each leaf node
            inputs[i] = stringArrayToString(input);
        }

        for (uint256 i = 0; i < count; ++i) {
            // get proof gets the nodes needed for the proof & stringify (from helper lib)
            string memory proof = bytes32ArrayToString(m.getProof(leafs, i));
            // get the root hash and stringify
            string memory root = vm.toString(m.getRoot(leafs));
            // get the specific leaf working on
            string memory leaf = vm.toString(leafs[i]);
            // get the singified input (address, amount)
            string memory input = inputs[i];

            // generate the Json output file (tree dump)
            outputs[i] = generateJsonEntries(input, proof, root, leaf);
        }

        // stringify the array of strings to a single string
        output = stringArrayToArrayString(outputs);
        // write to the output file the stringified output json (tree dump)
        vm.writeFile(string.concat(vm.projectRoot(), outputPath), output);

        console.log("DONE: The output is found at %s", outputPath);
    }
}
