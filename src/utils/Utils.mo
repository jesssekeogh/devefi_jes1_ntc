import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Nat8 "mo:base/Nat8";
import IterTools "mo:itertools/Iter";

module Utils = {

    public func principalToSubaccount(principal : Principal) : Blob {
        // Convert principal to array of Nat8
        let arr = Principal.toBlob(principal) |> Blob.toArray(_);

        // Prepend length and pad to 32 bytes, then convert back to Blob
        Iter.fromArray(arr)
        |> IterTools.prepend(Nat8.fromNat(arr.size()), _)
        |> IterTools.pad<Nat8>(_, 32, 0)
        |> Iter.toArray(_)
        |> Blob.fromArray(_);
    };

    // NTC minter version
    public func canister2subaccount(canister_id : Principal) : Blob {
        let can = Blob.toArray(Principal.toBlob(canister_id));
        let size = can.size();
        let pad_start = 32 - size - 1 : Nat;
        Blob.fromArray(Iter.toArray(IterTools.flattenArray<Nat8>([Array.tabulate<Nat8>(pad_start, func _ = 0), can, [Nat8.fromNat(size)]])));
    };
};
