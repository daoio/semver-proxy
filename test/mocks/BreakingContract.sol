pragma solidity ^0.8.28;

import {Version} from "../../src/lib/Versioning.sol";

contract Breaking {
    uint256[100] private __gap;
    Version public latestVersion_;

    function setVersion() external {
        latestVersion_ = Version(2, 2, 8);
    }
}
