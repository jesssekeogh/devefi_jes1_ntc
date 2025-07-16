module {
  public type Account = { owner : Principal; subaccount : ?Blob };
  public type GetNtcRequestsResponse = {
    ntc_requests : [
      (Nat64, { canister : Principal; amount : Nat; retry : Nat })
    ];
    total_pages_available : ?Nat64;
  };
  public type Result = { #ok; #err : Text };
  public type Stats = { cycles_balance : Nat };
  public type Self = actor {
    get_ntc_requests : shared query {
        page_size : ?Nat64;
        page_number : ?Nat64;
      } -> async GetNtcRequestsResponse;
    get_ntc_stats : shared query () -> async Stats;
    get_redeem_account : shared query Principal -> async (Account, Text);
    mint_ntc : shared Account -> async Result;
  }
}