import { resolve } from "node:path";
import { PocketIc } from "@dfinity/pic";
import { IDL } from "@dfinity/candid";
import {
  _SERVICE as NTCTESTPYLON,
  idlFactory,
  init as PylonInit,
} from "./declarations/ntc_test_pylon.did.js";

const WASM_PATH = resolve(
  __dirname,
  "../ntc_test_pylon/ntc_test_pylon.wasm.gz"
);

export async function NtcTestPylon(pic: PocketIc) {
  const subnets = await pic.getApplicationSubnets();

  const fixture = await pic.setupCanister<NTCTESTPYLON>({
    idlFactory,
    wasm: WASM_PATH,
    arg: IDL.encode(PylonInit({ IDL }), []),
    targetSubnetId: subnets[0].id,
  });

  return fixture;
}

export default NtcTestPylon;
