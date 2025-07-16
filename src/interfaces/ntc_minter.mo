module {
  public type Account = { owner : Principal; subaccount : ?Blob };
  public type Result = { #ok; #err : Text };
  public type Stats = { cycles_balance : Nat };
  public type Self = actor {
    get_account : shared query Principal -> async (Account, Text);
    get_stats : shared query () -> async Stats;
    mint_ntc : shared Account -> async Result;
  }
}