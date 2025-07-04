import Map "mo:map/Map";
import MU "mo:mosup";

module {

    public type Mem = {
        main : Map.Map<Nat32, RedeemNodeMem>;
    };

    public func new() : MU.MemShell<Mem> = MU.new<Mem>({
        main = Map.new<Nat32, RedeemNodeMem>();
    });

    public type RedeemNodeMem = {
        variables : {}; // allow to set minimum redeem amount
        internals : {
            var updating : UpdatingStatus;
        };
        var log : [Activity];
    };

    public type UpdatingStatus = {
        #Init;
        #Calling : Nat64;
        #Done : Nat64;
    };

    public type Activity = {
        #Ok : { operation : Text; timestamp : Nat64 };
        #Err : { operation : Text; msg : Text; timestamp : Nat64 };
    };

};
