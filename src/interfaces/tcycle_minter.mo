module {
  public type BlockIndex = Nat;
  public type BlockIndex__1 = Nat64;
  public type NotifyError = {
    #Refunded : { block_index : ?BlockIndex__1; reason : Text };
    #InvalidTransaction : Text;
    #Other : { error_message : Text; error_code : Nat64 };
    #Processing;
    #TransactionTooOld : BlockIndex__1;
  };
  public type NotifyMintCyclesResult = {
    #Ok : NotifyMintCyclesSuccess;
    #Err : NotifyError;
  };
  public type NotifyMintCyclesSuccess = {
    balance : Nat;
    block_index : Nat;
    minted : Nat;
  };
  public type RejectionCode = {
    #NoError;
    #CanisterError;
    #SysTransient;
    #DestinationInvalid;
    #Unknown;
    #SysFatal;
    #CanisterReject;
  };
  public type WithdrawError = {
    #FailedToWithdraw : {
      rejection_code : RejectionCode;
      fee_block : ?Nat;
      rejection_reason : Text;
    };
    #GenericError : { message : Text; error_code : Nat };
    #TemporarilyUnavailable;
    #Duplicate : { duplicate_of : Nat };
    #BadFee : { expected_fee : Nat };
    #InvalidReceiver : { receiver : Principal };
    #CreatedInFuture : { ledger_time : Nat64 };
    #TooOld;
    #InsufficientFunds : { balance : Nat };
  };
  public type Self = actor {
    mint_tcycles : shared {
        to_subaccount : Blob;
      } -> async NotifyMintCyclesResult;
    redeem_tcycles : shared { to_canister : Principal } -> async {
        #Ok : BlockIndex;
        #Err : WithdrawError;
      };
  }
}