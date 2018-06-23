pragma solidity ^0.4.13;


import "./owned.sol";
import "./TuanAnhToken.sol";


contract Exchange is owned {

    ///////////////////////
    // GENERAL STRUCTURE //
    ///////////////////////
    struct Offer {
        
        uint amount;
        address who;
    }

    struct OrderBook {
        
        uint higherPrice;
        uint lowerPrice;
        
        mapping (uint => Offer) offers;
        
        uint offers_key;
        uint offers_length;
    }

    struct Token {
        
        address tokenContract;

        string symbolName;
        
        
        mapping (uint => OrderBook) buyBook;
        
        uint curBuyPrice;
        uint lowestBuyPrice;
        uint amountBuyPrices;


        mapping (uint => OrderBook) sellBook;
        uint curSellPrice;
        uint highestSellPrice;
        uint amountSellPrices;

    }


    //we support a max of 255 tokens...
    mapping (uint8 => Token) tokens;
    uint8 symbolNameIndex;


    //////////////
    // BALANCES //
    //////////////
    mapping (address => mapping (uint8 => uint)) tokenBalanceForAddress;

    mapping (address => uint) balanceEthForAddress;




    ////////////
    // EVENTS //
    ////////////

    //EVENTS for Deposit/withdrawal
    event DepositForTokenReceived(address indexed _from, uint indexed _symbolIndex, uint _amount, uint _timestamp);
    event WithdrawalToken(address indexed _to, uint indexed _symbolIndex, uint _amount, uint _timestamp);
    event DepositForEthReceived(address indexed _from, uint _amount, uint _timestamp);
    event WithdrawalEth(address indexed _to, uint _amount, uint _timestamp);

    //events for orders
    event LimitSellOrderCreated(uint indexed _symbolIndex, address indexed _who, uint _amountTokens, uint _priceInWei, uint _orderKey);
    event SellOrderFulfilled(uint indexed _symbolIndex, uint _amount, uint _priceInWei, uint _orderKey);
    event SellOrderCanceled(uint indexed _symbolIndex, uint _priceInWei, uint _orderKey);
    event LimitBuyOrderCreated(uint indexed _symbolIndex, address indexed _who, uint _amountTokens, uint _priceInWei, uint _orderKey);
    event BuyOrderFulfilled(uint indexed _symbolIndex, uint _amount, uint _priceInWei, uint _orderKey);
    event BuyOrderCanceled(uint indexed _symbolIndex, uint _priceInWei, uint _orderKey);

    //events for management
    event TokenAddedToSystem(uint _symbolIndex, string _token, uint _timestamp);




    //////////////////////////////////
    // DEPOSIT AND WITHDRAWAL ETHER //
    //////////////////////////////////
    function depositEther() public payable {
        require(balanceEthForAddress[msg.sender] + msg.value >= balanceEthForAddress[msg.sender]);
        balanceEthForAddress[msg.sender] += msg.value;
        emit DepositForEthReceived(msg.sender, msg.value, now);
    }

    function withdrawEther(uint amountInWei) public {
        require(balanceEthForAddress[msg.sender] - amountInWei >= 0);
        require(balanceEthForAddress[msg.sender] - amountInWei <= balanceEthForAddress[msg.sender]);
        balanceEthForAddress[msg.sender] -= amountInWei;
        msg.sender.transfer(amountInWei);
        emit WithdrawalEth(msg.sender, amountInWei, now);

    }

    function getEthBalanceInWei() public constant returns (uint){
        return balanceEthForAddress[msg.sender];
    }


    //////////////////////
    // TOKEN MANAGEMENT //
    //////////////////////

    function addToken(string symbolName, address erc20TokenAddress) public onlyowner {
        require(!hasToken(symbolName));
        symbolNameIndex++;
        tokens[symbolNameIndex].symbolName = symbolName;
        tokens[symbolNameIndex].tokenContract = erc20TokenAddress;
        emit TokenAddedToSystem(symbolNameIndex, symbolName, now);
    }

    function hasToken(string symbolName) public constant returns (bool) {
        uint8 index = getSymbolIndex(symbolName);
        if (index == 0) {
            return false;
        }
        return true;
    }

    function getSymbolIndex(string symbolName) internal returns (uint8) {
        for (uint8 i = 1; i <= symbolNameIndex; i++) {
            if (stringsEqual(tokens[i].symbolName, symbolName)) {
                return i;
            }
        }
        return 0;
    }

    function getSymbolIndexOrThrow(string symbolName) public returns (uint8) {
        uint8 index = getSymbolIndex(symbolName);
        require(index > 0);
        return index;
    }


    ////////////////////////////////
    // STRING COMPARISON FUNCTION //
    ////////////////////////////////
    function stringsEqual(string storage _a, string memory _b) internal returns (bool) {
        bytes storage a = bytes(_a);
        bytes memory b = bytes(_b);
        if (a.length != b.length)
            return false;
        // @todo unroll this loop
        for (uint i = 0; i < a.length; i ++)
            if (a[i] != b[i])
                return false;
        return true;
    }


    //////////////////////////////////
    // DEPOSIT AND WITHDRAWAL TOKEN //
    //////////////////////////////////
    function depositToken(string symbolName, uint amount) public {
        uint8 index = getSymbolIndexOrThrow(symbolName);
        require(tokens[index].tokenContract != address(0));

        ERC20Interface token = ERC20Interface(tokens[index].tokenContract);
        require(token.transferFrom(msg.sender, address(this), amount) == true);
        require(tokenBalanceForAddress[msg.sender][index] + amount >= tokenBalanceForAddress[msg.sender][index]);
        tokenBalanceForAddress[msg.sender][index] += amount;
        emit DepositForTokenReceived(msg.sender, symbolNameIndex, amount, now);
    }

    function withdrawToken(string symbolName, uint amount) public {
        uint8 index = getSymbolIndexOrThrow(symbolName);
        require(tokens[index].tokenContract != address(0));

        ERC20Interface token = ERC20Interface(tokens[index].tokenContract);
        require(tokenBalanceForAddress[msg.sender][index] - amount >= 0);
        require(tokenBalanceForAddress[msg.sender][index] - amount <= tokenBalanceForAddress[msg.sender][index]);

        tokenBalanceForAddress[msg.sender][index] -= amount;
        require(token.transfer(msg.sender, amount) == true);
        emit WithdrawalToken(msg.sender, symbolNameIndex, amount, now);
    }

    function getBalance(string symbolName) public constant returns (uint) {
        uint8 index = getSymbolIndexOrThrow(symbolName);
        return tokenBalanceForAddress[msg.sender][index];
    }





    /////////////////////////////
    // ORDER BOOK - BID ORDERS //
    /////////////////////////////
    function getBuyOrderBook(string symbolName) constant returns (uint[], uint[]) {
    }


    /////////////////////////////
    // ORDER BOOK - ASK ORDERS //
    /////////////////////////////
    function getSellOrderBook(string symbolName) constant returns (uint[], uint[]) {
    }



    ////////////////////////////
    // NEW ORDER - BID ORDER //
    ///////////////////////////
    function buyToken(string symbolName, uint priceInWei, uint amount) public {
        uint8 tokenIndex = getSymbolIndexOrThrow(symbolName);
        uint total_amount_ether_necessary = 0;
        uint total_amount_ether_available = 0;
        
        total_amount_ether_necessary = amount * priceInWei;
        
        //overflow check
        require(total_amount_ether_necessary >= amount);
        require(total_amount_ether_necessary >= priceInWei);
        require(balanceEthForAddress[msg.sender] >= total_amount_ether_necessary);
        require(balanceEthForAddress[msg.sender] - total_amount_ether_necessary >= 0);
        
        balanceEthForAddress[msg.sender] -= total_amount_ether_necessary;
        
        if (tokens[tokenIndex].amountSellPrices == 0 || tokens[tokenIndex].curSellPrice > priceInWei) {
            //limit order: we don't have enough offers to fulfill the amount
            //add new limit buy order
            addLimitBuyOrder(tokenIndex, priceInWei, amount, msg.sender);
            LimitBuyOrderCreated(tokenIndex, msg.sender, amount, priceInWei, tokens[tokenIndex].buyBook[priceInWei].offers_length);
        } else {
            revert();
        }
    }


    ///////////////////////////
    // BID LIMIT ORDER LOGIC //
    ///////////////////////////
    function addLimitBuyOrder(uint8 tokenIndex, uint priceInWei, uint amount, address who) internal {
        tokens[tokenIndex].buyBook[priceInWei].offers_length++;
        tokens[tokenIndex].buyBook[priceInWei].offers[tokens[tokenIndex].buyBook[priceInWei].offers_length] = Offer(amount, who);
        
        if (tokens[tokenIndex].buyBook[priceInWei].offers_length == 1) {
            tokens[tokenIndex].buyBook[priceInWei].offers_key = 1;
            //new buy order - increase the counter
            tokens[tokenIndex].amountBuyPrices++;
            
            //lowerPrice and higherPrice have to be set
            uint curBuyPrice = tokens[tokenIndex].curBuyPrice;
            
            uint lowestBuyPrice = tokens[tokenIndex].lowestBuyPrice;
            if (lowestBuyPrice == 0 || lowestBuyPrice > priceInWei) {
                if (curBuyPrice == 0) {
                    //there is no buy order yet, insert the first one
                    tokens[tokenIndex].curBuyPrice = priceInWei;
                    tokens[tokenIndex].buyBook[priceInWei].higherPrice = priceInWei;
                    tokens[tokenIndex].buyBook[priceInWei].lowerPrice = 0;
                } else {
                    //insert to the bottom of the order book
                    tokens[tokenIndex].buyBook[lowestBuyPrice].lowerPrice = priceInWei;
                    tokens[tokenIndex].buyBook[priceInWei].higherPrice = lowestBuyPrice;
                    tokens[tokenIndex].buyBook[priceInWei].lowerPrice = 0;
                }
                tokens[tokenIndex].lowestBuyPrice = priceInWei;
                
            } else if (curBuyPrice < priceInWei) {
                //the offer to buy is the highest one, we don't need to find the right spot
                tokens[tokenIndex].buyBook[curBuyPrice].higherPrice = priceInWei;
                tokens[tokenIndex].buyBook[priceInWei].higherPrice = priceInWei;
                tokens[tokenIndex].buyBook[priceInWei].lowerPrice = curBuyPrice;
                tokens[tokenIndex].curBuyPrice = priceInWei; 
            } else {
                //buy order is somewhere in the middle of order book, find the spot first..
                uint buyPrice = tokens[tokenIndex].curBuyPrice;
                bool found = false;
                while (buyPrice > 0 && !found) {
                    if (buyPrice < priceInWei 
                        && priceInWei < tokens[tokenIndex].buyBook[buyPrice].higherPrice) {
                            tokens[tokenIndex].buyBook[priceInWei].lowerPrice = buyPrice;
                            tokens[tokenIndex].buyBook[priceInWei].higherPrice = tokens[tokenIndex].buyBook[buyPrice].higherPrice;
                            
                            tokens[tokenIndex].buyBook[tokens[tokenIndex].buyBook[buyPrice].higherPrice].lowerPrice = priceInWei;
                            tokens[tokenIndex].buyBook[buyPrice].higherPrice = priceInWei;
                            found = true;
                        }
                    buyPrice = tokens[tokenIndex].buyBook[buyPrice].lowerPrice;
                }
            }
        }
    }
    
    
    
    
    
    
    
    ////////////////////////////
    // NEW ORDER - ASK ORDER //
    ///////////////////////////
    function sellToken(string symbolName, uint priceInWei, uint amount) public {
        
        uint8 tokenIndex = getSymbolIndexOrThrow(symbolName);
        require(tokenBalanceForAddress[msg.sender][tokenIndex] >= amount);
        require(tokenBalanceForAddress[msg.sender][tokenIndex] - amount >= 0);
        
        tokenBalanceForAddress[msg.sender][tokenIndex] -= amount;
        
        if (tokens[tokenIndex].amountSellPrices == 0 || tokens[tokenIndex].curBuyPrice < priceInWei) {
            addLimitSellOrder(tokenIndex, priceInWei, amount, msg.sender);
            emit LimitSellOrderCreated(tokenIndex, msg.sender, amount, priceInWei, tokens[tokenIndex].sellBook[priceInWei].offers_length);
        } else {
            revert();
        }
        
    }

    function addLimitSellOrder(uint8 tokenIndex, uint priceInWei, uint amount, address who) internal {
        
        tokens[tokenIndex].sellBook[priceInWei].offers_length ++;
        tokens[tokenIndex].sellBook[priceInWei].offers[tokens[tokenIndex].buyBook[priceInWei].offers_length] = Offer(amount, who);
    
        if (tokens[tokenIndex].sellBook[priceInWei].offers_length == 1) {
            //new sell order 
            tokens[tokenIndex].sellBook[priceInWei].offers_key = 1;
            tokens[tokenIndex].amountSellPrices++;
            
            uint curSellPrice = tokens[tokenIndex].curSellPrice;
            uint highestSellPrice = tokens[tokenIndex].highestSellPrice;
            
            if (highestSellPrice == 0 || highestSellPrice < priceInWei) {
                if (curSellPrice == 0) {
                    //there is no sell oder yet
                    tokens[tokenIndex].curSellPrice = priceInWei;
                    tokens[tokenIndex].sellBook[priceInWei].higherPrice = 0;
                    tokens[tokenIndex].sellBook[priceInWei].lowerPrice = 0; 
                } else {
                    //new order is the highest one
                    tokens[tokenIndex].sellBook[highestSellPrice].higherPrice = priceInWei;
                    tokens[tokenIndex].sellBook[priceInWei].higherPrice = 0;
                    tokens[tokenIndex].sellBook[priceInWei].lowerPrice = highestSellPrice;
                }
                
                tokens[tokenIndex].highestSellPrice = priceInWei;
            } 
            
        } else if (curSellPrice > priceInWei) {
            //this sell order is the lowest one
            tokens[tokenIndex].sellBook[curSellPrice].lowerPrice = priceInWei;
            tokens[tokenIndex].sellBook[priceInWei].higherPrice = curSellPrice;
            tokens[tokenIndex].sellBook[priceInWei].lowerPrice = 0;
            tokens[tokenIndex].curSellPrice = priceInWei;
        } else {
            //new sell order is in the middle of sell book
            uint sellPrice = tokens[tokenIndex].curSellPrice;
            bool found = false;
            while (sellPrice > 0 && !found) {
                if (tokens[tokenIndex].sellBook[sellPrice].higherPrice > priceInWei
                    && sellPrice < priceInWei) {
                        
                        tokens[tokenIndex].sellBook[priceInWei].higherPrice = tokens[tokenIndex].sellBook[sellPrice].higherPrice;
                        tokens[tokenIndex].sellBook[priceInWei].lowerPrice = sellPrice;
                        
                        tokens[tokenIndex].sellBook[sellPrice].higherPrice = priceInWei;
                        tokens[tokenIndex].sellBook[tokens[tokenIndex].sellBook[sellPrice].higherPrice].lowerPrice = priceInWei;
                        found = true;
                }
                sellPrice = tokens[tokenIndex].sellBook[sellPrice].higherPrice;
            }
        }
    }

    //////////////////////////////
    // CANCEL LIMIT ORDER LOGIC //
    //////////////////////////////
    function cancelOrder(string symbolName, bool isSellOrder, uint priceInWei, uint offerKey) {
    }



}