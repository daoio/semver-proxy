// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Version, EncodedVersion} from "../lib/Versioning.sol";

interface ISemVerProxy {
    function latestVersion() external view returns (Version memory);
    function latestEncoded() external view returns (EncodedVersion);
    function latestRelease() external view returns (address);

    /**
     *                   * CLIENT ACTIONS *                   **
     */
    function subscribeToVersion(Version memory version) external;
    function unsubscribeFromVersioning() external;

    /**
     *                   * ADMIN ACTIONS *                   **
     */
    function releaseMajor(address release, bytes memory data) external;
    function releaseMinor(address release, bytes memory data) external;
    function releasePatch(address release, bytes memory data) external;
}
