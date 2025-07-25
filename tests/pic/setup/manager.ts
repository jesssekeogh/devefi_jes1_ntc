import {
  _SERVICE as NTCTESTPYLON,
  CreateRequest,
  CommonCreateRequest,
  NodeShared,
  LocalNodeId as NodeId,
  GetNodeResponse,
  CreateNodeRequest,
  Shared__1,
  Shared__2,
} from "./ntc_test_pylon/declarations/ntc_test_pylon.did.js";
import { _SERVICE as NTCMINTER } from "./ntc_minter/declarations/ntc_minter.did.js";
import { _SERVICE as NTCLEDGER } from "./ntc_ledger/declarations/ntc_ledger.idl.js";
import {
  _SERVICE as ICRCLEDGER,
  Account,
  TransferResult,
} from "./icrcledger/declarations/icrcledger.idl.js";
import {
  _SERVICE as ICPLEDGER,
  idlFactory as ledgerIdlFactory,
} from "./nns/ledger";
import { Actor, PocketIc, createIdentity, SubnetStateType } from "@dfinity/pic";
import { Principal } from "@dfinity/principal";
import {
  CMC_CANISTER_ID,
  ICP_LEDGER_CANISTER_ID,
  NNS_ROOT_CANISTER_ID,
  NTC_LEDGER_CANISTER_ID,
} from "./constants.ts";
import { NtcTestPylon, ICRCLedger, NtcMinter, NtcLedger } from "./index";
import { minterIdentity } from "./nns/identity.ts";
import { NNS_STATE_PATH } from "./constants.ts";
import Router from "./router/router.ts";
import { match, P } from "ts-pattern";

export class Manager {
  private readonly me: ReturnType<typeof createIdentity>;
  private readonly pic: PocketIc;
  private readonly ntcTestPylon: Actor<NTCTESTPYLON>;
  private readonly icrcActor: Actor<ICRCLEDGER>;
  private readonly icpLedgerActor: Actor<ICPLEDGER>;
  private readonly ntcLedgerActor: Actor<NTCLEDGER>;
  private readonly ntcMinterActor: Actor<NTCMINTER>;
  private readonly testCanisterId: Principal;
  private readonly testCanisterId2: Principal;

  constructor(
    pic: PocketIc,
    me: ReturnType<typeof createIdentity>,
    ntcTestPylon: Actor<NTCTESTPYLON>,
    icrcActor: Actor<ICRCLEDGER>,
    icpLedgerActor: Actor<ICPLEDGER>,
    ntcLedgerActor: Actor<NTCLEDGER>,
    ntcMinterActor: Actor<NTCMINTER>,
    testCanisterId: Principal,
    testCanisterId2: Principal
  ) {
    this.pic = pic;
    this.me = me;
    this.ntcTestPylon = ntcTestPylon;
    this.icrcActor = icrcActor;
    this.icpLedgerActor = icpLedgerActor;
    this.ntcLedgerActor = ntcLedgerActor;
    this.ntcMinterActor = ntcMinterActor;
    this.testCanisterId = testCanisterId;
    this.testCanisterId2 = testCanisterId2;

    // set identitys as me
    this.ntcTestPylon.setIdentity(this.me);
    this.icrcActor.setIdentity(this.me);
    this.icpLedgerActor.setIdentity(this.me);
    this.ntcLedgerActor.setIdentity(this.me);
    this.ntcMinterActor.setIdentity(this.me);
  }

  public static async beforeAll(): Promise<Manager> {
    let pic = await PocketIc.create(process.env.PIC_URL, {
      nns: {
        state: {
          type: SubnetStateType.FromPath,
          path: NNS_STATE_PATH,
        },
      },
      system: [{ state: { type: SubnetStateType.New } }],
      application: [{ state: { type: SubnetStateType.New } }],
    });

    await pic.setTime(new Date().getTime());
    await pic.tick();

    let identity = createIdentity("superSecretAlicePassword");

    // setup ICRC
    let icrcFixture = await ICRCLedger(pic, identity.getPrincipal());

    let ntcLedgerFixture = await NtcLedger(pic, identity.getPrincipal());

    // setup chrono router
    // we are not testing the router here, but we need it to spin up a pylon
    // pass time to allow router to setup slices
    const routerFixture = await Router(pic);
    await pic.advanceTime(240 * 60 * 1000);
    await pic.tick(240);

    const minterFixture = await NtcMinter(pic);

    let testCanister = await pic.createCanister();

    // setup icp ledger
    let icpLedgerActor = pic.createActor<ICPLEDGER>(
      ledgerIdlFactory,
      ICP_LEDGER_CANISTER_ID
    );

    // set identity as minter
    icpLedgerActor.setIdentity(minterIdentity);

    // mint ICP tokens
    await icpLedgerActor.icrc1_transfer({
      from_subaccount: [],
      to: { owner: identity.getPrincipal(), subaccount: [] },
      amount: 100000000000n,
      fee: [],
      memo: [],
      created_at_time: [],
    });

    // setup vector
    let pylonFixture = await NtcTestPylon(pic);

    let testCanister2 = await pic.createCanister();

    // console.log("Pylon canister Id", pylonFixture.canisterId.toString());
    // console.log("Minter canister Id", minterFixture.canisterId.toString());
    // console.log("NTC Ledger canister Id", ntcLedgerFixture.canisterId.toString());
    // console.log("ICRC Ledger canister Id", icrcFixture.canisterId.toString());
    // console.log("Router canister Id", routerFixture.canisterId.toString());
    // console.log("Test canister Id", testCanister.toString());

    return new Manager(
      pic,
      identity,
      pylonFixture.actor,
      icrcFixture.actor,
      icpLedgerActor,
      ntcLedgerFixture.actor,
      minterFixture.actor,
      testCanister,
      testCanister2
    );
  }

  public async afterAll(): Promise<void> {
    await this.pic.tearDown();
  }

  public getMe(): Principal {
    return this.me.getPrincipal();
  }

  public getNtcMinter(): Actor<NTCMINTER> {
    return this.ntcMinterActor;
  }

  public getNtcTestPylon(): Actor<NTCTESTPYLON> {
    return this.ntcTestPylon;
  }

  public getIcrcLedger(): Actor<ICRCLEDGER> {
    return this.icrcActor;
  }

  public getIcpLedger(): Actor<ICPLEDGER> {
    return this.icpLedgerActor;
  }

  public getNtcLedger(): Actor<NTCLEDGER> {
    return this.ntcLedgerActor;
  }

  public getTestCanisterId(): Principal {
    return this.testCanisterId;
  }

  public getTestCanisterId2(): Principal {
    return this.testCanisterId2;
  }

  public async stopCanister(canisterId: Principal): Promise<void> {
    return await this.pic.stopCanister({ canisterId });
  }

  public async startCanister(canisterId: Principal): Promise<void> {
    return await this.pic.startCanister({ canisterId });
  }

  public async stopCmcCanister(): Promise<void> {
    this.pic.stopCanister({
      canisterId: CMC_CANISTER_ID,
      sender: NNS_ROOT_CANISTER_ID,
    });
  }

  public async startCmcCanister(): Promise<void> {
    this.pic.startCanister({
      canisterId: CMC_CANISTER_ID,
      sender: NNS_ROOT_CANISTER_ID,
    });
  }

  public async getCyclesBalance(canisterId: Principal): Promise<number> {
    return await this.pic.getCyclesBalance(canisterId);
  }

  public async getNow(): Promise<bigint> {
    let time = await this.pic.getTime();
    return BigInt(Math.trunc(time));
  }

  public async advanceTime(seconds: number): Promise<void> {
    await this.pic.advanceTime(seconds * 1000);
  }

  public async advanceBlocks(blocks: number): Promise<void> {
    await this.pic.tick(blocks);
  }

  // used for when a refresh is pending on a node
  public async advanceBlocksAndTimeMinutes(mins: number): Promise<void> {
    const totalSeconds = mins * 60;
    const intervalSeconds = 20;
    const blocksPerInterval = 20; // 1 block per second for 20 seconds
    const rounds = Math.ceil(totalSeconds / intervalSeconds);

    for (let i = 0; i < rounds; i++) {
      const timeToAdvance = Math.min(
        intervalSeconds,
        totalSeconds - i * intervalSeconds
      );
      await this.pic.advanceTime(timeToAdvance * 1000);
      await this.pic.tick(blocksPerInterval);
    }
  }

  public async getTestCanisterCycles(): Promise<number> {
    return await this.pic.getCyclesBalance(this.testCanisterId);
  }

  public async createNode(nodeType: CreateRequest): Promise<NodeShared> {
    let [
      {
        endpoint: {
          // @ts-ignore
          ic: { account },
        },
      },
    ] = await this.ntcTestPylon.icrc55_accounts({
      owner: this.me.getPrincipal(),
      subaccount: [],
    });

    await this.sendIcrc(
      account,
      100_0001_0000n // more than enough (10_000 for fees)
    );

    await this.advanceBlocksAndTimeMinutes(3);

    const reqType: CreateNodeRequest = match(nodeType)
      .with({ devefi_jes1_ntcmint: P.select() }, (c): CreateNodeRequest => {
        let req: CommonCreateRequest = {
          controllers: [{ owner: this.me.getPrincipal(), subaccount: [] }],
          destinations: [
            [{ ic: { owner: this.me.getPrincipal(), subaccount: [] } }],
          ],
          refund: { owner: this.me.getPrincipal(), subaccount: [] },
          ledgers: [
            { ic: ICP_LEDGER_CANISTER_ID },
            { ic: NTC_LEDGER_CANISTER_ID }, // second ledger needs to be ntc ledger
          ],
          sources: [],
          extractors: [],
          affiliate: [],
          temporary: false,
          billing_option: 0n,
          initial_billing_amount: [],
          temp_id: 0,
        };

        let creq: CreateRequest = {
          devefi_jes1_ntcmint: {},
        };

        return [req, creq];
      })
      .with({ devefi_jes1_ntcredeem: P.select() }, (c): CreateNodeRequest => {
        let req: CommonCreateRequest = {
          controllers: [{ owner: this.me.getPrincipal(), subaccount: [] }],
          destinations: [
            [{ ic: { owner: this.testCanisterId, subaccount: [] } }],
            [{ ic: { owner: this.testCanisterId2, subaccount: [] } }],
          ],
          refund: { owner: this.me.getPrincipal(), subaccount: [] },
          ledgers: [{ ic: NTC_LEDGER_CANISTER_ID }],
          sources: [],
          extractors: [],
          affiliate: [],
          temporary: false,
          billing_option: 0n,
          initial_billing_amount: [],
          temp_id: 0,
        };

        let creq: CreateRequest = {
          devefi_jes1_ntcredeem: {
            variables: {
              split: [50n, 50n],
              names: ["Canister 1", "Canister 2"],
            },
          },
        };

        return [req, creq];
      })
      .exhaustive();

    let resp = await this.ntcTestPylon.icrc55_command({
      expire_at: [],
      request_id: [],
      controller: { owner: this.me.getPrincipal(), subaccount: [] },
      signature: [],
      commands: [{ create_node: reqType }],
    });

    //@ts-ignore
    if (resp.ok.commands[0].create_node.err) {
      //@ts-ignore
      throw new Error(resp.ok.commands[0].create_node.err);
    }
    //@ts-ignore
    return resp.ok.commands[0].create_node.ok;
  }

  public async deleteNode(nodeId: number) {
    let resp = await this.ntcTestPylon.icrc55_command({
      expire_at: [],
      request_id: [],
      controller: { owner: this.me.getPrincipal(), subaccount: [] },
      signature: [],
      commands: [{ delete_node: nodeId }],
    });

    //@ts-ignore
    if (resp.ok.commands[0].delete_node.err) {
      //@ts-ignore
      throw new Error(resp.ok.commands[0].delete_node.err);
    }
    //@ts-ignore
    return resp.ok.commands[0].delete_node.ok;
  }

  public async getNode(nodeId: NodeId): Promise<GetNodeResponse> {
    let resp = await this.ntcTestPylon.icrc55_get_nodes([{ id: nodeId }]);
    if (resp[0][0] === undefined) throw new Error("Node not found");
    return resp[0][0];
  }

  public async sendIcrc(to: Account, amount: bigint): Promise<TransferResult> {
    let txresp = await this.icrcActor.icrc1_transfer({
      from_subaccount: [],
      to: to,
      amount: amount,
      fee: [],
      memo: [],
      created_at_time: [],
    });

    if (!("Ok" in txresp)) {
      throw new Error("Transaction failed");
    }

    return txresp;
  }

  public async sendNtc(to: Account, amount: bigint): Promise<TransferResult> {
    let txresp = await this.ntcLedgerActor.icrc1_transfer({
      from_subaccount: [],
      to: to,
      amount: amount,
      fee: [],
      memo: [],
      created_at_time: [],
    });

    if (!("Ok" in txresp)) {
      throw new Error("Transaction failed");
    }

    return txresp;
  }

  public async sendIcp(to: Account, amount: bigint): Promise<TransferResult> {
    let txresp = await this.icpLedgerActor.icrc1_transfer({
      from_subaccount: [],
      to: to,
      amount: amount,
      fee: [],
      memo: [],
      created_at_time: [],
    });

    if (!("Ok" in txresp)) {
      throw new Error("Transaction failed");
    }

    return txresp;
  }

  public async getMyBalances() {
    let icrc = await this.icrcActor.icrc1_balance_of({
      owner: this.me.getPrincipal(),
      subaccount: [],
    });

    let icp = await this.icpLedgerActor.icrc1_balance_of({
      owner: this.me.getPrincipal(),
      subaccount: [],
    });

    let ntc = await this.ntcLedgerActor.icrc1_balance_of({
      owner: this.me.getPrincipal(),
      subaccount: [],
    });

    return { icrc_tokens: icrc, icp_tokens: icp, ntc_tokens: ntc };
  }

  public async getBillingBalances() {
    let author = Principal.fromText(
      "jv4ws-fbili-a35rv-xd7a5-xwvxw-trink-oluun-g7bcp-oq5f6-35cba-vqe"
    );
    // return other balances to check things out
    let icrc = await this.icrcActor.icrc1_balance_of({
      owner: author,
      subaccount: [],
    });

    let icp = await this.icpLedgerActor.icrc1_balance_of({
      owner: author,
      subaccount: [],
    });

    let ntc = await this.ntcLedgerActor.icrc1_balance_of({
      owner: author,
      subaccount: [],
    });

    return { icrc_tokens: icrc, icp_tokens: icp, ntc_tokens: ntc };
  }

  public getNodeSourceAccount(node: NodeShared, port: number): Account {
    if (!node || node.sources.length === 0) {
      throw new Error("Invalid node or no sources found");
    }

    let endpoint = node.sources[port].endpoint;

    if ("ic" in endpoint) {
      return endpoint.ic.account;
    }

    throw new Error("Invalid endpoint type: 'ic' endpoint expected");
  }

  public getNodeDestinationAccount(node: NodeShared): Account {
    if (!node || node.destinations.length === 0) {
      throw new Error("Invalid node or no sources found");
    }

    let endpoint = node.destinations[0].endpoint;

    if ("ic" in endpoint && endpoint.ic.account.length > 0) {
      return endpoint.ic.account[0];
    }

    throw new Error("Invalid endpoint type: 'ic' endpoint expected");
  }

  public getMintNodeCustom(node: NodeShared): Shared__1 {
    if (!node || !node.custom) {
      throw new Error("Invalid node or no custom data found");
    }

    if ("devefi_jes1_ntcmint" in node.custom[0]) {
      return node.custom[0].devefi_jes1_ntcmint;
    }

    throw new Error("Invalid custom data: 'devefi_jes1_ntcmint' expected");
  }

  public getRedeemNodeCustom(node: NodeShared): Shared__2 {
    if (!node || !node.custom) {
      throw new Error("Invalid node or no custom data found");
    }

    if ("devefi_jes1_ntcredeem" in node.custom[0]) {
      return node.custom[0].devefi_jes1_ntcredeem;
    }

    throw new Error("Invalid custom data: 'devefi_jes1_ntcredeem' expected");
  }

  public async pylonDebug(): Promise<void> {
    const info = await this.ntcTestPylon.get_ledgers_info();
    const errs = await this.ntcTestPylon.get_ledger_errors();

    console.log("ICRC Ledger ID:", info[0].id.toString());
    //@ts-ignore
    console.log("ICRC Ledger info:", info[0].info.icrc);

    console.log("ICP Ledger ID:", info[1].id.toString());
    //@ts-ignore
    console.log("ICP Ledger info:", info[1].info.icp);

    console.log("NTC Ledger ID:", info[2].id.toString());
    //@ts-ignore
    console.log("NTC Ledger info:", info[2].info.icrc);

    console.log("Errors in ledgers:", errs);
  }
}
