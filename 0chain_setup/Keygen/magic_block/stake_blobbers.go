package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"os"
	"sync"

	"github.com/0chain/gosdk/core/common"
	"github.com/0chain/gosdk/core/zcncrypto"
	"github.com/0chain/gosdk/zboxcore/sdk"
	"github.com/0chain/gosdk/zcncore"
)

const SignatureSchema = "bls0chain"

func main() {
	walletFile := flag.String("wallet_file", "keys.json", "wallet_file")
	blockWorker := flag.String("block_worker", "", "block_worker")
	tokens := flag.Float64("tokens", 1, "tokens")
	totalBlobbers := flag.Int("total_blobbers", 4, "total_blobbers")
	flag.Parse()

	f, err := os.Open(*walletFile)
	if err != nil {
		panic(err)
	}

	walletBytes, err := ioutil.ReadAll(f)
	if err != nil {
		panic(err)
	}

	walletString := string(walletBytes)

	InitZCN(*blockWorker, walletString)

	err = sdk.InitStorageSDK(walletString, *blockWorker, "", SignatureSchema, nil)
	if err != nil {
		panic(err)
	}

	balance, err := CheckBalance()
	if err != nil {
		panic(err)
	}

	fmt.Println("Wallet current balance : ", balance)

	for balance < (*tokens)*float64(*totalBlobbers) {
		err = CallFaucet()
		if err != nil {
			fmt.Println("Error calling faucet : ", err.Error())
			continue
		}
		fmt.Println("Faucet called successfully !!!")

		balance, err = CheckBalance()
		if err != nil {
			fmt.Println("Error calling checkBalance : ", err.Error())
			continue
		}
		fmt.Println("Wallet current balance : ", balance)
	}
	fmt.Println("Enough balance to stake, Moving to staking now...")

	blobbers, err := sdk.GetBlobbers()
	if err != nil {
		panic(err)
	}
	fmt.Println("Total blobbers found on network : ", len(blobbers))

	if len(blobbers) != *totalBlobbers {
		panic("Not all blobbers registered")
	}

	done := 0
	for done < len(blobbers) {
		blobber := blobbers[done]
		fmt.Println("Getting stake pool info for :", blobber.BaseURL)
		info, err := sdk.GetStakePoolInfo(string(blobber.ID))
		if err != nil {
			fmt.Println("Get stake pool info failed for :", blobber.BaseURL, " Retrying...")
			continue
		}

		if zcncore.ConvertToToken(int64(info.Balance)) < *tokens {
			poolID, err := sdk.StakePoolLock(string(blobber.ID), zcncore.ConvertToValue(*tokens), 0)
			if err != nil {
				fmt.Println("Failed to stake for :", blobber.BaseURL, " Retrying...")
				continue
			}
			fmt.Println("Successfully staked for blobber ", blobber.BaseURL, " with pool ID ", poolID)
			done++
		} else {
			fmt.Println("Blobber already have stake pool, URL : ", blobber.BaseURL, " poolID : ", info.ID, " amount : ", info.Balance)
			done++
		}
	}
}

const (
	ZCNStatusSuccess int = 0
	ZCNStatusError   int = 1
)

type ZCNStatus struct {
	walletString string
	wg           *sync.WaitGroup
	success      bool
	errMsg       string
	balance      int64
	wallets      []string
	clientID     string
}

func (zcn *ZCNStatus) OnBalanceAvailable(status int, value int64, info string) {
	defer zcn.wg.Done()
	if status == zcncore.StatusSuccess {
		zcn.success = true
	} else {
		zcn.success = false
	}
	zcn.balance = value
}

func (zcn *ZCNStatus) OnTransactionComplete(t *zcncore.Transaction, status int) {
	defer zcn.wg.Done()
	if status == zcncore.StatusSuccess {
		zcn.success = true
	} else {
		zcn.success = false
	}
}

func (zcn *ZCNStatus) OnVerifyComplete(t *zcncore.Transaction, status int) {
	defer zcn.wg.Done()
	if status == zcncore.StatusSuccess {
		zcn.success = true
	} else {
		zcn.success = false
	}
}

func (zcn *ZCNStatus) OnWalletCreateComplete(status int, wallet string, err string) {
	defer zcn.wg.Done()
	if status == ZCNStatusError {
		zcn.success = false
		zcn.errMsg = err
		zcn.walletString = ""
		return
	}
	zcn.success = true
	zcn.errMsg = ""
	zcn.walletString = wallet
	return
}

func (zcn *ZCNStatus) OnAuthComplete(t *zcncore.Transaction, status int) {}

func InitZCN(blockWorker string, walletString string) {
	// No logs from SDK
	zcncore.SetLogLevel(0)
	err := zcncore.InitZCNSDK(blockWorker, SignatureSchema)
	if err != nil {
		panic("Error: Unable to init SDK")
	}

	var wallet zcncrypto.Wallet
	json.Unmarshal([]byte(walletString), &wallet)

	wg := &sync.WaitGroup{}
	statusBar := &ZCNStatus{wg: wg}
	wg.Add(1)
	err = zcncore.RegisterToMiners(&wallet, statusBar)
	if err != nil {
		panic("Error trying to register wallet to miners")
	}
	wg.Wait()
	if statusBar.success {
		err := zcncore.SetWalletInfo(walletString, false)
		if err != nil {
			panic("Error in setting wallet info")
		}
	} else {
		panic("Wallet registration failed")
	}
}

func CheckBalance() (float64, error) {
	wg := &sync.WaitGroup{}
	statusBar := &ZCNStatus{wg: wg}
	wg.Add(1)
	err := zcncore.GetBalance(statusBar)
	if err != nil {
		return 0, common.NewError("check_balance_failed", "Call to GetBalance failed with err: "+err.Error())
	}
	wg.Wait()
	if statusBar.success == false {
		return 0, nil
	}
	return zcncore.ConvertToToken(statusBar.balance), nil
}

func CallFaucet() error {
	wg := &sync.WaitGroup{}
	statusBar := &ZCNStatus{wg: wg}
	txn, err := zcncore.NewTransaction(statusBar, 0)
	if err != nil {
		return common.NewError("call_faucet_failed", "Failed to create new transaction with err: "+err.Error())
	}
	wg.Add(1)
	err = txn.ExecuteSmartContract(zcncore.FaucetSmartContractAddress, "pour", "Blobber Registration", zcncore.ConvertToValue(0))
	if err != nil {
		return common.NewError("call_faucet_failed", "Failed to execute smart contract with err: "+err.Error())
	}
	wg.Wait()
	if statusBar.success == false {
		return common.NewError("call_faucet_failed", "Failed to execute smart contract with statusBar success failed")
	}
	statusBar.success = false
	wg.Add(1)
	err = txn.Verify()
	if err != nil {
		return common.NewError("call_faucet_failed", "Failed to verify smart contract with err: "+err.Error())
	}
	wg.Wait()
	if statusBar.success == false {
		return common.NewError("call_faucet_failed", "Failed to verify smart contract with statusBar success failed")
	}
	return nil
}
