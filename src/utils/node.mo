import Ver1 "../memory/v1";
import U "mo:devefi/utils";
import Buffer "mo:base/Buffer";

module NodeUtils {

    public func node_ready(nodeMem : Ver1.NodeMem) : Bool {
        let timeout : Nat64 = (3 * 60 * 1_000_000_000);

        switch (nodeMem.internals.updating) {
            case (#Init) {
                // Initial state, ready to start processing
                nodeMem.internals.updating := #Calling(U.now());
                return true;
            };
            case (#Calling(_)) {
                // If in Calling state, don't restart even if timeout has passed
                // This indicates an operation is still in progress, and we need to wait for results
                return false;
            };
            case (#Done(ts)) {
                // If in Done state and timeout has passed, ready for next operation
                if (U.now() >= ts + timeout) {
                    nodeMem.internals.updating := #Calling(U.now());
                    return true;
                } else {
                    return false;
                };
            };
        };
    };

    public func node_done(nodeMem : Ver1.NodeMem) : () {
        nodeMem.internals.updating := #Done(U.now());
    };

    public func log_activity(nodeMem : Ver1.NodeMem, operation : Text, result : { #Ok; #Err : Text }) : () {
        let log = Buffer.fromArray<Ver1.Activity>(nodeMem.log);

        switch (result) {
            case (#Ok(())) {
                log.add(#Ok({ operation = operation; timestamp = U.now() }));
            };
            case (#Err(msg)) {
                log.add(#Err({ operation = operation; msg = msg; timestamp = U.now() }));
            };
        };

        if (log.size() > 10) {
            ignore log.remove(0); // remove 1 item from the beginning
        };

        nodeMem.log := Buffer.toArray(log);
    };
};
