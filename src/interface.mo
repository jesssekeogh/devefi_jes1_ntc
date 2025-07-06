import Ver1 "./memory/v1";

module {

    public type CreateRequest = {};

    public type ModifyRequest = {};

    public type Shared = {
        internals : {
            updating : Ver1.UpdatingStatus;
        };
        log : [Ver1.Activity];
    };

};
