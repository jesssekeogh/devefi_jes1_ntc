import Ver1 "./memory/v1";

module {

    public type CreateRequest = {};

    public type ModifyRequest = {};

    public type Shared = {
        internals : {
            updating : Ver1.UpdatingStatus;
            refresh_idx : ?Nat64;
        };
        log : [Ver1.Activity];
    };

};
