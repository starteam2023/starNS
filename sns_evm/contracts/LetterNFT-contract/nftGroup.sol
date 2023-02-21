// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.1;


import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ColorLib} from "./ColorLib.sol";
import "base64-sol/base64.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


interface RewardNFT{
    function mintNFT(address recipient,string memory tokenURI)external returns (uint256);
}

contract NFTGroup is ReentrancyGuard {
    using Counters for Counters.Counter;

    Counters.Counter private _groupIds;
    mapping(address => uint256) private groupID;
    mapping(uint256 => address[]) private groupMembers;
    mapping(address => bool) private inGroup;
    mapping(uint256 => bool) private inReward;
    string private _letters = "STAR";
    RewardNFT reward;
    constructor(address _rewardAddr){
        reward = RewardNFT(_rewardAddr);
    }
    //// claim reward /////////////
    function claimReward() public returns(string memory _msg){
        require(
            (groupID[msg.sender] != 0),
            "no group."
        );
        require(
            (!inReward[groupID[msg.sender]]),
            "already claim reward."
        );
        uint256 len = bytes(_letters).length;
        address[] memory members = groupMembers[groupID[msg.sender]];
        require((len==members.length),"not enough letters");
        // TODO  奖励分发,发完后，领取奖励的帐号置inReward[_groupID]=true;防止再领
        // TODO  此处暂时设置奖励为写死的NFT
        for(uint8 index=0;index<members.length;index++){
            reward.mintNFT(members[index],"https://bafybeiackrdow5u7qzqugexczutyvhi2i6pdiakmv6unlc4bmib3c5oq4a.ipfs.infura-ipfs.io/");
        }
        inReward[groupID[msg.sender]]=true;
        _msg = string(abi.encodePacked("reward has distributed."));
    }

    
 //////////////Operate own group/////////////////

    ////// create group //////////////
    function createGroup() public returns (uint256 _groupID){
        require(
            (groupID[msg.sender] == 0) && (!inGroup[msg.sender]),
            "group exist."
        );
        _groupIds.increment();
        groupID[msg.sender]=_groupIds.current();
        groupMembers[_groupIds.current()].push(msg.sender);
        inGroup[msg.sender]=true;
        _groupID = groupID[msg.sender];
    }

    //////// add other user to my group///////////
    function addUserToOwnGroup(address user) public {
        require(
            (groupID[msg.sender] != 0) && (groupMembers[groupID[msg.sender]].length<bytes(_letters).length),
            "no group or full members."
        );
        require(
            (groupID[user] == 0) && (!inGroup[user]),
            "already in group."
        );
        checkLetterExist(user,groupID[msg.sender]);
        groupMembers[groupID[msg.sender]].push(user);
        inGroup[user]=true;
    }

    //////// add to group by groupID///////////////
    function addToGroupByGroupID(uint256 _groupID) public returns(bool _inGroup){
        require((!inGroup[msg.sender] && groupMembers[_groupID].length<bytes(_letters).length),"already in group or full members.");
        require((groupID[msg.sender]==0),"exist own group.");
        checkLetterExist(msg.sender,_groupID);
        groupMembers[_groupID].push(msg.sender);
        inGroup[msg.sender]=true;
        _inGroup=inGroup[msg.sender];
    }

    /////////burn my group/////////////////////
    function burnOwnGroup() public {
        require(
            (inGroup[msg.sender]),
            "not in group."
        );
        require(
            (groupID[msg.sender]!=0),
            "no group."
        );
        require(
            (!inReward[groupID[msg.sender]]),
            "reward group can't burn."
        );
        address[] memory members = groupMembers[groupID[msg.sender]];
        for(uint8 index=0;index<members.length;index++){
            inGroup[members[index]]=false;
        }
        delete groupMembers[groupID[msg.sender]];
        groupID[msg.sender]=0;
    }

////////////////////Viewers/////////////////////

    function viewGroupMembers(uint256 _groupID) public view returns(address[] memory){
        if(_groupID==0){
            return groupMembers[groupID[msg.sender]];
        }
        return groupMembers[_groupID];
    }
    function viewGroupLetters(uint256 _groupID) public view returns(string[] memory){
        address[] memory members = groupMembers[_groupID];
        string[] memory letters=new string[](members.length);
        
        for(uint8 index=0;index<letters.length;index++){
            letters[index]=getLetterForAddress(members[index]);
        }
        return letters;
    }



///////////////////Getters//////////////////////////

    function getInGroup() external view returns(bool) {
        return inGroup[msg.sender];
    }
    
    function getLetterForAddress(address user) public view returns (string memory) {
        return ColorLib.getLetterForAddress(user,_letters);
    }

    


/////////////util function/////////////

     //////// check if already exsit same letter/////////////
    function checkLetterExist(address user,uint256 _groupID) view internal {
        address[] memory members = groupMembers[_groupID];
        for(uint8 index=0;index<members.length;index++){
            require(
            (keccak256(bytes(getLetterForAddress(members[index])))!=keccak256(bytes(getLetterForAddress(user)))),
            "exist same letter."
            );
        }
    }
    
}
