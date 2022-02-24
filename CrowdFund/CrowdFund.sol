// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./IERC20.sol";

interface CrowdFuncEvent {
    event Launch(
        uint256 id,
        address indexed creator,
        uint256 goal,
        uint32 startAt,
        uint32 endAt
    );
    event Cancel(uint256 id);
    event Pledge(uint256 indexed id, address indexed caller, uint256 amount);
    event UnPledge(uint256 indexed id, address indexed caller, uint256 amount);
    event Claim(uint256 id);
    event Refund(uint256 indexed id, address indexed caller, uint256 amount);
}

contract CrowdFund is CrowdFuncEvent {
    struct Campaign {
        // 펀딩을 받을 하나의 구조체 입니다.
        address creator; // 주체자 입니다.
        uint256 goal; // 목표 금액
        uint256 pledged; // 예치된 금액
        uint32 startAt; // 시작 시간
        uint32 endAt; // 끝날 시간
        bool claimed; // 펀딩 종료 여부
    }

    IERC20 public token;

    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => uint256)) public pledgedAmount;

    uint256 public count;

    constructor(address _token) {
        token = IERC20(_token);
    }

    function launch(
        uint256 _goal,
        uint32 _startAt,
        uint32 _endAt
    ) external {
        // 단순하게 하나의 펀딩을 만드는 함수 입니다.
        require(_startAt >= block.timestamp, "start at < now");
        require(_endAt >= _startAt, " end at < start at");
        require(_endAt <= block.timestamp + 90 days, "end at > max duration");

        count++;
        campaigns[count] = Campaign({
            creator: msg.sender,
            goal: _goal,
            pledged: 0,
            startAt: _startAt,
            endAt: _endAt,
            claimed: false
        });

        emit Launch(count, msg.sender, _goal, _startAt, _endAt);
    }

    function cancel(uint256 _id) external {
        // 펀딩을 취소하는 함수 입니다.
        Campaign memory campaign = campaigns[_id];
        require(msg.sender == campaign.creator, "not creater!!");
        require(block.timestamp < campaign.startAt, "started!!");
        delete campaigns[_id];

        emit Cancel(_id);
    }

    function pledge(uint256 _id, uint256 _amount) external {
        // 펀딩에 금액을 예치하는 함수 입니다.
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp >= campaign.startAt, "Not started!");
        require(block.timestamp <= campaign.endAt, "ended");

        campaign.pledged += _amount;
        pledgedAmount[_id][msg.sender] += _amount;
        // 보안성을 고려하여 컨트랙트에 토큰을 보관 합니다.
        token.transferFrom(msg.sender, address(this), _amount);

        emit Pledge(_id, msg.sender, _amount);
    }

    function unpledge(uint256 _id, uint256 _amount) external {
        // 예치한 금액을 다시 뺴는 함수 입니다.
        // 이 부분은 아직 부족한 부분이 많은 것 같습니다;;
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp <= campaign.endAt, "ended");
        require(pledgedAmount[_id][msg.sender] >= _amount, "Not enough money");

        campaign.pledged -= _amount;
        pledgedAmount[_id][msg.sender] -= _amount;

        token.transfer(msg.sender, _amount);
        emit UnPledge(_id, msg.sender, _amount);
    }

    function claim(uint256 _id) external {
        // 펀딩이 끝나고 돈을 회수하는 함수 입니다.
        Campaign storage campaign = campaigns[_id];
        require(msg.sender == campaign.creator, "Not Creator");
        require(block.timestamp > campaign.endAt, "not ended");
        require(campaign.pledged >= campaign.goal, "pledged <goal");
        require(!campaign.claimed, "claimed");

        campaign.claimed = true;

        token.transfer(msg.sender, campaign.pledged);
        emit Claim(_id);
    }

    function refund(uint256 _id) external {
        // 예치한 금액을 모두 뺴는 함수 입니다.
        Campaign storage campaign = campaigns[_id];
        require(campaign.pledged < campaign.goal, "pledged <goal");
        require(block.timestamp > campaign.endAt, "Not Ended");

        uint256 bal = pledgedAmount[_id][msg.sender];
        pledgedAmount[_id][msg.sender] = 0;

        token.transfer(msg.sender, bal);

        emit Refund(_id, msg.sender, bal);
    }
}
