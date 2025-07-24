module {
  public type Account = { owner : Principal; subaccount : ?Blob };
  public type NTC2Can_request_shared = {
    canister : Principal;
    amount : Nat;
    retry : Nat;
  };
  public type Stats = { cycles : Nat };
  public type Self = actor {
    get_account : shared query Principal -> async (Account, Text, Principal);
    get_queue : shared query () -> async [(Nat64, NTC2Can_request_shared)];
    mint : shared Account -> async ();
    stats : shared query () -> async Stats;
  }
}