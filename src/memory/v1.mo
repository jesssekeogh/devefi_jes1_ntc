import Map "mo:map/Map";
import MU "mo:mosup";

module {

    public type Mem = {
        main : Map.Map<Nat32, CyclesNodeMem>;
    };

    public func new() : MU.MemShell<Mem> = MU.new<Mem>({
        main = Map.new<Nat32, CyclesNodeMem>();
    });

    public type CyclesNodeMem = {
        variables : {};
    };

};
