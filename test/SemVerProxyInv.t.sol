pragma solidity 0.8.30;

import {ProxyAdmin} from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Versioning, Version, EncodedVersion} from "../src/lib/Versioning.sol";
import {ISemVerProxy} from "../src/interfaces/ISemVerProxy.sol";
import {X, Y, Z} from "./mocks/VersionedContract.sol";
import {SemVerProxy} from "../src/SemVerProxy.sol";
import {Test, Vm} from "forge-std/Test.sol";

contract SemVerProxyInv is Test {
    using {Versioning.encode} for Version;

    address latestRelease;
    address owner;

    ProxyAdmin proxyAdmin;
    SemVerProxy private semVerProxy;

    Version initialVersion;

    X release0;
    Y release1;
    Z release2;

    function setUp() public {
        release0 = new X();
        release1 = new Y();
        release2 = new Z();

        latestRelease = address(release0);
        owner = address(15);

        vm.recordLogs();
        semVerProxy = new SemVerProxy(latestRelease, owner, "");

        Vm.Log[] memory entries = vm.getRecordedLogs();

        // Catch this event: OwnershipTransferred(address, address);
        (, address _proxyAdmin) = abi.decode(
            entries[2].data,
            (address, address)
        );
        proxyAdmin = ProxyAdmin(_proxyAdmin);

        initialVersion = semVerProxy.latestVersion();

        vm.prank(_proxyAdmin);
        ISemVerProxy(address(semVerProxy)).releaseMajor(address(release1), "");

        // Target only {SemVerProxy} for invariant testing.
        targetContract(address(semVerProxy));
    }

    // A client subscribed to a specific version, will
    // call exactly it, until he unsubscribes.
    function invariant_alwaysDispatchesSubscribers() public {
        semVerProxy.subscribeToVersion(initialVersion);

        X(address(semVerProxy)).setX();
        assertEq(X(address(semVerProxy)).x(), release0.WILL_BE_X());

	// Non-subscriber will always be routed to the latest release.
	vm.prank(owner);
	X(address(semVerProxy)).setX(); // call to 1.0.0
        assertEq(X(address(semVerProxy)).x(), release1.NEW_WILL_BE_X());
    }
}
