import { resolve } from "node:path";
import { PocketIc } from "@dfinity/pic";
import {
  _SERVICE as NTCLEDGER,
  idlFactory,
  init,
  LedgerArg,
} from "./declarations/ntc_ledger.idl";
import { IDL } from "@dfinity/candid";
import { Principal } from "@dfinity/principal";
import { NTC_MINTER_CANISTER_ID } from "../constants";

const WASM_PATH = resolve(__dirname, "../ntc_ledger/ntc_ledger.wasm");

export async function NtcLedger(pic: PocketIc, me: Principal) {
  let ledger_args: LedgerArg = {
    Init: {
      minting_account: {
        owner: NTC_MINTER_CANISTER_ID,
        subaccount: [],
      },
      fee_collector_account: [{ owner: NTC_MINTER_CANISTER_ID, subaccount: [] }],
      transfer_fee: 500_000n,
      decimals: [8],
      token_symbol: "NTC",
      token_name: "Neutrinite TCYCLES",
      metadata: [],
      initial_balances: [
        [
          { owner: me, subaccount: [] },
          1000_0000_0000n,
        ],
      ], // just to get a block
      archive_options: {
        num_blocks_to_archive: 10000n,
        trigger_threshold: 9000n,
        controller_id: NTC_MINTER_CANISTER_ID,
        max_transactions_per_response: [],
        max_message_size_bytes: [],
        cycles_for_archive_creation: [],
        node_max_memory_size_bytes: [],
      },
      maximum_number_of_accounts: [],
      accounts_overflow_trim_quantity: [],
      max_memo_length: [],
      feature_flags: [{ icrc2: true }],
    },
  };

  const subnets = await pic.getApplicationSubnets();

  const fixture = await pic.setupCanister<NTCLEDGER>({
    idlFactory,
    wasm: WASM_PATH,
    arg: IDL.encode(init({ IDL }), [ledger_args]),
    targetSubnetId: subnets[0].id,
  });

  return fixture;
}

export default NtcLedger;
