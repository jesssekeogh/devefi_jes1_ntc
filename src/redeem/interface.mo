module {

    public type CreateRequest = {
        variables : {
            split : [Nat];
            names : [Text];
        };
    };

    public type ModifyRequest = {
        split : [Nat];
        names : [Text];
    };

    public type Shared = {
        variables : {
            split : [Nat];
            names : [Text];
        };
    };

};
