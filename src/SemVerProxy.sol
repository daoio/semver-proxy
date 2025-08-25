// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {TransparentUpgradeableProxy, ERC1967Utils} from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Versioning, Version, EncodedVersion} from "./lib/Versioning.sol";
import {ISemVerProxy} from "./interfaces/ISemVerProxy.sol";
import {Clients, Client} from "./lib/Clients.sol";

/**
 * @title SemVerProxy
 *
 * @dev Though, {SemVerProxy} inherits {TransparentUpgradeableProxy}
 *      it's not "transparent" since it declares 5 externally accessable functions:
 *      [latestVersion, latestEncoded, latestRelease, subscribeToVersion, unsubscribeFromVersioning]
 *      that might possibly clash if implementations declare functions with
 *      the same signatures.
 *
 * @dev Upgrade functionality in this contract can be achieved via {release*} functions
 *      callable only by the admin.
 *
 * @dev Users of this proxy can subscribe to using specific version of implementation
 *      contract, via {subscribeToVersion} function. By default, if no subscription is
 *      specified {_fallback} will delegate to the latest release.
 *
 * @dev Latest version is stored in a storage slot, specified in ERC-1967.
 *
 * @dev Storage variables are stored starting from 1000th slot.
 */
contract SemVerProxy is TransparentUpgradeableProxy layout at 1_000 {
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
    
    using {
        Clients.subscribe,
        Clients.unsubscribe,
        Clients.isSubscribed
    } for mapping(Client => address);

    /***                   * EVENTS *                   ***/
    event Release(EncodedVersion indexed latestEncoded, address release);
    event ClientSubscribed(Client indexed client, Version indexed version);
    event ClientUnsubscribed(Client indexed client);

    /***                   * STORAGE *                   ***/

    /// @notice Stores SemVer-like latest version of the implemenation.
    /// @dev {_latestVersion} is stored in storage slot [1_000].
    Version internal _latestVersion;

    /// @notice Stores addresses of every existing version.
    mapping(EncodedVersion => address) internal _releases;
    /// @notice Points to releases to which clients are subscribed.
    mapping(Client => address) internal _subscribedClients;

    /**
     * @dev First deployment will initialize implementation at 0.1.0 version.
     * @dev Setting admin and implementation slots will be handled by
     *      a child {TransparentUpgradeableProxy} contract.
     * @param release - Address of the first implementation contract.
     * @param initialOwner - Owner of {ProxyAdmin} contract that will be
     *        created in {TransparentUpgradeableProxy} constructor.
     */
    constructor(
        address release,
        address initialOwner,
        bytes memory _data
    ) payable TransparentUpgradeableProxy(release, initialOwner, _data) {
        // Store SemVer data for the initial release.
        _latestVersion.incMinor();
        _releases.store(latestEncoded(), release);
    }

    /**
     * @dev If caller is the admin process the call internally,
     *      otherwise transparently fallback to the proxy behavior.
     */
    function _fallback() internal virtual override {
        if (msg.sender == _proxyAdmin()) {
            /// @dev Target {release*} function type.
            function(address, bytes memory) releaseFunc;
            if (msg.sig == ISemVerProxy.releaseMajor.selector) {
                releaseFunc = releaseMajor;
            } else if (msg.sig == ISemVerProxy.releaseMinor.selector) {
                releaseFunc = releaseMinor;
            } else if (msg.sig == ISemVerProxy.releasePatch.selector) {
                releaseFunc = releasePatch;
            } else {
                /**
                 * @notice Call to {upgradeToAndCall} is prohibited as well
                 *         as upgrades are made via {release*} functions.
                 */
                revert ProxyDeniedAdminAccess();
            }

            (address release, bytes memory data) = abi.decode(
                msg.data[4:],
                (address, bytes)
            );
            releaseFunc(release, data);
        } else {
            super._fallback();
        }
    }

    /***                   * VIEW FUNCTIONS *                   ***/

    /**
     * @notice Returns current latest version.
     */
    function latestVersion() public view returns (Version memory) {
        return _latestVersion;
    }

    /**
     * @notice Returns current latest version as packedly encoded bytes32.
     */
    function latestEncoded() public view returns (EncodedVersion) {
        return _latestVersion.encode();
    }

    /**
     * @notice Returns address of latest release.
     */
    function latestRelease() public view returns (address) {
        return _releases[latestEncoded()];
    }

    /***                   * CLIENT ACTIONS *                   ***/

    /**
     * @notice Attaches implementation address for provided {version}
     *         to the msg.sender client.
     * @dev With attached version, every fallback for this particular
     *      msg.sender client will delegate to the implementation
     *      under specified {version}.
     */
    function subscribeToVersion(Version memory version) external {
        Client client = Client.wrap(msg.sender);
        _subscribedClients.subscribe(client, _releases.obtainRelease(version));

        emit ClientSubscribed(client, version);
    }

    /**
     * @notice Unsubscribes from specific version usage for
     *         msg.sender client.
     * @dev Therefore, every fallback for this particular
     *      msg.sender client will delegate to the implementation
     *      under the {_latestVersion}.
     */
    function unsubscribeFromVersioning() external {
        Client client = Client.wrap(msg.sender);
        _subscribedClients.unsubscribe(client);

        emit ClientUnsubscribed(client);
    }

    /***                   * ADMIN ACTIONS *                   ***/

    /**
     * @notice Increments latest major version.
     *         Sets [minor & patch] to 0.
     * @param release - address of updated implementation contract.
     */
    function releaseMajor(address release, bytes memory data) private {
        _latestVersion.incMajor();
        _setLatest(release, data);
    }

    /**
     * @notice Increments latest minor version.
     *         Sets [patch] to 0.
     * @param release - address of updated implementation contract.
     */
    function releaseMinor(address release, bytes memory data) private {
        _latestVersion.incMinor();
        _setLatest(release, data);
    }

    /**
     * @notice Increments latest patch version.
     * @param release - address of updated implementation contract.
     */
    function releasePatch(address release, bytes memory data) private {
        _latestVersion.incPatch();
        _setLatest(release, data);
    }

    /***                   * HELPERS *                   ***/

    /**
     * @notice Updates {_releases} map with a newly released address.
     */
    function _setLatest(address _release, bytes memory _data) private {
        EncodedVersion _encodedVersion = latestEncoded();
        _releases.store(_encodedVersion, _release);

        emit Release(_encodedVersion, _release);

        // Update ERC-1967 implementation slot with new latest release.
        ERC1967Utils.upgradeToAndCall(_release, _data);
    }

    /**
     * @dev Returns implementation address for client.
     *      If client is subscribed to a specific version
     *      return address of that version,
     *      otherwise use latest release.
     * @notice The latest release is stored in ERC-1967
     *         implementation slot.
     */
    function _implementation() internal view override returns (address) {
        Client client = Client.wrap(msg.sender);
        (bool subscribed, address release) = _subscribedClients.isSubscribed(
            client
        );

        return subscribed ? release : ERC1967Utils.getImplementation();
    }
}
