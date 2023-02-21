pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IDeposit.sol";
import "./IQuoter.sol";
import "./ILayerZeroReceiver.sol";
import "./ILayerZeroEndpoint.sol";

contract AdminInETH_iquoter is Ownable, ILayerZeroReceiver, ERC721{
    address public input = 0xc778417E063141139Fce010982780140Aa0cD5Ab;
    address public output =  0xc778417E063141139Fce010982780140Aa0cD5Ab;
    uint256 MAX = 100;
    uint256 gas = 350000;
    Price public price;
    ILayerZeroEndpoint public endpoint;
    IQuoter public quoter;
    address private deposit;
    mapping(uint16 => mapping(bytes => mapping(uint => FailedMessages))) public failedMessages;
    mapping(uint16 => bytes) public trustedRemoteLookup;

//TEST

    uint256 message_send = 0;
    uint256 message_receive = 0;

    struct Price {
        uint256 base;
        uint256 premium;
    }

    struct FailedMessages {
        uint payloadLength;
        bytes32 payloadHash;
    }

    event MessageFailed(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes _payload);
    event ReceiveMsg(
        uint16 _srcChainId,
        address _from,
        bytes _payload
    ); 

    constructor(address _endpoint,
        uint256 baseprice,
        uint256 premiumprice,
        IQuoter _quoter
        ) ERC721("star","star") {

        endpoint = ILayerZeroEndpoint(_endpoint);
        price.base = baseprice;
        price.premium = premiumprice;
        quoter = _quoter;
    }



    function setdepositAddress(address _deposit)
        external
        onlyOwner
    {
        deposit = _deposit;
    }

    function setTrustedRemote(uint16 _chainId, bytes calldata _trustedRemote) external onlyOwner {
        trustedRemoteLookup[_chainId] = _trustedRemote;
    }


    function setgas(uint newVal) external onlyOwner {
        gas = newVal;
    }





    function retryMessage(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes calldata _payload) external payable {
        // assert there is message to retry
        FailedMessages storage failedMsg = failedMessages[_srcChainId][_srcAddress][_nonce];
        require(failedMsg.payloadHash != bytes32(0), "NonblockingReceiver: no stored message");
        require(_payload.length == failedMsg.payloadLength && keccak256(_payload) == failedMsg.payloadHash, "LayerZero: invalid payload");
        // clear the stored message
        failedMsg.payloadLength = 0;
        failedMsg.payloadHash = bytes32(0);
        // execute the message. revert if it fails again
        this.onLzReceive(_srcChainId, _srcAddress, _nonce, _payload);
    }

    function crossChain(
        uint16 _dstChainId,
        bytes calldata _destination,
        string calldata name
    ) public payable {
        
        uint256 label = uint256(keccak256(bytes(name)));
        require(_exists(label));
        require(msg.sender == ownerOf(label));
        _transfer(msg.sender, deposit, label);
        IDeposit(deposit).deposit(label);
        bytes memory payload = abi.encode(msg.sender, label, 0);

        // encode adapterParams to specify more gas for the destination
        uint16 version = 1;
        bytes memory adapterParams = abi.encodePacked(version, gas);

        (uint256 messageFee, ) = endpoint.estimateFees(
            _dstChainId,
            address(this),
            payload,
            false,
            adapterParams
        );
        
        require(
            msg.value >= messageFee,
            "Must send enough value to cover messageFee"
        );
        endpoint.send{value: msg.value}(
            _dstChainId,
            _destination,
            payload,
            payable(msg.sender),
            address(0x0),
            adapterParams
        );
        message_send++;
    }

    function check_price(uint256 bnb_amount) public returns(uint256){

        uint256 eth_amount = quoter.quoteExactOutputSingle(input, output, 3000, bnb_amount, 0);
        return eth_amount;
    }

    function register(
        uint16 _dstChainId,
        bytes calldata _destination,
        string calldata name,
        uint duration
    ) public payable {
        address owner = msg.sender;
        uint256 label = uint256(keccak256(bytes(name)));
        require(!_exists(label));
        
        // uint256 bnb_amount = price.base + price.premium;
        // uint256 eth_amount = check_price(bnb_amount);
        // require(msg.value >= eth_amount);
        // if (msg.value > eth_amount) {
        //     payable(msg.sender).transfer(
        //         msg.value - eth_amount
        //     );
        // }
        bytes memory payload = abi.encode(owner, label, 0);

        // encode adapterParams to specify more gas for the destination
        uint16 version = 1;
        bytes memory adapterParams = abi.encodePacked(version, gas);

        (uint256 messageFee, ) = endpoint.estimateFees(
            _dstChainId,
            address(this),
            payload,
            false,
            adapterParams
        );
        
        require(
            msg.value >= messageFee,
            "Must send enough value to cover messageFee"
        );
        endpoint.send{value: msg.value}(
            _dstChainId,
            _destination,
            payload,
            payable(msg.sender),
            address(0x0),
            adapterParams
        );
        message_send++;
    }


    function lzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) external override {
        require(msg.sender == address(endpoint)); // boilerplate! lzReceive must be called by the endpoint for security
        require(_srcAddress.length == trustedRemoteLookup[_srcChainId].length && keccak256(_srcAddress) == keccak256(trustedRemoteLookup[_srcChainId]), 
            "NonblockingReceiver: invalid source sending contract");

        // try-catch all errors/exceptions
        // having failed messages does not block messages passing
        try this.onLzReceive(_srcChainId, _srcAddress, _nonce, _payload) {
            // do nothing
        } catch {
            // error / exception
            failedMessages[_srcChainId][_srcAddress][_nonce] = FailedMessages(_payload.length, keccak256(_payload));
            emit MessageFailed(_srcChainId, _srcAddress, _nonce, _payload);
        }
    }


    function onLzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) public {
        // only internal transaction
        require(msg.sender == address(this), "NonblockingReceiver: caller must be Bridge.");

        // handle incoming message
        _LzReceive( _srcChainId, _srcAddress, _nonce, _payload);
    }


    function _LzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload)  internal{

        address from;
        assembly {
            from := mload(add(_srcAddress, 20))
        }
        (address owner, uint256 label) = abi.decode(
            _payload,
            (address, uint256)
        );
        if (!_exists(label)){
            _mint(owner, label);
        }else if ( ownerOf(label) == deposit ){
            IDeposit(deposit).withdraw(label, owner);
        }
        o = true;
        message_receive++;
        emit ReceiveMsg(_srcChainId, from,  _payload);

    }


    function estimateFees(
        uint16 _dstChainId,
        address _userApplication,
        bytes calldata _payload,
        bool _payInZRO,
        bytes calldata _adapterParams
    ) external view returns (uint256 nativeFee, uint256 zroFee) {
        return
            endpoint.estimateFees(
                _dstChainId,
                _userApplication,
                _payload,
                _payInZRO,
                _adapterParams
            );
    }



//test
    function checkfee(
        uint16 _dstChainId,
        string calldata name 
    ) public view returns (uint256) {
        uint256 label = check_label(name);
        bytes memory payload = abi.encode(msg.sender, label, 0);

        // encode adapterParams to specify more gas for the destination
        uint16 version = 1;
        bytes memory adapterParams = abi.encodePacked(version, gas);

        (uint256 messageFee, ) = endpoint.estimateFees(
            _dstChainId,
            address(this),
            payload,
            false,
            adapterParams
        );
        return messageFee;
    }

    function check_label(string calldata name) public view returns(uint256 label){
        uint256 label = uint256(keccak256(bytes(name)));
    }


    function check()public view returns(bool){
        return o;
    }
    function change(bool _o)public returns(bool){
        o = _o;
        return o;
    }

    bool public o = false;


    function check_message() public view returns (uint256, uint256){
        return (message_send, message_receive);
    }

    
    function checkdepositAddress() public view returns (address){
        return deposit;
    }

}
