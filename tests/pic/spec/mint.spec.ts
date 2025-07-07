import { Manager } from "../setup/manager.ts";
import { NodeShared } from "../setup/tcycles_test_pylon/declarations/tcycles_test_pylon.did";

describe("Mint", () => {
  let manager: Manager;
  let node: NodeShared;

  beforeAll(async () => {
    manager = await Manager.beforeAll();
    node = await manager.createNode({ devefi_jes1_tcyclesmint: null });
  });

  afterAll(async () => {
    await manager.afterAll();
  });

  it("should mint and send tcycles", async () => {
    let beforeBalance = await manager.getMyBalances();
    expect(node.sources[0].balance).toBe(0n);
    expect(
      manager.checkNodeUpdatingDone(manager.getNodeCustom(node))
    ).toBeNull();
    expect(beforeBalance.tcycles_tokens).toBe(0n);

    await manager.sendIcp(manager.getNodeSourceAccount(node, 0), 2_0000_0000n);

    await manager.advanceBlocksAndTimeMinutes(10);

    node = await manager.getNode(node.id);
    let afterBalance = await manager.getMyBalances();
    
    console.log(manager.getNodeCustom(node).log)
    expect(node.sources[0].balance).toBe(0n);
    expect(
      manager.checkNodeUpdatingDone(manager.getNodeCustom(node))
    ).not.toBeNull();
    expect(afterBalance.tcycles_tokens).toBeGreaterThan(0n);
  });
});
