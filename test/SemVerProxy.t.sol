pragma solidity ^0.8.28;

import {ProxyAdmin} from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Versioning, Version, EncodedVersion} from "../src/lib/Versioning.sol";
import {ISemVerProxy} from "../src/interfaces/ISemVerProxy.sol";
import {X, Y, Z} from "./mocks/VersionedContract.sol";
import {SemVerProxy} from "../src/SemVerProxy.sol";
import {Test, Vm} from "forge-std/Test.sol";

contract SemVerProxyTest is Test {
    using {Versioning.encode} for Version;

    address latestRelease;
    address owner;

    ProxyAdmin proxyAdmin;
    SemVerProxy private semVerProxy;

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
    }

    function test_verifyInitialVersion() public {
        assertEq(semVerProxy.latestRelease(), latestRelease);
        _compareVersions(semVerProxy.latestVersion(), Version(0, 1, 0));
    }

    function testFuzz_subscribe(address caller) public {
        vm.assume(caller != address(proxyAdmin) && caller != address(0));

        // Caller subscribes to 0.1.0
        vm.startPrank(caller);
        semVerProxy.subscribeToVersion(semVerProxy.latestVersion());
        vm.stopPrank();

        X implementation = X(address(semVerProxy));
        assertEq(implementation.x(), 0);

        // Set {x} storage variable to the value specified in {release0}.
        vm.prank(caller);
        implementation.setX();

        assertEq(implementation.x(), release0.WILL_BE_X());

        // Admin releases new major update.
        vm.prank(address(proxyAdmin));
        ISemVerProxy(address(semVerProxy)).releaseMajor(address(release1), "");

        // Version was incremented to 1.0.0
        _compareVersions(semVerProxy.latestVersion(), Version(1, 0, 0));

        // Subscribed client calls {setX} to set {x} storage variable.
        vm.prank(caller);
        implementation.setX();

        // Since {caller} is still subscribed to 0.1.0 version
        // call to {setX} will stil yield {WILL_BE_X}
        assertEq(implementation.x(), release0.WILL_BE_X());

        // Connect caller to use latest releases.
        vm.startPrank(caller);
        semVerProxy.unsubscribeFromVersioning();
        vm.stopPrank();

        // Set {x} storage variable to the value
        // specified in {release1}.
        vm.prank(caller);
        implementation.setX();

        // Now {x} was updated by the {caller} since
        // he's connected to 1.0.0
        assertEq(implementation.x(), release1.NEW_WILL_BE_X());

        // Admin releases minor update.
        vm.prank(address(proxyAdmin));
        ISemVerProxy(address(semVerProxy)).releaseMinor(address(release2), "");

        // Version was incremented to 1.1.0
        _compareVersions(semVerProxy.latestVersion(), Version(1, 1, 0));

        // Since {caller} is now connected to the latest release
        // {setX} call will set {x} to the value specified in {release2}.
        vm.prank(caller);
        implementation.setX();

        assertEq(implementation.x(), release2.ANOTHA_WILL_BE_X());

        // Subscribing to the previous 1.0.0 version
        // will now dispatch {caller} calls to it.
        vm.startPrank(caller);
        semVerProxy.subscribeToVersion(Version(1, 0, 0));
        vm.stopPrank();

        // Therefore, the new value of {x} after {setX}
        // call will be equal to the value specified
        // in {release1}.
        vm.prank(caller);
        implementation.setX();
        assertEq(implementation.x(), release1.NEW_WILL_BE_X());

        Version memory invalidVersion = Version(10, 5, 5);
        bytes4 errorSelector = bytes4(
            keccak256("NoReleaseForProvidedVersion(bytes32)")
        );

        vm.startPrank(caller);
        // {caller} can't subscribe to a non-existing version.
        vm.expectRevert(
            abi.encodeWithSelector(errorSelector, (invalidVersion.encode()))
        );
        semVerProxy.subscribeToVersion(invalidVersion);

        vm.stopPrank();
    }

    function testFuzz_adminFunctions(bytes4 selector, address caller) public {
        vm.assume(caller != address(proxyAdmin));

        /*
         * Admin's POV calls.
         */
        vm.startPrank(address(proxyAdmin));
        address newRelease = address(new X());

        // Verify that every call to a non-admin function
        // is prohibited for admin!
        (bool ok, bytes memory data) = address(semVerProxy).call(
            abi.encodeWithSelector(selector, newRelease, "")
        );

        if (selector == ISemVerProxy.releaseMajor.selector) {
            assertEq(ok, true);
        } else if (selector == ISemVerProxy.releaseMinor.selector) {
            assertEq(ok, true);
        } else if (selector == ISemVerProxy.releasePatch.selector) {
            assertEq(ok, true);
        } else {
            // All calls by {proxyAdmin} to non-admin functions
            // should always revert.
            assertEq(ok, false);

            // Moreover all calls should revert with
            // {ProxyDeniedAdminAccess} error.
            assertEq(
                bytes4(data),
                bytes4(keccak256("ProxyDeniedAdminAccess()"))
            );
        }
        vm.stopPrank();
    }

    function testFuzz_accessControl(address caller) public {
        vm.assume(caller != address(proxyAdmin));

        vm.startPrank(caller);

        vm.expectRevert();
        ISemVerProxy(address(semVerProxy)).releaseMajor(address(1), "");

        vm.expectRevert();
        ISemVerProxy(address(semVerProxy)).releaseMinor(address(1), "");

        vm.expectRevert();
        ISemVerProxy(address(semVerProxy)).releasePatch(address(1), "");

        // Executing non-admin functions still works, though.
        X implementation = X(address(semVerProxy));
        implementation.setX();
        assertEq(implementation.x(), release0.WILL_BE_X());

        vm.stopPrank();
    }

    function testFuzz_multiVersioning(address[3] memory callers) public {
        address nonSubscribedCaller = address(3);

	// Each caller in {callers} array has unique address.
        vm.assume(
            callers[0] != callers[1] &&
                callers[0] != callers[2] &&
                callers[1] != callers[2]
        );

        Version[] memory versions = new Version[](3);
        versions[0] = semVerProxy.latestVersion(); // 0.1.0
        versions[1] = Version(0, 2, 0); // 0.2.0
        versions[2] = Version(0, 2, 1); // 0.2.1

        // Initialize versions defined above^.
        vm.startPrank(address(proxyAdmin));
        // Release 0.2.0
        ISemVerProxy(address(semVerProxy)).releaseMinor(address(release1), "");
        _compareVersions(semVerProxy.latestVersion(), Version(0, 2, 0));

        // Release 0.2.1
        ISemVerProxy(address(semVerProxy)).releasePatch(address(release2), "");
        _compareVersions(semVerProxy.latestVersion(), Version(0, 2, 1));
        vm.stopPrank();

        for (uint256 i = 0; i < callers.length; ++i) {
            address caller = callers[i];
            vm.assume(
                caller != address(proxyAdmin) && caller != nonSubscribedCaller
            );

            // {caller} => {release0}
            vm.prank(caller);
            semVerProxy.subscribeToVersion(versions[i]);
        }

        X implementation = X(address(semVerProxy));

        // {caller[2]} calls {release2}
        vm.prank(callers[2]);
        implementation.setX();
        assertEq(implementation.x(), release2.ANOTHA_WILL_BE_X());

        // {caller[1]} calls {release1}
        // and overwrites {x}
        vm.prank(callers[1]);
        implementation.setX();
        assertEq(implementation.x(), release1.NEW_WILL_BE_X());

        // {caller[0]} calls {release0}
        // and overwrites {x}
        vm.prank(callers[0]);
        implementation.setX();
        assertEq(implementation.x(), release0.WILL_BE_X());

        // {nonSubscribedCaller} calls latest release
        // {release2} and overwrites {x} again.
        vm.prank(nonSubscribedCaller);
        implementation.setX();
        assertEq(implementation.x(), release2.ANOTHA_WILL_BE_X());
    }

    function _compareVersions(Version memory v0, Version memory v1) internal {
        assertEq(
            EncodedVersion.unwrap(v0.encode()),
            EncodedVersion.unwrap(v1.encode())
        );
    }
}
