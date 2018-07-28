pragma solidity 0.4.24;

import "../ERC721/IERC721Receiver.sol";
import "../Interfaces/SupportsInterfaceWithLookup.sol";
import "../Introspection/MyCryptoChampCoreInterface.sol";
import "../ownable.sol";
import "../AddressUtils.sol";

contract ERC721 is Ownable, SupportsInterfaceWithLookup {

  using AddressUtils for address;

  string private _ERC721name = "MyCryptoItem";
  string private _ERC721symbol = "MCCI";
  bool private tokenIsChamp = false;
  address private coreAddress;
  
  MyCryptoChampCore core;

  function setCoreAddress(address newCoreAddress) public onlyOwner {
      require(newCoreAddress != address(0));
      coreAddress = newCoreAddress;
      core = MyCryptoChampCore(coreAddress);
  }

    //ERC721 START
    event Transfer(address indexed _from, address indexed _to, uint indexed _tokenId);
    event Approval(address indexed _owner, address indexed _approved, uint indexed _tokenId);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    bytes4 private constant InterfaceId_ERC721 = 0x80ac58cd;
    /**
     * 0x80ac58cd ===
     *   bytes4(keccak256('balanceOf(address)')) ^
     *   bytes4(keccak256('ownerOf(uint256)')) ^
     *   bytes4(keccak256('approve(address,uint256)')) ^
     *   bytes4(keccak256('getApproved(uint256)')) ^
     *   bytes4(keccak256('setApprovalForAll(address,bool)')) ^
     *   bytes4(keccak256('isApprovedForAll(address,address)')) ^
     *   bytes4(keccak256('transferFrom(address,address,uint256)')) ^
     *   bytes4(keccak256('safeTransferFrom(address,address,uint256)')) ^
     *   bytes4(keccak256('safeTransferFrom(address,address,uint256,bytes)'))
     */

    bytes4 private constant InterfaceId_ERC721Exists = 0x4f558e79;
    /**
     * 0x4f558e79 ===
     *   bytes4(keccak256('exists(uint256)'))
     */

     /**
     * @dev Magic value to be returned upon successful reception of an NFT
     *  Equals to `bytes4(keccak256("onERC721Received(address,address,uint,bytes)"))`,
     *  which can be also obtained as `ERC721Receiver(0).onERC721Received.selector`
     */
    bytes4 private constant ERC721_RECEIVED = 0x150b7a02;
    
    bytes4 constant InterfaceId_ERC721Enumerable = 0x780e9d63;
    /**
        bytes4(keccak256('totalSupply()')) ^
        bytes4(keccak256('tokenOfOwnerByIndex(address,uint256)')) ^
        bytes4(keccak256('tokenByIndex(uint256)'));
    */

    bytes4 private constant InterfaceId_ERC721Metadata = 0x5b5e139f;
    /**
       * 0x5b5e139f ===
       *   bytes4(keccak256('name()')) ^
       *   bytes4(keccak256('symbol()')) ^
       *   bytes4(keccak256('tokenURI(uint256)'))
    */

     constructor()
      public
    {
      // register the supported interfaces to conform to ERC721 via ERC165
      _registerInterface(InterfaceId_ERC721);
      _registerInterface(InterfaceId_ERC721Exists);
      _registerInterface(InterfaceId_ERC721Enumerable);
      _registerInterface(InterfaceId_ERC721Metadata);
    }


    /**
   * @dev Guarantees msg.sender is owner of the given token
   * @param _tokenId uint ID of the token to validate its ownership belongs to msg.sender
   */
    modifier onlyOwnerOf(uint _tokenId) {
      require(ownerOf(_tokenId) == msg.sender);
      _;
    }

    /**
   * @dev Checks msg.sender can transfer a token, by being owner, approved, or operator
   * @param _tokenId uint ID of the token to validate
   */
    modifier canTransfer(uint _tokenId) {
      require(isApprovedOrOwner(msg.sender, _tokenId));
      _;
  }

    /**
   * @dev Gets the balance of the specified address
   * @param _owner address to query the balance of
   * @return uint representing the amount owned by the passed address
   */
    function balanceOf(address _owner) public view returns (uint) {
      require(_owner != address(0));
      uint balance;
      (,balance,,) = core.addressInfo(_owner);
      return balance;
  }

    /**
   * @dev Gets the owner of the specified token ID
   * @param _tokenId uint ID of the token to query the owner of
   * @return owner address currently marked as the owner of the given token ID
   */
  function ownerOf(uint _tokenId) public view returns (address) {
      address owner = core.tokenToOwner(tokenIsChamp,_tokenId);
      require(owner != address(0));
      return owner;
  }


  /**
   * @dev Returns whether the specified token exists
   * @param _tokenId uint ID of the token to query the existence of
   * @return whether the token exists
   */
  function exists(uint _tokenId) public view returns (bool) {
      address owner = core.tokenToOwner(tokenIsChamp,_tokenId);
      return owner != address(0);
  }

  /**
   * @dev Approves another address to transfer the given token ID
   * The zero address indicates there is no approved address.
   * There can only be one approved address per token at a given time.
   * Can only be called by the token owner or an approved operator.
   * @param _to address to be approved for the given token ID
   * @param _tokenId uint ID of the token to be approved
   */
  function approve(address _to, uint _tokenId) public {
      address owner = ownerOf(_tokenId);
      require(_to != owner);
      require(msg.sender == owner || isApprovedForAll(owner, msg.sender));

      core.setTokenApproval(_tokenId, _to,tokenIsChamp);
      emit Approval(owner, _to, _tokenId);
   }

  /**
   * @dev Gets the approved address for a token ID, or zero if no address set
   * @param _tokenId uint ID of the token to query the approval of
   * @return address currently approved for the given token ID
   */
    function getApproved(uint _tokenId) public view returns (address) {
      return core.tokenApprovals(tokenIsChamp,_tokenId);
    }

  /**
   * @dev Sets or unsets the approval of a given operator
   * An operator is allowed to transfer all tokens of the sender on their behalf
   * @param _to operator address to set the approval
   * @param _approved representing the status of the approval to be set
   */
    function setApprovalForAll(address _to, bool _approved) public {
      require(_to != msg.sender);
      core.setTokenOperatorApprovals(msg.sender,_to,_approved,tokenIsChamp);
      emit ApprovalForAll(msg.sender, _to, _approved);
    }

  /**
   * @dev Tells whether an operator is approved by a given owner
   * @param _owner owner address which you want to query the approval of
   * @param _operator operator address which you want to query the approval of
   * @return bool whether the given operator is approved by the given owner
   */
    function isApprovedForAll(
      address _owner,
      address _operator
    )
      public
      view
      returns (bool)
    {
      return core.tokenOperatorApprovals(tokenIsChamp, _owner,_operator);
  }

  /**
   * @dev Returns whether the given spender can transfer a given token ID
   * @param _spender address of the spender to query
   * @param _tokenId uint ID of the token to be transferred
   * @return bool whether the msg.sender is approved for the given token ID,
   *  is an operator of the owner, or is the owner of the token
   */
  function isApprovedOrOwner(
      address _spender,
      uint _tokenId
    )
      internal
      view
      returns (bool)
    {
      address owner = ownerOf(_tokenId);
      // Disable solium check because of
      // https://github.com/duaraghav8/Solium/issues/175
      // solium-disable-next-line operator-whitespace
      return (
        _spender == owner ||
        getApproved(_tokenId) == _spender ||
        isApprovedForAll(owner, _spender)
      );
  }

  /**
   * @dev Transfers the ownership of a given token ID to another address
   * Usage of this method is discouraged, use `safeTransferFrom` whenever possible
   * Requires the msg sender to be the owner, approved, or operator
   * @param _from current owner of the token
   * @param _to address to receive the ownership of the given token ID
   * @param _tokenId uint ID of the token to be transferred
  */
  function transferFrom(
      address _from,
      address _to,
      uint _tokenId
    )
      public
      canTransfer(_tokenId)
    {
      require(_from != address(0));
      require(_to != address(0));

      core.clearTokenApproval(_from, _tokenId, tokenIsChamp);
      core.transferToken(_from, _to, _tokenId, tokenIsChamp);

      emit Transfer(_from, _to, _tokenId);
  }

  /**
   * @dev Safely transfers the ownership of a given token ID to another address
   * If the target address is a contract, it must implement `onERC721Received`,
   * which is called upon a safe transfer, and return the magic value
   * `bytes4(keccak256("onERC721Received(address,address,uint,bytes)"))`; otherwise,
   * the transfer is reverted.
   *
   * Requires the msg sender to be the owner, approved, or operator
   * @param _from current owner of the token
   * @param _to address to receive the ownership of the given token ID
   * @param _tokenId uint ID of the token to be transferred
  */
  function safeTransferFrom(
      address _from,
      address _to,
      uint _tokenId
    )
      public
      canTransfer(_tokenId)
    {
      // solium-disable-next-line arg-overflow
      safeTransferFrom(_from, _to, _tokenId, "");
  }

    /**
     * @dev Safely transfers the ownership of a given token ID to another address
     * If the target address is a contract, it must implement `onERC721Received`,
     * which is called upon a safe transfer, and return the magic value
     * `bytes4(keccak256("onERC721Received(address,address,uint,bytes)"))`; otherwise,
     * the transfer is reverted.
     * Requires the msg sender to be the owner, approved, or operator
     * @param _from current owner of the token
     * @param _to address to receive the ownership of the given token ID
     * @param _tokenId uint ID of the token to be transferred
     * @param _data bytes data to send along with a safe transfer check
     */
  function safeTransferFrom(
      address _from,
      address _to,
      uint _tokenId,
      bytes _data
    )
      public
      canTransfer(_tokenId)
    {
      transferFrom(_from, _to, _tokenId);
      // solium-disable-next-line arg-overflow
      require(checkAndCallSafeTransfer(_from, _to, _tokenId, _data));
  }

  /**
   * @dev Internal function to invoke `onERC721Received` on a target address
   * The call is not executed if the target address is not a contract
   * @param _from address representing the previous owner of the given token ID
   * @param _to target address that will receive the tokens
   * @param _tokenId uint ID of the token to be transferred
   * @param _data bytes optional data to send along with the call
   * @return whether the call correctly returned the expected magic value
   */
  function checkAndCallSafeTransfer(
      address _from,
      address _to,
      uint _tokenId,
      bytes _data
    )
      internal
      returns (bool)
    {
      if (!_to.isContract()) {
        return true;
      }
      bytes4 retval = ERC721Receiver(_to).onERC721Received(
        msg.sender, _from, _tokenId, _data);
      return (retval == ERC721_RECEIVED);
  }
  
    ///
    /// ERC721Enumerable
    ///
    /// @notice Count NFTs tracked by this contract
    /// @return A count of valid NFTs tracked by this contract, where each one of
    ///  them has an assigned and queryable owner not equal to the zero address
    function totalSupply() external view returns (uint){
      return core.getTokenCount(tokenIsChamp);
    }

    /// @notice Enumerate valid NFTs
    /// @dev Throws if `_index` >= `totalSupply()`.
    /// @param _index A counter less than `totalSupply()`
    /// @return The token identifier for the `_index`th NFT,
    ///  (sort order not specified)
    function tokenByIndex(uint _index) external view returns (uint){
      uint tokenIndexesLength = this.totalSupply();
      require(_index < tokenIndexesLength);
      return _index;
    }

    
    /// @notice Enumerate NFTs assigned to an owner
    /// @dev Throws if `_index` >= `balanceOf(_owner)` or if
    ///  `_owner` is the zero address, representing invalid NFTs.
    /// @param _owner An address where we are interested in NFTs owned by them
    /// @param _index A counter less than `balanceOf(_owner)`
    /// @return The token identifier for the `_index`th NFT assigned to `_owner`,
    ///   (sort order not specified)
    function tokenOfOwnerByIndex(address _owner, uint _index) external view returns (uint){
        require(_index >= balanceOf(_owner));
        require(_owner!=address(0));
        
        uint[] memory tokens;
        uint tokenId;
        
        if(tokenIsChamp){
            tokens = core.getChampsByOwner(_owner);
        }else{
            tokens = core.getItemsByOwner(_owner);
        }
        
        for(uint i = 0; i < tokens.length; i++){
            if(i + 1 == _index){
                tokenId = tokens[i];
                break;
            }
        }
        
        return tokenId;
    }
    
    
    ///
    /// ERC721Metadata
    ///
    /// @notice A descriptive name for a collection of NFTs in this contract
    function name() external view returns (string _name){
      return _ERC721name;
    }

    /// @notice An abbreviated name for NFTs in this contract
    function symbol() external view returns (string _symbol){
      return _ERC721symbol;
    }

    /// @notice A distinct Uniform Resource Identifier (URI) for a given asset.
    /// @dev Throws if `_tokenId` is not a valid NFT. URIs are defined in RFC
    ///  3986. The URI may point to a JSON file that conforms to the "ERC721
    ///  Metadata JSON Schema".
    function tokenURI(uint _tokenId) external view returns (string){
      require(exists(_tokenId));
      return core.getTokenURIs(_tokenId,tokenIsChamp);
    }

}