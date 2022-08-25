pragma solidity 0.5.17;

import "ownable"

contract YieldFarm is Ownable { 
    struct Yield {
        string site;
        uint256 ratio;
    }

    Yield[] private siteArray;

    mapping(uint256 => uint256) nftstaked;

    mapping(bytes32 => uint256) yieldMap;
    mapping(bytes32 => uint256) yieldBalanceMap;

    mapping(bytes32 => uint256[]) yieldParticipant;
    mapping(address => uint256) rewardWallet;

    uint256 referenceTime;
    uint256 nextReferenceTime;

    uint256 distributeRatio;
    uint256 beforeAmount;
    uint256 public constant DECIMAL1e18 = 1e18;

    // uint256 constant TERM = 7 days ;
    uint256 constant TERM = 1 days / 24;

     function addYield(string[] calldata _yieldSite, uint256[] calldata _ratio)
        external
        onlyOwner
    {
        require(
            _yieldSite.length == _ratio.length,
            "Error : length is Not match"
        );

        uint256 length = _yieldSite.length;
        bytes32 checkByte = keccak256(bytes(""));

        for (uint256 i = 0; i < length; i++) {
            bytes32 site = keccak256(bytes(_yieldSite[i]));
            uint256 ratio = _ratio[i];

            require(site != checkByte, "Error : _site is  Blank");
            require(ratio != 0, "Error : ration is Zero");
            require(yieldMap[site] == 0, "Error : already Existed Site");

            yieldMap[site] = ratio;
            siteArray.push(Yield(_yieldSite[i], ratio));
        }

        if (referenceTime == 0) {
            uint256 currentTime = _currentTime();
            referenceTime = currentTime;
            nextReferenceTime = currentTime.add(TERM);
        }

        distributeRatio = 7;
    }

    function deleteYield(string calldata _yieldSite) external onlyStakingOwner {
        bytes32 site = keccak256(bytes(_yieldSite));
        require(yieldMap[site] != 0, "Error : Not Existed Yield");

        delete yieldMap[site];
        delete yieldBalanceMap[site];

        for (uint256 i = 0; i < siteArray.length; i++) {
            bytes32 existedSite = keccak256(bytes(siteArray[i].site));

            if (existedSite == site) {
                delete siteArray[i];

                if (siteArray.length == 1 || i == siteArray.length - 1) {
                    siteArray.pop();
                } else {
                    Yield memory tempYield = siteArray[siteArray.length - 1];
                    siteArray[i] = tempYield;
                    siteArray.pop();
                }

                break;
            }
        }
    }

    function reviseYieldRatio(string calldata _yieldSite, uint256 _ratio)
        external
        onlyStakingOwner
    {
        bytes32 site = keccak256(bytes(_yieldSite));
        require(yieldMap[site] != 0, "Error : Not Existed Site");
        yieldMap[site] = _ratio;
    }

    function reviseDistributeRatio(uint256 _distributeRatio)
        external
        onlyStakingOwner
    {
        require(
            distributeRatio != _distributeRatio,
            "Error : Same DistributeRatio"
        );
        require(_distributeRatio != 0, "Error : _distributeRatio is Zero");

        distributeRatio = _distributeRatio;
    }

    function withDrawAll() external onlyOwner {
        uint256 totalPoolReward;
        uint256 zmtValue = zmt.balanceOf(address(this));

        for (uint256 i = 0; i < siteArray.length; i++) {
            bytes32 yieldSite = keccak256(bytes(siteArray[i].site));
            uint256 willBeDistributedAmount = yieldBalanceMap[yieldSite];

            totalPoolReward = totalPoolReward.add(willBeDistributedAmount);
        }

        uint256 willWithDrawedMgoldAmount = mgold.balanceOf(address(this)).sub(
            totalPoolReward
        );

        mgold.transfer(msg.sender, willWithDrawedMgoldAmount);
        zmt.transfer(msg.sender, zmtValue);
        msg.sender.transfer(address(this).balance);
    }

    function claimReward(uint256 _amount)
        external
        checkFunctionLock
        stakingNotPaused
    {
        require(rewardWallet[msg.sender] != 0, "Error Reward is Zero Amount:");
        require(
            rewardWallet[msg.sender] >= _amount,
            "Error : _amount is Over the Balance"
        );

        mgold.transfer(msg.sender, _amount);
        beforeAmount = beforeAmount.sub(_amount);
        rewardWallet[msg.sender] = rewardWallet[msg.sender].sub(_amount);
    }

    function rewardDistribute() public {
        uint256 currentTime = _currentTime();

        if (currentTime < nextReferenceTime) {
            return;
        }

        uint256 terms = currentTime.sub(referenceTime).div(TERM);

        require(terms >= 1, "Error : Term Can't Be Zero");

        uint256 maxNumTerms = 1;
        bool isOddNumber;

        if ((terms.div(2)).mul(2) < terms && terms >= 39) {
            isOddNumber = true;
        }

        while(terms >= 39){
            terms = terms.div(2);
            maxNumTerms++;
        }

        uint256 tempNumerator = (SafeMath.sub(100, distributeRatio))**terms; 
        uint256 tempDenominator = 100**terms; 

        while (tempNumerator >= DECIMAL1e18) {
            tempDenominator = tempDenominator.div(1e16);
            tempNumerator = tempNumerator.div(1e16);
        }

        uint256 numerator = (tempNumerator**maxNumTerms).mul(
            isOddNumber ? (SafeMath.sub(100, distributeRatio)) : 1
        );

        uint256 denominator = (tempDenominator**maxNumTerms).mul(
            isOddNumber ? 100 : 1
        );

        while (numerator >= DECIMAL1e18) {
            denominator = denominator.div(1e16);
            numerator = numerator.div(1e16);
        }

        for (uint256 i = 0; i < siteArray.length; i++) {
            bytes32 site = keccak256(bytes(siteArray[i].site));
            uint256 accumulatedCompensation = yieldBalanceMap[site];

            if (accumulatedCompensation > 100) {
                uint256 totalReward = accumulatedCompensation.sub(
                    accumulatedCompensation.div(denominator).mul(numerator)
                );

                uint256[] memory tokenListInPool = yieldParticipant[site];

                if (tokenListInPool.length != 0) {
                    uint256 compensationPerToken = totalReward.div(
                        tokenListInPool.length
                    );

                    for (uint256 j = 0; j < tokenListInPool.length; j++) {
                        uint256 tokenId = tokenListInPool[j];

                        address owner = mthzVault[tokenId].owner;

                        rewardWallet[owner] = rewardWallet[owner].add(
                            compensationPerToken
                        );

                        yieldBalanceMap[site] = yieldBalanceMap[site].sub(
                            compensationPerToken
                        );
                    }
                }
            }
        }

        referenceTime = referenceTime.add(TERM.mul(terms));
        nextReferenceTime = referenceTime.add(TERM);
    }

    function distributeYield() public {
        uint256 currentTime = _currentTime();
        uint256 totalMgold = token.balanceOf(address(this));

        if (totalMgold == 0) {
            return;
        }

        if (currentTime >= nextReferenceTime) {
            rewardDistribute();
        }

        uint256 distributedAmount = (
            beforeAmount == 0 ? totalMgold : totalMgold.sub(beforeAmount)
        );
         
        uint256 totalSitePower = _getSiteTotalRatio();

        for (uint256 i = 0; i < siteArray.length; i++) {
            bytes32 site = keccak256(bytes(siteArray[i].site));
            uint256 ratio = siteArray[i].ratio;

            uint256 totalAmount = distributedAmount.div(totalSitePower).mul(
                ratio
            );

            yieldBalanceMap[site] = yieldBalanceMap[site].add(totalAmount);
        }

        beforeAmount = beforeAmount.add(distributedAmount);
    }

}