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

    let MAX_CYCLE_SEND_CALLS = 10;

    let NTC_ledger_id = "ueyo2-wx777-77776-aaatq-cai"; // TODO: replace with the actual NTC ledger ID in production

    private let ic : IC.Self = actor ("aaaaa-aa");

    stable let NTC_mem_v1 = ICRCLedger.Mem.Ledger.V1.new();
    let NTC_ledger = ICRCLedger.Ledger<system>(NTC_mem_v1, NTC_ledger_id, #last, Principal.fromActor(this));

    type NtcRedeemRequest = {
        amount : Nat;
        canister : Principal;
        var retry : Nat;
    };

    type Stats = {
        cycles_balance : Nat;
    };

    type GetNtcRequestsResponse = {
        ntc_requests : [(Nat64, { amount : Nat; canister : Principal; retry : Nat })];
        total_pages_available : ?Nat64;
    };

    stable let ntc_requests = BTree.init<Nat64, NtcRedeemRequest>(?32); // 32 is the order, or the size of each BTree node

    stable var unique_request_id : Nat32 = 0;

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

    public query func get_ntc_stats() : async Stats {
        {
            cycles_balance = Cycles.balance();
        };
    };

    public query func get_ntc_requests({
        page_size : ?Nat64;
        page_number : ?Nat64;
    }) : async GetNtcRequestsResponse {
        let page_size_val = switch (page_size) {
            case (?s) { 
                let size = Nat64.toNat(s);
                if (size > 0 and size <= 1000) size else 100;
            };
            case (_) 100; // Default page size
        };
        
        let page_number_val = switch (page_number) {
            case (?p) Nat64.toNat(p);
            case (_) 0;
        };

        let all_entries = BTree.toArray<Nat64, NtcRedeemRequest>(ntc_requests);
        let total = all_entries.size();
        
        let total_pages = if (total == 0 or page_size_val == 0) {
            0
        } else {
            let full_pages = total / page_size_val;
            let has_remainder = total % page_size_val > 0;
            if (has_remainder) full_pages + 1 else full_pages
        };
        
        let start_index = Nat.min(page_number_val * page_size_val, total);
        let end_index = Nat.min(start_index + page_size_val, total);
        
        let page_entries = Array.tabulate<(Nat64, { amount : Nat; canister : Principal; retry : Nat })>(
            end_index - start_index,
            func(i) {
                let (id, req) = all_entries[start_index + i];
                (id, { amount = req.amount; canister = req.canister; retry = req.retry });
            }
        );
        
        {
            ntc_requests = page_entries;
            total_pages_available = if (total_pages == 0) null else ?Nat64.fromNat(total_pages);
        };
    };
    
    public query func get_redeem_account(canister_id : Principal) : async (Account.Account, Text) {
        let acc : Account.Account = {
            owner = Principal.fromActor(this);
            subaccount = ?canisterToSubaccount(canister_id);
        };
        (
            acc,
            Account.toText(acc),
        );
    };

    ignore Timer.recurringTimer<system>(
        #seconds(30),
        func() : async () {

            var processing = List.nil<(async (), Nat64, NtcRedeemRequest)>();

            var i = 0;

            // Make it send MAX_CYCLE_SEND_CALLS requests at a time and then await all
            label sendloop while (i < MAX_CYCLE_SEND_CALLS) {
                let ?(id, request) = BTree.max<Nat64, NtcRedeemRequest>(ntc_requests) else continue sendloop;

                if (Cycles.balance() < request.amount) continue sendloop; // If we don't have enough cycles, wait for the ICP to be burned. Make sure we don't delete requests.

                // Now that we've confirmed we have enough cycles, delete the entry
                ignore BTree.deleteMax<Nat64, NtcRedeemRequest>(ntc_requests, Nat64.compare);

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
                    // We read it to the queue, but with a lower id
                    if (req.retry > 10) continue awaitreq;
                    let new_id : Nat64 = ((id >> 32) / 2) << 32 | Nat64.fromNat32(unique_request_id);
                    req.retry += 1;
                    ignore BTree.insert<Nat64, NtcRedeemRequest>(ntc_requests, Nat64.compare, new_id, req);
                    unique_request_id += 1;
                };
            };

        },
    );

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

    NTC_ledger.onReceive(
        func(t) {
            // Strategy: Unlike the TCycles ledger, we will retry refilling the canister.
            // If it doesn't work, the NTC gets burned. No NTC is returned if the subaccount is not a valid canister.

            // Here we convert the subaccount to a canister and send cycles while burning the NTC.
            // We are adding these requests to a queue.

            // We send from bal, meaning if the user sends below the threshold they can later send more and the redeem will process.
            let ?subaccount = t.to.subaccount else return;
            let bal = NTC_ledger.balance(?subaccount);

             if (bal < ONE_NTC) return;

            // We add them based on balance and request id so we can pick the largest requests first
            let id : Nat64 = ((Nat64.fromNat(bal) / 1_0000_0000) << 32) | Nat64.fromNat32(unique_request_id);
            ignore BTree.insert<Nat64, NtcRedeemRequest>(
                ntc_requests,
                Nat64.compare,
                id,
                {
                    amount = bal;
                    canister = subaccountToCanister(Blob.toArray(subaccount));
                    var retry = 0;
                },
            );
            unique_request_id += 1;

            // Burn
            ignore do ? {
                ignore NTC_ledger.send({
                    to = NTC_ledger.getMinter()!;
                    amount = bal;
                    from_subaccount = ?subaccount;
                });
            };

        }
    );

};
