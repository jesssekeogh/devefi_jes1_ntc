import MU "mo:mosup";
import Map "mo:map/Map";
import Principal "mo:base/Principal";
import Nat64 "mo:base/Nat64";
import Error "mo:base/Error";
import Option "mo:base/Option";
import Buffer "mo:base/Buffer";
import Ledgers "mo:devefi/ledgers";
import Core "mo:devefi/core";
import U "mo:devefi/utils";
import Ver1 "./memory/v1";
import I "./interface";
import Utils "../utils/Utils";
import NtcMinterInterface "../interfaces/ntc_minter";
import CyclesMintingInterface "../interfaces/cycles_minting";
import Cycles "mo:base/ExperimentalCycles";

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
        dvf : Ledgers.Ledgers;
    }) : T.Class<I.CreateRequest, I.ModifyRequest, I.Shared> {

        let mem = MU.access(xmem);

        public type NodeMem = Ver1.NodeMem;

        let IcpLedger = Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai");

        let CmcMinter = actor ("rkp4c-7iaaa-aaaaa-aaaca-cai") : CyclesMintingInterface.Self;

        // PRODUCTION ENVIRONMENT (uncomment for production deployment):

        // let NtcLedger = Principal.fromText("7dx3o-7iaaa-aaaal-qsrdq-cai");
        // let NtcMinter = actor ("7ew52-sqaaa-aaaal-qsrda-cai") : NtcMinterInterface.Self;

        // TESTING ENVIRONMENT (comment out for production):

        let NtcLedger = Principal.fromText("txyno-ch777-77776-aaaaq-cai");
        let NtcMinter = actor ("vjwku-z7777-77776-aaaua-cai") : NtcMinterInterface.Self;

        let MINIMUM_MINT : Nat = 100_000_000; // 1 ICP

        let CYCLES_BALANCE_THRESHOLD : Nat = 20_000_000_000_000; // 20 T

        let NOTIFY_TOP_UP_MEMO : Blob = "\54\50\55\50\00\00\00\00";

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
                        transaction_fee = #flat_fee_multiplier(20); // 0.1 NTC
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

        // set the callback to save any block index
        dvf.onEvent(
            func(event) {
                let #sent({ id; ledger; block_id }) = event else return;

                if (ledger != IcpLedger) return;

                label vec_loop for ((vid, nodeMem) in Map.entries(mem.main)) {
                    let ?vec_tx_id = nodeMem.internals.tx_idx else continue vec_loop;
                    if (vec_tx_id == id) nodeMem.internals.block_idx := ?block_id;
                };
            }
        );

        module Run {
            public func single(vid : T.NodeId, vec : T.NodeCoreMem, nodeMem : NodeMem) : () {
                let ?sourceMint = core.getSource(vid, vec, 0) else return;
                let mintBal = core.Source.balance(sourceMint);
                let mintFee = core.Source.fee(sourceMint);

                // only try send when a tx is not already in progress
                if (mintBal > mintFee + MINIMUM_MINT and Option.isNull(nodeMem.internals.tx_idx)) {
                    let #ok(intent) = core.Source.Send.intent(
                        sourceMint,
                        #external_account(#icrc({ owner = Principal.fromActor(CmcMinter); subaccount = ?Utils.principalToSubaccount(core.getThisCan()) })),
                        mintBal,
                        ?NOTIFY_TOP_UP_MEMO,
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
                        null,
                    ) else return;

                    ignore core.Source.Send.commit(intent);
                };
            };

            public func singleAsync(vid : T.NodeId, vec : T.NodeCoreMem, nodeMem : NodeMem) : async* () {
                try {
                    await* NtcMintingActions.top_up(nodeMem, vid);
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
                    var tx_idx = null;
                    var block_idx = null;
                    var cycles_to_send = null;
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
                    tx_idx = t.internals.tx_idx;
                    block_idx = t.internals.block_idx;
                    cycles_to_send = t.internals.cycles_to_send;
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

        module NodeUtils {
            public func node_ready(nodeMem : Ver1.NodeMem) : Bool {
                let timeout : Nat64 = (3 * 60 * 1_000_000_000); // 3 mins

                if (Option.isNull(nodeMem.internals.block_idx)) return false;

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
                nodeMem.internals.tx_idx := ?txId;
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

        module NtcMintingActions {
            public func top_up(nodeMem : NodeMem, vid : T.NodeId) : async* () {
                let ?blockIdx = nodeMem.internals.block_idx else return;
                if (Option.isSome(nodeMem.internals.cycles_to_send)) return; // already topped up

                switch (await CmcMinter.notify_top_up({ block_index = Nat64.fromNat(blockIdx); canister_id = core.getThisCan() })) {
                    case (#Ok(cycles)) {
                        nodeMem.internals.cycles_to_send := ?cycles;
                        NodeUtils.log_activity(nodeMem, "top_up", #Ok());
                    };
                    case (#Err(err)) {
                        switch (err) {
                            case (#Refunded(_)) {
                                // If refunded - for whatever reason, reset the transaction index and block index
                                nodeMem.internals.block_idx := null;
                                nodeMem.internals.tx_idx := null;
                                NodeUtils.log_activity(nodeMem, "top_up", #Err(debug_show err));
                            };
                            case (_) {
                                // For any other error, we log it and allow the vector to retry
                                NodeUtils.log_activity(nodeMem, "top_up", #Err(debug_show err));
                            };
                        };
                    };
                };
            };

            public func mint_ntc(nodeMem : NodeMem, vid : T.NodeId, vec : T.NodeCoreMem) : async* () {
                let ?cyclesToMint = nodeMem.internals.cycles_to_send else return;
                let ?toSourceAccount = core.getSourceAccountIC(vec, 1) else return;

                let balance = Cycles.balance();

                if (balance < cyclesToMint + CYCLES_BALANCE_THRESHOLD) {
                    NodeUtils.log_activity(nodeMem, "mint_ntc", #Err("Not enough cycles to mint NTC"));
                    return;
                };

                await (with cycles = cyclesToMint) NtcMinter.mint(toSourceAccount); // traps if there is an issue
                NodeUtils.log_activity(nodeMem, "mint_ntc", #Ok());
                nodeMem.internals.block_idx := null;
                nodeMem.internals.tx_idx := null;
                nodeMem.internals.cycles_to_send := null;
            };

        };
    };

};
