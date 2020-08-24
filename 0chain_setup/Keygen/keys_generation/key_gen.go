package main

import (
	"encoding/hex"
	"flag"
	"fmt"
	"os"

	"0chain.net/core/encryption"
)

func main() {
	clientSigScheme := flag.String("signature_scheme", "", "ed25519 or bls0chain")
	keysFileName := flag.String("keys_file_name", "keys.txt", "keys_file_name")
	path := flag.String("keys_file_path", "keys.txt", "keys_file_path")
	generateKeys := flag.Bool("generate_keys", false, "generate_keys")
	printPrivate := flag.Bool("print_private", false, "print_private")
	flag.Parse()
	keysFile := fmt.Sprintf("%s/%s", *path, *keysFileName)
	var sigScheme = encryption.GetSignatureScheme(*clientSigScheme)
	if *generateKeys {
		err := sigScheme.GenerateKeys()
		if err != nil {
			panic(err)
		}
		if len(keysFile) > 0 {
			writer, err := os.OpenFile(keysFile, os.O_RDWR|os.O_CREATE, 0644)
			if err != nil {
				panic(err)
			}
			defer writer.Close()
			sigScheme.WriteKeys(writer)
		} else {
			sigScheme.WriteKeys(os.Stdout)
		}
	}
	if len(keysFile) == 0 {
		return
	}
	reader, err := os.Open(keysFile)
	if err != nil {
		panic(err)
	}
	_, publicKey, privateKey := encryption.ReadKeys(reader)
	pubKeyBytes, err := hex.DecodeString(publicKey)
	if err != nil {
		panic(err)
	}
	clientID := encryption.Hash(pubKeyBytes)
	reader.Close()
	fmt.Printf("- id: %v\n", clientID)
	fmt.Printf("  public_key: %v\n", publicKey)
	if *printPrivate {
		fmt.Printf("  private_key: %v\n", privateKey)
	}
}
