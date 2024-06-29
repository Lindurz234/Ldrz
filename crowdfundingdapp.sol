// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract Crowdfunding {
    mapping(address=>uint) public contributors;
    address public manager;
    uint public  minimum;
    uint public  deadline;
    uint public target;
    uint public raised;
    uint public numofcontributors;


    struct Request{
        string description;
        address payable recepient;
        uint value;
        bool completed;
        uint noofVoters;
        mapping (address=>bool) voters;
    }

    mapping (uint=> Request) requests;
    uint public numofrequests;


    constructor(uint _target, uint _deadline){
        target=_target;
        deadline=block.timestamp+_deadline;
        minimum=100 wei;
        manager=msg.sender;
    }


    modifier onlyManager(){
        require(msg.sender==manager, "You are not me");
        _;
    }

    function createRequest(string calldata _description, address payable _recipient, uint _value) public {
        Request storage newRequest=requests[numofrequests];
        numofrequests++;
        newRequest.description=_description;
        newRequest.recepient=_recipient;
        newRequest.value=_value;
        newRequest.completed=false;
        newRequest.noofVoters=0;
    }

    function contribution() public payable {
        require(block.timestamp<deadline,"Deadline has passed");
        require(msg.value>=minimum,"Minimum required is 100 wei");

        if (contributors[msg.sender]==0){
            numofcontributors++;
        }
        contributors[msg.sender]=msg.value;
        raised+=msg.value;
    }

    function getBalance() public  view  returns(uint){
        return address(this).balance;
    }

    function refund() public {
        require(block.timestamp>deadline && raised<target, "You are not eligible for refund");
        require(contributors[msg.sender]>0, "You are not a contributor");
        payable(msg.sender).transfer(contributors[msg.sender]);
        contributors[msg.sender]=0;
    }

    function voteRequest(uint _request) public {
        require(contributors[msg.sender]>0, "You are not a contributor");
        Request storage thisRequest=requests[_request];
        require(thisRequest.voters[msg.sender]==false, "You have already voted");
        thisRequest.voters[msg.sender]=true;
        thisRequest.noofVoters++;
    }

    function makePayment(uint _request) public onlyManager{
        require(raised>=target, "Target is not Reached");
        Request storage thisRequest=requests[_request];
        require(thisRequest.completed==false, "the request has been completed");
        require(thisRequest.noofVoters>numofcontributors/2,"Majority does not support that");
        thisRequest.recepient.transfer(thisRequest.value);
        thisRequest.completed=true;
    }
}
