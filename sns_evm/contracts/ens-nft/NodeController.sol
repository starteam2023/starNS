pragma solidity >=0.8.4;
import "./IRegister.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * The ENS registry contract.
 */
contract NodeController is Ownable {
    struct Record {
        address owner;
        address resolver;
        uint64 ttl;
    }
    
    // bytes32 private constant ETH_NODE =
    //     0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae;
    // bytes32 private constant ETH_NODE = 0x4f5b812789fc606be1b3b16908db13fc7a9adf7ca72641f84d75b47069d3d7f0;
    mapping (bytes32 => Record) records;
    mapping (address => mapping(address => bool)) operators;
    mapping (address => bool) controllers;

    mapping (bytes32 => IRegister) registerars;


    event NewOwner(bytes32 indexed node, bytes32 indexed label, address owner);
    event Transfer(bytes32 indexed node, address owner);
    event NewResolver(bytes32 indexed node, address resolver);
    event NewTTL(bytes32 indexed node, uint64 ttl);

    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );


    modifier authorised(bytes32 node) {
        address owner = records[node].owner;
        require(owner == msg.sender || operators[owner][msg.sender]);
        _;
    }
    
    // modifier unexpiredAndauthorised(uint256 tokenID, bytes32 tldnode) {
    //     require(!registerars[ETH_NODE].available(tokenID));
    //     bytes32 node = makeNode(tldnode, tokenID);
    //     address owner = records[node].owner;
    //     require(owner == msg.sender || operators[owner][msg.sender]);
    //     _;
    // }

    constructor() public {

        records[0x0].owner = msg.sender;
    }


    // function addController(address controller) external  onlyOwner {
    //     controllers[controller] = true;
    // }


    // function removeController(address controller) external onlyOwner {
    //     controllers[controller] = false;
    // }

    // function addRegisterar(bytes32 tldnode, IRegister registerar) external onlyOwner {
    //     registerars[tldnode] = registerar;
    // }

    // function removeRegisterar(bytes32 tldnode) external onlyOwner {
    //     delete registerars[tldnode];
    // }

    // function setDefaultResolver(Resolver _resolver) external onlyOwner {
    //     defaultResolver = _resolver;
    // }

    // function checkDefaultResolver() external view onlyOwner returns(Resolver){
    //     return defaultResolver;
    // }
    // function registerTLD(
    //     string calldata name,
    //     address owner
    // ) external onlyOwner returns(uint256 expires){
    //     bytes node = keccak256(bytes(name));


    //     setRecord(node, owner, deresolver);
    // }


    function set2LDrecord(
        bytes32 node, 
        bytes32 label, 
        address owner, 
        address resolver
    ) external  authorised(node)  {
        bytes32 subnode = makeNode(node, label);
        _setOwner(subnode, owner);
        _setResolver(subnode, resolver);
    }


    //  function renewTLD(
    //     string calldata name,
    //     address owner
    // ) external onlyOwner returns(uint256 expires){
    //     bytes node = keccak256(bytes(name));

    //     setRecord(node, owner, deresolver);
    // }
    function set2LDowner(bytes32 node, bytes32 label, address owner) public authorised(node){
        bytes32 subnode = makeNode(node, label);
        _setOwner(subnode, owner);
        emit NewOwner(node, label, owner);

    }


    function setRecord(bytes32 node, address owner, address resolver) external {
        setOwner(node, owner);
        _setResolver(node, resolver);
    }

    function setOwner(bytes32 node, address owner) public virtual  authorised(node) {
        _setOwner(node, owner);
    }


    function setResolver(bytes32 node, address resolver) public  authorised(node){
        if(resolver != records[node].resolver) {
        records[node].resolver = resolver;
        }
        emit NewResolver(node, resolver);

    }

    function setTTL(bytes32 node, uint64 ttl) public virtual authorised(node) {
        records[node].ttl = ttl;
    }


    function setApprovalForAll(address operator, bool approved) external {
        operators[msg.sender][operator] = approved;
    }


    function ownerOfnode(bytes32 node) public view returns (address) {
        address addr = records[node].owner;
        if (addr == address(this)) {
            return address(0x0);
        }

        return addr;
    }


    function resolver(bytes32 node) public   view returns (address) {
        return records[node].resolver;
    }


    function ttl(bytes32 node) public  view returns (uint64) {
        return records[node].ttl;
    }


    function recordExists(bytes32 node) public view returns (bool) {
        return records[node].owner != address(0x0);
    }


    function isApprovedForAll(address owner, address operator) external view returns (bool) {
        return operators[owner][operator];
    }


    function _setOwner(bytes32 node, address owner) internal  {
        records[node].owner = owner;

        emit Transfer(node, owner);
    }

    function _setResolver(bytes32 node, address resolver) internal {
        if(resolver != records[node].resolver) {
        records[node].resolver = resolver;
        }
    }



    function makeNode(bytes32 node, bytes32 label)
        public
        pure
        returns (bytes32)
    {

        return keccak256(abi.encodePacked(node,label));
    }





    function checkNode()
        public
        pure
        returns (bytes32)
    {
        
        return keccak256("eth");
    }

    function getNode()
        public
        pure 
        returns (bytes32) 
    {
        return bytes32(0x0);
    }

    function _setApprovalForAll(address owner, address operator, bool approved) external {
        operators[owner][operator] = approved;
    }
}



