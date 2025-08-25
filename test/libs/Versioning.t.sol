pragma solidity 0.8.30;

import {Version, Versioning, EncodedVersion} from "../../src/lib/Versioning.sol";
import {Test} from "forge-std/Test.sol";

contract VersioningTest is Test {
    using {
        Versioning.store,
        Versioning.obtainRelease
    } for mapping(EncodedVersion => address);
    using {
        Versioning.incMajor,
        Versioning.incMinor,
        Versioning.incPatch,
        Versioning.encode
    } for Version;

    mapping(EncodedVersion => address) private versions;
    Version private latestVersion;
    address private release;

    function setUp() public {
        /// @dev The initial version is 0.0.0
        versions[latestVersion.encode()] = release;
    }

    function testFuzz_incPatch(uint256 iter) public {
        vm.assume(iter < 200);

        for (uint256 i = 0; i < iter; ++i) {
            latestVersion.incPatch();
        }
        assertEq(latestVersion.patch, iter);
        assertEq(latestVersion.minor, 0);
        assertEq(latestVersion.major, 0);
    }

    function testFuzz_incMinor(uint256 iter) public {
        vm.assume(iter < 200);

        for (uint256 i = 0; i < iter; ++i) {
            latestVersion.incMinor();
        }
        assertEq(latestVersion.patch, 0);
        assertEq(latestVersion.minor, iter);
        assertEq(latestVersion.major, 0);
    }

    function testFuzz_incMajor(uint256 iter) public {
        vm.assume(iter < 200);

        for (uint256 i = 0; i < iter; ++i) {
            latestVersion.incMajor();
        }
        assertEq(latestVersion.patch, 0);
        assertEq(latestVersion.minor, 0);
        assertEq(latestVersion.major, iter);
    }

    function testFuzz_store(uint64 major, uint64 minor, uint128 patch) public {
        Version memory version = Version(major, minor, patch);
        address randomRelease = address(404);

        versions.store(version.encode(), randomRelease);
        address _release = versions.obtainRelease(version);

        assertEq(_release, randomRelease);

        // Reassign version to another release address.
        address anotherRelease = address(1001001);
        versions.store(version.encode(), anotherRelease);
        _release = versions.obtainRelease(version);

        assertEq(_release, anotherRelease);
    }

    function testFuzz_obtainRelease(
        uint64 major,
        uint64 minor,
        uint128 patch
    ) public {
        // Generate version that doesn't equal to the currently stored one.
        major = uint64(bound(major, latestVersion.major + 1, type(uint64).max));
        minor = uint64(bound(minor, latestVersion.minor + 1, type(uint64).max));
        patch = uint128(
            bound(patch, latestVersion.patch + 1, type(uint128).max)
        );

        Version memory v = Version(major, minor, patch);

        bytes4 errorSelector = bytes4(
            keccak256("NoReleaseForProvidedVersion(bytes32)")
        );
        vm.expectRevert(abi.encodeWithSelector(errorSelector, (v.encode())));
        versions.obtainRelease(v);

        address _release = address(404);
        versions.store(v.encode(), _release);

        assertEq(_release, versions.obtainRelease(v));
    }

    function testFuzz_encode(
        uint64 major,
        uint64 minor,
        uint128 patch
    ) public pure {
        Version memory v = Version(major, minor, patch);
        EncodedVersion ev = v.encode();

        assertEq(
            EncodedVersion.unwrap(ev),
            bytes32(abi.encodePacked(major, minor, patch))
        );
    }
}
