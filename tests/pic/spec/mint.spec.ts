import { Manager } from "../setup/manager.ts";
import { NodeShared } from "../setup/ntc_test_pylon/declarations/ntc_test_pylon.did";

describe("Mint", () => {
  let manager: Manager;
  let node: NodeShared;

  beforeAll(async () => {
    manager = await Manager.beforeAll();
    node = await manager.createNode({ devefi_jes1_ntcmint: null });
  });

  afterAll(async () => {
    await manager.afterAll();
  });

  it("should mint and send ntc", async () => {
    let beforeBalance = await manager.getMyBalances();
    expect(node.sources[0].balance).toBe(0n);
    expect(beforeBalance.ntc_tokens).toBe(0n);

    await manager.sendIcp(manager.getNodeSourceAccount(node, 0), 2_0000_0000n);

    await manager.advanceBlocksAndTimeMinutes(10);

    node = await manager.getNode(node.id);
    let afterBalance = await manager.getMyBalances();

    expect(node.sources[0].balance).toBe(0n);
    expect(afterBalance.ntc_tokens).toBeGreaterThan(0n);
  });

  // it.skip("should reject ICP amounts below MINIMUM_MINT (1 ICP)", async () => {
  //   // TODO: Test sending < 100_000_000 ICP returns error or doesn't process
  // });

  // it.skip("should only process when ICP balance exceeds fee + MINIMUM_MINT", async () => {
  //   // TODO: Test mintBal > mintFee + MINIMUM_MINT condition
  // });

  // it.skip("should send ICP to CMC with correct subaccount", async () => {
  //   // TODO: Test ICP sent to CmcMinter with principalToSubaccount(core.getThisCan())
  // });

  // it.skip("should track transaction ID after ICP transfer", async () => {
  //   // TODO: Test NodeUtils.tx_sent(nodeMem, txId) functionality
  // });

  // it.skip("should wait for ICP transaction confirmation before minting", async () => {
  //   // TODO: Test ledger.isSent(refreshIdx) check in async flow
  // });

  // it.skip("should call CMC notify_top_up after ICP transfer", async () => {
  //   // TODO: Test cycles minting canister notification process
  // });

  // it.skip("should mint NTC using received cycles", async () => {
  //   // TODO: Test NtcMinter.mint_ntc call with cycles
  // });

  // it.skip("should forward NTC to destination slot", async () => {
  //   // TODO: Test NTC forwarding from source slot 1 to destination port 0
  // });

  // it.skip("should handle node state transitions correctly", async () => {
  //   // TODO: Test node_ready, node_done state management
  // });

  // it.skip("should respect 3-minute timeout between operations", async () => {
  //   // TODO: Test timeout logic in node_ready function
  // });

  // it.skip("should handle async errors gracefully", async () => {
  //   // TODO: Test try/catch error handling in singleAsync
  // });

  // it.skip("should log activities for successful operations", async () => {
  //   // TODO: Test NodeUtils.log_activity for #Ok results
  // });

  // it.skip("should log activities for failed operations", async () => {
  //   // TODO: Test NodeUtils.log_activity for #Err results with error messages
  // });

  // it.skip("should maintain activity log with maximum 10 entries", async () => {
  //   // TODO: Test log buffer management and oldest entry removal
  // });

  // it.skip("should handle concurrent node operations", async () => {
  //   // TODO: Test multiple nodes processing simultaneously
  // });

  // it.skip("should skip inactive nodes during run cycle", async () => {
  //   // TODO: Test nodes with active=false are skipped
  // });

  // it.skip("should skip frozen nodes during run cycle", async () => {
  //   // TODO: Test nodes with billing.frozen=true are skipped
  // });

  // it.skip("should skip expired nodes during run cycle", async () => {
  //   // TODO: Test nodes with billing.expires set are skipped
  // });

  // it.skip("should handle missing ledger class gracefully", async () => {
  //   // TODO: Test behavior when core.get_ledger_cls(IcpLedger) returns null
  // });

  // it.skip("should handle missing source account gracefully", async () => {
  //   // TODO: Test behavior when getSourceAccountIC returns null subaccount
  // });

  // it.skip("should validate supported ledgers (ICP and NTC)", async () => {
  //   // TODO: Test meta().supported_ledgers includes both ICP and NTC ledgers
  // });

  // it.skip("should configure correct ledger slots (MINT and NTC)", async () => {
  //   // TODO: Test meta().ledger_slots configuration
  // });

  // it.skip("should apply correct billing fee (0.05 NTC)", async () => {
  //   // TODO: Test billing.transaction_fee flat_fee_multiplier(500)
  // });

  // it.skip("should handle node creation and deletion", async () => {
  //   // TODO: Test create() and delete() node lifecycle
  // });

  // it.skip("should preserve node state during modify operations", async () => {
  //   // TODO: Test modify() function maintains node integrity
  // });

  // it.skip("should return correct node data in get() calls", async () => {
  //   // TODO: Test get() returns proper internals and log data
  // });

  // it.skip("should define correct source and destination endpoints", async () => {
  //   // TODO: Test sources() returns [(0, "Mint"), (1, "_To")] and destinations() returns [(1, "To")]
  // });

  // it.skip("should verify all source balances are zero after processing", async () => {
  //   // TODO: Test both mint source (slot 0) and NTC source (slot 1) balances return to 0
  // });

  // it.skip("should verify redeem account balances are zero after operations", async () => {
  //   // TODO: Test redeem-related account balances are properly cleared
  // });

  // it.skip("should deduct correct billing fee (0.05 NTC) from operations", async () => {
  //   // TODO: Test flat_fee_multiplier(500) is properly applied and deducted
  // });

  // it.skip("should track cycles received and cycles added accurately", async () => {
  //   // TODO: Test cycles balance increases match expected amounts from ICP conversion
  // });

  // it.skip("should handle normal ICRC transfers without breaking functionality", async () => {
  //   // TODO: Test regular ICRC token transfers don't interfere with mint operations
  // });

  // it.skip("should process ICRC transfers alongside mint operations", async () => {
  //   // TODO: Test concurrent ICRC transfers and minting don't cause conflicts
  // });

  // it.skip("should maintain balance integrity during ICRC transfer operations", async () => {
  //   // TODO: Test balances remain consistent when mixing ICRC transfers with mints
  // });

  // it.skip("should apply billing fees correctly with ICRC transfers", async () => {
  //   // TODO: Test billing fee application works properly with normal transfers
  // });

  // it.skip("should verify cycles accounting after ICRC and mint operations", async () => {
  //   // TODO: Test cycles balance reflects all operations including ICRC transfers
  // });

  // it.skip("should collect billing fees to author account", async () => {
  //   // TODO: Test 0.05 NTC billing fees are transferred to author_account
  // });

  // it.skip("should verify author account balance increases with fees", async () => {
  //   // TODO: Test author account (jv4ws-fbili-a35rv-xd7a5-xwvxw-trink-oluun-g7bcp-oq5f6-35cba-vqe) receives fees
  // });

  // it.skip("should track billing account transactions", async () => {
  //   // TODO: Test billing transactions are properly recorded and tracked
  // });

  // it.skip("should handle billing fee collection errors gracefully", async () => {
  //   // TODO: Test behavior when billing fee transfer to author account fails
  // });

  // it.skip("should apply billing fees per transaction correctly", async () => {
  //   // TODO: Test flat_fee_multiplier(500) applied to each mint operation
  // });

  // it.skip("should verify billing fees don't affect mint amounts", async () => {
  //   // TODO: Test billing fees are separate from actual mint/redeem amounts
  // });

  // it.skip("should accumulate multiple billing fees to author account", async () => {
  //   // TODO: Test multiple operations result in cumulative fees to author
  // });

  // it.skip("should maintain stable pylon cycles balance after operations", async () => {
  //   // TODO: Test pylon cycles balance doesn't change significantly after topping up and sending cycles
  // });

  // it.skip("should verify cycles consumption is within expected bounds", async () => {
  //   // TODO: Test cycles used for operations don't exceed reasonable thresholds
  // });

  // it.skip("should track pylon cycles before and after cycle operations", async () => {
  //   // TODO: Test pylon cycles balance monitoring during mint/send operations
  // });

  // it.skip("should not process new transactions while refresh_idx exists", async () => {
  //   // TODO: Test that new ICP transfers are blocked when refresh_idx is not null
  // });

  // it.skip("should clear refresh_idx after successful async processing", async () => {
  //   // TODO: Test refresh_idx is set to null after successful mint_ntc completion
  // });

  // it.skip("should retry failed CMC notify_top_up calls", async () => {
  //   // TODO: Test retry mechanism for CmcMinter.notify_top_up failures (can stop canister to test)
  // });

  // it.skip("should retry failed NTC minter calls", async () => {
  //   // TODO: Test retry mechanism for NtcMinter.mint_ntc failures (can stop canister to test)
  // });

  // it.skip("should increment retry_count on async failures", async () => {
  //   // TODO: Test retry_count increases when notify_top_up or mint_ntc fails
  // });

  // it.skip("should abandon processing after MAX_RETRY_COUNT failures", async () => {
  //   // TODO: Test processing stops after 10 failed retries (can stop canister to test)
  // });

  // it.skip("should reset retry_count after successful processing", async () => {
  //   // TODO: Test retry_count is reset to 0 after successful mint_ntc completion
  // });

  // it.skip("should handle async errors in singleAsync gracefully", async () => {
  //   // TODO: Test try/catch in singleAsync logs errors and calls node_done
  // });

  // it.skip("should verify ledger.isSent before async processing", async () => {
  //   // TODO: Test async flow only proceeds when ICP transaction is confirmed
  // });

});
