//  SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.4;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Register.sol";
import "hardhat/console.sol";


contract Commit is Ownable {

    struct Price {
        uint256 base;
        uint256 premium;
    }
    uint256 public constant MIN_REGISTRATION_DURATION = 1 seconds;
    uint256 public immutable minCommitmentAge; //1   
    uint256 public immutable maxCommitmentAge; //10000  
    Register public immutable base;
    Price public price;

    mapping(bytes32 => uint256) public commitments;
    mapping(uint256 => string) public token_name;
    
    event NameRegistered(
        string name,
        bytes32 indexed label,
        address indexed owner,
        uint256 expires
    );


    event NameRenewed(
        string name,
        bytes32 indexed label,
        uint256 expires
    );



    constructor(
        uint256 _minCommitmentAge,
        uint256 _maxCommitmentAge,
        uint256 baseprice,
        uint256 premiumprice,
        Register _base
    ) {
        require(_maxCommitmentAge > _minCommitmentAge);
        minCommitmentAge = _minCommitmentAge;//60
        maxCommitmentAge = _maxCommitmentAge;

        require(baseprice > 0 && premiumprice > 0);
        price.base = baseprice;
        price.premium = premiumprice;
        base = _base;
    }

    function withdraw() public {
        payable(owner()).transfer(address(this).balance);
    }

    function setfee(uint256 baseprice, uint256 premiumprice) onlyOwner public  {
        price.base = baseprice;
        price.premium = premiumprice;
    }


    function register(
        string calldata name,
        address owner,
        uint256 duration,
        uint256 secret
    ) external payable returns(uint) {

        require(bytes(name).length >= 3, "illegal name");
        bytes32 label = keccak256(bytes(name));
        token_name[uint256(label)] = name;
        // 需要补充price设置语句
        require(
            msg.value >= (price.base + price.premium * duration),
            " Not enough ether provided"
        );
        _consumeCommitment(
            name,
            duration,
            makeCommitment(
                name,
                owner,
                duration,
                secret
            )
        );

        uint expires = base.register(
            uint256(label),
            owner,
            uint(duration)
        );

        if (msg.value > (price.base + price.premium * duration)) {
            payable(msg.sender).transfer(
                msg.value - (price.base + price.premium * duration)
            );
        }

        emit NameRegistered(
                    name,
                    keccak256(bytes(name)),
                    owner,
                    expires
                );

        return expires;

    }

    function renew(string calldata name, uint256 duration)
        external
        payable
    returns(uint) {
        bytes32 label = keccak256(bytes(name));
        require(
            msg.value >= price.base,
            "ETHController: Not enough Ether provided for renewal"
        );

        uint expires = base.renew(uint256(label), duration);

        if (msg.value > price.base + price.premium * duration) {
            payable(msg.sender).transfer(msg.value - price.base - price.premium * duration);
        }

        emit NameRenewed(name, label,  expires);


        return expires;
    }



    function commit(bytes32 commitment) public  {
        require(commitments[commitment] + maxCommitmentAge < block.timestamp,
        "This commitment has not expired"); //只有超过最大时间才能重新更新   
        commitments[commitment] = block.timestamp;
    }


    function makeCommitment(
        string memory name,
        address owner,
        uint256 duration,
        uint256 secret
    ) public view  returns (bytes32) {
        bytes32 label = keccak256(bytes(name));
        require(name_available(name),
        "This name has been already exist"
        ); 
        return 
            keccak256(
                abi.encode(
                    label,
                    owner,
                    duration,
                    secret
                )
            );
    }

    function name_available(string memory name) public view returns (bool) {
        bytes32 label = keccak256(bytes(name));
        return base.available(uint256(label)) && bytes(name).length >= 3;
    }


    function check_commit_time(bytes32 commitment) public view returns(uint256){
        return commitments[commitment];
    }


    function check_lable(string calldata name) public pure returns(uint256){
        return uint256(keccak256(bytes(name)));
    }


    function _consumeCommitment(
        string memory name,
        uint256 duration,
        bytes32 commitment
    ) internal {
        require(
            commitments[commitment] + minCommitmentAge <= block.timestamp,
            "Commitment is not valid, Please wait!" 
        );
        require(
            commitments[commitment] + maxCommitmentAge > block.timestamp,
            "Commitment has expired,Please commit again!"
        );
        require(name_available(name), "Name is unavailable");

        delete(commitments[commitment]);

        require(duration >= MIN_REGISTRATION_DURATION);
    }
//test
    function checkTokenName(uint256 tokenId) public view returns(string memory){
        return token_name[tokenId];
    }

//test
    function checkcurrent() public view returns (uint){
        return block.timestamp;
    }
//test
    function byte_check_lable(string memory name) public pure returns(bytes32){
        return bytes32(uint256(keccak256(bytes(name))));
    }


}