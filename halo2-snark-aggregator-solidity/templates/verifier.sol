// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

library LibFr {
    uint256 constant q_mod =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    function from_bytes(bytes memory buf, uint256 offset)
        internal
        pure
        returns (uint256)
    {
        uint256 v;
        uint256 o;

        o = offset + 0x20;

        assembly {
            v := mload(add(buf, o))
        }

        return v;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256 r) {
        return addmod(a, b, q_mod);
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256 r) {
        return addmod(a, q_mod - b, q_mod);
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return mulmod(a, b, q_mod);
    }

    function invert(uint256 a) internal view returns (uint256) {
        return pow(a, q_mod - 2);
    }

    function pow(uint256 a, uint256 power) internal view returns (uint256) {
        uint256[6] memory input;
        uint256[1] memory result;
        bool ret;

        input[0] = 32;
        input[1] = 32;
        input[2] = 32;
        input[3] = a;
        input[4] = power;
        input[5] = q_mod;

        assembly {
            ret := staticcall(gas(), 0x05, input, 0xc0, result, 0x20)
        }
        require(ret);

        return result[0];
    }

    function div(uint256 a, uint256 b) internal view returns (uint256) {
        require(b != 0);
        return mulmod(a, invert(b), q_mod);
    }

    function mul_add_constant(
        uint256 a,
        uint256 b,
        uint256 c
    ) internal pure returns (uint256) {
        return add(mul(a, b), c);
    }
}

library LibEcc {
    uint256 constant p_mod =
        21888242871839275222246405745257275088696311157297823662689037894645226208583;

    struct G1Point {
        uint256 x;
        uint256 y;
    }

    struct G2Point {
        uint256[2] x;
        uint256[2] y;
    }

    function to_tuple(G1Point memory f)
        internal
        pure
        returns (uint256, uint256)
    {
        return (f.x, f.y);
    }

    function from(uint256 x, uint256 y)
        internal
        pure
        returns (G1Point memory r)
    {
        r.x = x;
        r.y = y;
    }

    function from_bytes(bytes memory buf, uint256 offset)
        internal
        pure
        returns (G1Point memory r)
    {
        uint256 x;
        uint256 y;
        uint256 o;

        o = offset + 0x20;

        assembly {
            x := mload(add(buf, o))
            y := mload(add(buf, add(o, 0x20)))
        }

        r.x = x;
        r.y = y;
    }

    function is_identity(G1Point memory a) internal pure returns (bool) {
        return a.x == 0 && a.y == 0;
    }

    function add(G1Point memory a, G1Point memory b)
        internal
        view
        returns (G1Point memory)
    {
        if (is_identity(a)) {
            return b;
        } else if (is_identity(b)) {
            return a;
        } else {
            bool ret = false;
            G1Point memory r;
            uint256[4] memory input_points;

            input_points[0] = a.x;
            input_points[1] = a.y;
            input_points[2] = b.x;
            input_points[3] = b.y;

            assembly {
                ret := staticcall(gas(), 6, input_points, 0x80, r, 0x40)
            }
            require(ret);

            return r;
        }
    }

    function sub(G1Point memory a, G1Point memory b)
        internal
        view
        returns (G1Point memory)
    {
        G1Point memory _b;
        _b.x = b.x;
        _b.y = p_mod - b.y;
        return add(a, _b);
    }

    function mul(G1Point memory p, uint256 s)
        internal
        view
        returns (G1Point memory)
    {
        if (is_identity(p)) {
            return p;
        } else {
            uint256[3] memory input;
            bool ret = false;
            G1Point memory r;

            input[0] = p.x;
            input[1] = p.y;
            input[2] = s;

            assembly {
                ret := staticcall(gas(), 7, input, 0x60, r, 0x40)
            }
            require(ret);

            return r;
        }
    }
}

library LibPairing {
    function pairing(LibEcc.G1Point[] memory p1, LibEcc.G2Point[] memory p2)
        internal
        view
        returns (bool)
    {
        uint256 length = p1.length * 6;
        uint256[] memory input = new uint256[](length);
        uint256[1] memory result;
        bool ret;

        require(p1.length == p2.length);

        for (uint256 i = 0; i < length; i++) {
            input[0 + i * 6] = p1[i].x;
            input[1 + i * 6] = p1[i].y;
            input[2 + i * 6] = p2[i].x[0];
            input[3 + i * 6] = p2[i].x[1];
            input[4 + i * 6] = p2[i].y[0];
            input[5 + i * 6] = p2[i].y[1];
        }

        assembly {
            ret := staticcall(
                gas(),
                8,
                add(input, 0x20),
                mul(length, 0x20),
                result,
                0x20
            )
        }
        require(ret);
        return result[0] != 0;
    }
}

contract Verifier {
    uint256[{{memory_size}}] m;
    uint8[] private absorbing;
    bytes32 tmp;

    function toBytes(uint256 x) private {
        tmp = bytes32(x);
    }

    function update_hash_scalar(uint256 v) internal {
        absorbing.push(2);
        toBytes(v);
        // to little-endian
        for (uint256 i = 0; i < 32; i++) {
            absorbing.push(uint8(tmp[31 - i]));
        }
    }

    function update_hash_point(LibEcc.G1Point memory v) internal {
        absorbing.push(1);
        toBytes(v.x);
        for (uint256 i = 0; i < 32; i++) {
            absorbing.push(uint8(tmp[31 - i]));
        }

        toBytes(v.y);
        for (uint256 i = 0; i < 32; i++) {
            absorbing.push(uint8(tmp[31 - i]));
        }
    }

    function to_bytes() private view returns (bytes memory v) {
        v = new bytes(absorbing.length);
        for (uint256 i = 0; i < absorbing.length; i++) {
            v[i] = bytes1(absorbing[i]);
        }
    }

    function reverse(uint256 input) internal pure returns (uint256 v) {
        v = input;

        // swap bytes
        v = ((v & 0xFF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00) >> 8) |
            ((v & 0x00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF) << 8);

        // swap 2-byte long pairs
        v = ((v & 0xFFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000) >> 16) |
            ((v & 0x0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF) << 16);

        // swap 4-byte long pairs
        v = ((v & 0xFFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000) >> 32) |
            ((v & 0x00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF) << 32);

        // swap 8-byte long pairs
        v = ((v & 0xFFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF0000000000000000) >> 64) |
            ((v & 0x0000000000000000FFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF) << 64);

        // swap 16-byte long pairs
        v = (v >> 128) | (v << 128);
    }

    function to_scalar(bytes32 r) private pure returns (uint256 v) {
        uint256 tmp = uint256(r);
        tmp = reverse(tmp);
        v = tmp % 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001;
    }

    function squeeze_challenge() internal returns (uint256 v) {
        bytes32 ret;

        absorbing.push(uint8(0));
        ret = sha256(to_bytes());
        v = to_scalar(ret);
    }

    function get_g2_s() internal pure returns (LibEcc.G2Point memory s) {
        s.x[0] = uint256({{s_g2_x0}});
        s.x[1] = uint256({{s_g2_x1}});
        s.y[0] = uint256({{s_g2_y0}});
        s.y[1] = uint256({{s_g2_y1}});
    }

    function get_g2_n() internal pure returns (LibEcc.G2Point memory n) {
        n.x[0] = uint256({{n_g2_x0}});
        n.x[1] = uint256({{n_g2_x1}});
        n.y[0] = uint256({{n_g2_y0}});
        n.y[1] = uint256({{n_g2_y1}});
    }

    function get_wx_wg(bytes memory proof, bytes memory instances)
        internal
        returns (LibEcc.G1Point[2] memory)
    {
        {% for statement in statements %}
        {{statement}}
        {%- endfor %}
        return [{{ wx }}, {{ wg }}];
    }

    function verify(bytes memory proof, bytes memory instances) public {
        // wx, wg
        LibEcc.G1Point[2] memory wx_wg = get_wx_wg(proof, instances);
        LibEcc.G1Point[] memory g1_points = new LibEcc.G1Point[](2);
        g1_points[0] = wx_wg[0];
        g1_points[1] = wx_wg[1];
        LibEcc.G2Point[] memory g2_points = new LibEcc.G2Point[](2);
        g2_points[0] = get_g2_s();
        g2_points[1] = get_g2_s();

        bool checked = LibPairing.pairing(g1_points, g2_points);
        require(checked);
    }
}
