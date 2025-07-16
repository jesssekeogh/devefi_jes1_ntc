import ICRCLedger "mo:devefi-icrc-ledger";
import IC "./interfaces/ic";
import Principal "mo:base/Principal";
import Account "mo:account";
import Timer "mo:base/Timer";
import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Cycles "mo:base/ExperimentalCycles";
import BTree "mo:stableheapbtreemap/BTree";
import Nat64 "mo:base/Nat64";
import IterTools "mo:itertools/Iter";
import List "mo:base/List";
import Result "mo:base/Result";
import Nat8 "mo:base/Nat8";

actor class NtcMinter() = this {

    let ONE_NTC = 1_000_000_000_000; // 12 decimals
    let NTC_ledger_id = "n6tkf-tqaaa-aaaal-qsneq-cai"; // Ledger needs to be 12 decimals

    stable let NTC_mem_v1 = ICRCLedger.Mem.Ledger.V1.new();
    let NTC_ledger = ICRCLedger.Ledger<system>(NTC_mem_v1, NTC_ledger_id, #last, Principal.fromActor(this));

    private let ic : IC.Self = actor ("aaaaa-aa");

    type NTC2Can_request = {
        amount : Nat;
        canister : Principal;
        var retry : Nat;
    };

    stable let NTC2Can_requests = BTree.init<Nat64, NTC2Can_request>(?32); // 32 is the order, or the size of each BTree node

    private func canisterToSubaccount(canister_id : Principal) : Blob {
        // Convert principal to array of Nat8
        let arr = Principal.toBlob(canister_id) |> Blob.toArray(_);

        // Prepend length and pad to 32 bytes, then convert back to Blob
        Iter.fromArray(arr)
        |> IterTools.prepend(Nat8.fromNat(arr.size()), _)
        |> IterTools.pad<Nat8>(_, 32, 0)
        |> Iter.toArray(_)
        |> Blob.fromArray(_);
    };

    private func subaccountToCanister(subaccount : [Nat8]) : Principal {
        Array.subArray<Nat8>(subaccount, 1, 29)
        |> Blob.fromArray(_)
        |> Principal.fromBlob(_);
    };

    stable var unique_request_id : Nat32 = 0;
    let MAX_CYCLE_SEND_CALLS = 10;

    ignore Timer.recurringTimer<system>(
        #seconds(6),
        func() : async () {

            var processing = List.nil<(async (), Nat64, NTC2Can_request)>();

            var i = 0;
            // Make it send MAX_CYCLE_SEND_CALLS requests at a time and then await all
            label sendloop while (i < MAX_CYCLE_SEND_CALLS) {
                let ?(id, request) = BTree.deleteMax<Nat64, NTC2Can_request>(NTC2Can_requests, Nat64.compare) else continue sendloop;

                if (Cycles.balance() < request.amount) continue sendloop; // If we don't have enough cycles, wait for the ICP to be burned. Make sure we don't delete requests.

                processing := List.push(((with cycles = request.amount) ic.deposit_cycles({ canister_id = request.canister }), id, request), processing);
                i += 1;
            };

            label awaitreq for ((promise, id, req) in List.toIter(processing)) {
                // Await results of all promises
                try {
                    // Q: Can this even trap? When?
                    let _myrefill = await promise; // Await the promise to get the tick data
                } catch (_e) {
                    // Q: If it traps, does it mean we are 100% sure the cycles didn't get sent?
                    // We readd it to the queue, but with a lower id
                    if (req.retry > 10) continue awaitreq;
                    let new_id : Nat64 = ((id >> 32) / 2) << 32 | Nat64.fromNat32(unique_request_id);
                    req.retry += 1;
                    ignore BTree.insert<Nat64, NTC2Can_request>(NTC2Can_requests, Nat64.compare, new_id, req);
                    unique_request_id += 1;
                };
            };

        },
    );

    NTC_ledger.onReceive(
        func(t) {
            // Strategy: Unlike TCycles ledger, we will retry refilling the canister
            // if it doesn't work, the NTC gets burned. No NTC is gets returned if the subaccount is not a valid canister.

            // Here we can convert the subaccount to a canister and send cycles while burning the NTC
            // We are adding these requests to a queue
            if (t.amount < 200000) return;
            let ?subaccount = t.to.subaccount else return;

            // We add them based on amount and request id so we can pick the largest requests first
            let id : Nat64 = ((Nat64.fromNat(t.amount) / 1_0000_0000) << 32) | Nat64.fromNat32(unique_request_id);
            ignore BTree.insert<Nat64, NTC2Can_request>(
                NTC2Can_requests,
                Nat64.compare,
                id,
                {
                    amount = t.amount;
                    canister = subaccountToCanister(Blob.toArray(subaccount));
                    var retry = 0;
                },
            );
            unique_request_id += 1;

            // Burn
            ignore do ? {
                ignore NTC_ledger.send({
                    to = NTC_ledger.getMinter()!;
                    amount = t.amount;
                    from_subaccount = ?subaccount;
                });
            };

        }
    );

    public func mint_ntc(to : Account.Account) : async Result.Result<(), Text> {
        // Here we accept native cycles to mint NTC
        let received = Cycles.accept<system>(Cycles.available());
        if (received < ONE_NTC) return #err("Not enough cycles received. Required: " # debug_show (ONE_NTC) # ", received: " # debug_show (received));

        // Mint
        ignore NTC_ledger.send({
            to = to;
            amount = received;
            from_subaccount = null;
        });

        return #ok();
    };

    type Stats = {
        cycles_balance : Nat;
    };

    public query func get_stats() : async Stats {
        {
            cycles_balance = Cycles.balance();
        };
    };

    public query func get_account(canister_id : Principal) : async (Account.Account, Text) {
        let acc : Account.Account = {
            owner = Principal.fromActor(this);
            subaccount = ?canisterToSubaccount(canister_id);
        };
        (
            acc,
            Account.toText(acc),
        );
    }

};
