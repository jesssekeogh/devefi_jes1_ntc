import { resolve } from "node:path";
import { PocketIc } from "@dfinity/pic";
import { IDL } from "@dfinity/candid";
import {
  _SERVICE as NTCTESTMINTER,
  idlFactory,
  init as PylonInit,
} from "./declarations/ntc_minter.did.js";

const WASM_PATH = resolve(__dirname, "../ntc_minter/ntc_minter.wasm.gz");

export async function NtcTestMinter(pic: PocketIc) {
  const subnets = await pic.getApplicationSubnets();

  const fixture = await pic.setupCanister<NTCTESTMINTER>({
    idlFactory,
    wasm: WASM_PATH,
    arg: IDL.encode(PylonInit({ IDL }), []),
    targetSubnetId: subnets[0].id,
  });

  return fixture;
}

export default NtcTestMinter;
