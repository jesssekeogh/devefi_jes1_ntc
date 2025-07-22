import Map "mo:map/Map";
import MU "mo:mosup";

module {

    public type Mem = {
        main : Map.Map<Nat32, NodeMem>;
    };

    public func new() : MU.MemShell<Mem> = MU.new<Mem>({
        main = Map.new<Nat32, NodeMem>();
    });

    // placeholders for if we want to add more adavnced async functionality later
    public type NodeMem = {
        internals : {};
    };

};
