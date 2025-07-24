import Ver1 "./memory/v1";

module {

    public type CreateRequest = {};

    public type ModifyRequest = {};

    public type Shared = {
        internals : {
            updating : Ver1.UpdatingStatus;
            tx_idx : ?Nat64;
            block_idx : ?Nat;
            cycles_to_send : ?Nat;
        };
        log : [Ver1.Activity];
    };

};