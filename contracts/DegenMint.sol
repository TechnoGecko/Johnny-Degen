//SPDX-License-Identifier: Unlicense

/**                                                                                                           
         ,---._                                                                                                         
       .-- -.' \           ,---,                                       ,---,                                            
       |    |   :        ,--.' |                                     .'  .' `\                                          
       :    ;   |  ,---. |  |  :         ,---,      ,---,          ,---.'     \                                  ,---,  
       :        | '   ,'\:  :  :     ,-+-. /  | ,-+-. /  |         |   |  .`\  |          ,----._,.          ,-+-. /  | 
       |    :   :/   /   :  |  |,--.,--.'|'   |,--.'|'   |     .--,:   : |  '  |  ,---.  /   /  ' /  ,---.  ,--.'|'   | 
       :        .   ; ,. |  :  '   |   |  ,"' |   |  ,"' |   /_ ./||   ' '  ;  : /     \|   :     | /     \|   |  ,"' | 
       |    ;   '   | |: |  |   /' |   | /  | |   | /  | |, ' , ' :'   | ;  .  |/    /  |   | .\  ./    /  |   | /  | | 
   ___ l        '   | .; '  :  | | |   | |  | |   | |  | /___/ \: ||   | :  |  .    ' / .   ; ';  .    ' / |   | |  | | 
 /    /\    J   |   :    |  |  ' | |   | |  |/|   | |  |/ .  \  ' |'   : | /  ;'   ;   /'   .   . '   ;   /|   | |  |/  
/  ../  `..-    ,\   \  /|  :  :_:,|   | |--' |   | |--'   \  ;   :|   | '` ,/ '   |  / |`---`-'| '   |  / |   | |--'   
\    \         ;  `----' |  | ,'   |   |/     |   |/        \  \  ;;   :  .'   |   :    |.'__/\_: |   :    |   |/       
 \    \      ,'          `--''     '---'      '---'          :  \  |   ,.'      \   \  / |   :    :\   \  /'---'        
  "---....--'                                                 \  ' '---'         `----'   \   \  /  `----'              
                                                               `--`                        `--`-'                       
**/

pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DegenMint is ERC721, Ownable {
    using Strings for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private supply;

    //Variable Declaration

    string public uriPrefix = "";
    string public uriSuffix = ".json";
    string public hiddenMetadataUri;

    uint256 public maxSupply;
    uint256 public maxMintPerTxn;
    uint256 public maxAllowlistFreeMint;
    uint256 public maxFreeMint;
    uint256 public maxMintPostFreePhase;
    uint256 public mintPrice;

    bool public allowlistOnly;
    bool public paused;
    bool public revealed;
    bool public freeMintPhase;

    mapping(address => uint256) private quantityMintedByWallet;

    //Solidity automatically declares bool values to false
    mapping(address => bool) private walletIsAllowlisted;

    constructor() ERC721("JohnnyDegen", "JD") {
        maxSupply = 5555;
        allowlistOnly = true;
        maxMintPerTxn = 3;
        paused = true;
        maxAllowlistFreeMint = 3;
        maxFreeMint = 1;
        mintPrice = 0.03 ether;
    }

    modifier mintCompliance(uint256 _mintAmount) {
        require(!paused, "Minting is paused");
        require(
            supply.current() + _mintAmount <= maxSupply,
            "Transaction would exceed max supply."
        );
        _;
    }

    function totalSupply() public view returns (uint256) {
        return supply.current();
    }

    function mint(uint256 _mintAmount)
        public
        payable
        mintCompliance(_mintAmount)
    {
        if (
            //Allowlisted during free mint phase
            walletIsAllowlisted[msg.sender] && freeMintPhase
        ) {
            require(
                _mintAmount > 0,
                "Allowlisted wallets may mint between 1 and 3 Tokens in the free mint phase"
            );
            _mintLoop(msg.sender, _mintAmount, maxAllowlistFreeMint);
        } else if (
            //Minting during free mint WITHOUT allowlist
            !walletIsAllowlisted[msg.sender] && !allowlistOnly && freeMintPhase
        ) {
            require(_mintAmount == 1, "One free mint is allowed per wallet!");
            _mintLoop(msg.sender, _mintAmount, maxFreeMint);
        } else if (
            //Minting after free mint phase
            !walletIsAllowlisted[msg.sender] && !freeMintPhase
        ) {
            require(
                msg.value >= _mintAmount * mintPrice,
                "Must send the correct amount of ETH for transaction"
            );
            _mintLoop(msg.sender, _mintAmount, maxMintPostFreePhase);
        }
    }

    //From HashLips SimpleNftLowerGas.sol contract
    function walletOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory ownedTokenIds = new uint256[](ownerTokenCount);
        uint256 currentTokenId = 1;
        uint256 ownedTokenIndex = 0;

        while (
            ownedTokenIndex < ownerTokenCount && currentTokenId <= maxSupply
        ) {
            address currentTokenOwner = ownerOf(currentTokenId);

            if (currentTokenOwner == _owner) {
                ownedTokenIds[ownedTokenIndex] = currentTokenId;

                ownedTokenIndex++;
            }

            currentTokenId++;
        }

        return ownedTokenIds;
    }

    //From HashLips SimpleNftLowerGas.sol contract
    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (revealed == false) {
            return hiddenMetadataUri;
        }

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        _tokenId.toString(),
                        uriSuffix
                    )
                )
                : "";
    }

    function setFreeMint(bool _state) public onlyOwner {
        freeMintPhase = _state;
    }

    function setRevealed(bool _state) public onlyOwner {
        revealed = _state;
    }

    function setMintPrice(uint256 _mintPrice) public onlyOwner {
        mintPrice = _mintPrice;
    }

    function setHiddenMetadataUri(string memory _hiddenMetadataUri)
        public
        onlyOwner
    {
        hiddenMetadataUri = _hiddenMetadataUri;
    }

    function setUriPrefix(string memory _uriPrefix) public onlyOwner {
        uriPrefix = _uriPrefix;
    }

    function setUriSuffix(string memory _uriSuffix) public onlyOwner {
        uriSuffix = _uriSuffix;
    }

    function setPaused(bool _state) public onlyOwner {
        paused = _state;
    }

    function beginMint() public onlyOwner {
        paused = false;
        freeMintPhase = true;
    }

    function withdraw() public onlyOwner {
        // This will transfer the remaining contract balance to the owner.
        // Do not remove this otherwise you will not be able to withdraw the funds.
        // =============================================================================
        (bool os, ) = payable(owner()).call{value: address(this).balance}("");
        require(os);
        // =============================================================================
    }

    function _mintLoop(
        address _receiver,
        uint256 _mintAmount,
        uint256 _maxMint
    ) internal {
        require(_mintAmount + quantityMintedByWallet[_receiver] <= _maxMint);
        for (uint256 i = 0; i < _mintAmount; i++) {
            supply.increment();
            quantityMintedByWallet[_receiver]++;
            _safeMint(_receiver, supply.current());
        }
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return uriPrefix;
    }
}
