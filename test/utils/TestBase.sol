// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.36;

interface Vm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }

    function addr(uint256 privateKey) external returns (address);
    function sign(uint256 privateKey, bytes32 digest)
        external
        returns (uint8 v, bytes32 r, bytes32 s);
    function chainId(uint256 newChainId) external;
    function readFile(string calldata path) external view returns (string memory data);
    function parseJsonString(string calldata json, string calldata key)
        external
        pure
        returns (string memory);
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory logs);
}

abstract contract TestBase {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    error AssertionFailed();

    function assertTrue(bool condition) internal pure {
        if (!condition) revert AssertionFailed();
    }

    function assertEq(bytes32 a, bytes32 b) internal pure {
        if (a != b) revert AssertionFailed();
    }

    function assertEq(uint256 a, uint256 b) internal pure {
        if (a != b) revert AssertionFailed();
    }

    function assertEq(address a, address b) internal pure {
        if (a != b) revert AssertionFailed();
    }

    function assertEq(bytes4 a, bytes4 b) internal pure {
        if (a != b) revert AssertionFailed();
    }

    function assertEq(string memory a, string memory b) internal pure {
        if (keccak256(bytes(a)) != keccak256(bytes(b))) revert AssertionFailed();
    }

    function signature(uint256 privateKey, bytes32 digest) internal returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }
}
