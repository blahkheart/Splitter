// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

/**
    !Disclaimer!
    please review this code on your own before using any of
    the following code for production.
    Dannithomx will not be liable in any way if for the use 
    of the code. That being said, the code has been tested 
    to the best of the developers' knowledge to work as intended.
*/

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Splitter Contract
 * @author Danny Thomx
 * @notice Explain to an end user what this does
 * @dev Explain to a developer any extra details
 * @notice Distributes funds among multiple recipients based on specified shares.
 * @dev This contract allows an owner to distribute tokens or Ether to multiple recipients according to predefined shares.
 * Recipients are added and removed by the owner, and tokens or Ether are distributed proportionally to the shares specified for each recipient.
 * Shares are represented in basis points (1 basis point = 0.01%), and the total shares across all recipients cannot exceed 10000 basis points.
 * Only the owner can call functions to add/remove recipients and distribute tokens/Ether.
 * Users can query the shares of a recipient and check if an address is a valid recipient.
 */

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
}

contract Splitter is Ownable {
    mapping(address => uint256) shares;
    mapping(address => bool) addedRecipients;
    mapping(address => uint256) public etherReleased;
    mapping(IERC20 => mapping(address => uint256)) erc20Released;
    mapping(IERC20 => uint256) erc20TotalReleased;

    address[] recipients;
    uint256 constant MAX_SHARES = 100;
    uint256 public totalShares = 0;
    uint256 totalReleased;

    event RecipientAdded(address indexed recipient, uint256 indexed share);
    event RecipientRemoved(address indexed recipient);
    event TokenDistributed(address indexed token, address recipient, uint256 amount);
    event EtherDistributed(address recipient, uint256 amount);

    constructor() { }

    receive() external payable {}

    /**
     * @notice Gets the share of a recipient.
     * @param _recipient Address of the recipient.
     * @return percentageShare Number of basis points representing the recipient's share.
     */
    function getShares(address _recipient) public view returns(uint256 percentageShare) {
        percentageShare = shares[_recipient];
    }

    /**
     * @notice Checks if an address is a valid recipient.
     * @param _recipient Address to be checked.
     * @return isRecipient Boolean indicating whether the address is a valid recipient.
     */
    function getIsRecipient(address _recipient)public view returns(bool isRecipient){
        isRecipient = addedRecipients[_recipient];
    }

    /**
     * @notice Gets the token balance of the contract for a specific ERC20 token.
     * @param _tokenAddress Address of the ERC20 token.
     * @return balance Token balance of the contract for the specified token.
     */
    function getTokenBalance(address _tokenAddress) public view returns(uint256 balance) {
        balance = IERC20(_tokenAddress).balanceOf(address(this));
    }

    /**
     * @dev Getter for the total amount of Ether already released.
     * @return uint256 Total ether amount distributed by the contract.
     */
    function getTotalEtherReleased() public view returns (uint256) {
        return totalReleased;
    }

    /**
     * @notice Gets the total token amount distributed to a `_recipient` for a specific ERC20 token.
     * @param _token Address of an ERC20 token contract.
     * @return uint256 ERC20 Token amount distributed by the contract to `_recipient` for `_token` specified.
     */
    function getErc20Released(IERC20 _token, address _recipient) public view returns(uint256){
        return erc20Released[_token][_recipient];
    }

    /**
     * @notice Gets the total token amount distributed by the contract for a specific ERC20 token.
     * @param _token Address of an ERC20 token contract.
     * @return uint256 ERC20 Token balance distributed by the contract for `_token` specified.
     */
    function getTotalErc20Released(IERC20 _token) public view returns(uint256){
        return erc20TotalReleased[_token];
    }

    /**
     * @notice Adds a recipient with a specified share.
     * @param _recipient Address of the recipient.
     * @param _share Number of basis points (out of 10000) representing the recipient's share.
     */
    function addRecipient(address _recipient, uint256 _share) public onlyOwner {
        require(_recipient != address(0), "Invalid address");
        require(_share > 0 && _share <= MAX_SHARES, "Invalid share");
        if(addedRecipients[_recipient]) {
            uint256 previousShare = shares[_recipient];
            totalShares -= previousShare;
            require(_share + totalShares <= MAX_SHARES, "Total shares above maximum shares");
            shares[_recipient] = _share;
            totalShares += _share;
        } else {
            require(_share + totalShares <= MAX_SHARES, "Total shares above maximum shares");
            recipients.push(_recipient);
            shares[_recipient] = _share;
            totalShares += _share;
            addedRecipients[_recipient] = true;
            emit RecipientAdded(_recipient, _share);
        }
    }

    /**
    * @notice Removes a recipient.
    * @param _recipient Address of the recipient to be removed.
    */
    function removeRecipient(address _recipient)public onlyOwner {
        require(addedRecipients[_recipient], "Not recipient");
        _removeRecipient(_recipient);
    }

    /**
     * @notice Distributes tokens among recipients based on their shares.
     * @param _token Interface of the ERC20 token to be distributed.
     */
    function distributeToken(IERC20 _token) public onlyOwner {
        require(_token.balanceOf(address(this)) > 0, "Zero balance");
        require(recipients.length > 1, "At least 2 recipients required");
        for(uint256 i = 0; i < recipients.length; i++) {
            _releaseTokens(_token, recipients[i]);
        }
    }

    /**
     * @notice Distributes Ether among recipients based on their shares.
     */
    function distributeEther() public payable onlyOwner {
        require(address(this).balance > 0, "Zero ETH balance");
        require(recipients.length > 1, "At least 2 recipients required");
        
        for(uint256 i = 0; i < recipients.length; i++) {
            _releaseEther(payable(recipients[i]));
        }
    }

    /**
     * @dev internal logic for removing a recipient and thier shares.
     * @param _recipient Address of the recipient to be removed..
     */
    function _removeRecipient(address _recipient) private {
       uint256 recipientToRemoveIndex;
       uint256 currentShare = shares[_recipient];
   
       for(uint256 i = 0; i < recipients.length; i++){
           if(keccak256(abi.encodePacked(recipients[i])) == keccak256(abi.encodePacked(_recipient))){
               recipientToRemoveIndex = i;
               recipients[recipientToRemoveIndex] = recipients[recipients.length - 1];
               recipients.pop();
               totalShares -= currentShare;
               shares[_recipient] = 0;
               addedRecipients[_recipient] = false;
               emit RecipientRemoved(_recipient);
           }
       }
    }

    /**
     * @dev internal logic for computing the pending payment of an `account` given the token historical balances and
     * already released amounts.
     */
    function _pendingPayment(
        address account,
        uint256 totalReceived,
        uint256 alreadyReleased
    ) internal view returns (uint256) {
        return (totalReceived * shares[account]) / totalShares - alreadyReleased;
    }

    /**
     * @dev Internal logic for triggering a transfer to `account` the amount of Ether they are owed, according to their percentage of the
     * total shares and their previous withdrawals.
     */
    function _releaseEther(address payable account) internal returns (uint256) {
        uint256 totalReceived = address(this).balance + totalReleased;
        uint256 payment = _pendingPayment(account, totalReceived, etherReleased[account]);

        if (payment == 0) {
            return 0;
        }

        etherReleased[account] += payment;
        totalReleased += payment;

        (bool success) = payable(account).send(payment);
        require(success, "Failed to transfer Ether");
        emit EtherDistributed(account, payment);
        return payment;
    }

    /**
     * @dev Internal logic for triggering a transfer to `account` the amount of `token` they are owed, according to their
     * percentage of the total shares and their previous withdrawals. `token` must be the address of an IERC20
     * contract.
     */
    function _releaseTokens(IERC20 token, address account) private {
        uint256 totalReceived = token.balanceOf(address(this)) + erc20TotalReleased[token];
        uint256 payment = _pendingPayment(account, totalReceived, erc20Released[token][account]);

        require(payment != 0, "PaymentSplitter: account is not due payment");

        erc20Released[token][account] += payment;
        erc20TotalReleased[token] += payment;

        (bool success) = IERC20(token).transfer(account, payment);
        require(success, "Failed to transfer tokens");
        emit TokenDistributed(address(token), account, payment);
    }
}