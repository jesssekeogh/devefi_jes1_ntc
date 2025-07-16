import ICRC55 "mo:devefi/ICRC55";
import Core "mo:devefi/core";
import NtcMintVector "../../src/mint";
import NtcRedeemVector "../../src/redeem";
import Result "mo:base/Result";
import Debug "mo:base/Debug";

module {

    public type CreateRequest = {
        #devefi_jes1_ntcmint : NtcMintVector.Interface.CreateRequest;
        #devefi_jes1_ntcredeem : NtcRedeemVector.Interface.CreateRequest;
    };

    public type Shared = {
        #devefi_jes1_ntcmint : NtcMintVector.Interface.Shared;
        #devefi_jes1_ntcredeem : NtcRedeemVector.Interface.Shared;
    };

    public type ModifyRequest = {
        #devefi_jes1_ntcmint : NtcMintVector.Interface.ModifyRequest;
        #devefi_jes1_ntcredeem : NtcRedeemVector.Interface.ModifyRequest;
    };

    public class VectorModules(
        m : {
            devefi_jes1_ntcmint : NtcMintVector.Mod;
            devefi_jes1_ntcredeem : NtcRedeemVector.Mod;

        }
    ) {

        public func get(mid : Core.ModuleId, id : Core.NodeId, vec : Core.NodeMem) : Result.Result<Shared, Text> {

            if (mid == NtcMintVector.ID) {
                switch (m.devefi_jes1_ntcmint.get(id, vec)) {
                    case (#ok(x)) return #ok(#devefi_jes1_ntcmint(x));
                    case (#err(x)) return #err(x);
                };
            };

            if (mid == NtcRedeemVector.ID) {
                switch (m.devefi_jes1_ntcredeem.get(id, vec)) {
                    case (#ok(x)) return #ok(#devefi_jes1_ntcredeem(x));
                    case (#err(x)) return #err(x);
                };
            };

            #err("Unknown variant");
        };

        public func getDefaults(mid : Core.ModuleId) : CreateRequest {
            if (mid == NtcMintVector.ID) return #devefi_jes1_ntcmint(m.devefi_jes1_ntcmint.defaults());
            if (mid == NtcRedeemVector.ID) return #devefi_jes1_ntcredeem(m.devefi_jes1_ntcredeem.defaults());
            Debug.trap("Unknown variant");

        };

        public func sources(mid : Core.ModuleId, id : Core.NodeId) : Core.EndpointsDescription {
            if (mid == NtcMintVector.ID) return m.devefi_jes1_ntcmint.sources(id);
            if (mid == NtcRedeemVector.ID) return m.devefi_jes1_ntcredeem.sources(id);
            Debug.trap("Unknown variant");

        };

        public func destinations(mid : Core.ModuleId, id : Core.NodeId) : Core.EndpointsDescription {
            if (mid == NtcMintVector.ID) return m.devefi_jes1_ntcmint.destinations(id);
            if (mid == NtcRedeemVector.ID) return m.devefi_jes1_ntcredeem.destinations(id);
            Debug.trap("Unknown variant");
        };

        public func create(id : Core.NodeId, creq : Core.CommonCreateRequest, req : CreateRequest) : Result.Result<Core.ModuleId, Text> {

            switch (req) {
                case (#devefi_jes1_ntcmint(t)) return m.devefi_jes1_ntcmint.create(id, creq, t);
                case (#devefi_jes1_ntcredeem(t)) return m.devefi_jes1_ntcredeem.create(id, creq, t);
            };
            #err("Unknown variant or mismatch");
        };

        public func modify(mid : Core.ModuleId, id : Core.NodeId, creq : ModifyRequest) : Result.Result<(), Text> {
            switch (creq) {
                case (#devefi_jes1_ntcmint(r)) if (mid == NtcMintVector.ID) return m.devefi_jes1_ntcmint.modify(id, r);
                case (#devefi_jes1_ntcredeem(r)) if (mid == NtcRedeemVector.ID) return m.devefi_jes1_ntcredeem.modify(id, r);
            };
            #err("Unknown variant or mismatch");
        };

        public func delete(mid : Core.ModuleId, id : Core.NodeId) : Result.Result<(), Text> {
            if (mid == NtcMintVector.ID) return m.devefi_jes1_ntcmint.delete(id);
            if (mid == NtcRedeemVector.ID) return m.devefi_jes1_ntcredeem.delete(id);
            Debug.trap("Unknown variant");
        };

        public func nodeMeta(mid : Core.ModuleId) : ICRC55.ModuleMeta {
            if (mid == NtcMintVector.ID) return m.devefi_jes1_ntcmint.meta();
            if (mid == NtcRedeemVector.ID) return m.devefi_jes1_ntcredeem.meta();
            Debug.trap("Unknown variant");
        };

        public func meta() : [ICRC55.ModuleMeta] {
            [
                m.devefi_jes1_ntcmint.meta(),
                m.devefi_jes1_ntcredeem.meta(),
            ];
        };

    };
};
