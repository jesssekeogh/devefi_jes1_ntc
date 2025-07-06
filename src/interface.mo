import Ver1 "./memory/v1";

module {

    public type CreateRequest = { variables : {} };

    public type ModifyRequest = {};

    public type Shared = {
        variables : {};
        internals : {
            updating : Ver1.UpdatingStatus;
        };
        log : [Ver1.Activity];
    };

};
