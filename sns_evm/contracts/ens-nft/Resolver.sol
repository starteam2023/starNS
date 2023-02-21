// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;
import "./Register.sol";
import "./NodeController.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";


contract Resolver is Ownable{

    uint constant private COIN_TYPE_ETH = 60;
    mapping(bytes32 => uint64) public recordVersions;
    mapping(bytes32=>mapping(uint=>bytes)) _addresses;
    mapping(uint64 => mapping(bytes32 => bytes)) versionable_hashes;
    mapping(uint64 => mapping(bytes32 => mapping(string => string))) versionable_texts;
    mapping(uint64 => mapping(bytes32 => string)) versionable_names;


    NodeController immutable public nodecontroller;
    event ContenthashChanged(bytes32 indexed node, bytes hash);
    event TextChanged(
        bytes32 indexed node,
        string indexed indexedKey,
        string key,
        string value
    );

    constructor(
        NodeController _nodecontroller
    ){
        nodecontroller = _nodecontroller;
    }


    modifier authorised(bytes32 node){
        address owner = nodecontroller.ownerOfnode(node);
        require(owner == msg.sender || nodecontroller.isApprovedForAll(owner, msg.sender));
        _;
    }

    /**
     * Sets the name associated with an ENS node, for reverse records.
     * May only be called by the owner of that node in the ENS registry.
     * @param node The node to update.
     */
    function setName(bytes32 node, string calldata newName)
        external
        virtual
        authorised(node)
    {
        versionable_names[recordVersions[node]][node] = newName;
    }

    


    function setAddr(bytes32 node, address a) external authorised(node) {
        
        _setAddr(node, COIN_TYPE_ETH, addressToBytes(a));
        
    }


    function addr(bytes32 node)  public view returns (address payable) {
        bytes memory a = _addr(node, COIN_TYPE_ETH);
        if(a.length == 0) {
            return payable(0);
        }
        return bytesToAddress(a);
    }

    function _setAddr(bytes32 node, uint coinType, bytes memory a) public authorised(node) {
        _addresses[node][coinType] = a;
                console.log("dddd");

    }

     function _addr(bytes32 node, uint coinType)  public view returns(bytes memory) {
         return _addresses[node][coinType];
     }


    function bytesToAddress(bytes memory b) internal pure returns(address payable a) {
        require(b.length == 20);
        assembly {
            a := div(mload(add(b, 32)), exp(256, 12))
        }
    }


    function addressToBytes(address a) internal pure returns(bytes memory b) {
        b = new bytes(20);
        assembly {
            mstore(add(b, 32), mul(a, exp(256, 12)))
        }
    }

    function setContenthash(bytes32 node, bytes calldata hash)
        external
        virtual
        authorised(node)
    {
        versionable_hashes[recordVersions[node]][node] = hash;
        emit ContenthashChanged(node, hash);
    }

    function contenthash(bytes32 node)
        external
        view

        returns (bytes memory)
    {
        return versionable_hashes[recordVersions[node]][node];
    }

    function setText(
        bytes32 node,
        string calldata key,
        string calldata value
    ) external virtual authorised(node) {
        versionable_texts[recordVersions[node]][node][key] = value;
        emit TextChanged(node, key, key, value);
    }

    function text(bytes32 node, string calldata key)
        external
        view
        returns (string memory)
    {
        return versionable_texts[recordVersions[node]][node][key];
    }
}