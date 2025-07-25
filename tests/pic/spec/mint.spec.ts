import {
  ICP_TRANSACTION_FEE,
  NTC_MINTER_CANISTER_ID,
  NTC_TEST_PYLON_CANISTER_ID,
} from "../setup/constants.ts";
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

  it("should reject ICP amounts below MINIMUM_MINT (1 ICP)", async () => {
    expect(node.sources[0].balance).toBe(0n);
    await manager.sendIcp(
      manager.getNodeSourceAccount(node, 0),
      10000_0000n + ICP_TRANSACTION_FEE
    ); // 1.0001 ICP

    await manager.advanceBlocksAndTimeMinutes(3);
    node = await manager.getNode(node.id);

    expect(node.sources[0].balance).toBe(10000_0000n); // should remain unchanged
    let mem = manager.getMintNodeCustom(node);

    expect(mem.log.length).toBe(0);
    expect(mem.internals.cycles_to_send).toEqual([]);
    expect(mem.internals.block_idx).toEqual([]);
    expect(mem.internals.updating).toEqual({ Init: null });
    expect(mem.internals.tx_idx).toEqual([]);
  });

  it("should only process when ICP balance exceeds fee + MINIMUM_MINT", async () => {
    expect(node.sources[0].balance).toBe(10000_0000n);

    await manager.sendIcp(
      manager.getNodeSourceAccount(node, 0),
      ICP_TRANSACTION_FEE * 3n
    ); // just enought to process

    await manager.advanceBlocksAndTimeMinutes(3);
    node = await manager.getNode(node.id);
    let mem = manager.getMintNodeCustom(node);
    expect(node.sources[0].balance).toBe(0n);
    expect(mem.log.length).toBe(2);

    // Check for any errors first
    const errors = mem.log.filter((entry) => "Err" in entry);
    expect(errors).toHaveLength(0); // More descriptive failure message

    // Then check successful operations
    const successfulOps = mem.log
      .filter((entry) => "Ok" in entry)
      .map((entry) => entry.Ok.operation);
    expect(successfulOps).toContain("top_up");
    expect(successfulOps).toContain("mint_ntc");

    expect(mem.internals.cycles_to_send).toEqual([]);
    expect(mem.internals.block_idx).toEqual([]);
    expect(mem.internals.updating).toHaveProperty("Done");
    expect(mem.internals.tx_idx).toEqual([]);
  });

  it("should successfully mint NTC tokens when receiving sufficient ICP", async () => {
    let beforeBalance = await manager.getMyBalances();
    expect(node.sources[0].balance).toBe(0n);

    await manager.sendIcp(manager.getNodeSourceAccount(node, 0), 2_0000_0000n);

    await manager.advanceBlocksAndTimeMinutes(5);

    node = await manager.getNode(node.id);
    let afterBalance = await manager.getMyBalances();
    let mem = manager.getMintNodeCustom(node);

    expect(node.sources[0].balance).toBe(0n);
    expect(afterBalance.ntc_tokens).toBeGreaterThan(beforeBalance.ntc_tokens);

    // Check for any errors first
    const errors = mem.log.filter((entry) => "Err" in entry);
    expect(errors).toHaveLength(0); // More descriptive failure message

    // Then check successful operations
    const successfulOps = mem.log
      .filter((entry) => "Ok" in entry)
      .map((entry) => entry.Ok.operation);
    expect(successfulOps).toContain("top_up");
    expect(successfulOps).toContain("mint_ntc");
    expect(mem.internals.cycles_to_send).toEqual([]);
    expect(mem.internals.block_idx).toEqual([]);
    expect(mem.internals.updating).toHaveProperty("Done");
    expect(mem.internals.tx_idx).toEqual([]);
  });

  it("should respect 3-minute timeout between operations", async () => {
    // Use existing node - ensure it starts with zero balance
    expect(node.sources[0].balance).toBe(0n);

    // Get initial log length (from previous tests)
    let mem = manager.getMintNodeCustom(node);
    const initialLogLength = mem.log.length;

    // Send first ICP
    await manager.sendIcp(manager.getNodeSourceAccount(node, 0), 2_0000_0000n);
    await manager.advanceBlocksAndTimeMinutes(3);

    node = await manager.getNode(node.id);
    expect(node.sources[0].balance).toBe(0n); // Should be processed

    // Send second ICP
    await manager.sendIcp(manager.getNodeSourceAccount(node, 0), 2_0000_0000n);
    await manager.advanceBlocksAndTimeMinutes(3);

    node = await manager.getNode(node.id);
    expect(node.sources[0].balance).toBe(0n); // Should be processed

    // Send third ICP
    await manager.sendIcp(manager.getNodeSourceAccount(node, 0), 2_0000_0000n);
    await manager.advanceBlocksAndTimeMinutes(3);

    node = await manager.getNode(node.id);
    expect(node.sources[0].balance).toBe(0n); // Should be processed

    // Now advance enough time for all async operations to complete
    await manager.advanceBlocksAndTimeMinutes(3); // Let all operations finish

    node = await manager.getNode(node.id);
    mem = manager.getMintNodeCustom(node);

    // All operations should be complete
    expect(mem.internals.updating).toHaveProperty("Done");
    expect(mem.log.length).toBe(initialLogLength + 6); // Should have 6 operations (3 × 2)

    // Get all new log entries added by this test
    const newLogEntries = mem.log.slice(initialLogLength);
    const successfulEntries = newLogEntries.filter((entry) => "Ok" in entry);

    // Should have 6 successful operations
    expect(successfulEntries).toHaveLength(6);

    // Verify operations are in correct order
    const operations = successfulEntries.map((entry) => entry.Ok.operation);
    expect(operations).toEqual([
      "top_up",
      "mint_ntc", // First batch
      "top_up",
      "mint_ntc", // Second batch
      "top_up",
      "mint_ntc", // Third batch
    ]);

    // Check timestamps to ensure 3-minute gaps between batches
    const timestamps = successfulEntries.map((entry) => entry.Ok.timestamp);

    const threeMinutesInNanos = 3n * 60n * 1_000_000_000n;

    // Check gap between first and second batch (compare end of first to start of second)
    const firstToSecondGap = timestamps[2] - timestamps[1];
    expect(firstToSecondGap).toBeGreaterThanOrEqual(threeMinutesInNanos);

    // Check gap between second and third batch
    const secondToThirdGap = timestamps[4] - timestamps[3];
    expect(secondToThirdGap).toBeGreaterThanOrEqual(threeMinutesInNanos);
  });

  it("should increase minter cycles while keeping pylon cycles stable after minting operations", async () => {
    const minterBeforeBalance = await manager.getCyclesBalance(
      NTC_MINTER_CANISTER_ID
    );
    const pylonBeforeBalance = await manager.getCyclesBalance(
      NTC_TEST_PYLON_CANISTER_ID
    );

    let beforeBalance = await manager.getMyBalances();
    expect(node.sources[0].balance).toBe(0n);

    await manager.sendIcp(
      manager.getNodeSourceAccount(node, 0),
      200_0000_0000n
    ); // enough to reflect significant changes
    await manager.advanceBlocksAndTimeMinutes(5);

    node = await manager.getNode(node.id);

    node = await manager.getNode(node.id);
    let afterBalance = await manager.getMyBalances();

    expect(node.sources[0].balance).toBe(0n);
    expect(afterBalance.ntc_tokens).toBeGreaterThan(beforeBalance.ntc_tokens); // ensure top up happened

    const minterAfterCyclesBalance = await manager.getCyclesBalance(
      NTC_MINTER_CANISTER_ID
    );
    const pylonAfterCyclesBalance = await manager.getCyclesBalance(
      NTC_TEST_PYLON_CANISTER_ID
    );

    // Allow for some variance in cycles (within ~100 billion cycles)
    const cyclesDifference =
      pylonAfterCyclesBalance > pylonBeforeBalance
        ? pylonAfterCyclesBalance - pylonBeforeBalance
        : pylonBeforeBalance - pylonAfterCyclesBalance;
    expect(cyclesDifference).toBeLessThan(100_000_000_000n); // Within 100 billion cycles
    expect(minterAfterCyclesBalance).toBeGreaterThan(minterBeforeBalance);
  });

  it("should mint NTC tokens proportionally to ICP amount sent", async () => {
    // Test with small amount (2 ICP)
    let beforeBalance1 = await manager.getMyBalances();
    expect(node.sources[0].balance).toBe(0n);

    await manager.sendIcp(manager.getNodeSourceAccount(node, 0), 2_0000_0000n); // 2 ICP
    await manager.advanceBlocksAndTimeMinutes(5);

    node = await manager.getNode(node.id);
    let afterBalance1 = await manager.getMyBalances();
    let mem1 = manager.getMintNodeCustom(node);

    expect(node.sources[0].balance).toBe(0n);
    expect(afterBalance1.ntc_tokens).toBeGreaterThan(beforeBalance1.ntc_tokens);

    // Verify successful operations
    const errors1 = mem1.log.filter((entry) => "Err" in entry);
    expect(errors1).toHaveLength(0);

    const ntcMinted1 = afterBalance1.ntc_tokens - beforeBalance1.ntc_tokens;

    // Test with larger amount (10 ICP)
    let beforeBalance2 = await manager.getMyBalances();

    await manager.sendIcp(manager.getNodeSourceAccount(node, 0), 10_0000_0000n); // 10 ICP
    await manager.advanceBlocksAndTimeMinutes(5);

    node = await manager.getNode(node.id);
    let afterBalance2 = await manager.getMyBalances();
    let mem2 = manager.getMintNodeCustom(node);

    expect(node.sources[0].balance).toBe(0n);
    expect(afterBalance2.ntc_tokens).toBeGreaterThan(beforeBalance2.ntc_tokens);

    // Verify successful operations
    const errors2 = mem2.log.filter((entry) => "Err" in entry);
    expect(errors2).toHaveLength(0);

    const ntcMinted2 = afterBalance2.ntc_tokens - beforeBalance2.ntc_tokens;

    // Test with even larger amount (50 ICP)
    let beforeBalance3 = await manager.getMyBalances();

    await manager.sendIcp(manager.getNodeSourceAccount(node, 0), 50_0000_0000n); // 50 ICP
    await manager.advanceBlocksAndTimeMinutes(5);

    node = await manager.getNode(node.id);
    let afterBalance3 = await manager.getMyBalances();
    let mem3 = manager.getMintNodeCustom(node);

    expect(node.sources[0].balance).toBe(0n);
    expect(afterBalance3.ntc_tokens).toBeGreaterThan(beforeBalance3.ntc_tokens);

    // Verify successful operations
    const errors3 = mem3.log.filter((entry) => "Err" in entry);
    expect(errors3).toHaveLength(0);

    const ntcMinted3 = afterBalance3.ntc_tokens - beforeBalance3.ntc_tokens;

    // Verify that larger ICP amounts result in more NTC tokens
    expect(ntcMinted2).toBeGreaterThan(ntcMinted1); // 10 ICP should mint more than 2 ICP
    expect(ntcMinted3).toBeGreaterThan(ntcMinted2); // 50 ICP should mint more than 10 ICP

    // Verify proportional relationship (approximately)
    const ratio1to2 = Number(ntcMinted2) / Number(ntcMinted1);
    const ratio2to3 = Number(ntcMinted3) / Number(ntcMinted2);

    // The ratios should be reasonable (not exactly proportional due to fees, but should reflect the ICP difference)
    expect(ratio1to2).toBeGreaterThan(2); // Should be more than 2x for 5x ICP
    expect(ratio2to3).toBeGreaterThan(2); // Should be more than 2x for 5x ICP
  });

  it("should retry failed top-up operations when CMC service is temporarily unavailable", async () => {
    expect(node.sources[0].balance).toBe(0n);
    
    // Get initial balance
    let beforeBalance = await manager.getMyBalances();

    // Stop the CMC canister to simulate failure
    await manager.stopCmcCanister();

    // Send ICP to trigger minting process
    await manager.sendIcp(manager.getNodeSourceAccount(node, 0), 2_0000_0000n);
    await manager.advanceBlocksAndTimeMinutes(5);

    node = await manager.getNode(node.id);
    let mem = manager.getMintNodeCustom(node);

    // Should process the ICP but fail on async_cycle operation
    expect(node.sources[0].balance).toBe(0n);
    
    // Check that we have an error in the recent log entries (log max is 10)
    const errors = mem.log.filter((entry) => "Err" in entry);
    expect(errors.length).toBeGreaterThan(0);
    
    // Should have a async_cycle error
    const asyncCycleError = errors.find((entry) => entry.Err.operation === "async_cycle");
    expect(asyncCycleError).toBeDefined();

    // Start the CMC canister back up
    await manager.startCmcCanister();
    
    // Wait for retry mechanism to kick in
    await manager.advanceBlocksAndTimeMinutes(5);

    node = await manager.getNode(node.id);
    mem = manager.getMintNodeCustom(node);

    // Should now complete successfully
    expect(mem.internals.updating).toHaveProperty("Done");
    
    // Check the latest entries in the log for successful operations
    const latestEntries = mem.log.slice(-3); // Get last 3 entries
    const latestSuccessfulOps = latestEntries
      .filter((entry) => "Ok" in entry)
      .map((entry) => entry.Ok.operation);
    
    expect(latestSuccessfulOps).toContain("top_up");
    expect(latestSuccessfulOps).toContain("mint_ntc");

    // Verify NTC tokens were actually minted
    let afterBalance = await manager.getMyBalances();
    expect(afterBalance.ntc_tokens).toBeGreaterThan(beforeBalance.ntc_tokens);
  });

  it("should retry failed minting operations when NTC minter service is temporarily unavailable", async () => {
    expect(node.sources[0].balance).toBe(0n);
    
    // Get initial balance
    let beforeBalance = await manager.getMyBalances();

    // Stop the NTC minter canister to simulate failure
    await manager.stopCanister(NTC_MINTER_CANISTER_ID);

    // Send ICP to trigger minting process
    await manager.sendIcp(manager.getNodeSourceAccount(node, 0), 2_0000_0000n);
    await manager.advanceBlocksAndTimeMinutes(5);

    node = await manager.getNode(node.id);
    let mem = manager.getMintNodeCustom(node);

    // Should process the ICP and succeed with top_up but fail on mint_ntc operation
    expect(node.sources[0].balance).toBe(0n);
    
    // Check the log entries (log max is 10)
    const errors = mem.log.filter((entry) => "Err" in entry);
    const successes = mem.log.filter((entry) => "Ok" in entry);

    // Should have successful top_up
    const topUpSuccess = successes.find((entry) => entry.Ok.operation === "top_up");
    expect(topUpSuccess).toBeDefined();
    
    // Should have an error for async_cycle operation (mint_ntc failure)
    const asyncCycleError = errors.find((entry) => entry.Err.operation === "async_cycle");
    expect(asyncCycleError).toBeDefined();

    // Start the NTC minter canister back up
    await manager.startCanister(NTC_MINTER_CANISTER_ID);
    
    // Wait for retry mechanism to kick in
    await manager.advanceBlocksAndTimeMinutes(5);

    node = await manager.getNode(node.id);
    mem = manager.getMintNodeCustom(node);

    // Should now complete successfully
    expect(mem.internals.updating).toHaveProperty("Done");
    
    // Check the latest entries in the log for successful operations
    const latestEntries = mem.log.slice(-3); // Get last 3 entries
    const latestSuccessfulOps = latestEntries
      .filter((entry) => "Ok" in entry)
      .map((entry) => entry.Ok.operation);
    
    expect(latestSuccessfulOps).toContain("top_up");
    expect(latestSuccessfulOps).toContain("mint_ntc");
    
    // Verify NTC tokens were actually minted
    let afterBalance = await manager.getMyBalances();
    expect(afterBalance.ntc_tokens).toBeGreaterThan(beforeBalance.ntc_tokens);
  });

  it("should maintain proper async operation sequencing and avoid duplicate calls during retries", async () => {
    expect(node.sources[0].balance).toBe(0n);

    // First, test normal operation flow - operations should be batched together
    await manager.sendIcp(manager.getNodeSourceAccount(node, 0), 2_0000_0000n);
    await manager.advanceBlocksAndTimeMinutes(5);

    node = await manager.getNode(node.id);
    let mem = manager.getMintNodeCustom(node);

    // Check that the latest operations include both top_up and mint_ntc close together in time
    const latestOps = mem.log.slice(-2).filter((entry) => "Ok" in entry); // Get last 2 entries only
    const normalTopUp = latestOps.find((entry) => entry.Ok.operation === "top_up");
    const normalMintNtc = latestOps.find((entry) => entry.Ok.operation === "mint_ntc");
    expect(normalTopUp).toBeDefined();
    expect(normalMintNtc).toBeDefined();

    // Verify they are close in time (less than 3 minutes = 180_000_000_000 nanoseconds)
    const threeMinutesInNanos = 3n * 60n * 1_000_000_000n;
    const timeDifference = normalMintNtc!.Ok.timestamp - normalTopUp!.Ok.timestamp;
    expect(timeDifference).toBeLessThan(threeMinutesInNanos);

    // Now test the retry scenario - stop NTC minter to cause mint_ntc to fail
    await manager.stopCanister(NTC_MINTER_CANISTER_ID);

    // Send ICP to trigger another minting process
    await manager.sendIcp(manager.getNodeSourceAccount(node, 0), 2_0000_0000n);
    await manager.advanceBlocksAndTimeMinutes(5);

    node = await manager.getNode(node.id);
    mem = manager.getMintNodeCustom(node);

    // Should have successful top_up but failed async_cycle (mint_ntc attempt)
    // Look for recent top_up and async_cycle error in latest entries
    const recentEntries = mem.log.slice(-3); // Get last 3 entries only to capture recent activity
    const retryTopUp = recentEntries.find((entry) => "Ok" in entry && entry.Ok.operation === "top_up");
    const retryError = recentEntries.find((entry) => "Err" in entry && entry.Err.operation === "async_cycle");
    
    expect(retryTopUp).toBeDefined();
    expect(retryError).toBeDefined();

    // The error should happen reasonably soon after top_up (within reasonable async processing time)
    // But the important timing constraint is that retry happens AFTER 3 minutes from the error
    const retryTimeDifference = ("Err" in retryError! ? retryError.Err.timestamp : 0n) - 
                               ("Ok" in retryTopUp! ? retryTopUp.Ok.timestamp : 0n);
    expect(retryTimeDifference).toBeLessThan(threeMinutesInNanos); // Error should happen reasonably soon after top_up

    // Store the retry error timestamp for later comparison
    const retryErrorTimestamp = ("Err" in retryError! ? retryError.Err.timestamp : 0n);

    // Start the NTC minter canister back up
    await manager.startCanister(NTC_MINTER_CANISTER_ID);
    
    // Wait for retry mechanism to kick in (should retry mint_ntc without calling top_up again)
    await manager.advanceBlocksAndTimeMinutes(5);

    node = await manager.getNode(node.id);
    mem = manager.getMintNodeCustom(node);

    // Should now complete successfully
    expect(mem.internals.updating).toHaveProperty("Done");

    // Check the most recent entries for the retry operations
    const finalEntries = mem.log.slice(-3); // Get last 3 entries
    
    // Should have a successful mint_ntc in recent entries (the retry)
    const retryMintNtc = finalEntries.find((entry) => "Ok" in entry && entry.Ok.operation === "mint_ntc");
    expect(retryMintNtc).toBeDefined();

    // CRITICAL: Verify NO duplicate top_up in recent entries during retry phase
    // After the retry, we should NOT see another top_up call - only the mint_ntc retry
    const duplicateTopUp = finalEntries.find((entry) => 
      "Ok" in entry && 
      entry.Ok.operation === "top_up" && 
      entry.Ok.timestamp > retryErrorTimestamp
    );
    expect(duplicateTopUp).toBeUndefined(); // Should NOT find a top_up after the error

    // CRITICAL: Verify the retry mint_ntc happened AFTER the 3-minute timeout from the error
    // This ensures the retry mechanism respects the 3-minute cooldown period
    const retryMintTimestamp = ("Ok" in retryMintNtc! ? retryMintNtc.Ok.timestamp : 0n);
    const retryMintDelay = retryMintTimestamp - retryErrorTimestamp;
    expect(retryMintDelay).toBeGreaterThanOrEqual(threeMinutesInNanos);

    // Verify NTC tokens were actually minted in both normal and retry scenarios
    let finalBalance = await manager.getMyBalances();
    expect(finalBalance.ntc_tokens).toBeGreaterThan(0n);
  });

  // it.skip("should apply correct billing fee (0.05 NTC)", async () => {
  //   // TODO: Test billing.transaction_fee flat_fee_multiplier(500)
  // });

  // it.skip("should collect billing fees to author account", async () => {
  //   // TODO: Test 0.05 NTC billing fees are transferred to author_account
  // });
});
