package main

import (
	"flag"
	"os"

	"github.com/0chain/gosdk/core/zcncrypto"
)

func main() {
	clientSigScheme := flag.String("signature_scheme", "bls0chain", "ed25519 or bls0chain")
	publicKey := flag.String("public_key", "", "public_key")
	privateKey := flag.String("private_key", "", "private_key")
	hostURL := flag.String("host_url", "", "host_url")
	n2nIP := flag.String("n2n_ip", "", "n2n_ip")
	port := flag.String("port", "", "port")
	keysFile := flag.String("keys_file", "keys.txt", "keys_file")
	flag.Parse()

	if len(*hostURL) == 0 ||
		len(*port) == 0 {
		panic("Invalid input params")
	}

	if len(*publicKey) == 0 || len(*privateKey) == 0 {
		sigScheme := zcncrypto.NewSignatureScheme(*clientSigScheme)
		wallet, err := sigScheme.GenerateKeys()
		if err != nil {
			panic(err)
		}
		privateKey = &wallet.Keys[0].PrivateKey
		publicKey = &wallet.Keys[0].PublicKey
	}

	file, err := os.Create(*keysFile)
	if err != nil {
		panic(err)
	}
	defer file.Close()
	file.WriteString(*publicKey + "\n")
	file.WriteString(*privateKey + "\n")
	file.WriteString(*hostURL + "\n")
	if len(*n2nIP) != 0 {
		file.WriteString(*n2nIP + "\n")
	}
	file.WriteString(*port)
}
