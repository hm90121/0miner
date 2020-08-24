package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/0chain/gosdk/core/zcncrypto"
)

func main() {
	clientSigScheme := flag.String("signature_scheme", "bls0chain", "ed25519 or bls0chain")
	keysFile := flag.String("keys_file", "keys.json", "keys_file")
	flag.Parse()
	sigScheme := zcncrypto.NewSignatureScheme(*clientSigScheme)
	wallet, err := sigScheme.GenerateKeys()
	if err != nil {
		panic(err)
	}

	walletString, err := wallet.Marshal()
	if err != nil {
		panic(err)
	}
	if len(*keysFile) > 0 {
		writer, err := os.OpenFile(*keysFile, os.O_RDWR|os.O_CREATE, 0644)
		if err != nil {
			panic(err)
		}
		defer writer.Close()
		fmt.Fprintf(writer, walletString)
	} else {
		fmt.Println(walletString)
	}

	fmt.Println(wallet.ClientID)
}
