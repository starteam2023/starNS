pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IDeposit.sol";
import "hardhat/console.sol";
import "./ILayerZeroReceiver.sol";
import "./ILayerZeroEndpoint.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract AdminInFuji is Ownable, ILayerZeroReceiver, ERC721 {
    uint256 MAX = 100;
    uint256 gas = 350000;
    uint256 message_send = 0;
    uint256 message_receive = 0;
    ILayerZeroEndpoint public endpoint;
    address private deposit;
    mapping(uint256 => uint256) private expire_data;
    mapping(uint16 => mapping(bytes => mapping(uint256 => FailedMessages)))
        public failedMessages;
    mapping(uint16 => bytes) public trustedRemoteLookup;

    struct FailedMessages {
        uint256 payloadLength;
        bytes32 payloadHash;
    }

    event MessageFailed(
        uint16 _srcChainId,
        bytes _srcAddress,
        uint64 _nonce,
        bytes _payload
    );
    event ReceiveMsg(uint16 _srcChainId, address _from, bytes _payload);

    constructor(address _endpoint) ERC721("DomainName", "DomainName") {
        endpoint = ILayerZeroEndpoint(_endpoint);
    }

    function setdepositAddress(address _deposit) external onlyOwner {
        deposit = _deposit;
    }

    function setTrustedRemote(uint16 _chainId, bytes calldata _trustedRemote)
        external
        onlyOwner
    {
        trustedRemoteLookup[_chainId] = _trustedRemote;
    }

    function setgas(uint256 newVal) external onlyOwner {
        gas = newVal;
    }

    function retryMessage(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes calldata _payload
    ) external payable {
        // assert there is message to retry
        FailedMessages storage failedMsg = failedMessages[_srcChainId][
            _srcAddress
        ][_nonce];
        require(
            failedMsg.payloadHash != bytes32(0),
            "NonblockingReceiver: no stored message"
        );
        require(
            _payload.length == failedMsg.payloadLength &&
                keccak256(_payload) == failedMsg.payloadHash,
            "LayerZero: invalid payload"
        );
        // clear the stored message
        failedMsg.payloadLength = 0;
        failedMsg.payloadHash = bytes32(0);
        // execute the message. revert if it fails again
        this.onLzReceive(_srcChainId, _srcAddress, _nonce, _payload);
    }

    function checkLabel(string calldata name)
        public
        pure
        returns (uint256 label)
    {
        label = uint256(keccak256(bytes(name)));
        return label;
    }

    function CrossChain(
        uint16 _dstChainId,
        bytes calldata _destination,
        uint256 tokenId
    ) public payable {
        require(msg.sender == ownerOf(tokenId), "Not the owner");

        address owner = ownerOf(tokenId);
        // working  NFT
        transferFrom(msg.sender, deposit, tokenId);

        IDeposit(deposit).deposit(tokenId);

        bytes memory payload = abi.encode(owner, tokenId);

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

    function lzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload
    ) external override {
        require(msg.sender == address(endpoint)); // boilerplate! lzReceive must be called by the endpoint for security
        // require(_srcAddress.length == trustedRemoteLookup[_srcChainId].length && keccak256(_srcAddress) == keccak256(trustedRemoteLookup[_srcChainId]),
        //     "NonblockingReceiver: invalid source sending contract");

        // try-catch all errors/exceptions
        // having failed messages does not block messages passing
        try this.onLzReceive(_srcChainId, _srcAddress, _nonce, _payload) {
            // do nothing
        } catch {
            // error / exception
            failedMessages[_srcChainId][_srcAddress][_nonce] = FailedMessages(
                _payload.length,
                keccak256(_payload)
            );
            emit MessageFailed(_srcChainId, _srcAddress, _nonce, _payload);
        }
    }

    function onLzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload
    ) public {
        // only internal transaction
        require(
            msg.sender == address(this),
            "NonblockingReceiver: caller must be Bridge."
        );

        // handle incoming message
        _LzReceive(_srcChainId, _srcAddress, _nonce, _payload);
    }

    function _LzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload
    ) internal {
        address from;
        assembly {
            from := mload(add(_srcAddress, 20))
        }
        (address owner, uint256 label, uint256 expire) = abi.decode(
            _payload,
            (address, uint256, uint256)
        );
        o = true;
        expire_data[label] = expire;
        if (_exists(label)) {
            IDeposit(deposit).withdraw(label, owner);
        } else {
            _mint(owner, label);
        }
        message_receive++;
        emit ReceiveMsg(_srcChainId, from, _payload);
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
    function checkfee(uint16 _dstChainId, uint256 tokenId)
        public
        view
        returns (uint256)
    {
        bytes memory payload = abi.encode(msg.sender, tokenId);

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

    function check() public view returns (bool) {
        return o;
    }

    function change(bool _o) public returns (bool) {
        o = _o;
        return o;
    }

    bool public o = false;

    function check_message() public view returns (uint256, uint256) {
        return (message_send, message_receive);
    }

    function checkdepositAddress() public view returns (address) {
        return deposit;
    }
}
