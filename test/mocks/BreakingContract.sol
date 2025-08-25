pragma solidity 0.8.30;

import {Version} from "../../src/lib/Versioning.sol";

contract Breaking layout at 1_000 {
    Version public latestVersion_;

    function setVersion() external {
        latestVersion_ = Version(2, 2, 8);
    }
}
