// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @dev Uses 64+64+128 bits unsigned integers
 *      to allow storing {Version} struct in
 *      1 storage slot;
 *      And to adhere to the requirement of
 *      SemVer specification to use
 *      "non-negative integers" that
 *      "MUST NOT contain leading zeroes".
 */
struct Version {
    uint64 major;
    uint64 minor;
    uint128 patch;
}

/// @dev Wrapper-type for 256-bits packedly encoded {Version} struct.
type EncodedVersion is bytes32;

/**
 * @notice Library that defines methods for versioning logic.
 *         That is, incrementing {major.minor.patch} parts of
 *         a version and provides some helper functions.
 */
library Versioning {
    error NoReleaseForProvidedVersion(EncodedVersion version);

    /***                   * MUTATIVE ACTIONS *                   ***/

    /// @notice Writes directly to {version} from storage.
    function incMajor(Version storage version) internal {
        version.major++;
        version.minor = 0;
        version.patch = 0;
    }

    /// @notice Writes directly to {version} from storage.
    function incMinor(Version storage version) internal {
        version.minor++;
        version.patch = 0;
    }

    /// @notice Writes directly to {version} from storage.
    function incPatch(Version storage version) internal {
        version.patch++;
    }

    /**
     * @notice Stores {release} value for {latestVersion} key
     *         inside {versions} storage map.
     */
    function store(
        mapping(EncodedVersion => address) storage versions,
        EncodedVersion latestVersion,
        address release
    ) internal {
        versions[latestVersion] = release;
    }

    /***                   * PURE | VIEW ACTIONS *                   ***/

    /**
     * @dev Reverts if provided {version} doesn't exist.
     * @notice Finds contract address for specified {version}
     *         inside {versions} storage map.
     */
    function obtainRelease(
        mapping(EncodedVersion => address) storage versions,
        Version memory version
    ) internal view returns (address) {
        EncodedVersion encodedVersion = encode(version);

        address release = versions[encodedVersion];
        if (release == address(0))
            revert NoReleaseForProvidedVersion(encodedVersion);

        return release;
    }

    /// @dev Packedly encodes {Version} struct.
    function encode(
        Version memory version
    ) internal pure returns (EncodedVersion) {
        /// @dev {abi.encodePacked} will pack 64+64+128 bits into one 32-byte string.
        return
            EncodedVersion.wrap(
                bytes32(
                    abi.encodePacked(
                        version.major,
                        version.minor,
                        version.patch
                    )
                )
            );
    }
}
