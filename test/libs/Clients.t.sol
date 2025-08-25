pragma solidity 0.8.30;

import {Client, Clients} from "../../src/lib/Clients.sol";
import {Test} from "forge-std/Test.sol";

contract ClientsTest is Test {
    using {
        Clients.subscribe,
        Clients.unsubscribe,
        Clients.isSubscribed
    } for mapping(Client => address);

    Client client0;
    Client client1;

    address subscription0;
    address subscription1;

    mapping(Client => address) private subscribedClients;

    function setUp() public {
        client0 = Client.wrap(address(this));
        client1 = Client.wrap(msg.sender);

        subscription0 = address(228);
        subscription1 = address(420);

        subscribedClients[client0] = subscription0;
        subscribedClients[client1] = subscription1;
    }

    function test_isSubscribed() public view {
        (bool ok, address release) = subscribedClients.isSubscribed(client0);
        assertEq(ok, true);
        assertEq(release, subscription0);

        (ok, release) = subscribedClients.isSubscribed(client1);
        assertEq(ok, true);
        assertEq(release, subscription1);

        (ok, release) = subscribedClients.isSubscribed(
            Client.wrap(address(404))
        );
        assertEq(ok, false);
        assertEq(release, address(0));
    }

    function testFuzz_subscribe(address caller) public {
        Client newClient = Client.wrap(caller);

        subscribedClients.subscribe(newClient, subscription0);

        (bool ok, address release) = subscribedClients.isSubscribed(newClient);
        assertEq(ok, true);
        assertEq(release, subscription0);
    }

    function testFuzz_unsubscribe(address caller) public {
        // Use only fresh clients.
        vm.assume(
            caller != Client.unwrap(client0) && caller != Client.unwrap(client1)
        );

        Client newClient = Client.wrap(caller);

        bytes4 errorSelector = bytes4(keccak256("ClientIsntSubscribed()"));
        vm.expectRevert(errorSelector);
        subscribedClients.unsubscribe(newClient);

        subscribedClients.subscribe(newClient, subscription0);
        subscribedClients.unsubscribe(newClient);

        (bool ok, address release) = subscribedClients.isSubscribed(newClient);
        assertEq(ok, false);
        assertEq(release, address(0));
    }
}
