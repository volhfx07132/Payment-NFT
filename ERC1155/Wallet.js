0x6Ccb41eedA5a073076F3E7dC1614C185b5fA41eD
0x4f0B12bBF40Fc182559822A5b1dB6D34dbC3E016
0x39Ba3ca2AE86A881a1De9cC4B81d0fD59CA189BD
0xe4c1eC323AA9AB600bA062614D254AC678afa484

    mapping(uint256 => mapping(address => uint256)) private _balances;

mapping(address => mapping(address => bool)) private _operatorApprovals;

isApprovedForAll(from, _msgSender()),

function isApprovedForAll(address account, address operator) public view virtual override returns (bool) {
    return _operatorApprovals[account][operator];
}
[0, 1, 2, 3, 4, 1]

[1232, 2342, 4234234, 2343, 1000, 3]

["0x6Ccb41eedA5a073076F3E7dC1614C185b5fA41eD", "0x6Ccb41eedA5a073076F3E7dC1614C185b5fA41eD", "0x6Ccb41eedA5a073076F3E7dC1614C185b5fA41eD", "0x6Ccb41eedA5a073076F3E7dC1614C185b5fA41eD"]
["0x6Ccb41eedA5a073076F3E7dC1614C185b5fA41eD", "0x6Ccb41eedA5a073076F3E7dC1614C185b5fA41eD", "0x6Ccb41eedA5a073076F3E7dC1614C185b5fA41eD", "0x6Ccb41eedA5a073076F3E7dC1614C185b5fA41eD"]

1232,2343,4234234,2343,

