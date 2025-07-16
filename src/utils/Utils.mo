import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import Nat8 "mo:base/Nat8";
import IterTools "mo:itertools/Iter";

module Utils = {

    // Works the same as `canisterToSubaccount`
    public func principalToSubaccount(canister_id : Principal) : Blob {
        // Convert principal to array of Nat8
        let arr = Principal.toBlob(canister_id) |> Blob.toArray(_);

        // Prepend length and pad to 32 bytes, then convert back to Blob
        Iter.fromArray(arr)
        |> IterTools.prepend(Nat8.fromNat(arr.size()), _)
        |> IterTools.pad<Nat8>(_, 32, 0)
        |> Iter.toArray(_)
        |> Blob.fromArray(_);
    };

};
