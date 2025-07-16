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

// This is a test canister ID for development purposes
// The real NTC Ledger canister ID should be used in production
export const NTC_LEDGER_CANISTER_ID = Principal.fromText(
  "ueyo2-wx777-77776-aaatq-cai"
);

export const NNS_STATE_PATH = resolve(__dirname, "..", "nns_state");
