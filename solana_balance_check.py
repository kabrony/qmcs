#!/usr/bin/env python3

import os
import sys
import logging
from dotenv import load_dotenv
from solana.publickey import PublicKey
from solana.rpc.api import Client as SolanaClient

logging.basicConfig(level=logging.INFO)

def main():
    load_dotenv()  # Reads .env in the same folder
    rpc_url = os.getenv("SOLANA_RPC_URL")
    public_key_str = os.getenv("SOLANA_PUBLIC_KEY")

    if not rpc_url or not public_key_str:
        logging.error("Missing SOLANA_RPC_URL or SOLANA_PUBLIC_KEY in environment.")
        sys.exit(1)

    client = SolanaClient(rpc_url)
    try:
        pubkey = PublicKey(public_key_str)  # Convert string to PublicKey
        balance_resp = client.get_balance(pubkey)
        # Newer solana-py returns a dict like {"jsonrpc":..., "result": {...}, "id":...}
        # So extract the numeric value from "result"
        lamports = balance_resp["result"]["value"]
        logging.info(f"Balance for {public_key_str}: {lamports} lamports")
    except Exception as e:
        logging.error(f"Error fetching Solana balance: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
