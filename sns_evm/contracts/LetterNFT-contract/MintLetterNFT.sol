// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ColorLib} from "./ColorLib.sol";
import "base64-sol/base64.sol";

contract MintLetterNFT is ERC721URIStorage, Ownable{

    mapping(address => bool) public trustees;

    event TrusteeAdded(address indexed trustee);
    event TrusteeRemoved(address indexed trustee);

    modifier onlyTrustee {
        require(trustees[msg.sender]);
        _;
    }

    function AddTrustee (address trustee) external onlyOwner {
        trustees[trustee] = true;
        emit TrusteeAdded(trustee);
    }

    function RemoveTrustee (address trustee) external onlyOwner {
        trustees[trustee] = false;
        emit TrusteeRemoved(trustee);

    }


    
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    string private _letters = "star";


    constructor() ERC721(string(abi.encodePacked(_letters," NFT")),string(abi.encodePacked(_letters," NFT"))) {}

        function mintNFT(address recipient)
        external
        onlyTrustee
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURIForAddress(recipient));
        return newItemId;
    }


    function tokenURIForAddress(address user) public view returns (string memory) {
        bytes[5] memory colors = ColorLib.gradientForAddress(user);
        // string memory letter = getLetterForAddress(user);
        string memory encoded = Base64.encode(
          bytes(string(abi.encodePacked(  
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 140 140"><defs>'
                // new gradient fix – test
                '<radialGradient id="gzr" gradientTransform="translate(140 20) scale(150)" gradientUnits="userSpaceOnUse" r="1" cx="0" cy="0%">'
                // '<radialGradient fx="66.46%" fy="24.36%" id="grad">'
                '<stop offset="15.62%" stop-color="',
                colors[0],
                '" /><stop offset="39.58%" stop-color="',
                colors[1],
                '" /><stop offset="72.92%" stop-color="',
                colors[2],
                '" /><stop offset="90.63%" stop-color="',
                colors[3],
                '" /><stop offset="100%" stop-color="',
                colors[4],
                '" /></radialGradient>     </defs><g >'
                '<rect x="20" y="20" width="100" height="100" fill="url(#gzr)" rx="20" ry="20"  stroke="rgba(0,0,0,0.075)"/>'
        '<rect x="30" y="30" width="80" height="80" fill="#fff" rx="12" ry="12"  stroke="rgba(0,0,0,0.075)"/><text x="52" y="90" font-family="poppins, sans-serif" font-style="normal" font-weight="600" font-size="60px" fill="url(#gzr)" >',
                ColorLib.getLetterForAddress(user,_letters),
                '</text>'
                "</g></svg>"
            )
            )
           )
        );
        string memory encodedForAddress = string(abi.encodePacked("data:image/svg+xml;base64,", encoded));


        
        string memory base64encode = Base64.encode( abi.encodePacked(
                    '{"image": "',
                    encodedForAddress,
                    '"}'
                ));

        string memory encodeJSON =  string(abi.encodePacked(
                    "data:application/json;base64,",
                    base64encode
                ));

        return encodeJSON;
    }
    
}
