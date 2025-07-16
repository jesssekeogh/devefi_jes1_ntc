import MU "mo:mosup";
import Map "mo:map/Map";
import Principal "mo:base/Principal";
import Nat64 "mo:base/Nat64";
import Error "mo:base/Error";
import Option "mo:base/Option";
import Buffer "mo:base/Buffer";
import Core "mo:devefi/core";
import U "mo:devefi/utils";
import Ver1 "./memory/v1";
import I "./interface";
import NtcMinterInterface "../interfaces/ntc_minter";
import CyclesMintingInterface "../interfaces/cycles_minting";

module {
    let T = Core.VectorModule;

    public let Interface = I;

    public module Mem {
        public module Vector {
            public let V1 = Ver1;
        };
    };

    let M = Mem.Vector.V1;

    public let ID = "devefi_jes1_ntcmint";

    public class Mod({
        xmem : MU.MemShell<M.Mem>;
        core : Core.Mod;
    }) : T.Class<I.CreateRequest, I.ModifyRequest, I.Shared> {

        let mem = MU.access(xmem);

        public type NodeMem = Ver1.NodeMem;

        let IcpLedger = Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai");

        let CmcMinter = actor ("rkp4c-7iaaa-aaaaa-aaaca-cai") : CyclesMintingInterface.Self;

        // PRODUCTION ENVIRONMENT (uncomment for production deployment):

        // let NtcLedger = Principal.fromText("production-ntc-ledger-id");
        // let NtcMinter = actor ("production-ntc-minter-id") : NtcMinterInterface.Self;
        
        // TESTING ENVIRONMENT (comment out for production):
        
        let NtcLedger = Principal.fromText("ueyo2-wx777-77776-aaatq-cai");
        let NtcMinter = actor ("udzio-3p777-77776-aaata-cai") : NtcMinterInterface.Self;

        let MINIMUM_MINT : Nat = 100_000_000; // 1 ICP

        public func meta() : T.Meta {
            {
                id = ID;
                name = "Mint NTC";
                author = "jes1";
                description = "Mint NTC from ICP";
                supported_ledgers = [#ic(IcpLedger), #ic(NtcLedger)];
                version = #beta([0, 1, 0]);
                create_allowed = true;
                ledger_slots = [
                    "MINT",
                    "NTC",
                ];
                billing = [
                    {
                        cost_per_day = 0;
                        transaction_fee = #flat_fee_multiplier(500); // 0.05 NTC
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
                if (NodeUtils.node_ready(nodeMem)) {
                    await* Run.singleAsync(vid, vec, nodeMem);
                    return; // return after finding the first ready node
                };
            };
        };

        module Run {
            public func single(vid : T.NodeId, vec : T.NodeCoreMem, nodeMem : NodeMem) : () {
                // Forward icp to the ntc minter
                let ?sourceMint = core.getSource(vid, vec, 0) else return;
                let mintBal = core.Source.balance(sourceMint);
                let mintFee = core.Source.fee(sourceMint);

                if (mintBal > mintFee + MINIMUM_MINT) {
                    let ?sourceToAccount = core.getSourceAccountIC(vec, 1) else return;

                    let #ok(intent) = core.Source.Send.intent(
                        sourceMint,
                        #external_account({
                            owner = Principal.fromActor(CmcMinter);
                            subaccount = sourceToAccount.subaccount;
                        }),
                        mintBal,
                    ) else return;

                    let txId = core.Source.Send.commit(intent);

                    NodeUtils.tx_sent(nodeMem, txId);
                };

                // Forward ntc to the destination
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
                    await* NtcMintingActions.mint_ntc(nodeMem, vid, vec);
                } catch (err) {
                    NodeUtils.log_activity(nodeMem, "async_cycle", #Err(Error.message(err)));
                } finally {
                    NodeUtils.node_done(nodeMem);
                };
            };
        };

        public func create(vid : T.NodeId, _req : T.CommonCreateRequest, _t : I.CreateRequest) : T.Create {
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

        public func modify(vid : T.NodeId, _m : I.ModifyRequest) : T.Modify {
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
            [(0, "Mint"), (1, "_To")];
        };

        public func destinations(_id : T.NodeId) : T.Endpoints {
            [(1, "To")];
        };

        module NtcMintingActions {
            // TODO use the new onSent and then mint cycles to this canister and send with cycles to the minter
            public func mint_ntc(nodeMem : NodeMem, vid : T.NodeId, vec : T.NodeCoreMem) : async* () {
                let ?refreshIdx = nodeMem.internals.refresh_idx else return;
                let ?{ cls = #icp(ledger) } = core.get_ledger_cls(IcpLedger) else return;
                let ?{ subaccount = ?subaccount } = core.getSourceAccountIC(vec, 1) else return;

                if (ledger.isSent(refreshIdx)) {
                    // switch (await NtcMinter.mint_tcycles({ to_subaccount = subaccount })) {
                    //     case (#Ok(_)) {
                    //         if (Option.equal(?refreshIdx, nodeMem.internals.refresh_idx, Nat64.equal)) {
                    //             nodeMem.internals.refresh_idx := null;
                    //         };

                    //         NodeUtils.log_activity(nodeMem, "mint_ntc", #Ok());
                    //     };
                    //     case (#Err(err)) {
                    //         NodeUtils.log_activity(nodeMem, "mint_ntc", #Err(debug_show err));
                    //     };
                    // };
                };
            };
        };

        module NodeUtils {
            public func node_ready(nodeMem : Ver1.NodeMem) : Bool {
                let timeout : Nat64 = (3 * 60 * 1_000_000_000); // 3 mins

                if (Option.isNull(nodeMem.internals.refresh_idx)) return false;

                switch (nodeMem.internals.updating) {
                    case (#Init) {
                        nodeMem.internals.updating := #Calling(U.now());
                        return true;
                    };
                    case (#Calling(_)) {
                        return false; // If already in Calling state, do not proceed
                    };
                    case (#Done(ts)) {
                        if (U.now() >= ts + timeout) {
                            nodeMem.internals.updating := #Calling(U.now());
                            return true;
                        } else {
                            return false;
                        };
                    };
                };
            };

            public func node_done(nodeMem : Ver1.NodeMem) : () {
                nodeMem.internals.updating := #Done(U.now());
            };

            public func tx_sent(nodeMem : Ver1.NodeMem, txId : Nat64) : () {
                nodeMem.internals.refresh_idx := ?txId;
            };

            public func log_activity(nodeMem : Ver1.NodeMem, operation : Text, result : { #Ok; #Err : Text }) : () {
                let log = Buffer.fromArray<Ver1.Activity>(nodeMem.log);

                switch (result) {
                    case (#Ok(())) {
                        log.add(#Ok({ operation = operation; timestamp = U.now() }));
                    };
                    case (#Err(msg)) {
                        log.add(#Err({ operation = operation; msg = msg; timestamp = U.now() }));
                    };
                };

                if (log.size() > 10) {
                    ignore log.remove(0); // remove 1 item from the beginning
                };

                nodeMem.log := Buffer.toArray(log);
            };
        };
    };
};
