import ICRCLedger "mo:devefi-icrc-ledger";
import ICPLedger "mo:devefi-icp-ledger";
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
import CyclesMintingInterface "./interfaces/cycles_minting";

actor class NtcMinter() = this {

    let ONE_NTC = 1_000_000_000_000; // 12 decimals

    let ONE_ICP : Nat = 100_000_000;

    let MAX_SEND_CALLS = 10;

    let NOTIFY_TOP_UP_MEMO : Blob = "\54\50\55\50\00\00\00\00";

    let NTC_ledger_id = "ueyo2-wx777-77776-aaatq-cai"; // TODO: replace with the actual NTC ledger ID in production
    let ICP_ledger_id = "ryjl3-tyaaa-aaaaa-aaaba-cai";

    let CmcMinter = actor ("rkp4c-7iaaa-aaaaa-aaaca-cai") : CyclesMintingInterface.Self;
    let IcManagement : IC.Self = actor ("aaaaa-aa");

    stable let NTC_mem_v1 = ICRCLedger.Mem.Ledger.V1.new();
    let NTC_ledger = ICRCLedger.Ledger<system>(NTC_mem_v1, NTC_ledger_id, #last, Principal.fromActor(this));

    stable let ICP_mem_v1 = ICPLedger.Mem.Ledger.V1.new();
    stable let ICP_mem_v2 = ICPLedger.Mem.Ledger.V2.upgrade(ICP_mem_v1);
    let ICP_ledger = ICPLedger.Ledger<system>(ICP_mem_v2, ICP_ledger_id, #last, Principal.fromActor(this));

    type NtcRedeemRequest = {
        amount : Nat;
        canister : Principal;
        var retry : Nat;
    };

    type NtcMintRequest = {
        to : Account.Account;
        var block_index : ?Nat;
        var retry : Nat;
    };

    public type NtcRedeemRequestShared = {
        amount : Nat;
        canister : Principal;
        retry : Nat;
    };

    public type NtcMintRequestShared = {
        to : Account.Account;
        block_index : ?Nat;
        retry : Nat;
    };

    public type Stats = {
        cycles_balance : Nat;
        ntc_redeem_requests_in_progress : [(Nat64, NtcRedeemRequestShared)];
        ntc_mint_requests_in_progress : [(Nat64, NtcMintRequestShared)];
    };

    stable let ntc_redeem_requests = BTree.init<Nat64, NtcRedeemRequest>(?32);
    stable let ntc_mint_requests = BTree.init<Nat64, NtcMintRequest>(?32);

    public func mint_ntc(to : Account.Account) : async Result.Result<(), Text> {
        // Here we accept native cycles to mint NTC
        let received = Cycles.accept<system>(Cycles.available());
        if (received < ONE_NTC) return #err("Not enough cycles received. Required: " # debug_show (ONE_NTC) # ", received: " # debug_show (received));

        // Mint
        ignore NTC_ledger.send({
            to = #icrc(to);
            amount = received;
            from_subaccount = null;
            memo = null;
        });

        return #ok();
    };

    public query func get_ntc_stats() : async Stats {
        let redeem_requests = BTree.toArray<Nat64, NtcRedeemRequest>(ntc_redeem_requests);
        let mint_requests = BTree.toArray<Nat64, NtcMintRequest>(ntc_mint_requests);

        {
            cycles_balance = Cycles.balance();
            ntc_redeem_requests_in_progress = Array.map<(Nat64, NtcRedeemRequest), (Nat64, NtcRedeemRequestShared)>(
                redeem_requests,
                func((id, req)) : (Nat64, NtcRedeemRequestShared) {
                    (
                        id,
                        {
                            amount = req.amount;
                            canister = req.canister;
                            retry = req.retry;
                        },
                    );
                },
            );
            ntc_mint_requests_in_progress = Array.map<(Nat64, NtcMintRequest), (Nat64, NtcMintRequestShared)>(
                mint_requests,
                func((id, req)) : (Nat64, NtcMintRequestShared) {
                    (
                        id,
                        {
                            to = req.to;
                            block_index = req.block_index;
                            retry = req.retry;
                        },
                    );
                },
            );
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
            if (BTree.size(ntc_redeem_requests) == 0) return;

            var processing = List.nil<(async (), Nat64, NtcRedeemRequest)>();

            var i = 0;

            label sendloop while (i < MAX_SEND_CALLS) {
                let ?(id, request) = BTree.max<Nat64, NtcRedeemRequest>(ntc_redeem_requests) else continue sendloop;

                if (Cycles.balance() < request.amount) continue sendloop; // If we don't have enough cycles, wait for the ICP to be burned. Make sure we don't delete requests.

                // Now that we've confirmed we have enough cycles, delete the entry
                ignore BTree.deleteMax<Nat64, NtcRedeemRequest>(ntc_redeem_requests, Nat64.compare);

                processing := List.push(((with cycles = request.amount) IcManagement.deposit_cycles({ canister_id = request.canister }), id, request), processing);
                i += 1;
            };

            label awaitreq for ((promise, id, req) in List.toIter(processing)) {
                try {
                    let _myrefill = await promise;
                } catch (_e) {
                    // We read it to the queue, but with a lower id
                    if (req.retry > 10) continue awaitreq;
                    let new_id : Nat64 = ((id >> 32) / 2) << 32 | id;
                    req.retry += 1;
                    ignore BTree.insert<Nat64, NtcRedeemRequest>(ntc_redeem_requests, Nat64.compare, new_id, req);
                };
            };

        },
    );

    ignore Timer.recurringTimer<system>(
        #seconds(30),
        func() : async () {
            if (BTree.size(ntc_mint_requests) == 0) return;

            var processing = List.nil<(async CyclesMintingInterface.NotifyTopUpResult, Nat64, NtcMintRequest)>();

            var i = 0;

            label sendloop while (i < MAX_SEND_CALLS) {
                let ?(id, request) = BTree.max<Nat64, NtcMintRequest>(ntc_mint_requests) else continue sendloop;
                let ?blockid = request.block_index else return;

                ignore BTree.deleteMax<Nat64, NtcMintRequest>(ntc_mint_requests, Nat64.compare);

                processing := List.push((CmcMinter.notify_top_up({ block_index = Nat64.fromNat(blockid); canister_id = Principal.fromActor(this) }), id, request), processing);
                i += 1;
            };

            label awaitreq for ((promise, id, req) in List.toIter(processing)) {
                try {
                    switch (await promise) {
                        case (#Ok(cycles)) {
                            ignore NTC_ledger.send({
                                to = #icrc(req.to);
                                amount = cycles;
                                from_subaccount = null;
                                memo = null;
                            });
                        };
                        case (#Err(_)) {
                            // We read it to the queue, but with a lower id
                            if (req.retry > 10) continue awaitreq;
                            let new_id : Nat64 = ((id >> 32) / 2) << 32 | id;
                            req.retry += 1;
                            ignore BTree.insert<Nat64, NtcMintRequest>(ntc_mint_requests, Nat64.compare, new_id, req);
                        };
                    }

                } catch (_e) {
                    // We read it to the queue, but with a lower id
                    if (req.retry > 10) continue awaitreq;
                    let new_id : Nat64 = ((id >> 32) / 2) << 32 | id;
                    req.retry += 1;
                    ignore BTree.insert<Nat64, NtcMintRequest>(ntc_mint_requests, Nat64.compare, new_id, req);
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
        func(tx) {
            // Strategy: Unlike the TCycles ledger, we will retry refilling the canister.
            // If it doesn't work, the NTC gets burned. No NTC is returned if the subaccount is not a valid canister.

            // Here we convert the subaccount to a canister and send cycles while burning the NTC.
            // We are adding these requests to a queue.

            // We send from bal, meaning if the user sends below the threshold they can later send more and the redeem will process.
            let ?subaccount = tx.to.subaccount else return;
            let bal = NTC_ledger.balance(?subaccount);

            if (bal < ONE_NTC) return;

            // Burn NTC by sending it to the minter
            let ?minter = NTC_ledger.getMinter() else return;
            let #ok(send_idx) = NTC_ledger.send({
                to = #icrc(minter);
                amount = bal;
                from_subaccount = ?subaccount;
                memo = null;
            }) else return;

            // We add them based on balance and request id so we can pick the largest requests first
            let id : Nat64 = ((Nat64.fromNat(bal) / 1_0000_0000) << 32) | send_idx;
            ignore BTree.insert<Nat64, NtcRedeemRequest>(
                ntc_redeem_requests,
                Nat64.compare,
                id,
                {
                    amount = bal;
                    canister = subaccountToCanister(Blob.toArray(subaccount));
                    var retry = 0;
                },
            );
        }
    );

    ICP_ledger.onReceive(
        func(tx) {
            let #icrc(from) = tx.from else return;
            let subaccount = switch (tx.memo) {
                case (?memo) {
                    if (memo.size() == 32) { ?memo } else { return } // Ensure the memo is a valid subaccount
                };
                case (null) { null };
            };

            let bal = ICP_ledger.balance(subaccount);

            if (bal < ONE_ICP) return;

            let #ok(send_idx) = ICP_ledger.send({
                to = #icrc({
                    owner = Principal.fromActor(CmcMinter);
                    subaccount = ?canisterToSubaccount(Principal.fromActor(this));
                });
                amount = bal;
                from_subaccount = null;
                memo = ?NOTIFY_TOP_UP_MEMO;
            }) else return;

            // We add them based on balance and request id so we can pick the largest requests first
            let id : Nat64 = ((Nat64.fromNat(bal) / 1_0000_0000) << 32) | send_idx;
            ignore BTree.insert<Nat64, NtcMintRequest>(
                ntc_mint_requests,
                Nat64.compare,
                id,
                {
                    to = { owner = from.owner; subaccount = subaccount };
                    var block_index = null;
                    var retry = 0;
                },
            );
        }
    );

    ICP_ledger.onSent(
        func(txid, blockid) {
            let ?mint_request = BTree.get<Nat64, NtcMintRequest>(ntc_mint_requests, Nat64.compare, txid) else return;
            mint_request.block_index := ?blockid;
        }
    );

};
