import Principal "mo:base/Principal";
import Ledgers "mo:devefi/ledgers";
import ICRC55 "mo:devefi/ICRC55";
import Rechain "mo:rechain";
import RT "./rechain";
import Timer "mo:base/Timer";
import U "mo:devefi/utils";
import T "./vector_modules";
import MU_sys "mo:devefi/sys";
import Chrono "mo:chronotrinite/client";
import Core "mo:devefi/core";
import TcyclesMintVector "../../src/Mint";
import TcyclesRedeemVector "../../src/Redeem";

shared ({ caller = owner }) actor class NNSTESTPYLON() = this {

    let me_can = Principal.fromActor(this);
    stable let chain_mem = Rechain.Mem.Rechain.V1.new();

    var chain = Rechain.Chain<system, RT.DispatchAction, RT.DispatchActionError>({
        settings = ?{
            Rechain.DEFAULT_SETTINGS with supportedBlocks = [{
                block_type = "55vec";
                url = "https://github.com/dfinity/ICRC/issues/55";
            }];
        };
        xmem = chain_mem;
        encodeBlock = RT.encodeBlock;
        reducers = [];
        me_can;
    });

    // chrono
    stable let chrono_mem_v1 = Chrono.Mem.ChronoClient.V1.new({
        router = Principal.fromText("txyno-ch777-77776-aaaaq-cai"); // Test chrono router canister
    });

    let chrono = Chrono.ChronoClient<system>({ xmem = chrono_mem_v1 });

    stable let dvf_mem_1 = Ledgers.Mem.Ledgers.V1.new();

    let dvf = Ledgers.Ledgers<system>({ xmem = dvf_mem_1; me_can; chrono });

    stable let mem_core_1 = Core.Mem.Core.V1.new();

    let test_icrc : Principal = Principal.fromText("tqzl2-p7777-77776-aaaaa-cai"); // Test ICRC ledger
    let icp_ledger = Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai");
    let cycles_ledger = Principal.fromText("7tjcv-pp777-77776-qaaaa-cai");

    dvf.add_ledger<system>(test_icrc, #icrc);
    dvf.add_ledger<system>(icp_ledger, #icp);
    dvf.add_ledger<system>(cycles_ledger, #icrc);
    
    let billing : ICRC55.BillingPylon = {
        ledger = test_icrc;
        min_create_balance = 3000000;
        operation_cost = 20_000;
        freezing_threshold_days = 10;
        split = {
            platform = 20;
            pylon = 20;
            author = 40;
            affiliate = 20;
        };
        pylon_account = {
            owner = Principal.fromText("eqsml-lyaaa-aaaaq-aacdq-cai");
            subaccount = null;
        };
        platform_account = {
            owner = Principal.fromText("eqsml-lyaaa-aaaaq-aacdq-cai");
            subaccount = null;
        };
    };

    let core = Core.Mod<system>({
        _chrono = chrono;
        xmem = mem_core_1;
        settings = {
            BILLING = billing;
            PYLON_NAME = "NNS Vector Test";
            PYLON_GOVERNED_BY = "";
            TEMP_NODE_EXPIRATION_SEC = 3600;
            MAX_INSTRUCTIONS_PER_HEARTBEAT = 300_000_000;
            REQUEST_MAX_EXPIRE_SEC = 3600;
            ALLOW_TEMP_NODE_CREATION = true;
        };
        dvf;
        me_can;
    });

    // Components
    stable let mem_vec_tcyclesmint_1 = TcyclesMintVector.Mem.Vector.V1.new();
    stable let mem_vec_tcyclesredeem_1 = TcyclesRedeemVector.Mem.Vector.V1.new();

    let devefi_jes1_tcyclesmint = TcyclesMintVector.Mod({
        xmem = mem_vec_tcyclesmint_1;
        core;
    });

    let devefi_jes1_tcyclesredeem = TcyclesRedeemVector.Mod({
        xmem = mem_vec_tcyclesredeem_1;
        core;
    });

    let vmod = T.VectorModules({
        devefi_jes1_tcyclesmint;
        devefi_jes1_tcyclesredeem;
    });

    let sys = MU_sys.Mod<system, T.CreateRequest, T.Shared, T.ModifyRequest>({
        xmem = mem_core_1;
        dvf;
        core;
        vmod;
        me_can;
    });

    private func proc() { devefi_jes1_tcyclesmint.run() };

    private func async_proc() : async* () {
        await* devefi_jes1_tcyclesmint.runAsync();
        await* devefi_jes1_tcyclesredeem.runAsync();
    };

    ignore Timer.recurringTimer<system>(
        #seconds 30,
        func() : async () { core.heartbeat(proc) },
    );

    ignore Timer.recurringTimer<system>(
        #seconds 45,
        func() : async () { await* async_proc() },
    );

    // ICRC-55

    public query func icrc55_get_pylon_meta() : async ICRC55.PylonMetaResp {
        sys.icrc55_get_pylon_meta();
    };

    public shared ({ caller }) func icrc55_command(req : ICRC55.BatchCommandRequest<T.CreateRequest, T.ModifyRequest>) : async ICRC55.BatchCommandResponse<T.Shared> {
        sys.icrc55_command<RT.DispatchActionError>(
            caller,
            req,
            func(r) {
                chain.dispatch({
                    caller;
                    payload = #vector(r);
                    ts = U.now();
                });
            },
        );
    };

    public query func icrc55_get_nodes(req : [ICRC55.GetNode]) : async [?MU_sys.NodeShared<T.Shared>] {
        sys.icrc55_get_nodes(req);
    };

    public query ({ caller }) func icrc55_get_controller_nodes(req : ICRC55.GetControllerNodesRequest) : async [MU_sys.NodeShared<T.Shared>] {
        sys.icrc55_get_controller_nodes(caller, req);
    };

    public query func icrc55_get_defaults(id : Text) : async T.CreateRequest {
        sys.icrc55_get_defaults(id);
    };

    public shared ({ caller }) func icrc55_account_register(acc : ICRC55.Account) : async () {
        sys.icrc55_account_register(caller, acc);
    };

    public query ({ caller }) func icrc55_accounts(req : ICRC55.AccountsRequest) : async ICRC55.AccountsResponse {
        sys.icrc55_accounts(caller, req);
    };

    // ICRC-3

    public query func icrc3_get_blocks(args : Rechain.GetBlocksArgs) : async Rechain.GetBlocksResult {
        return chain.icrc3_get_blocks(args);
    };

    public query func icrc3_get_archives(args : Rechain.GetArchivesArgs) : async Rechain.GetArchivesResult {
        return chain.icrc3_get_archives(args);
    };

    public query func icrc3_supported_block_types() : async [Rechain.BlockType] {
        return chain.icrc3_supported_block_types();
    };
    public query func icrc3_get_tip_certificate() : async ?Rechain.DataCertificate {
        return chain.icrc3_get_tip_certificate();
    };

    // ---------- Debug functions -----------

    public query func get_ledger_errors() : async [[Text]] {
        dvf.getErrors();
    };

    public query func get_ledgers_info() : async [Ledgers.LedgerInfo] {
        dvf.getLedgersInfo();
    };

};
