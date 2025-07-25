import { NTC_TRANSACTION_FEE } from "../setup/constants.ts";
import { Manager } from "../setup/manager.ts";
import { NodeShared } from "../setup/ntc_test_pylon/declarations/ntc_test_pylon.did";

describe("Redeem", () => {
  let manager: Manager;
  let node: NodeShared;

  beforeAll(async () => {
    manager = await Manager.beforeAll();
    node = await manager.createNode({ devefi_jes1_ntcredeem: null });
  });

  afterAll(async () => {
    await manager.afterAll();
  });

  it("should reject NTC amounts below MINIMUM_REDEEM threshold (each destination needs >50x NTC ledger fee)", async () => {
    expect(node.sources[0].balance).toBe(0n);

    // Send amount where each destination would receive less than 50x fee
    // With 50/50 split, each destination gets 50% of balance
    // Need: balance * 50% > fee * 50, so balance > fee * 100
    // Send just below threshold: fee * 99 (after transaction fee: fee * 98)
    await manager.sendNtc(
      manager.getNodeSourceAccount(node, 0),
      NTC_TRANSACTION_FEE * 99n
    );

    await manager.advanceBlocksAndTimeMinutes(3);
    node = await manager.getNode(node.id);

    // Should remain unchanged (minus transaction fee)
    expect(node.sources[0].balance).toBe(NTC_TRANSACTION_FEE * 98n);

    let mem = manager.getRedeemNodeCustom(node);
    // Verify the split is still 50/50 as expected
    expect(mem.variables.split).toEqual([50n, 50n]);
  });

  it("should process when NTC balance exceeds threshold for both destinations", async () => {
    expect(node.sources[0].balance).toBe(NTC_TRANSACTION_FEE * 98n);

    // Send just enough to exceed threshold (fee * 2 to get over fee * 100 total)
    await manager.sendNtc(
      manager.getNodeSourceAccount(node, 0),
      NTC_TRANSACTION_FEE * 4n
    );

    await manager.advanceBlocksAndTimeMinutes(3);
    node = await manager.getNode(node.id);

    // Should be processed and balance should be 0
    expect(node.sources[0].balance).toBe(0n);
  });

  it("should distribute cycles equally to both test canisters when redeeming NTC", async () => {
    expect(node.sources[0].balance).toBe(0n);

    // Get initial cycles balances for both test canisters
    const canister1BeforeCycles = await manager.getCyclesBalance(
      manager.getTestCanisterId()
    );
    const canister2BeforeCycles = await manager.getCyclesBalance(
      manager.getTestCanisterId2()
    );

    // Send a significant amount of NTC for redemption
    await manager.sendNtc(
      manager.getNodeSourceAccount(node, 0),
      100_0000_0000n // 100 NTC tokens
    );

    await manager.advanceBlocksAndTimeMinutes(6);
    node = await manager.getNode(node.id);

    // Verify NTC was processed
    expect(node.sources[0].balance).toBe(0n);

    // Get final cycles balances
    const canister1AfterCycles = await manager.getCyclesBalance(
      manager.getTestCanisterId()
    );
    const canister2AfterCycles = await manager.getCyclesBalance(
      manager.getTestCanisterId2()
    );

    // Both canisters should have increased cycles
    expect(canister1AfterCycles).toBeGreaterThan(canister1BeforeCycles);
    expect(canister2AfterCycles).toBeGreaterThan(canister2BeforeCycles);

    // Calculate cycles increase for each canister
    const canister1Increase = canister1AfterCycles - canister1BeforeCycles;
    const canister2Increase = canister2AfterCycles - canister2BeforeCycles;

    // With 50/50 split, both increases should be exactly equal
    expect(canister1Increase).toBe(canister2Increase);

    // Verify both increases are significant (> 0)
    expect(canister1Increase).toBeGreaterThan(0);
    expect(canister2Increase).toBeGreaterThan(0);
  });

  it("should handle multiple NTC redemptions proportionally", async () => {
    expect(node.sources[0].balance).toBe(0n);

    // Test with smaller amount first
    const canister1Before1 = await manager.getCyclesBalance(
      manager.getTestCanisterId()
    );
    const canister2Before1 = await manager.getCyclesBalance(
      manager.getTestCanisterId2()
    );

    await manager.sendNtc(
      manager.getNodeSourceAccount(node, 0),
      10_0000_0000n // 10 NTC tokens
    );
    await manager.advanceBlocksAndTimeMinutes(5);

    node = await manager.getNode(node.id);
    expect(node.sources[0].balance).toBe(0n);

    const canister1After1 = await manager.getCyclesBalance(
      manager.getTestCanisterId()
    );
    const canister2After1 = await manager.getCyclesBalance(
      manager.getTestCanisterId2()
    );

    const cycles1Increase1 = canister1After1 - canister1Before1;
    const cycles2Increase1 = canister2After1 - canister2Before1;

    // Test with larger amount
    await manager.sendNtc(
      manager.getNodeSourceAccount(node, 0),
      50_0000_0000n // 50 NTC tokens (5x larger)
    );
    await manager.advanceBlocksAndTimeMinutes(5);

    node = await manager.getNode(node.id);
    expect(node.sources[0].balance).toBe(0n);

    const canister1After2 = await manager.getCyclesBalance(
      manager.getTestCanisterId()
    );
    const canister2After2 = await manager.getCyclesBalance(
      manager.getTestCanisterId2()
    );

    const cycles1Increase2 = canister1After2 - canister1After1;
    const cycles2Increase2 = canister2After2 - canister2After1;

    // Both increases should be equal within each transaction
    expect(cycles1Increase1).toBe(cycles2Increase1);
    expect(cycles1Increase2).toBe(cycles2Increase2);

    // Larger NTC amount should result in more cycles (approximately 5x more)
    const ratio1 = Number(cycles1Increase2) / Number(cycles1Increase1);
    const ratio2 = Number(cycles2Increase2) / Number(cycles2Increase1);

    // Should be approximately 5x more cycles (within reasonable tolerance)
    expect(ratio1).toBeGreaterThan(4);
    expect(ratio1).toBeLessThan(6);
    expect(ratio2).toBeGreaterThan(4);
    expect(ratio2).toBeLessThan(6);
  });

  it("should handle edge case where balance exactly equals threshold", async () => {
    expect(node.sources[0].balance).toBe(0n);

    // Send exactly the threshold amount (fee * 100 for 50/50 split)
    await manager.sendNtc(
      manager.getNodeSourceAccount(node, 0),
      NTC_TRANSACTION_FEE * 102n // +2 to account for transaction fee
    );

    await manager.advanceBlocksAndTimeMinutes(3);
    node = await manager.getNode(node.id);

    // Should process because each destination gets exactly fee * 50
    expect(node.sources[0].balance).toBe(0n);
  });

  it("should maintain proper destination naming and splitting behavior", async () => {
    expect(node.sources[0].balance).toBe(0n);

    let mem = manager.getRedeemNodeCustom(node);

    // Verify initial configuration
    expect(mem.variables.split).toEqual([50n, 50n]);
    expect(mem.variables.names).toEqual(["Canister 1", "Canister 2"]);

    // Verify destinations are properly set up
    expect(node.destinations.length).toBe(2);
    expect(node.destinations[0].name).toBe("Canister 1");
    expect(node.destinations[1].name).toBe("Canister 2");

    // Send NTC and verify processing works with this configuration
    await manager.sendNtc(
      manager.getNodeSourceAccount(node, 0),
      200_0000_0000n
    );

    await manager.advanceBlocksAndTimeMinutes(5);
    node = await manager.getNode(node.id);

    expect(node.sources[0].balance).toBe(0n);
  });
});
