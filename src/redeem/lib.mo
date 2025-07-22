import MU "mo:mosup";
import Map "mo:map/Map";
import Principal "mo:base/Principal";
import Option "mo:base/Option";
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

        // let NtcLedger = Principal.fromText("production-ntc-ledger-id");
        // let NtcMinter = Principal.fromText("production-ntc-minter-id");

        // TESTING ENVIRONMENT (comment out for production):

        let NtcLedger = Principal.fromText("ueyo2-wx777-77776-aaatq-cai");
        let NtcMinter = Principal.fromText("udzio-3p777-77776-aaata-cai");

        let MINIMUM_REDEEM : Nat = 1_0000_0000_0000; // 1 NTC

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

        module Run {
            public func single(vid : T.NodeId, vec : T.NodeCoreMem, nodeMem : NodeMem) : () {
                let ?sourceRedeem = core.getSource(vid, vec, 0) else return;
                let redeemBal = core.Source.balance(sourceRedeem);
                let redeemFee = core.Source.fee(sourceRedeem);

                if (redeemBal > redeemFee + MINIMUM_REDEEM) {
                    let ?redeemCanister = core.getDestinationAccountIC(vec, 0) else return;
                    if (Option.isSome(redeemCanister.subaccount)) return; // can't send cycles to subaccounts

                    let #ok(intent) = core.Source.Send.intent(
                        sourceRedeem,
                        #external_account(#icrc({
                            owner = NtcMinter;
                            subaccount = ?Utils.principalToSubaccount(redeemCanister.owner);
                        })),
                        redeemBal,
                        null,
                    ) else return;

                    ignore core.Source.Send.commit(intent);
                };
            };
        };

        public func create(vid : T.NodeId, _req : T.CommonCreateRequest, _t : I.CreateRequest) : T.Create {
            let nodeMem : NodeMem = {
                internals = {};
            };
            ignore Map.put(mem.main, Map.n32hash, vid, nodeMem);
            #ok(ID);
        };

        public func delete(vid : T.NodeId) : T.Delete {
            let ?_t = Map.get(mem.main, Map.n32hash, vid) else return #err("Node not found for ID: " # debug_show vid);

            ignore Map.remove(mem.main, Map.n32hash, vid);
            return #ok();

        };

        public func modify(vid : T.NodeId, _m : I.ModifyRequest) : T.Modify {
            let ?_t = Map.get(mem.main, Map.n32hash, vid) else return #err("Node not found for ID: " # debug_show vid);

            #ok();
        };

        public func get(vid : T.NodeId, _vec : T.NodeCoreMem) : T.Get<I.Shared> {
            let ?_t = Map.get(mem.main, Map.n32hash, vid) else return #err("Node not found for ID: " # debug_show vid);

            #ok {
                internals = {};
            };
        };

        public func defaults() : I.CreateRequest { {} };

        public func sources(_id : T.NodeId) : T.Endpoints {
            [(0, "Redeem")];
        };

        public func destinations(_id : T.NodeId) : T.Endpoints {
            [(0, "Canister")];
        };
    };
};
