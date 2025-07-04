import U "mo:devefi/utils";
import MU "mo:mosup";
import Map "mo:map/Map";
import Principal "mo:base/Principal";
import Option "mo:base/Option";
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

    public let ID = "devefi_jes1_cycles";

    public class Mod({
        xmem : MU.MemShell<M.Mem>;
        core : Core.Mod;
    }) : T.Class<I.CreateRequest, I.ModifyRequest, I.Shared> {

        let mem = MU.access(xmem);

        public type CyclesNodeMem = Ver1.CyclesNodeMem;

        public func meta() : T.Meta {
            {
                id = ID; // This has to be same as the variant in vec.custom
                name = "Cycles";
                author = "jes1";
                description = "Mint and deliver cycles to your canisters";
                supported_ledgers = []; // all pylon ledgers
                version = #beta([0, 1, 0]);
                create_allowed = true;
                ledger_slots = [
                    "Cycles"
                ];
                billing = []; // TBD
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
                if (vec.billing.frozen) continue vec_loop; // don't run if frozen
                if (Option.isSome(vec.billing.expires)) continue vec_loop;
                Run.single(vid, vec, nodeMem);
            };
        };

        // public func runAsync() : async* () {
        //     label vec_loop for ((vid, nodeMem) in Map.entries(mem.main)) {
        //         let ?vec = core.getNodeById(vid) else continue vec_loop;
        //         if (not vec.active) continue vec_loop;
        //         if (vec.billing.frozen) continue vec_loop;
        //         if (Option.isSome(vec.billing.expires)) continue vec_loop;
        //         if (NodeUtils.node_ready(nodeMem)) {
        //             await* Run.singleAsync(vid, vec, nodeMem);
        //             return; // return after finding the first ready node
        //         };
        //     };
        // };

        module Run {
            public func single(vid : T.NodeId, vec : T.NodeCoreMem, nodeMem : CyclesNodeMem) : () {};

            public func singleAsync(vid : T.NodeId, vec : T.NodeCoreMem, nodeMem : CyclesNodeMem) : async* () {};
        };

        public func create(vid : T.NodeId, _req : T.CommonCreateRequest, t : I.CreateRequest) : T.Create {
            let nodeMem : CyclesNodeMem = {
                variables = {};
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
            };
        };

        public func defaults() : I.CreateRequest {
            {
                variables = {};
            };
        };

        public func sources(_id : T.NodeId) : T.Endpoints {
            [(0, "Stake"), (0, "_Maturity")];
        };

        public func destinations(_id : T.NodeId) : T.Endpoints {
            [(0, "Maturity"), (0, "Disburse")];
        };

    };
};
