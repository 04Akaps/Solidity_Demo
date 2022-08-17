const Web3 = require("Web3");

const web3 = new Web3("URL");

const contract = new web3.eth.Contract(abi, ca).methods;

const data = contract.함수명("인자").encodeABI();
