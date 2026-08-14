// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.36;

import {TestBase, Vm} from "./utils/TestBase.sol";
import {IReceiptRootAuthorityV1} from "../src/interfaces/IReceiptRootAuthorityV1.sol";
import {ReceiptRootEncodingV1} from "../src/libraries/ReceiptRootEncodingV1.sol";
import {ReceiptRootAuthorityV1} from "../src/ReceiptRootAuthorityV1.sol";

contract FuzzEncodingHarness {
    function digest(IReceiptRootAuthorityV1.Authorization memory a)
        external
        pure
        returns (bytes32)
    {
        return ReceiptRootEncodingV1.authorizationDigest(a);
    }
}

contract RootInvariantHandler {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    ReceiptRootAuthorityV1 public immutable root;
    mapping(bytes32 => bool) public seen;
    uint64 public successfulSteps;
    uint64 public conflictAttempts;

    constructor(ReceiptRootAuthorityV1 root_) {
        root = root_;
    }

    function step(uint64 aggregationId) external {
        bytes32 coordinate = ReceiptRootEncodingV1.coordinateId(_network(), 2, aggregationId);
        if (seen[coordinate]) return;
        IReceiptRootAuthorityV1.Authorization memory a = IReceiptRootAuthorityV1.Authorization({
            signerSetEpoch: 1,
            sourceNetworkId: _network(),
            sourceGenesisHash: 0xff7fe5a610f15fe7a0c52f94f86313fb7db7d3786e7f8acf2b66c11d5be7c242,
            sourceRuntimeId: 0x7f98ae91ea34aff20365f8f157636ea7b2eccd216212dca424ca4bce2b2b9a8b,
            verificationContextHash: 0x676acbc40b7c7b5ba646aee26dd77984104e0674391ebd9f8e70b60d84ca6660,
            domainId: 2,
            sourceBlockNumber: 6_726_351,
            sourceBlockHash: 0xb995cd3981fb8013be45d89009aa360a338935e4ec9feb8e653e7d724af9206c,
            aggregationId: aggregationId,
            root: 0x7c609ffcf63004e1203188d6fbed6f5431fa344d6f90990c2c45a6db3bbc466e,
            leafCount: 1,
            authorizationNonce: root.nextAuthorizationNonce()
        });
        bytes32 digest = ReceiptRootEncodingV1.authorizationDigest(a);
        bytes[] memory signatures = new bytes[](2);
        signatures[0] = _signature(2, digest);
        signatures[1] = _signature(3, digest);
        root.register(a, signatures);
        seen[coordinate] = true;
        ++successfulSteps;
        _attemptOverwrite(a, coordinate);
    }

    function _attemptOverwrite(IReceiptRootAuthorityV1.Authorization memory a, bytes32 coordinate)
        private
    {
        bytes32 originalRoot = a.root;
        a.root = bytes32(uint256(a.root) ^ 1);
        bytes32 digest = ReceiptRootEncodingV1.authorizationDigest(a);
        bytes[] memory signatures = new bytes[](2);
        signatures[0] = _signature(2, digest);
        signatures[1] = _signature(3, digest);
        bytes32 beforeDigest = root.stateDigest();
        (bool ok, bytes memory reason) =
            address(root).call(abi.encodeCall(root.register, (a, signatures)));
        require(!ok && _selector(reason) == ReceiptRootAuthorityV1.RootConflict.selector);
        require(root.stateDigest() == beforeDigest);
        require(root.registeredRoot(coordinate).root == originalRoot);
        ++conflictAttempts;
    }

    function _signature(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _network() private pure returns (bytes32) {
        return 0x63f64f53339e0cfb288c57b0091f4932fa3181361fa87ba1dc583fbc172d836e;
    }

    function _selector(bytes memory reason) private pure returns (bytes4 selector) {
        if (reason.length < 4) return bytes4(0);
        assembly ("memory-safe") { selector := mload(add(reason, 32)) }
    }
}

contract DestinationEnforcementFuzzTest is TestBase {
    ReceiptRootAuthorityV1 internal root;
    RootInvariantHandler internal handler;
    FuzzEncodingHarness internal encoding;
    address[] internal targets;

    function setUp() public {
        address[] memory signers = new address[](3);
        signers[0] = vm.addr(2);
        signers[1] = vm.addr(3);
        signers[2] = vm.addr(1);
        root = new ReceiptRootAuthorityV1(
            1,
            signers,
            2,
            0x63f64f53339e0cfb288c57b0091f4932fa3181361fa87ba1dc583fbc172d836e,
            0xff7fe5a610f15fe7a0c52f94f86313fb7db7d3786e7f8acf2b66c11d5be7c242,
            0x7f98ae91ea34aff20365f8f157636ea7b2eccd216212dca424ca4bce2b2b9a8b,
            0x676acbc40b7c7b5ba646aee26dd77984104e0674391ebd9f8e70b60d84ca6660,
            2
        );
        handler = new RootInvariantHandler(root);
        encoding = new FuzzEncodingHarness();
        targets.push(address(handler));
    }

    function targetContracts() public view returns (address[] memory) {
        return targets;
    }

    function testFuzzAuthorizationTupleIsFullyDigestBound(
        uint64 epoch,
        bytes32 network,
        bytes32 genesis,
        bytes32 runtime,
        bytes32 context,
        uint32 domain,
        uint64 blockNumber,
        bytes32 blockHash,
        uint64 aggregation,
        bytes32 receiptRoot,
        uint32 count,
        uint64 nonce
    ) public view {
        IReceiptRootAuthorityV1.Authorization memory a =
            IReceiptRootAuthorityV1.Authorization({
                signerSetEpoch: epoch,
                sourceNetworkId: network,
                sourceGenesisHash: genesis,
                sourceRuntimeId: runtime,
                verificationContextHash: context,
                domainId: domain,
                sourceBlockNumber: blockNumber,
                sourceBlockHash: blockHash,
                aggregationId: aggregation,
                root: receiptRoot,
                leafCount: count,
                authorizationNonce: nonce
            });
        bytes32 digest = encoding.digest(a);
        a.signerSetEpoch ^= 1;
        assertTrue(encoding.digest(a) != digest);
        a.signerSetEpoch ^= 1;
        a.sourceNetworkId = bytes32(uint256(a.sourceNetworkId) ^ 1);
        assertTrue(encoding.digest(a) != digest);
        a.sourceNetworkId = bytes32(uint256(a.sourceNetworkId) ^ 1);
        a.sourceGenesisHash = bytes32(uint256(a.sourceGenesisHash) ^ 1);
        assertTrue(encoding.digest(a) != digest);
        a.sourceGenesisHash = bytes32(uint256(a.sourceGenesisHash) ^ 1);
        a.sourceRuntimeId = bytes32(uint256(a.sourceRuntimeId) ^ 1);
        assertTrue(encoding.digest(a) != digest);
        a.sourceRuntimeId = bytes32(uint256(a.sourceRuntimeId) ^ 1);
        a.verificationContextHash = bytes32(uint256(a.verificationContextHash) ^ 1);
        assertTrue(encoding.digest(a) != digest);
        a.verificationContextHash = bytes32(uint256(a.verificationContextHash) ^ 1);
        a.domainId ^= 1;
        assertTrue(encoding.digest(a) != digest);
        a.domainId ^= 1;
        a.sourceBlockNumber ^= 1;
        assertTrue(encoding.digest(a) != digest);
        a.sourceBlockNumber ^= 1;
        a.sourceBlockHash = bytes32(uint256(a.sourceBlockHash) ^ 1);
        assertTrue(encoding.digest(a) != digest);
        a.sourceBlockHash = bytes32(uint256(a.sourceBlockHash) ^ 1);
        a.aggregationId ^= 1;
        assertTrue(encoding.digest(a) != digest);
        a.aggregationId ^= 1;
        a.root = bytes32(uint256(a.root) ^ 1);
        assertTrue(encoding.digest(a) != digest);
        a.root = bytes32(uint256(a.root) ^ 1);
        a.leafCount ^= 1;
        assertTrue(encoding.digest(a) != digest);
        a.leafCount ^= 1;
        a.authorizationNonce ^= 1;
        assertTrue(encoding.digest(a) != digest);
    }

    function invariant_SuccessfulRegistrationsAdvanceCountersAndStrictNonceTogether() public view {
        assertEq(root.transitionCount(), handler.successfulSteps());
        assertEq(root.eventCount(), handler.successfulSteps());
        assertEq(root.nextAuthorizationNonce(), handler.successfulSteps() + 1);
        assertEq(handler.conflictAttempts(), handler.successfulSteps());
    }
}
