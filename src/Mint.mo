import MU "mo:mosup";
import Map "mo:map/Map";
import Principal "mo:base/Principal";
import Nat64 "mo:base/Nat64";
import Error "mo:base/Error";
import Option "mo:base/Option";
import Core "mo:devefi/core";
import Ver1 "./memory/v1";
import I "./interface";
import CyclesMintingInterface "./interfaces/cycles_minting";
import CyclesLedgerInterface "./interfaces/cycles_ledger";
import IcpLedgerInterface "mo:devefi-icp-ledger/icp_ledger";
import NodeUtils "./utils/node";

module {
    let T = Core.VectorModule;

    public let Interface = I;

    public module Mem {
        public module Vector {
            public let V1 = Ver1;
        };
    };

    let M = Mem.Vector.V1;

    public let ID = "devefi_jes1_tcyclesmint";

    public class Mod({
        xmem : MU.MemShell<M.Mem>;
        core : Core.Mod;
    }) : T.Class<I.CreateRequest, I.ModifyRequest, I.Shared> {

        let mem = MU.access(xmem);

        public type NodeMem = Ver1.NodeMem;

        let CyclesMinting = actor ("rkp4c-7iaaa-aaaaa-aaaca-cai") : CyclesMintingInterface.Self;

        let IcpLedger = actor ("ryjl3-tyaaa-aaaaa-aaaba-cai") : IcpLedgerInterface.Self;

        // let CyclesLedger = actor ("um5iw-rqaaa-aaaaq-qaaba-cai") : CyclesLedgerInterface.Self;

        // TESTING ENVIRONMENT: Using a mock/test Cycles Ledger canister
        // This is a temporary test canister ID for development purposes
        // Replace before deploying to production environment
        let CyclesLedger = actor ("7tjcv-pp777-77776-qaaaa-cai") : CyclesLedgerInterface.Self;

        let BILLING_FLAT_FEE_MULTIPLIER : Nat = 100;

        let MINIMUM_MINT : Nat = 100_000_000; // 1 ICP

        // From here: https://forum.dfinity.org/t/a-couple-of-new-cmc-features-icrc-memo-and-automatic-refunds/41396
        let NOTIFY_MINT_CYCLES : Blob = "\4d\49\4e\54\00\00\00\00";

        public func meta() : T.Meta {
            {
                id = ID;
                name = "Mint TCYCLES";
                author = "jes1";
                description = "Mint TCYCLES from ICP";
                supported_ledgers = [#ic(Principal.fromActor(IcpLedger)), #ic(Principal.fromActor(CyclesLedger))]; // icp ledger and cycles ledger
                version = #beta([0, 1, 0]);
                create_allowed = true;
                ledger_slots = [
                    "MINT",
                    "TCYCLES",
                ];
                billing = [
                    {
                        cost_per_day = 0;
                        transaction_fee = #flat_fee_multiplier(BILLING_FLAT_FEE_MULTIPLIER);
                    },
                ];
                sources = sources(0);
                destinations = destinations(0);
                author_account = {
                    owner = Principal.fromText("jv4ws-fbili-a35rv-xd7a5-xwvxw-trink-oluun-g7bcp-oq5f6-35cba-vqe");
                    subaccount = null;
                };
                temporary_allowed = true;
            };
        };

        public func run() : () {
            label vec_loop for ((vid, nodeMem) in Map.entries(mem.main)) {
                let ?vec = core.getNodeById(vid) else continue vec_loop;
                if (not vec.active) continue vec_loop;
                if (vec.billing.frozen) continue vec_loop;
                if (Option.isSome(vec.billing.expires)) continue vec_loop;
                Run.single(vid, vec, nodeMem);
            };
        };

        public func runAsync() : async* () {
            label vec_loop for ((vid, nodeMem) in Map.entries(mem.main)) {
                let ?vec = core.getNodeById(vid) else continue vec_loop;
                if (not vec.active) continue vec_loop;
                if (vec.billing.frozen) continue vec_loop;
                if (Option.isSome(vec.billing.expires)) continue vec_loop;

                let ?sourceMint = core.getSource(vid, vec, 0) else continue vec_loop;
                let mintBal = core.Source.balance(sourceMint);
                let mintFee = core.Source.fee(sourceMint);

                if (NodeUtils.node_ready(nodeMem, mintBal, mintFee + MINIMUM_MINT)) {
                    await* Run.singleAsync(vid, vec, nodeMem);
                    return; // return after finding the first ready node
                };
            };
        };

        module Run {
            public func single(vid : T.NodeId, vec : T.NodeCoreMem, nodeMem : NodeMem) : () {
                let ?sourceTo = core.getSource(vid, vec, 1) else return;
                let toBal = core.Source.balance(sourceTo);
                let toFee = core.Source.fee(sourceTo);

                if (toBal > toFee) {
                    let #ok(intent) = core.Source.Send.intent(
                        sourceTo,
                        #destination({ port = 0 }),
                        toBal,
                    ) else return;

                    ignore core.Source.Send.commit(intent);
                };
            };

            public func singleAsync(vid : T.NodeId, vec : T.NodeCoreMem, nodeMem : NodeMem) : async* () {
                try {
                    await* CycleMintingActions.mint_tcycles(nodeMem, vid, vec);
                } catch (err) {
                    NodeUtils.log_activity(nodeMem, "async_cycle", #Err(Error.message(err)));
                } finally {
                    NodeUtils.node_done(nodeMem);
                };
            };
        };

        public func create(vid : T.NodeId, _req : T.CommonCreateRequest, t : I.CreateRequest) : T.Create {
            let nodeMem : NodeMem = {
                internals = { var updating = #Init };
                var log = [];
            };
            ignore Map.put(mem.main, Map.n32hash, vid, nodeMem);
            #ok(ID);
        };

        public func delete(vid : T.NodeId) : T.Delete {
            let ?_t = Map.get(mem.main, Map.n32hash, vid) else return #err("Node not found for ID: " # debug_show vid);

            ignore Map.remove(mem.main, Map.n32hash, vid);
            return #ok();

        };

        public func modify(vid : T.NodeId, m : I.ModifyRequest) : T.Modify {
            let ?_t = Map.get(mem.main, Map.n32hash, vid) else return #err("Node not found for ID: " # debug_show vid);

            #ok();
        };

        public func get(vid : T.NodeId, _vec : T.NodeCoreMem) : T.Get<I.Shared> {
            let ?t = Map.get(mem.main, Map.n32hash, vid) else return #err("Node not found for ID: " # debug_show vid);

            #ok {
                internals = {
                    updating = t.internals.updating;
                };
                log = t.log;
            };
        };

        public func defaults() : I.CreateRequest { {} };

        public func sources(_id : T.NodeId) : T.Endpoints {
            [(0, "Mint"), (1, "_To")];
        };

        public func destinations(_id : T.NodeId) : T.Endpoints {
            [(1, "To")];
        };

        module CycleMintingActions {
            public func mint_tcycles(nodeMem : NodeMem, vid : T.NodeId, vec : T.NodeCoreMem) : async* () {
                let ?sourceMint = core.getSource(vid, vec, 0) else return;
                let ?sourceMintAccount = core.getSourceAccountIC(vec, 0) else return;
                let mintBal = core.Source.balance(sourceMint);
                let mintFee = core.Source.fee(sourceMint);

                let ?sourceToAccount = core.getSourceAccountIC(vec, 1) else return;

                let amount_to_mint : Nat = mintBal - mintFee;

                // TODO balance is empty, balances are stored in the pylons
                switch (await IcpLedger.icrc1_transfer({ to = { owner = Principal.fromActor(CyclesMinting); subaccount = ?Principal.toLedgerAccount(core.getThisCan(), null) }; fee = null; memo = ?NOTIFY_MINT_CYCLES; from_subaccount = sourceMintAccount.subaccount; created_at_time = null; amount = amount_to_mint })) {
                    case (#Ok(block_idx)) {
                        switch (await CyclesMinting.notify_mint_cycles({ block_index = Nat64.fromNat(block_idx); deposit_memo = ?NOTIFY_MINT_CYCLES; to_subaccount = sourceToAccount.subaccount })) {
                            case (#Ok(_)) {
                                NodeUtils.log_activity(nodeMem, "mint_tcycles", #Ok());
                            };
                            case (#Err(err)) {
                                NodeUtils.log_activity(nodeMem, "mint_tcycles", #Err(debug_show err));
                            };
                        };
                    };
                    case (#Err(err)) {
                        NodeUtils.log_activity(nodeMem, "mint_tcycles", #Err(debug_show err));
                    };
                };
            };
        };
    };
};
