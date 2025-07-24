import { Principal } from "@dfinity/principal";
import { resolve } from "node:path";

export const GOVERNANCE_CANISTER_ID = Principal.fromText(
  "rrkah-fqaaa-aaaaa-aaaaq-cai"
);

export const ICP_LEDGER_CANISTER_ID = Principal.fromText(
  "ryjl3-tyaaa-aaaaa-aaaba-cai"
);

export const NNS_ROOT_CANISTER_ID = Principal.fromText(
  "r7inp-6aaaa-aaaaa-aaabq-cai"
);

export const CMC_CANISTER_ID = Principal.fromText(
  "rkp4c-7iaaa-aaaaa-aaaca-cai"
);

// These are test canister IDs for development purposes:

export const NTC_LEDGER_CANISTER_ID = Principal.fromText(
  "txyno-ch777-77776-aaaaq-cai"
);

export const NTC_MINTER_CANISTER_ID = Principal.fromText(
  "vjwku-z7777-77776-aaaua-cai"
);

export const NTC_TEST_PYLON_CANISTER_ID = Principal.fromText(
  "vhuh4-cp777-77776-aaava-cai"
);

export const ICP_TRANSACTION_FEE = 10_000n;

export const NTC_TRANSACTION_FEE = 500_000n;

export const NTC_TO_CANISTER_FEE = 1000_0000n;

export const NNS_STATE_PATH = resolve(__dirname, "..", "nns_state");
