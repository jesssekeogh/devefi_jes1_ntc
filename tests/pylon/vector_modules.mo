import ICRC55 "mo:devefi/ICRC55";
import Core "mo:devefi/core";
import TcyclesMintVector "../../src/Mint";
import TcyclesRedeemVector "../../src/Redeem";
import Result "mo:base/Result";
import Debug "mo:base/Debug";

module {

    public type CreateRequest = {
        #devefi_jes1_tcyclesmint : TcyclesMintVector.Interface.CreateRequest;
        #devefi_jes1_tcyclesredeem : TcyclesRedeemVector.Interface.CreateRequest;
    };

    public type Shared = {
        #devefi_jes1_tcyclesmint : TcyclesMintVector.Interface.Shared;
        #devefi_jes1_tcyclesredeem : TcyclesRedeemVector.Interface.Shared;
    };

    public type ModifyRequest = {
        #devefi_jes1_tcyclesmint : TcyclesMintVector.Interface.ModifyRequest;
        #devefi_jes1_tcyclesredeem : TcyclesRedeemVector.Interface.ModifyRequest;
    };

    public class VectorModules(
        m : {
            devefi_jes1_tcyclesmint : TcyclesMintVector.Mod;
            devefi_jes1_tcyclesredeem : TcyclesRedeemVector.Mod;

        }
    ) {

        public func get(mid : Core.ModuleId, id : Core.NodeId, vec : Core.NodeMem) : Result.Result<Shared, Text> {

            if (mid == TcyclesMintVector.ID) {
                switch (m.devefi_jes1_tcyclesmint.get(id, vec)) {
                    case (#ok(x)) return #ok(#devefi_jes1_tcyclesmint(x));
                    case (#err(x)) return #err(x);
                };
            };

            if (mid == TcyclesRedeemVector.ID) {
                switch (m.devefi_jes1_tcyclesredeem.get(id, vec)) {
                    case (#ok(x)) return #ok(#devefi_jes1_tcyclesredeem(x));
                    case (#err(x)) return #err(x);
                };
            };

            #err("Unknown variant");
        };

        public func getDefaults(mid : Core.ModuleId) : CreateRequest {
            if (mid == TcyclesMintVector.ID) return #devefi_jes1_tcyclesmint(m.devefi_jes1_tcyclesmint.defaults());
            if (mid == TcyclesRedeemVector.ID) return #devefi_jes1_tcyclesredeem(m.devefi_jes1_tcyclesredeem.defaults());
            Debug.trap("Unknown variant");

        };

        public func sources(mid : Core.ModuleId, id : Core.NodeId) : Core.EndpointsDescription {
            if (mid == TcyclesMintVector.ID) return m.devefi_jes1_tcyclesmint.sources(id);
            if (mid == TcyclesRedeemVector.ID) return m.devefi_jes1_tcyclesredeem.sources(id);
            Debug.trap("Unknown variant");

        };

        public func destinations(mid : Core.ModuleId, id : Core.NodeId) : Core.EndpointsDescription {
            if (mid == TcyclesMintVector.ID) return m.devefi_jes1_tcyclesmint.destinations(id);
            if (mid == TcyclesRedeemVector.ID) return m.devefi_jes1_tcyclesredeem.destinations(id);
            Debug.trap("Unknown variant");
        };

        public func create(id : Core.NodeId, creq : Core.CommonCreateRequest, req : CreateRequest) : Result.Result<Core.ModuleId, Text> {

            switch (req) {
                case (#devefi_jes1_tcyclesmint(t)) return m.devefi_jes1_tcyclesmint.create(id, creq, t);
                case (#devefi_jes1_tcyclesredeem(t)) return m.devefi_jes1_tcyclesredeem.create(id, creq, t);
            };
            #err("Unknown variant or mismatch");
        };

        public func modify(mid : Core.ModuleId, id : Core.NodeId, creq : ModifyRequest) : Result.Result<(), Text> {
            switch (creq) {
                case (#devefi_jes1_tcyclesmint(r)) if (mid == TcyclesMintVector.ID) return m.devefi_jes1_tcyclesmint.modify(id, r);
                case (#devefi_jes1_tcyclesredeem(r)) if (mid == TcyclesRedeemVector.ID) return m.devefi_jes1_tcyclesredeem.modify(id, r);
            };
            #err("Unknown variant or mismatch");
        };

        public func delete(mid : Core.ModuleId, id : Core.NodeId) : Result.Result<(), Text> {
            if (mid == TcyclesMintVector.ID) return m.devefi_jes1_tcyclesmint.delete(id);
            if (mid == TcyclesRedeemVector.ID) return m.devefi_jes1_tcyclesredeem.delete(id);
            Debug.trap("Unknown variant");
        };

        public func nodeMeta(mid : Core.ModuleId) : ICRC55.ModuleMeta {
            if (mid == TcyclesMintVector.ID) return m.devefi_jes1_tcyclesmint.meta();
            if (mid == TcyclesRedeemVector.ID) return m.devefi_jes1_tcyclesredeem.meta();
            Debug.trap("Unknown variant");
        };

        public func meta() : [ICRC55.ModuleMeta] {
            [
                m.devefi_jes1_tcyclesmint.meta(),
                m.devefi_jes1_tcyclesredeem.meta(),
            ];
        };

    };
};
