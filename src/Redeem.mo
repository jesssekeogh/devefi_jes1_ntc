import MU "mo:mosup";
import Map "mo:map/Map";
import Principal "mo:base/Principal";
import Error "mo:base/Error";
import Option "mo:base/Option";
import Core "mo:devefi/core";
import Ver1 "./memory/v1";
import I "./interface";
import NodeUtils "./utils/node";
import TcycleMinterInterface "./interfaces/tcycle_minter";

module {
    let T = Core.VectorModule;

    public let Interface = I;

    public module Mem {
        public module Vector {
            public let V1 = Ver1;
        };
    };

    let M = Mem.Vector.V1;

    public let ID = "devefi_jes1_tcyclesredeem";

    public class Mod({
        xmem : MU.MemShell<M.Mem>;
        core : Core.Mod;
    }) : T.Class<I.CreateRequest, I.ModifyRequest, I.Shared> {

        let mem = MU.access(xmem);

        public type NodeMem = Ver1.NodeMem;

        // let CyclesLedger = Principal.fromText("um5iw-rqaaa-aaaaq-qaaba-cai");

        // TESTING ENVIRONMENT: Using a mock/test Cycles Ledger canister
        // This is a temporary test canister ID for development purposes
        // Replace before deploying to production environment
        let CyclesLedger = Principal.fromText("7tjcv-pp777-77776-qaaaa-cai");

        let TcycleMinter = actor ("oaez2-oaaaa-aaaaa-qbkmq-cai") : TcycleMinterInterface.Self;

        public func meta() : T.Meta {
            {
                id = ID;
                name = "Redeem TCYCLES";
                author = "jes1";
                description = "Redeem TCYCLES for CYCLES";
                supported_ledgers = [#ic(CyclesLedger)];
                version = #beta([0, 1, 0]);
                create_allowed = true;
                ledger_slots = [
                    "TCYCLES"
                ];
                billing = [];
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
                if (NodeUtils.node_ready(nodeMem)) {
                    await* Run.singleAsync(vid, vec, nodeMem);
                    return; // return after finding the first ready node
                };
            };
        };

        module Run {
            public func single(vid : T.NodeId, vec : T.NodeCoreMem, nodeMem : NodeMem) : () {
                let ?sourceRedeem = core.getSource(vid, vec, 0) else return;
                let redeemBal = core.Source.balance(sourceRedeem);
                let redeemFee = core.Source.fee(sourceRedeem);

                if (redeemBal > redeemFee) {
                    let ?redeemCanister = core.getDestinationAccountIC(vec, 0) else return;
                    if (Option.isSome(redeemCanister.subaccount)) return; // can't send cycles to subaccounts

                    let #ok(intent) = core.Source.Send.intent(
                        sourceRedeem,
                        #external_account({
                            owner = Principal.fromActor(TcycleMinter);
                            subaccount = ?Principal.toLedgerAccount(redeemCanister.owner, null);
                        }),
                        redeemBal,
                    ) else return;

                    let txId = core.Source.Send.commit(intent);

                    NodeUtils.tx_sent(nodeMem, txId);
                };
            };

            public func singleAsync(vid : T.NodeId, vec : T.NodeCoreMem, nodeMem : NodeMem) : async* () {
                try {
                    await* CycleLedgerActions.redeem_tcycles(nodeMem, vid, vec);
                } catch (err) {
                    NodeUtils.log_activity(nodeMem, "async_cycle", #Err(Error.message(err)));
                } finally {
                    NodeUtils.node_done(nodeMem);
                };
            };
        };

        public func create(vid : T.NodeId, _req : T.CommonCreateRequest, t : I.CreateRequest) : T.Create {
            let nodeMem : NodeMem = {
                internals = {
                    var updating = #Init;
                    var refresh_idx = null;
                };
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
                    refresh_idx = t.internals.refresh_idx;
                };
                log = t.log;
            };
        };

        public func defaults() : I.CreateRequest { {} };

        public func sources(_id : T.NodeId) : T.Endpoints {
            [(0, "Redeem")];
        };

        public func destinations(_id : T.NodeId) : T.Endpoints {
            [(0, "Canister")];
        };

        module CycleLedgerActions {
            public func redeem_tcycles(nodeMem : NodeMem, vid : T.NodeId, vec : T.NodeCoreMem) : async* () {
                let ?refreshIdx = nodeMem.internals.refresh_idx else return;

                // // TODO can't withdraw directly from subaccount
                // switch (await TcycleMinter.redeem_tcycles({ to_subaccount = subaccount })) {
                //     case (#Ok(_)) {
                //         NodeUtils.log_activity(nodeMem, "redeem_tcycles", #Ok());
                //     };
                //     case (#Err(err)) {
                //         NodeUtils.log_activity(nodeMem, "redeem_tcycles", #Err(debug_show err));
                //     };
                // };

            };
        };
    };
};
