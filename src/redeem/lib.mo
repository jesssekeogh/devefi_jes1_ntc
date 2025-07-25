import MU "mo:mosup";
import Map "mo:map/Map";
import Principal "mo:base/Principal";
import Option "mo:base/Option";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Core "mo:devefi/core";
import Ver1 "./memory/v1";
import I "./interface";
import Utils "../utils/Utils";

module {
    let T = Core.VectorModule;

    public let Interface = I;

    public module Mem {
        public module Vector {
            public let V1 = Ver1;
        };
    };

    let M = Mem.Vector.V1;

    public let ID = "devefi_jes1_ntcredeem";

    public class Mod({
        xmem : MU.MemShell<M.Mem>;
        core : Core.Mod;
    }) : T.Class<I.CreateRequest, I.ModifyRequest, I.Shared> {

        let mem = MU.access(xmem);

        public type NodeMem = Ver1.NodeMem;

        // PRODUCTION ENVIRONMENT (uncomment for production deployment):

        // let NtcLedger = Principal.fromText("7dx3o-7iaaa-aaaal-qsrdq-cai");
        // let NtcMinter = Principal.fromText("7ew52-sqaaa-aaaal-qsrda-cai");

        // TESTING ENVIRONMENT (comment out for production):

        let NtcLedger = Principal.fromText("txyno-ch777-77776-aaaaq-cai");
        let NtcMinter = Principal.fromText("vjwku-z7777-77776-aaaua-cai");

        public func meta() : T.Meta {
            {
                id = ID;
                name = "Redeem NTC";
                author = "jes1";
                description = "Redeem NTC for CYCLES";
                supported_ledgers = [#ic(NtcLedger)];
                version = #beta([0, 1, 0]);
                create_allowed = true;
                ledger_slots = [
                    "REDEEM"
                ];
                billing = [
                    {
                        cost_per_day = 0;
                        transaction_fee = #flat_fee_multiplier(5); // TODO Implement 0.025 NTC fee
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

        module Run {
            public func single(vid : T.NodeId, vec : T.NodeCoreMem, nodeMem : NodeMem) : () {
                let ?source = core.getSource(vid, vec, 0) else return;
                let bal = core.Source.balance(source);
                let fee = core.Source.fee(source);
                let feeThreshold = fee * 50;

                // First loop: Calculate totalSplit and find the largest share destination
                var totalSplit = 0;
                var largestPort : ?Nat = null;
                var largestAmount = 0;

                label iniloop for (port_id in nodeMem.variables.split.keys()) {
                    if (not core.hasDestination(vec, port_id)) continue iniloop;

                    let splitShare = nodeMem.variables.split[port_id];
                    totalSplit += splitShare;

                    if (splitShare > largestAmount) {
                        largestPort := ?port_id;
                        largestAmount := splitShare;
                    };
                };

                // If no valid destinations, skip the rest of the loop
                if (totalSplit == 0) return;

                // Pre-check loop: Ensure each destination has a valid amount
                label precheckLoop for (port_id in nodeMem.variables.split.keys()) {
                    if (not core.hasDestination(vec, port_id)) continue precheckLoop;

                    let splitShare = nodeMem.variables.split[port_id];

                    let amount = bal * splitShare / totalSplit;

                    if (amount <= feeThreshold) return;
                };

                var remainingBalance = bal;

                // Second loop: Send to each valid destination
                label port_send for (port_id in nodeMem.variables.split.keys()) {
                    let ?redeemCanister = core.getDestinationAccountIC(vec, port_id) else continue port_send;
                    if (Option.isSome(redeemCanister.subaccount)) continue port_send; // can't send cycles to subaccounts

                    let splitShare = nodeMem.variables.split[port_id];

                    // Skip the largestPort for now, as we will handle it last
                    if (?port_id == largestPort) continue port_send;

                    let amount = bal * splitShare / totalSplit;

                    let #ok(intent) = core.Source.Send.intent(
                        source,
                        #external_account(#icrc({ owner = NtcMinter; subaccount = ?Utils.canister2subaccount(redeemCanister.owner) })),
                        amount,
                        null,
                    ) else return;

                    ignore core.Source.Send.commit(intent);
                    remainingBalance -= amount;
                };

                // Send the remaining balance to the largest share destination
                if (remainingBalance > 0) {
                    ignore do ? {
                        let ?redeemCanister = core.getDestinationAccountIC(vec, largestPort!) else return;

                        let #ok(intent) = core.Source.Send.intent(
                            source,
                            #external_account(#icrc({ owner = NtcMinter; subaccount = ?Utils.canister2subaccount(redeemCanister.owner) })),
                            remainingBalance,
                            null,
                        ) else return;

                        ignore core.Source.Send.commit(intent);
                    };
                };

            };
        };

        public func create(vid : T.NodeId, _req : T.CommonCreateRequest, t : I.CreateRequest) : T.Create {
            for (name in t.variables.names.vals()) {
                if (Text.size(name) > 50) {
                    return #err("Name too long: maximum 50 characters allowed");
                };
            };

            let nodeMem : NodeMem = {
                variables = {
                    var split = t.variables.split;
                    var names = t.variables.names;
                };
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
            let ?t = Map.get(mem.main, Map.n32hash, vid) else return #err("Node not found for ID: " # debug_show vid);

            t.variables.split := m.split;
            t.variables.names := m.names;
            #ok();
        };

        public func get(vid : T.NodeId, _vec : T.NodeCoreMem) : T.Get<I.Shared> {
            let ?t = Map.get(mem.main, Map.n32hash, vid) else return #err("Node not found for ID: " # debug_show vid);

            #ok {
                variables = {
                    split = t.variables.split;
                    names = t.variables.names;
                };
            };
        };

        public func defaults() : I.CreateRequest {
            {
                variables = {
                    split = [50, 50];
                    names = ["Canister 1", "Canister 2"];
                };
            };
        };

        public func sources(_id : T.NodeId) : T.Endpoints {
            [(0, "Redeem")];
        };

        public func destinations(id : T.NodeId) : T.Endpoints {
            let ?t = Map.get(mem.main, Map.n32hash, id) else return [];

            Array.tabulate<(Nat, Text)>(
                t.variables.split.size(),
                func(idx : Nat) {
                    let name = if (idx < t.variables.names.size()) {
                        t.variables.names[idx];
                    } else {
                        Nat.toText(t.variables.split[idx]);
                    };
                    (0, name);
                },
            );
        };
    };
};
