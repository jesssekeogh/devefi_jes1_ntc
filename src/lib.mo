import U "mo:devefi/utils";
import MU "mo:mosup";
import Map "mo:map/Map";
import CyclesLedgerInterface "../interfaces/cycles_ledger";
import Principal "mo:base/Principal";
import Error "mo:base/Error";
import Option "mo:base/Option";
import Buffer "mo:base/Buffer";
import Core "mo:devefi/core";
import Ver1 "./memory/v1";
import I "./interface";

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

        public type RedeemNodeMem = Ver1.RedeemNodeMem;

        let CyclesLedger = actor ("um5iw-rqaaa-aaaaq-qaaba-cai") : CyclesLedgerInterface.Self;

        // Timeout interval for when calling async
        let TIMEOUT_NANOS : Nat64 = (3 * 60 * 1_000_000_000); // every 3 minutes

        // Maximum number of activities to keep in the main neuron's activity log
        let ACTIVITY_LOG_LIMIT : Nat = 10;

        public func meta() : T.Meta {
            {
                id = ID; // This has to be same as the variant in vec.custom
                name = "Redeem TCYCLES";
                author = "jes1";
                description = "Redeem TCYCLES for CYCLES";
                supported_ledgers = [#ic(Principal.fromActor(CyclesLedger))]; // tcycles ledger
                version = #beta([0, 1, 0]);
                create_allowed = true;
                ledger_slots = [
                    "TCYCLES"
                ];
                billing = [
                    {
                        cost_per_day = 0;
                        transaction_fee = #flat_fee_multiplier(100);
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
            public func single(vid : T.NodeId, vec : T.NodeCoreMem, nodeMem : RedeemNodeMem) : () {
                let ?sourceDeposit = core.getSource(vid, vec, 0) else return;
                let depositBal = core.Source.balance(sourceDeposit);
                let depositFee = core.Source.fee(sourceDeposit) * 1000; // still a fraction of a USD

                if (depositBal > depositFee) {
                    let #ok(intent) = core.Source.Send.intent(
                        sourceDeposit,
                        #remote_destination({ node = vid; port = 1 }), // ensures fee is withdrawn
                        depositBal,
                    ) else return;

                    ignore core.Source.Send.commit(intent);
                };
            };

            public func singleAsync(vid : T.NodeId, vec : T.NodeCoreMem, nodeMem : RedeemNodeMem) : async* () {
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
            let nodeMem : RedeemNodeMem = {
                variables = {};
                internals = {
                    var updating = #Init;
                };
                var log = [];
            };
            ignore Map.put(mem.main, Map.n32hash, vid, nodeMem);
            #ok(ID);
        };

        public func delete(vid : T.NodeId) : T.Delete {
            let ?t = Map.get(mem.main, Map.n32hash, vid) else return #err("Node not found for ID: " # debug_show vid);

            ignore Map.remove(mem.main, Map.n32hash, vid);
            return #ok();

        };

        public func modify(vid : T.NodeId, m : I.ModifyRequest) : T.Modify {
            let ?t = Map.get(mem.main, Map.n32hash, vid) else return #err("Node not found for ID: " # debug_show vid);

            #ok();
        };

        public func get(vid : T.NodeId, _vec : T.NodeCoreMem) : T.Get<I.Shared> {
            let ?t = Map.get(mem.main, Map.n32hash, vid) else return #err("Node not found for ID: " # debug_show vid);

            #ok {
                variables = {};
                internals = {
                    updating = t.internals.updating;
                };
                log = t.log;
            };
        };

        public func defaults() : I.CreateRequest {
            {
                variables = {};
            };
        };

        public func sources(_id : T.NodeId) : T.Endpoints {
            [(0, "Deposit"), (0, "Redeem")];
        };

        public func destinations(_id : T.NodeId) : T.Endpoints {
            [(0, "Canister")];
        };

        module NodeUtils {
            public func node_ready(nodeMem : RedeemNodeMem) : Bool {
                // Determine the appropriate timeout based on whether the neuron should be refreshed
                let timeout = TIMEOUT_NANOS;

                switch (nodeMem.internals.updating) {
                    case (#Init) {
                        nodeMem.internals.updating := #Calling(U.now());
                        return true;
                    };
                    case (#Calling(ts) or #Done(ts)) {
                        if (U.now() >= ts + timeout) {
                            nodeMem.internals.updating := #Calling(U.now());
                            return true;
                        } else {
                            return false;
                        };
                    };
                };
            };

            public func node_done(nodeMem : RedeemNodeMem) : () {
                nodeMem.internals.updating := #Done(U.now());
            };

            public func log_activity(nodeMem : RedeemNodeMem, operation : Text, result : { #Ok; #Err : Text }) : () {
                let log = Buffer.fromArray<Ver1.Activity>(nodeMem.log);

                switch (result) {
                    case (#Ok(())) {
                        log.add(#Ok({ operation = operation; timestamp = U.now() }));
                    };
                    case (#Err(msg)) {
                        log.add(#Err({ operation = operation; msg = msg; timestamp = U.now() }));
                    };
                };

                if (log.size() > ACTIVITY_LOG_LIMIT) {
                    ignore log.remove(0); // remove 1 item from the beginning
                };

                nodeMem.log := Buffer.toArray(log);
            };
        };

        module CycleLedgerActions {
            public func redeem_tcycles(nodeMem : RedeemNodeMem, vid : T.NodeId, vec : T.NodeCoreMem) : async* () {
                let ?sourceRedeem = core.getSource(vid, vec, 1) else return;
                let ?sourceRedeemAccount = core.getSourceAccountIC(vec, 1) else return;
                let redeemBal = core.Source.balance(sourceRedeem);
                let redeemFee = core.Source.fee(sourceRedeem);

                if (redeemBal > redeemFee * 2) {
                    let ?{ owner; subaccount } = core.getDestinationAccountIC(vec, 0) else return;
                    if (Option.isSome(subaccount)) return; // can't send cycles to subaccounts

                    switch (await CyclesLedger.withdraw({ to = owner; from_subaccount = sourceRedeemAccount.subaccount; created_at_time = null; amount = redeemBal - redeemFee })) {
                        case (#Ok(_)) {
                            NodeUtils.log_activity(nodeMem, "redeem_tcycles", #Ok());
                        };
                        case (#Err(err)) {
                            NodeUtils.log_activity(nodeMem, "redeem_tcycles", #Err(debug_show err));
                        };
                    };
                };
            };
        };

    };
};
