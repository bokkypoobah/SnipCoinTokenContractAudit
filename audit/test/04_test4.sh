#!/bin/bash
# ----------------------------------------------------------------------------------------------
# Testing the smart contract
#
# Enjoy. (c) BokkyPooBah / Bok Consulting Pty Ltd 2017. The MIT Licence.
# ----------------------------------------------------------------------------------------------

MODE=${1:-test}

GETHATTACHPOINT=`grep ^IPCFILE= settings.txt | sed "s/^.*=//"`
PASSWORD=`grep ^PASSWORD= settings.txt | sed "s/^.*=//"`

SOURCEDIR=`grep ^SOURCEDIR= settings.txt | sed "s/^.*=//"`

CROWDSALESOL=`grep ^CROWDSALESOL= settings.txt | sed "s/^.*=//"`
CROWDSALEJS=`grep ^CROWDSALEJS= settings.txt | sed "s/^.*=//"`

DEPLOYMENTDATA=`grep ^DEPLOYMENTDATA= settings.txt | sed "s/^.*=//"`

INCLUDEJS=`grep ^INCLUDEJS= settings.txt | sed "s/^.*=//"`
TEST4OUTPUT=`grep ^TEST4OUTPUT= settings.txt | sed "s/^.*=//"`
TEST4RESULTS=`grep ^TEST4RESULTS= settings.txt | sed "s/^.*=//"`

CURRENTTIME=`date +%s`
CURRENTTIMES=`date -r $CURRENTTIME -u`

BLOCKSINDAY=10

if [ "$MODE" == "dev" ]; then
  # Start time now
  STARTTIME=`echo "$CURRENTTIME" | bc`
else
  # Start time 1m 10s in the future
  STARTTIME=`echo "$CURRENTTIME+90" | bc`
fi
STARTTIME_S=`date -r $STARTTIME -u`
ENDTIME=`echo "$CURRENTTIME+60*3" | bc`
ENDTIME_S=`date -r $ENDTIME -u`

printf "MODE            = '$MODE'\n" | tee $TEST4OUTPUT
printf "GETHATTACHPOINT = '$GETHATTACHPOINT'\n" | tee -a $TEST4OUTPUT
printf "PASSWORD        = '$PASSWORD'\n" | tee -a $TEST4OUTPUT
printf "SOURCEDIR       = '$SOURCEDIR'\n" | tee -a $TEST4OUTPUT
printf "CROWDSALESOL    = '$CROWDSALESOL'\n" | tee -a $TEST4OUTPUT
printf "CROWDSALEJS     = '$CROWDSALEJS'\n" | tee -a $TEST4OUTPUT
printf "DEPLOYMENTDATA  = '$DEPLOYMENTDATA'\n" | tee -a $TEST4OUTPUT
printf "INCLUDEJS       = '$INCLUDEJS'\n" | tee -a $TEST4OUTPUT
printf "TEST4OUTPUT     = '$TEST4OUTPUT'\n" | tee -a $TEST4OUTPUT
printf "TEST4RESULTS    = '$TEST4RESULTS'\n" | tee -a $TEST4OUTPUT
printf "CURRENTTIME     = '$CURRENTTIME' '$CURRENTTIMES'\n" | tee -a $TEST4OUTPUT
printf "STARTTIME       = '$STARTTIME' '$STARTTIME_S'\n" | tee -a $TEST4OUTPUT
printf "ENDTIME         = '$ENDTIME' '$ENDTIME_S'\n" | tee -a $TEST4OUTPUT

# Make copy of SOL file and modify start and end times ---
# `cp modifiedContracts/SnipCoin.sol .`
`cp $SOURCEDIR/SnipCoin.sol .`

# --- Modify parameters ---
# `perl -pi -e "s/bool transferable/bool public transferable/" $TOKENSOL`
# `perl -pi -e "s/MULTISIG_WALLET_ADDRESS \= 0xc79ab28c5c03f1e7fbef056167364e6782f9ff4f;/MULTISIG_WALLET_ADDRESS \= 0xa22AB8A9D641CE77e06D98b7D7065d324D3d6976;/" GimliCrowdsale.sol`
# `perl -pi -e "s/START_DATE = 1505736000;.*$/START_DATE \= $STARTTIME; \/\/ $STARTTIME_S/" GimliCrowdsale.sol`
# `perl -pi -e "s/END_DATE = 1508500800;.*$/END_DATE \= $ENDTIME; \/\/ $ENDTIME_S/" GimliCrowdsale.sol`
# `perl -pi -e "s/VESTING_1_DATE = 1537272000;.*$/VESTING_1_DATE \= $VESTING1TIME; \/\/ $VESTING1TIME_S/" GimliCrowdsale.sol`
# `perl -pi -e "s/VESTING_2_DATE = 1568808000;.*$/VESTING_2_DATE \= $VESTING2TIME; \/\/ $VESTING2TIME_S/" GimliCrowdsale.sol`

DIFFS1=`diff $SOURCEDIR/$CROWDSALESOL $CROWDSALESOL`
echo "--- Differences $SOURCEDIR/$CROWDSALESOL $CROWDSALESOL ---" | tee -a $TEST4OUTPUT
echo "$DIFFS1" | tee -a $TEST4OUTPUT

echo "var tokenOutput=`solc --optimize --combined-json abi,bin,interface $CROWDSALESOL`;" > $CROWDSALEJS

geth --verbosity 3 attach $GETHATTACHPOINT << EOF | tee -a $TEST4OUTPUT
loadScript("$CROWDSALEJS");
loadScript("functions.js");

var tokenAbi = JSON.parse(tokenOutput.contracts["$CROWDSALESOL:SnipCoin"].abi);
var tokenBin = "0x" + tokenOutput.contracts["$CROWDSALESOL:SnipCoin"].bin;

// console.log("DATA: tokenAbi=" + JSON.stringify(tokenAbi));
// console.log("DATA: tokenBin=" + JSON.stringify(tokenBin));

unlockAccounts("$PASSWORD");
printBalances();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var tokenMessage = "Deploy Crowdsale/Token Contract";
// -----------------------------------------------------------------------------
console.log("RESULT: " + tokenMessage);
var tokenContract = web3.eth.contract(tokenAbi);
// console.log(JSON.stringify(tokenContract));
var tokenTx = null;
var tokenAddress = null;

var token = tokenContract.new({from: contractOwnerAccount, data: tokenBin, gas: 6000000},
  function(e, contract) {
    if (!e) {
      if (!contract.address) {
        tokenTx = contract.transactionHash;
      } else {
        tokenAddress = contract.address;
        addAccount(tokenAddress, "Token '" + token.symbol() + "' '" + token.name() + "'");
        addTokenContractAddressAndAbi(tokenAddress, tokenAbi);
        console.log("DATA: tokenAddress=" + tokenAddress);
      }
    }
  }
);

while (txpool.status.pending > 0) {
}

printTxData("tokenAddress=" + tokenAddress, tokenTx);
printBalances();
failIfGasEqualsGasUsed(tokenTx, tokenMessage);
printTokenContractDetails();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var whitelistMessage = "Whitelist";
// -----------------------------------------------------------------------------
console.log("RESULT: " + whitelistMessage);
var whitelist1Tx = token.addAddressToUncappedAddresses(account3, {from: contractOwnerAccount, gas: 400000});
var whitelist2Tx = token.addAddressToCappedAddresses(account4, {from: contractOwnerAccount, gas: 400000});
while (txpool.status.pending > 0) {
}
printTxData("whitelist1Tx", whitelist1Tx);
printTxData("whitelist2Tx", whitelist2Tx);
printBalances();
failIfGasEqualsGasUsed(whitelist1Tx, whitelistMessage + " - ac3 Whitelist Uncapped");
failIfGasEqualsGasUsed(whitelist2Tx, whitelistMessage + " - ac4 Whitelist Capped");
printTokenContractDetails();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var openSaleMessage = "Open Sale";
// -----------------------------------------------------------------------------
console.log("RESULT: " + openSaleMessage);
var openSaleTx = token.openOrCloseSale(true, {from: contractOwnerAccount, gas: 400000});
while (txpool.status.pending > 0) {
}
printTxData("openSaleTx", openSaleTx);
printBalances();
failIfGasEqualsGasUsed(openSaleTx, openSaleMessage);
printTokenContractDetails();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var sendContribution4Message = "Send Contribution After Start - Below Cap";
// -----------------------------------------------------------------------------
console.log("RESULT: " + sendContribution4Message);
var sendContribution4_aTx = eth.sendTransaction({from: account3, to: tokenAddress, gas: 400000, value: web3.toWei("10", "ether")});
var sendContribution4_bTx = eth.sendTransaction({from: account4, to: tokenAddress, gas: 400000, value: web3.toWei("10", "ether")});
while (txpool.status.pending > 0) {
}
printTxData("sendContribution4_aTx", sendContribution4_aTx);
printTxData("sendContribution4_bTx", sendContribution4_bTx);
printBalances();
failIfGasEqualsGasUsed(sendContribution4_aTx, sendContribution4Message + " - ac3 10 ETH - 3,000,000");
failIfGasEqualsGasUsed(sendContribution4_bTx, sendContribution4Message + " - ac4 10 ETH - 3,000,000");
printTokenContractDetails();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var closeSaleMessage = "Close Sale";
// -----------------------------------------------------------------------------
console.log("RESULT: " + closeSaleMessage);
var closeSaleTx = token.openOrCloseSale(false, {from: contractOwnerAccount, gas: 400000});
while (txpool.status.pending > 0) {
}
printTxData("closeSaleTx", closeSaleTx);
printBalances();
failIfGasEqualsGasUsed(closeSaleTx, closeSaleMessage);
printTokenContractDetails();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var allowTransfersMessage = "Enable Transfers";
// -----------------------------------------------------------------------------
console.log("RESULT: " + allowTransfersMessage);
var allowTransfersTx = token.allowTransfers({from: contractOwnerAccount, gas: 400000});
while (txpool.status.pending > 0) {
}
printTxData("allowTransfersTx", allowTransfersTx);
printBalances();
failIfGasEqualsGasUsed(allowTransfersTx, allowTransfersMessage);
printTokenContractDetails();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var moveTokenMessage = "Move 0 Tokens After Transfers Allowed";
// -----------------------------------------------------------------------------
console.log("RESULT: " + moveTokenMessage);
var moveToken1Tx = token.transfer(account5, "0", {from: account3, gas: 100000});
var moveToken3Tx = token.transferFrom(account4, account7, "0", {from: account6, gas: 100000});
while (txpool.status.pending > 0) {
}
printTxData("moveToken1Tx", moveToken1Tx);
printTxData("moveToken3Tx", moveToken3Tx);
printBalances();
failIfGasEqualsGasUsed(moveToken1Tx, moveTokenMessage + " - transfer 0 SNIP ac3 -> ac5. SHOULD not throw");
failIfGasEqualsGasUsed(moveToken3Tx, moveTokenMessage + " - transferFrom 0 SNIP ac4 -> ac7 by ac6. SHOULD not throw");
printTokenContractDetails();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var moveTokenMessage = "Move More Tokens Than Owned After Transfers Allowed";
// -----------------------------------------------------------------------------
console.log("RESULT: " + moveTokenMessage);
var moveToken1Tx = token.transfer(account5, "3000000000000000000000001", {from: account3, gas: 100000});
var moveToken2Tx = token.approve(account6,  "3000000000000000000000001", {from: account4, gas: 100000});
while (txpool.status.pending > 0) {
}
var moveToken3Tx = token.transferFrom(account4, account7, "3000000000000000000000001", {from: account6, gas: 100000});
while (txpool.status.pending > 0) {
}
printTxData("moveToken1Tx", moveToken1Tx);
printTxData("moveToken2Tx", moveToken2Tx);
printTxData("moveToken3Tx", moveToken3Tx);
printBalances();
passIfGasEqualsGasUsed(moveToken1Tx, moveTokenMessage + " - transfer 300K+1e-18 SNIP ac3 -> ac5. SHOULD throw");
failIfGasEqualsGasUsed(moveToken2Tx, moveTokenMessage + " - approve 300K+1e-18 SNIP ac4 -> ac6");
passIfGasEqualsGasUsed(moveToken3Tx, moveTokenMessage + " - transferFrom 300K+1e-18 SNIP ac4 -> ac7 by ac6. SHOULD throw");
printTokenContractDetails();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var approveTokenMessage = "Change Approval Without Setting To 0";
// -----------------------------------------------------------------------------
console.log("RESULT: " + approveTokenMessage);
var approveToken2Tx = token.approve(account6,  "3000000000000000000000002", {from: account4, gas: 100000});
while (txpool.status.pending > 0) {
}
printTxData("approveToken2Tx", approveToken2Tx);
printBalances();
passIfGasEqualsGasUsed(approveToken2Tx, approveTokenMessage + " - approve 300K+2e-18 SNIP ac4 -> ac6. SHOULD throw");
printTokenContractDetails();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var approveTokenMessage = "Change Approval By Setting To 0 In Between";
// -----------------------------------------------------------------------------
console.log("RESULT: " + approveTokenMessage);
var approveToken2Tx = token.approve(account6,  "0", {from: account4, gas: 100000});
while (txpool.status.pending > 0) {
}
var approveToken3Tx = token.approve(account6,  "3000000000000000000000002", {from: account4, gas: 100000});
while (txpool.status.pending > 0) {
}
printTxData("approveToken2Tx", approveToken2Tx);
printTxData("approveToken3Tx", approveToken3Tx);
printBalances();
failIfGasEqualsGasUsed(approveToken2Tx, approveTokenMessage + " - approve 0 SNIP ac4 -> ac6");
failIfGasEqualsGasUsed(approveToken3Tx, approveTokenMessage + " - approve 300K+2e-18 SNIP ac4 -> ac6");
printTokenContractDetails();
console.log("RESULT: ");


EOF
grep "DATA: " $TEST4OUTPUT | sed "s/DATA: //" > $DEPLOYMENTDATA
cat $DEPLOYMENTDATA
grep "RESULT: " $TEST4OUTPUT | sed "s/RESULT: //" > $TEST4RESULTS
cat $TEST4RESULTS
