import { resolve } from "node:path";
import { PocketIc } from "@dfinity/pic";
import { IDL } from "@dfinity/candid";
import {
  _SERVICE as CYCLESLEDGER,
  idlFactory,
  init as CycleLedgerInit,
} from "./declarations/cycles_ledger.js";

const WASM_PATH = resolve(__dirname, "../cyclesledger/cycles_ledger.wasm.gz");

export async function CyclesLedger(pic: PocketIc) {
  const subnets = await pic.getSystemSubnets();

  const fixture = await pic.setupCanister<CYCLESLEDGER>({
    idlFactory,
    wasm: WASM_PATH,
    arg: IDL.encode(CycleLedgerInit({ IDL }), [
      {
        Init: {
          index_id: [],
          max_blocks_per_request: BigInt(2000),
        }
      }
    ]),
    targetSubnetId: subnets[0].id,
  });

  return fixture;
}

export default CyclesLedger;
