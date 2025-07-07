import { resolve } from "node:path";
import { PocketIc } from "@dfinity/pic";
import { IDL } from "@dfinity/candid";
import {
  _SERVICE as TCYCLESTESTPYLON,
  idlFactory,
  init as PylonInit,
} from "./declarations/tcycles_test_pylon.did.js";

const WASM_PATH = resolve(
  __dirname,
  "../tcycles_test_pylon/tcycles_test_pylon.wasm.gz"
);

export async function TcyclesTestPylon(pic: PocketIc) {
  const subnets = await pic.getApplicationSubnets();

  const fixture = await pic.setupCanister<TCYCLESTESTPYLON>({
    idlFactory,
    wasm: WASM_PATH,
    arg: IDL.encode(PylonInit({ IDL }), []),
    targetSubnetId: subnets[0].id,
  });

  return fixture;
}

export default TcyclesTestPylon;
