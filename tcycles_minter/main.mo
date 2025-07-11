import Principal "mo:base/Principal";
import Nat64 "mo:base/Nat64";
import TcyclesLedgerInterface "./interfaces/tcycles_ledger";
import IcpLedgerInterface "./interfaces/icp_ledger";
import CyclesMintingInterface "./interfaces/cycles_minting";
import ICRCLedger "mo:devefi-icrc-ledger";
import ICPLedger "mo:devefi-icp-ledger";

shared ({ caller = owner }) actor class TcyclesMinter({
    tcycles_ledger_id : Principal;
    pylon_id : Principal;
}) = this {

    let CyclesMinting = actor ("rkp4c-7iaaa-aaaaa-aaaca-cai") : CyclesMintingInterface.Self;
    let IcpLedger = actor ("ryjl3-tyaaa-aaaaa-aaaba-cai") : IcpLedgerInterface.Self;
    let CyclesLedger = actor (Principal.toText(tcycles_ledger_id)) : TcyclesLedgerInterface.Self;

    stable let icp_mem_v1 = ICPLedger.Mem.Ledger.V1.new();
    let icp_ledger = ICPLedger.Ledger<system>(icp_mem_v1, "ryjl3-tyaaa-aaaaa-aaaba-cai", #last, Principal.fromActor(this));

    stable let tcycles_mem_v1 = ICRCLedger.Mem.Ledger.V1.new();
    let tcycles_ledger = ICRCLedger.Ledger<system>(tcycles_mem_v1, Principal.toText(tcycles_ledger_id), #last, Principal.fromActor(this));

    // From here: https://forum.dfinity.org/t/a-couple-of-new-cmc-features-icrc-memo-and-automatic-refunds/41396
    let NOTIFY_MINT_CYCLES : Blob = "\4d\49\4e\54\00\00\00\00";

    tcycles_ledger.onReceive(
        func(tx) {
            let #icrc({ owner }) = tx.from else return;

            // minted
            if (owner == tcycles_ledger_id) { // TODO edit devefi lib to allow for this, add exception
                ignore tcycles_ledger.send({
                    from_subaccount = tx.to.subaccount;
                    to = { owner = pylon_id; subaccount = tx.to.subaccount };
                    amount = tx.amount;
                });
            };
        }
    );

    public func mint_tcycles({
        to_subaccount : Blob;
    }) : async CyclesMintingInterface.NotifyMintCyclesResult {
        let bal = icp_ledger.balance(?to_subaccount);
        let fee = icp_ledger.getFee();

        if (bal < fee) return #Err(#InvalidTransaction("Not enough ICP to mint Tcycles"));

        let transferResult = await IcpLedger.icrc1_transfer({
            to = {
                owner = Principal.fromActor(CyclesMinting);
                subaccount = ?Principal.toLedgerAccount(Principal.fromActor(this), null);
            };
            fee = null;
            memo = ?NOTIFY_MINT_CYCLES;
            from_subaccount = ?to_subaccount;
            created_at_time = null;
            amount = bal - fee;
        });

        switch (transferResult) {
            case (#Ok(block_idx)) {
                return await CyclesMinting.notify_mint_cycles({
                    block_index = Nat64.fromNat(block_idx);
                    deposit_memo = ?NOTIFY_MINT_CYCLES;
                    to_subaccount = ?to_subaccount;
                });
            };
            case (#Err(error)) {
                #Err(#InvalidTransaction(debug_show error));
            };
        };
    };

    public func redeem_tcycles({ to_canister : Principal }) : async {
        #Ok : TcyclesLedgerInterface.BlockIndex;
        #Err : TcyclesLedgerInterface.WithdrawError;
    } {
        let canisterSubaccount = Principal.toLedgerAccount(to_canister, null);
        let bal = tcycles_ledger.balance(?canisterSubaccount);
        let fee = tcycles_ledger.getFee();

        if (bal < fee) return #Err(#InsufficientFunds({ balance = bal }));

        return await CyclesLedger.withdraw({
            to = to_canister;
            from_subaccount = ?canisterSubaccount;
            created_at_time = null;
            amount = bal - fee;
        });
    };

};
