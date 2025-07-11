import { resolve } from "node:path";
import { PocketIc } from "@dfinity/pic";
import { IDL } from "@dfinity/candid";
import {
  _SERVICE as TCYCLESTESTMINTER,
  idlFactory,
  init as PylonInit,
} from "./declarations/tcycles_minter.did.js";
import { Principal } from "@dfinity/principal";

const WASM_PATH = resolve(
  __dirname,
  "../tcycles_minter/tcycles_minter.wasm.gz"
);

export async function TcyclesTestMinter(
  pic: PocketIc,
  pylonId: Principal,
  tcyclesLedgerId: Principal
) {
  const subnets = await pic.getApplicationSubnets();

  const fixture = await pic.setupCanister<TCYCLESTESTMINTER>({
    idlFactory,
    wasm: WASM_PATH,
    arg: IDL.encode(PylonInit({ IDL }), [
      {
        pylon_id: pylonId,
        tcycles_ledger_id: tcyclesLedgerId,
      },
    ]),
    targetSubnetId: subnets[0].id,
  });

  return fixture;
}

export default TcyclesTestMinter;
