// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.36;

import {TestBase, Vm} from "./utils/TestBase.sol";
import {IReceiptRootAuthorityV1} from "../src/interfaces/IReceiptRootAuthorityV1.sol";
import {ReceiptRootEncodingV1} from "../src/libraries/ReceiptRootEncodingV1.sol";
import {ReceiptRootAuthorityV1} from "../src/ReceiptRootAuthorityV1.sol";
import {StateSyncGKRSettlementV1} from "../src/StateSyncGKRSettlementV1.sol";

contract EncodingHarness {
    function preimage(IReceiptRootAuthorityV1.Authorization memory a)
        external
        pure
        returns (bytes memory)
    {
        return ReceiptRootEncodingV1.authorizationPreimage(a);
    }

    function digest(IReceiptRootAuthorityV1.Authorization memory a)
        external
        pure
        returns (bytes32)
    {
        return ReceiptRootEncodingV1.authorizationDigest(a);
    }

    function coordinate(bytes32 network, uint32 domain, uint64 aggregation)
        external
        pure
        returns (bytes32)
    {
        return ReceiptRootEncodingV1.coordinateId(network, domain, aggregation);
    }

    function statement(bytes memory raw) external pure returns (bytes32, bytes32, uint8) {
        return ReceiptRootEncodingV1.canonicalStatement(raw);
    }

    function preclaim(bytes32 route, bytes memory raw) external pure returns (bytes32) {
        return ReceiptRootEncodingV1.preclaimHash(route, raw);
    }

    function pfr(ReceiptRootEncodingV1.PrimaryFinalityRecord memory record)
        external
        pure
        returns (bytes32)
    {
        return ReceiptRootEncodingV1.pfrRecordId(record);
    }

    function claim(bytes32 route, bytes32 pfrId, bytes memory raw) external pure returns (bytes32) {
        return ReceiptRootEncodingV1.claimId(route, pfrId, raw);
    }

    function settlement(bytes32 transitionId, uint64 chainId, bytes32 consumer, uint8 action)
        external
        pure
        returns (bytes32)
    {
        return ReceiptRootEncodingV1.settlementKey(transitionId, chainId, consumer, action);
    }
}

contract RootHarness is ReceiptRootAuthorityV1 {
    constructor(
        uint64 epoch,
        address[] memory signers,
        uint16 threshold_,
        bytes32 network,
        bytes32 genesis,
        bytes32 runtime,
        bytes32 context,
        uint32 domain
    )
        ReceiptRootAuthorityV1(
            epoch, signers, threshold_, network, genesis, runtime, context, domain
        )
    {}

    function setCounters(uint64 nonce, uint64 transitions_, uint64 events_) external {
        nextNonce = nonce;
        transitions = transitions_;
        eventsEmitted = events_;
    }
}

contract SettlementHarness is StateSyncGKRSettlementV1 {
    constructor(
        IReceiptRootAuthorityV1 root,
        uint64 epoch,
        address[] memory signers,
        uint16 threshold_,
        bytes32 image,
        bytes32 version
    ) StateSyncGKRSettlementV1(root, epoch, signers, threshold_, image, version) {}

    function setCounters(uint64 transitions_, uint64 events_) external {
        transitions = transitions_;
        eventsEmitted = events_;
    }
}

contract DestinationEnforcementTest is TestBase {
    bytes32 internal constant NETWORK =
        0x63f64f53339e0cfb288c57b0091f4932fa3181361fa87ba1dc583fbc172d836e;
    bytes32 internal constant GENESIS =
        0xff7fe5a610f15fe7a0c52f94f86313fb7db7d3786e7f8acf2b66c11d5be7c242;
    bytes32 internal constant RUNTIME =
        0x7f98ae91ea34aff20365f8f157636ea7b2eccd216212dca424ca4bce2b2b9a8b;
    bytes32 internal constant CONTEXT =
        0x676acbc40b7c7b5ba646aee26dd77984104e0674391ebd9f8e70b60d84ca6660;
    bytes32 internal constant BLOCK_HASH =
        0xb995cd3981fb8013be45d89009aa360a338935e4ec9feb8e653e7d724af9206c;
    bytes32 internal constant STATEMENT =
        0xb4b058ae36bcc8357241b0c308630d7ba203bd47726edbad5ed16b04afeb8492;
    bytes32 internal constant ROOT =
        0x7c609ffcf63004e1203188d6fbed6f5431fa344d6f90990c2c45a6db3bbc466e;
    bytes32 internal constant IMAGE =
        0xdd947fec1fe270c41bc0457912e1e77427c16797ac47dc6a1c825a9323648643;
    bytes32 internal constant VERSION =
        0xaa24368f9ce9025f58596d966209fc3f322c8cac37dae753bb9b0367d273700d;
    bytes32 internal constant ROUTE =
        0x27b40b99a41976f061e94124b84cc8c43ee4e5ed6bad2e94267057e1d375f2ef;
    bytes32 internal constant RAW_SHA =
        0x959550f3847e15ae2d69ab027d8ef59621282eeb758746262205fa3f61b38721;
    bytes32 internal constant PRECLAIM =
        0x8efaa82794a8587ba8f497dbdcbb65695704322a87f0d16bf667af565ba6c3ad;
    bytes32 internal constant PFR_ID =
        0xa5a5ed3ac2ad0b61efdebcc8f9db1a020cb20fd186e2ea3657c747cb0aec5df7;
    bytes32 internal constant CLAIM =
        0x92a3b5b95bbba1a162dcd7107a7e797e7ca132c1fe7ae438e51014b37e4d03d4;
    bytes32 internal constant SETTLEMENT =
        0xe55506cb0cb5c7d6a8b1ca41a28beea24b5d160987566075ec10e11cd382e93d;
    bytes32 internal constant ACCEPTED =
        0x88957f2aa94f0f483d11f6bbc00b37db9fedd7911eee56e15c1661e148453200;
    address internal constant ROOT_2 = 0x2B5AD5c4795c026514f8317c7a215E218DcCD6cF;
    address internal constant ROOT_3 = 0x6813Eb9362372EEF6200f3b1dbC3f819671cBA69;
    address internal constant ROOT_1 = 0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf;
    address internal constant PFR_4 = 0x1efF47bc3a10a45D4B230B5d10E37751FE6AA718;

    EncodingHarness internal encoding;

    function setUp() public {
        encoding = new EncodingHarness();
    }

    function testVendoredVectorCustodyAndTypedRows() public view {
        string memory json = vm.readFile("vectors/risc0-route-b-destination-policy-v1.json");
        assertEq(
            sha256(bytes(json)), 0x29a4528629d471ab9d3efcefec4a494477a93b5866e689fbeb3010b1e7627141
        );
        for (uint256 i; i < 33; ++i) {
            string memory base = string.concat(".negative_cases[", _decimal(i), "]");
            assertTrue(bytes(vm.parseJsonString(json, string.concat(base, ".id"))).length != 0);
            assertTrue(
                bytes(vm.parseJsonString(json, string.concat(base, ".operation"))).length != 0
            );
            assertTrue(bytes(vm.parseJsonString(json, string.concat(base, ".field"))).length != 0);
            assertTrue(
                bytes(vm.parseJsonString(json, string.concat(base, ".value.kind"))).length != 0
            );
            assertTrue(
                bytes(vm.parseJsonString(json, string.concat(base, ".expected_error"))).length != 0
            );
        }
    }

    function testExactEncodingAndSettlementVectorParity() public view {
        IReceiptRootAuthorityV1.Authorization memory a = _authorization(1);
        bytes memory preimage = encoding.preimage(a);
        assertEq(preimage.length, 260);
        assertEq(
            keccak256(preimage), 0x7ccc4e3c7d7f38c2f37e515e26edf63b9d3cc8b069b463600961c780ea535c7d
        );
        assertEq(
            encoding.coordinate(NETWORK, 2, 53_668),
            0x02642bf98eddfd93180e16bd10f7b00206d37d708e281f3bdb331f689ee94698
        );
        bytes memory raw = _raw();
        (bytes32 rawSha, bytes32 accepted, uint8 action) = encoding.statement(raw);
        assertEq(rawSha, RAW_SHA);
        assertEq(accepted, ACCEPTED);
        assertEq(action, 0);
        assertEq(keccak256(abi.encodePacked(CONTEXT, IMAGE, VERSION, keccak256(raw))), STATEMENT);
        assertEq(encoding.preclaim(ROUTE, raw), PRECLAIM);
        ReceiptRootEncodingV1.PrimaryFinalityRecord memory record = _vectorRecord();
        assertEq(encoding.pfr(record), PFR_ID);
        assertEq(encoding.claim(ROUTE, PFR_ID, raw), CLAIM);
        assertEq(encoding.settlement(RAW_SHA, 84_532, _vectorConsumer(), 0), SETTLEMENT);
        address recovered = ecrecover(
            PFR_ID,
            28,
            0x6457db3ee18bd1c13829af54553c95862e87362a325989a42352b262169ab373,
            0x4c6061fa290797f2a90c6e19f51d82259d8e52d6a60138324f770a2df170f5e7
        );
        assertEq(recovered, PFR_4);
    }

    function testExactRootRegistrationAndReplayConflict() public {
        RootHarness root = _root();
        IReceiptRootAuthorityV1.Authorization memory a = _authorization(1);
        bytes[] memory signatures = _vectorRootSignatures();
        vm.recordLogs();
        bytes32 coordinate = root.register(a, signatures);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(root.nextAuthorizationNonce(), 2);
        assertEq(root.transitionCount(), 1);
        assertEq(root.eventCount(), 1);
        assertEq(root.registeredRoot(coordinate).root, ROOT);

        _assertRootFailure(
            root,
            abi.encodeCall(root.register, (a, signatures)),
            ReceiptRootAuthorityV1.AuthorizationReplay.selector
        );
        a.root = bytes32(uint256(ROOT) ^ 1);
        _assertRootFailure(
            root,
            abi.encodeCall(root.register, (a, _signRoot(a))),
            ReceiptRootAuthorityV1.RootConflict.selector
        );
    }

    function testRootSignerAndSignatureNegativeParity() public {
        _constructorNegatives();
        RootHarness root = _root();
        IReceiptRootAuthorityV1.Authorization memory a = _authorization(1);
        bytes32 digest = encoding.digest(a);
        bytes[] memory one = new bytes[](1);
        one[0] =
            hex"00000000000000000000000000000000000000000000000000000000000000000dc25336adb16930c8dc3eea3e9dfe7bd3f64f7709567d3522867977b83141d71b";
        _assertRootFailure(
            root,
            abi.encodeCall(root.register, (a, one)),
            ReceiptRootAuthorityV1.ZeroAttester.selector
        );

        bytes[] memory duplicate = new bytes[](2);
        duplicate[0] = _vectorRootSignatures()[0];
        duplicate[1] = duplicate[0];
        _assertRootFailure(
            root,
            abi.encodeCall(root.register, (a, duplicate)),
            ReceiptRootAuthorityV1.DuplicateAttester.selector
        );
        bytes[] memory unsorted = new bytes[](2);
        unsorted[0] = _vectorRootSignatures()[1];
        unsorted[1] = _vectorRootSignatures()[0];
        _assertRootFailure(
            root,
            abi.encodeCall(root.register, (a, unsorted)),
            ReceiptRootAuthorityV1.AttestersNotSorted.selector
        );
        bytes[] memory below = new bytes[](1);
        below[0] = _vectorRootSignatures()[0];
        _assertRootFailure(
            root,
            abi.encodeCall(root.register, (a, below)),
            ReceiptRootAuthorityV1.BelowThreshold.selector
        );
        bytes[] memory nonmember = new bytes[](1);
        nonmember[0] =
            hex"4447e6dd35042c316114a4f4dd4e0c3454bdc29e2d4b87c73127cf82cd27530a53a90e348485d63261eceea31afc801dd5f6f3e1af3fc90cf5f712b196bd24631c";
        _assertRootFailure(
            root,
            abi.encodeCall(root.register, (a, nonmember)),
            ReceiptRootAuthorityV1.UnauthorizedAttester.selector
        );
        nonmember[0] =
            hex"c6ddd1fdd78a95833292d48573b5824fe6f831e97333b2964f5bbd679b4d809e0eec5b94a95e05d756f00d072829b80eb75c2227d6546b740edb864d75fc34ee1c";
        _assertRootFailure(
            root,
            abi.encodeCall(root.register, (a, nonmember)),
            ReceiptRootAuthorityV1.UnauthorizedAttester.selector
        );

        bytes memory zeroR = one[0];
        _assertPureFailure(
            address(root),
            abi.encodeCall(root.recoverSigner, (digest, zeroR)),
            ReceiptRootAuthorityV1.InvalidSignature.selector
        );
        bytes memory zeroS = abi.encodePacked(bytes32(uint256(1)), bytes32(0), uint8(27));
        _assertPureFailure(
            address(root),
            abi.encodeCall(root.recoverSigner, (digest, zeroS)),
            ReceiptRootAuthorityV1.InvalidSignature.selector
        );
        bytes memory highS =
            hex"24e99c2e886dc9580021cbcfca9c50834283f9a0d87e5b4655540e48c1db674cf23dacc9524e96cf3723c115c1620182e6b88d6fa5f223069d4be5151804ff6a1c";
        _assertPureFailure(
            address(root),
            abi.encodeCall(root.recoverSigner, (digest, highS)),
            ReceiptRootAuthorityV1.HighSignatureS.selector
        );
        bytes memory badV =
            hex"24e99c2e886dc9580021cbcfca9c50834283f9a0d87e5b4655540e48c1db674c0dc25336adb16930c8dc3eea3e9dfe7bd3f64f7709567d3522867977b83141d71d";
        _assertPureFailure(
            address(root),
            abi.encodeCall(root.recoverSigner, (digest, badV)),
            ReceiptRootAuthorityV1.InvalidRecoveryId.selector
        );
    }

    function testRootContextNonceOverflowAndBounds() public {
        RootHarness root = _root();
        IReceiptRootAuthorityV1.Authorization memory a = _authorization(1);
        a.signerSetEpoch = 0;
        _assertRootFailure(
            root,
            abi.encodeCall(root.register, (a, _signRoot(a))),
            ReceiptRootAuthorityV1.StaleSignerSetEpoch.selector
        );
        a = _authorization(1);
        a.sourceNetworkId = bytes32(uint256(NETWORK) ^ 1);
        _assertRootFailure(
            root,
            abi.encodeCall(root.register, (a, _signRoot(a))),
            ReceiptRootAuthorityV1.AuthorityContextMismatch.selector
        );
        a = _authorization(1);
        a.leafCount = 2;
        _assertRootFailure(
            root,
            abi.encodeCall(root.register, (a, _signRoot(a))),
            ReceiptRootAuthorityV1.InvalidLeafCount.selector
        );
        a = _authorization(2);
        _assertRootFailure(
            root,
            abi.encodeCall(root.register, (a, _signRoot(a))),
            ReceiptRootAuthorityV1.UnexpectedAuthorizationNonce.selector
        );

        a = _authorization(type(uint64).max);
        root.setCounters(type(uint64).max, 0, 0);
        _assertRootFailure(
            root,
            abi.encodeCall(root.register, (a, _signRoot(a))),
            ReceiptRootAuthorityV1.ArithmeticOverflow.selector
        );
        root = _root();
        a = _authorization(1);
        root.setCounters(1, type(uint64).max, 0);
        _assertRootFailure(
            root,
            abi.encodeCall(root.register, (a, _signRoot(a))),
            ReceiptRootAuthorityV1.ArithmeticOverflow.selector
        );
        root = _root();
        root.setCounters(1, 0, type(uint64).max);
        _assertRootFailure(
            root,
            abi.encodeCall(root.register, (a, _signRoot(a))),
            ReceiptRootAuthorityV1.ArithmeticOverflow.selector
        );

        bytes[] memory tooMany = new bytes[](4);
        _assertRootFailure(
            root,
            abi.encodeCall(root.register, (a, tooMany)),
            ReceiptRootAuthorityV1.TooManySignatures.selector
        );
    }

    function testNextCoordinateRequiresStrictNextNonce() public {
        RootHarness root = _root();
        IReceiptRootAuthorityV1.Authorization memory first = _authorization(1);
        root.register(first, _vectorRootSignatures());
        IReceiptRootAuthorityV1.Authorization memory next = _authorization(1);
        next.aggregationId += 1;
        _assertRootFailure(
            root,
            abi.encodeCall(root.register, (next, _signRoot(next))),
            ReceiptRootAuthorityV1.UnexpectedAuthorizationNonce.selector
        );
        next.authorizationNonce = 3;
        _assertRootFailure(
            root,
            abi.encodeCall(root.register, (next, _signRoot(next))),
            ReceiptRootAuthorityV1.UnexpectedAuthorizationNonce.selector
        );
        next.authorizationNonce = 2;
        root.register(next, _signRoot(next));
        assertEq(root.nextAuthorizationNonce(), 3);
        assertEq(root.transitionCount(), 2);
    }

    function testCanonicalPackingOddNextLimbAndEdges() public view {
        bytes memory raw = _raw();
        for (uint256 i = 32; i < 64; ++i) {
            raw[i] = bytes1(0);
        }
        raw[32] = bytes1(uint8(1));
        raw[35] = bytes1(uint8(0x80));
        encoding.statement(raw);
        raw = _raw();
        raw[63] = bytes1(uint8(1));
        _assertPureFailure(
            address(encoding),
            abi.encodeCall(encoding.statement, (raw)),
            ReceiptRootEncodingV1.NonCanonicalStatement.selector
        );
    }

    function testSettlementHonestConsumeAndAtomicReplay() public {
        (RootHarness root, SettlementHarness consumer) = _registeredSystem();
        ReceiptRootEncodingV1.PrimaryFinalityRecord memory record = _runtimeRecord(consumer);
        StateSyncGKRSettlementV1.ReceiptAttachment memory receipt = _receipt();
        bytes[] memory signatures = _signPfr(record);
        vm.recordLogs();
        (bytes32 claim, bytes32 settlement) = consumer.consume(record, _raw(), receipt, signatures);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertTrue(consumer.consumedClaims(claim));
        assertTrue(consumer.consumedSettlements(settlement));
        assertEq(consumer.transitionCount(), 1);
        assertEq(consumer.eventCount(), 1);
        _assertSettlementFailure(
            consumer,
            abi.encodeCall(consumer.consume, (record, _raw(), receipt, signatures)),
            StateSyncGKRSettlementV1.ClaimReplay.selector
        );

        ReceiptRootEncodingV1.PrimaryFinalityRecord memory alternate = record;
        alternate.routeId = bytes32(uint256(record.routeId) ^ 1);
        alternate.preclaimHash = encoding.preclaim(alternate.routeId, _raw());
        bytes[] memory alternateSignatures = _signPfr(alternate);
        _assertSettlementFailure(
            consumer,
            abi.encodeCall(consumer.consume, (alternate, _raw(), receipt, alternateSignatures)),
            StateSyncGKRSettlementV1.SettlementReplay.selector
        );
        assertEq(root.eventCount(), 1);
    }

    function testSettlementAttachmentAndBindingNegatives() public {
        (, SettlementHarness consumer) = _registeredSystem();
        ReceiptRootEncodingV1.PrimaryFinalityRecord memory record = _runtimeRecord(consumer);
        bytes[] memory signatures = _signPfr(record);
        StateSyncGKRSettlementV1.ReceiptAttachment memory receipt = _receipt();

        receipt.statement = bytes32(uint256(STATEMENT) ^ 1);
        _assertSettlementFailure(
            consumer,
            abi.encodeCall(consumer.consume, (record, _raw(), receipt, signatures)),
            StateSyncGKRSettlementV1.ReceiptRootMismatch.selector
        );
        receipt = _receipt();
        receipt.leafIndex = 1;
        _assertSettlementFailure(
            consumer,
            abi.encodeCall(consumer.consume, (record, _raw(), receipt, signatures)),
            StateSyncGKRSettlementV1.InvalidMerklePath.selector
        );
        receipt = _receipt();
        receipt.leafCount = 2;
        _assertSettlementFailure(
            consumer,
            abi.encodeCall(consumer.consume, (record, _raw(), receipt, signatures)),
            StateSyncGKRSettlementV1.InvalidMerklePath.selector
        );
        receipt = _receipt();
        receipt.merklePath = new bytes32[](1);
        _assertSettlementFailure(
            consumer,
            abi.encodeCall(consumer.consume, (record, _raw(), receipt, signatures)),
            StateSyncGKRSettlementV1.InvalidMerklePath.selector
        );

        receipt = _receipt();
        bytes memory wrongRaw = _raw();
        wrongRaw[160] ^= bytes1(uint8(1));
        _assertSettlementFailure(
            consumer,
            abi.encodeCall(consumer.consume, (record, wrongRaw, receipt, signatures)),
            StateSyncGKRSettlementV1.ReceiptRootMismatch.selector
        );
        record.acceptedRoot = bytes32(uint256(ACCEPTED) ^ 1);
        _assertSettlementFailure(
            consumer,
            abi.encodeCall(consumer.consume, (record, _raw(), receipt, _signPfr(record))),
            StateSyncGKRSettlementV1.AcceptedRootMismatch.selector
        );

        RootHarness wrongRoot = _root();
        IReceiptRootAuthorityV1.Authorization memory wrongAuthorization = _authorization(1);
        wrongAuthorization.root = bytes32(uint256(ROOT) ^ 1);
        wrongRoot.register(wrongAuthorization, _signRoot(wrongAuthorization));
        address[] memory pfr = new address[](1);
        pfr[0] = PFR_4;
        SettlementHarness wrongRootConsumer =
            new SettlementHarness(wrongRoot, 7, pfr, 1, IMAGE, VERSION);
        record = _runtimeRecord(wrongRootConsumer);
        _assertSettlementFailure(
            wrongRootConsumer,
            abi.encodeCall(
                wrongRootConsumer.consume, (record, _raw(), _receipt(), _signPfr(record))
            ),
            StateSyncGKRSettlementV1.ReceiptRootMismatch.selector
        );
    }

    function testNativeStatementManifestComponentMutationsFailClosed() public {
        (RootHarness root, SettlementHarness consumer) = _registeredSystem();
        ReceiptRootEncodingV1.PrimaryFinalityRecord memory record = _runtimeRecord(consumer);
        StateSyncGKRSettlementV1.ReceiptAttachment memory receipt = _receipt();
        receipt.verificationContextHash = bytes32(uint256(CONTEXT) ^ 1);
        _assertSettlementFailure(
            consumer,
            abi.encodeCall(consumer.consume, (record, _raw(), receipt, _signPfr(record))),
            StateSyncGKRSettlementV1.ReceiptRootMismatch.selector
        );
        address[] memory pfr = new address[](1);
        pfr[0] = PFR_4;
        SettlementHarness wrongImage =
            new SettlementHarness(root, 7, pfr, 1, bytes32(uint256(IMAGE) ^ 1), VERSION);
        assertTrue(wrongImage.stateDigest() != consumer.stateDigest());
        record = _runtimeRecord(wrongImage);
        _assertSettlementFailure(
            wrongImage,
            abi.encodeCall(wrongImage.consume, (record, _raw(), _receipt(), _signPfr(record))),
            StateSyncGKRSettlementV1.ReceiptRootMismatch.selector
        );
        SettlementHarness wrongVersion =
            new SettlementHarness(root, 7, pfr, 1, IMAGE, bytes32(uint256(VERSION) ^ 1));
        assertTrue(wrongVersion.stateDigest() != consumer.stateDigest());
        record = _runtimeRecord(wrongVersion);
        _assertSettlementFailure(
            wrongVersion,
            abi.encodeCall(wrongVersion.consume, (record, _raw(), _receipt(), _signPfr(record))),
            StateSyncGKRSettlementV1.ReceiptRootMismatch.selector
        );
    }

    function testSettlementRoleDestinationBoundsAndOverflow() public {
        RootHarness root = _root();
        address[] memory overlap = new address[](1);
        overlap[0] = ROOT_2;
        try new SettlementHarness(root, 7, overlap, 1, IMAGE, VERSION) {
            revert AssertionFailed();
        } catch (bytes memory reason) {
            assertTrue(_selector(reason) == StateSyncGKRSettlementV1.SignerRolesOverlap.selector);
        }

        (, SettlementHarness consumer) = _registeredSystem();
        ReceiptRootEncodingV1.PrimaryFinalityRecord memory record = _runtimeRecord(consumer);
        bytes[] memory wrongRole = new bytes[](1);
        wrongRole[0] = signature(2, encoding.pfr(record));
        _assertSettlementFailure(
            consumer,
            abi.encodeCall(consumer.consume, (record, _raw(), _receipt(), wrongRole)),
            StateSyncGKRSettlementV1.UnauthorizedAttester.selector
        );
        record.signerSetEpoch = 6;
        _assertSettlementFailure(
            consumer,
            abi.encodeCall(consumer.consume, (record, _raw(), _receipt(), _signPfr(record))),
            StateSyncGKRSettlementV1.InvalidPrimaryFinalityRecord.selector
        );
        record = _runtimeRecord(consumer);
        record.destinationChainId ^= 1;
        _assertSettlementFailure(
            consumer,
            abi.encodeCall(consumer.consume, (record, _raw(), _receipt(), _signPfr(record))),
            StateSyncGKRSettlementV1.InvalidPrimaryFinalityRecord.selector
        );
        record = _runtimeRecord(consumer);
        record.destinationConsumer = bytes32(uint256(record.destinationConsumer) ^ 1);
        _assertSettlementFailure(
            consumer,
            abi.encodeCall(consumer.consume, (record, _raw(), _receipt(), _signPfr(record))),
            StateSyncGKRSettlementV1.InvalidPrimaryFinalityRecord.selector
        );

        record = _runtimeRecord(consumer);
        consumer.setCounters(type(uint64).max, 0);
        _assertSettlementFailure(
            consumer,
            abi.encodeCall(consumer.consume, (record, _raw(), _receipt(), _signPfr(record))),
            StateSyncGKRSettlementV1.ArithmeticOverflow.selector
        );
        (, consumer) = _registeredSystem();
        record = _runtimeRecord(consumer);
        consumer.setCounters(0, type(uint64).max);
        _assertSettlementFailure(
            consumer,
            abi.encodeCall(consumer.consume, (record, _raw(), _receipt(), _signPfr(record))),
            StateSyncGKRSettlementV1.ArithmeticOverflow.selector
        );

        bytes[] memory tooMany = new bytes[](2);
        (, consumer) = _registeredSystem();
        record = _runtimeRecord(consumer);
        _assertSettlementFailure(
            consumer,
            abi.encodeCall(consumer.consume, (record, _raw(), _receipt(), tooMany)),
            StateSyncGKRSettlementV1.TooManySignatures.selector
        );
    }

    function _root() internal returns (RootHarness) {
        address[] memory signers = new address[](3);
        signers[0] = ROOT_2;
        signers[1] = ROOT_3;
        signers[2] = ROOT_1;
        return new RootHarness(1, signers, 2, NETWORK, GENESIS, RUNTIME, CONTEXT, 2);
    }

    function _registeredSystem() internal returns (RootHarness root, SettlementHarness consumer) {
        vm.chainId(84_532);
        root = _root();
        root.register(_authorization(1), _vectorRootSignatures());
        address[] memory pfr = new address[](1);
        pfr[0] = PFR_4;
        consumer = new SettlementHarness(root, 7, pfr, 1, IMAGE, VERSION);
    }

    function _receipt() internal pure returns (StateSyncGKRSettlementV1.ReceiptAttachment memory) {
        return StateSyncGKRSettlementV1.ReceiptAttachment({
            sourceNetworkId: NETWORK,
            domainId: 2,
            aggregationId: 53_668,
            sourceBlockNumber: 6_726_351,
            sourceBlockHash: BLOCK_HASH,
            sourceRuntimeId: RUNTIME,
            verificationContextHash: CONTEXT,
            statement: STATEMENT,
            leafCount: 1,
            leafIndex: 0,
            merklePath: new bytes32[](0)
        });
    }

    function _runtimeRecord(SettlementHarness consumer)
        internal
        view
        returns (ReceiptRootEncodingV1.PrimaryFinalityRecord memory record)
    {
        record = _vectorRecord();
        record.destinationChainId = consumer.destinationChainId();
        record.destinationConsumer = consumer.destinationConsumer();
    }

    function _signPfr(ReceiptRootEncodingV1.PrimaryFinalityRecord memory record)
        internal
        returns (bytes[] memory signatures)
    {
        signatures = new bytes[](1);
        signatures[0] = signature(4, encoding.pfr(record));
    }

    function _authorization(uint64 nonce)
        internal
        pure
        returns (IReceiptRootAuthorityV1.Authorization memory)
    {
        return IReceiptRootAuthorityV1.Authorization({
            signerSetEpoch: 1,
            sourceNetworkId: NETWORK,
            sourceGenesisHash: GENESIS,
            sourceRuntimeId: RUNTIME,
            verificationContextHash: CONTEXT,
            domainId: 2,
            sourceBlockNumber: 6_726_351,
            sourceBlockHash: BLOCK_HASH,
            aggregationId: 53_668,
            root: ROOT,
            leafCount: 1,
            authorizationNonce: nonce
        });
    }

    function _vectorRootSignatures() internal pure returns (bytes[] memory signatures) {
        signatures = new bytes[](2);
        signatures[0] =
            hex"24e99c2e886dc9580021cbcfca9c50834283f9a0d87e5b4655540e48c1db674c0dc25336adb16930c8dc3eea3e9dfe7bd3f64f7709567d3522867977b83141d71b";
        signatures[1] =
            hex"927c2ddb8fe7c6c5b683b28ec064bb32bfcacbc85e7d95c62e10dc03e6fec905547b94007288034de16fd961e9c3d631b0f755805ca60433fd386a55b490992f1c";
    }

    function _signRoot(IReceiptRootAuthorityV1.Authorization memory a)
        internal
        returns (bytes[] memory signatures)
    {
        bytes32 digest = encoding.digest(a);
        signatures = new bytes[](2);
        signatures[0] = signature(2, digest);
        signatures[1] = signature(3, digest);
    }

    function _raw() internal pure returns (bytes memory) {
        return hex"01000100010001001f0000001800000000000000000000000000000000000000abde249a257cd4e6c3ed34f2749a7d8be66fd418f5a5d8595bffc956b45f0e0088957f2aa94f0f483d11f6bbc00b37db9fedd7911eee56e15c1661e14845320088957f2aa94f0f483d11f6bbc00b37db9fedd7911eee56e15c1661e14845320005000000000000000000000000000000000000000000000000000000000000004cc6356134cfb0dcefee384334580a10c3f82929f64a9f8833dd47ebc2cdbf00";
    }

    function _vectorConsumer() internal pure returns (bytes32) {
        return 0x0000000000000000000000000807c544d38ae7729f8798388d89be6502a1e8a8;
    }

    function _vectorRecord()
        internal
        pure
        returns (ReceiptRootEncodingV1.PrimaryFinalityRecord memory)
    {
        return ReceiptRootEncodingV1.PrimaryFinalityRecord({
            primaryTransitionId: RAW_SHA,
            routeId: ROUTE,
            rawStatementSha256: RAW_SHA,
            preclaimHash: PRECLAIM,
            source: NETWORK,
            destinationChainId: 84_532,
            destinationConsumer: _vectorConsumer(),
            actionKind: 0,
            checkpoint: 6_726_351,
            sessionId: BLOCK_HASH,
            bvcId: CONTEXT,
            acceptedRoot: ACCEPTED,
            state: 1,
            signerSetEpoch: 7,
            issuanceHeight: 6_726_351,
            hasSupersedes: false,
            supersedesRecordId: bytes32(0)
        });
    }

    function _constructorNegatives() internal {
        address[] memory signers = new address[](3);
        signers[0] = address(0);
        signers[1] = ROOT_3;
        signers[2] = ROOT_1;
        try new RootHarness(1, signers, 2, NETWORK, GENESIS, RUNTIME, CONTEXT, 2) {
            revert AssertionFailed();
        } catch (bytes memory reason) {
            assertTrue(_selector(reason) == ReceiptRootAuthorityV1.ZeroConfiguredSigner.selector);
        }
        signers[0] = ROOT_2;
        signers[1] = ROOT_2;
        try new RootHarness(1, signers, 2, NETWORK, GENESIS, RUNTIME, CONTEXT, 2) {
            revert AssertionFailed();
        } catch (bytes memory reason) {
            assertTrue(
                _selector(reason) == ReceiptRootAuthorityV1.DuplicateConfiguredSigner.selector
            );
        }
        signers[0] = ROOT_3;
        signers[1] = ROOT_2;
        try new RootHarness(1, signers, 2, NETWORK, GENESIS, RUNTIME, CONTEXT, 2) {
            revert AssertionFailed();
        } catch (bytes memory reason) {
            assertTrue(
                _selector(reason) == ReceiptRootAuthorityV1.ConfiguredSignersNotSorted.selector
            );
        }
        signers[0] = ROOT_2;
        signers[1] = ROOT_3;
        try new RootHarness(1, signers, 4, NETWORK, GENESIS, RUNTIME, CONTEXT, 2) {
            revert AssertionFailed();
        } catch (bytes memory reason) {
            assertTrue(_selector(reason) == ReceiptRootAuthorityV1.InvalidThreshold.selector);
        }
    }

    function _assertRootFailure(RootHarness root, bytes memory data, bytes4 selector) internal {
        bytes32 stateBefore = root.stateDigest();
        uint64 eventsBefore = root.eventCount();
        vm.recordLogs();
        (bool ok, bytes memory reason) = address(root).call(data);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertTrue(!ok && _selector(reason) == selector);
        assertEq(root.stateDigest(), stateBefore);
        assertEq(root.eventCount(), eventsBefore);
        assertEq(logs.length, 0);
    }

    function _assertSettlementFailure(
        SettlementHarness consumer,
        bytes memory data,
        bytes4 selector
    ) internal {
        bytes32 stateBefore = consumer.stateDigest();
        uint64 eventsBefore = consumer.eventCount();
        vm.recordLogs();
        (bool ok, bytes memory reason) = address(consumer).call(data);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertTrue(!ok && _selector(reason) == selector);
        assertEq(consumer.stateDigest(), stateBefore);
        assertEq(consumer.eventCount(), eventsBefore);
        assertEq(logs.length, 0);
    }

    function _assertPureFailure(address target, bytes memory data, bytes4 selector) internal view {
        (bool ok, bytes memory reason) = target.staticcall(data);
        assertTrue(!ok && _selector(reason) == selector);
    }

    function _decimal(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 copy = value;
        uint256 digits;
        while (copy != 0) {
            ++digits;
            copy /= 10;
        }
        bytes memory out = new bytes(digits);
        while (value != 0) {
            // Safe: ASCII digit is always in the closed interval [48, 57].
            // forge-lint: disable-next-line(unsafe-typecast)
            out[--digits] = bytes1(uint8(48 + value % 10));
            value /= 10;
        }
        return string(out);
    }

    function _selector(bytes memory reason) internal pure returns (bytes4 selector) {
        if (reason.length < 4) return bytes4(0);
        assembly ("memory-safe") { selector := mload(add(reason, 32)) }
    }
}
