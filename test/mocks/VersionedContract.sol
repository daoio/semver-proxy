pragma solidity 0.8.30;

contract X {
    uint256 public constant WILL_BE_X = 228;
    uint256 public x;

    function setX() external virtual {
        x = WILL_BE_X;
    }
}

contract Y is X {
    uint256 public constant NEW_WILL_BE_X = 420;

    function setX() external virtual override {
        x = NEW_WILL_BE_X;
    }
}

contract Z is Y {
    uint256 public constant ANOTHA_WILL_BE_X = 1000;

    function setX() external override {
        x = ANOTHA_WILL_BE_X;
    }
}
