//  SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;
import "hardhat/console.sol";
import "./NodeController.sol";
import "./Resolver.sol";
import "./IRegister.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

//1.ans账户==true 可以转账 开关
//2.map 0000 1111 only eth 
//3.endpoint 


contract Register is IRegister, ERC721, Ownable {
    
    uint256 public constant GRACE_PERIOD = 28 days; //缓冲期
    NodeController public nodecontroller; 
    address public defaultResolver;
    bytes32 private constant ETH_NODE = 0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae;
    
    
    mapping(uint256 => uint) expires;
    mapping(address => bool) public controllers;
    mapping(address => mapping(uint256 => bool)) private depositlist;
    //to do nft名字没设置
    constructor(NodeController _nodecontroller) ERC721("star","star") {
        nodecontroller = _nodecontroller;
    }


    modifier onlyController {
        require(controllers[msg.sender]);
        _;
    }

    modifier live {
        require(nodecontroller.ownerOfnode(ETH_NODE) == address(this));
        _;
    }


    // Authorises a controller, who can register and renew domains.
    function addController(address controller) external override onlyOwner {
        controllers[controller] = true;
    }

    // Revoke controller permission for an address.
    function removeController(address controller) external override onlyOwner {
        controllers[controller] = false;
    }



    function setdefaultResolver(address _defaultResolver) external onlyOwner{
                defaultResolver = _defaultResolver;
    }


    function register(uint256 id, address owner, uint duration) external override returns(uint) {
      return _register(id, owner, duration);
    }

    // function deposit(address owner, uint256 id) external override{
    //     require(!available(id) && _isApprovedOrOwner(owner, id));//必须在期限内 且是所有者
    //     _deposit(owner,id);
    // }

    // function withdraw(address owner, uint256 id) external override{
    //     require(!available(id) && depositlist[owner][id]);//必须在期限内  且被所有者贮藏
    //     _withdraw(owner,id);
    // }

    function renew(uint256 id, uint duration) external override returns(uint){
        return _renew(id, duration);
    }

    
    function available(uint256 id) public view override returns(bool) {
        return (expires[id] + GRACE_PERIOD < block.timestamp);
    }


    function checkExpire(uint256 id)public view override returns(uint256){
        return expires[id];
    }

    // function _isApprovedOrOwner(address spender, uint256 tokenId) internal view override returns (bool) {
    //     address owner = ownerOf(tokenId);
    //     return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    // }


    // function _withdraw(address owner, uint256 id) internal onlyController{
    //     depositlist[owner][id] = false;
    //     _mint(owner, id);
    // }


    // function _deposit(address owner, uint256 id) internal onlyController{
    //     depositlist[owner][id] = true;
    //     _burn(id);
    // }

    function _register(uint256 id, address owner, uint duration) internal onlyController live returns(uint) {
        require(available(id));
        require(block.timestamp + duration + GRACE_PERIOD > block.timestamp + GRACE_PERIOD);    //防止溢出

        expires[id] = block.timestamp + duration;
        if(_exists(id)) {
            _burn(id);
        }
        _mint(owner, id);
        nodecontroller.set2LDrecord(ETH_NODE, bytes32(id), owner, address(defaultResolver));

        return block.timestamp + duration;
    }


    function _renew(uint256 id, uint duration) internal onlyController live returns(uint) {
        require(expires[id] + GRACE_PERIOD >= block.timestamp);                   // 在缓冲期内
        require(expires[id] + duration + GRACE_PERIOD > duration + GRACE_PERIOD); // 防止溢出

        expires[id] += duration;

        return expires[id];
    }

    function reclaim(uint256 id, address owner) external override live {
        require(_isApprovedOrOwner(msg.sender, id));
        nodecontroller.set2LDowner(ETH_NODE, bytes32(id), owner);
    }



    function makeNode(string calldata name)
        public
        pure
        returns (bytes32)
    {
        bytes32 label = keccak256(bytes(name));

        return keccak256(abi.encodePacked(ETH_NODE,label));
    }


//test
    function checkdefaultResolver() public view returns(address){
        return defaultResolver;
    }
    function checkduration(uint256 label) public view returns(uint256){
        return expires[label] - block.timestamp;
    }
    function check_node(string calldata name) public pure returns(bytes32){
        uint256 label = uint256(keccak256(bytes(name)));
        return keccak256(abi.encodePacked(ETH_NODE,bytes32(label)));
    }
}
