// import { Manager } from "../setup/manager.ts";

// describe.skip("Redeem", () => {
//   let manager: Manager;

//   beforeAll(async () => {
//     manager = await Manager.beforeAll();
//   });

//   afterAll(async () => {
//     await manager.afterAll();
//   });

//   it.skip("should reject NTC amounts below MINIMUM_REDEEM (1 NTC)", async () => {
//     // TODO: Test redeeming < 1_000_000_000_000 NTC doesn't process
//   });

//   it.skip("should only process when NTC balance exceeds fee + MINIMUM_REDEEM", async () => {
//     // TODO: Test redeemBal > redeemFee + MINIMUM_REDEEM condition
//   });

//   it.skip("should send NTC to minter with correct canister subaccount", async () => {
//     // TODO: Test NTC sent to NtcMinter with principalToSubaccount(destination.owner)
//   });

//   it.skip("should reject redemption to subaccounts", async () => {
//     // TODO: Test redemption fails when destination has subaccount (can't send cycles to subaccounts)
//   });

//   it.skip("should validate destination canister principal", async () => {
//     // TODO: Test getDestinationAccountIC returns valid canister owner
//   });

//   it.skip("should handle missing destination account gracefully", async () => {
//     // TODO: Test behavior when getDestinationAccountIC returns null
//   });

//   it.skip("should format subaccount correctly from canister principal", async () => {
//     // TODO: Test Utils.principalToSubaccount conversion for destination canister
//   });

//   it.skip("should send full NTC balance to minter", async () => {
//     // TODO: Test entire redeemBal is sent in transfer to minter
//   });

//   it.skip("should trigger minter's onReceive for redeem processing", async () => {
//     // TODO: Test NTC transfer triggers automatic cycles redemption in minter
//   });

//   it.skip("should verify NTC tokens get burned after minter receives them", async () => {
//     // TODO: Test NTC tokens are sent back to minter (burned) after redeem request queuing
//   });

//   it.skip("should confirm NTC total supply decreases after redemption", async () => {
//     // TODO: Test total NTC supply is reduced by burned amount
//   });

//   it.skip("should track NTC burning in minter's onReceive handler", async () => {
//     // TODO: Test minter burns NTC by sending to getMinter() after adding to redeem queue
//   });

//   it.skip("should verify destination canister receives cycles", async () => {
//     // TODO: Test destination canister cycles balance increases by expected amount after redemption
//   });

//   it.skip("should confirm cycles received match NTC amount redeemed", async () => {
//     // TODO: Test cycles deposited to canister equals NTC tokens burned (1:1 ratio)
//   });

//   it.skip("should track canister cycles before and after redemption", async () => {
//     // TODO: Test monitoring destination canister cycles balance throughout redemption process
//   });

//   it.skip("should handle NTC transfer failures gracefully", async () => {
//     // TODO: Test behavior when core.Source.Send.intent or commit fails
//   });

//   it.skip("should skip inactive nodes during run cycle", async () => {
//     // TODO: Test nodes with active=false are skipped
//   });

//   it.skip("should skip frozen nodes during run cycle", async () => {
//     // TODO: Test nodes with billing.frozen=true are skipped
//   });

//   it.skip("should skip expired nodes during run cycle", async () => {
//     // TODO: Test nodes with billing.expires set are skipped
//   });

//   it.skip("should handle missing source account gracefully", async () => {
//     // TODO: Test behavior when getSource returns null
//   });

//   it.skip("should validate supported ledger (NTC only)", async () => {
//     // TODO: Test meta().supported_ledgers includes only NTC ledger
//   });

//   it.skip("should configure correct ledger slot (REDEEM)", async () => {
//     // TODO: Test meta().ledger_slots contains "REDEEM"
//   });

//   it.skip("should have no billing fees for redeem operations", async () => {
//     // TODO: Test billing array is empty (no fees for redemption)
//   });

//   it.skip("should handle node creation and deletion", async () => {
//     // TODO: Test create() and delete() node lifecycle
//   });

//   it.skip("should preserve node state during modify operations", async () => {
//     // TODO: Test modify() function maintains node integrity
//   });

//   it.skip("should return correct node data in get() calls", async () => {
//     // TODO: Test get() returns proper internals and log data
//   });

//   it.skip("should define correct source and destination endpoints", async () => {
//     // TODO: Test sources() returns [(0, "Redeem")] and destinations() returns [(0, "Canister")]
//   });

//   it.skip("should verify source balance is zero after processing", async () => {
//     // TODO: Test redeem source (slot 0) balance returns to 0 after transfer
//   });

//   it.skip("should handle concurrent redeem operations", async () => {
//     // TODO: Test multiple redeem nodes processing simultaneously
//   });

//   it.skip("should maintain same author account as mint vector", async () => {
//     // TODO: Test author_account matches mint vector for consistency
//   });

//   it.skip("should process multiple redemptions in single run cycle", async () => {
//     // TODO: Test run() processes all eligible redeem nodes
//   });

//   it.skip("should handle zero balance gracefully", async () => {
//     // TODO: Test behavior when source has zero NTC balance
//   });

//   it.skip("should respect NTC transfer fees in calculations", async () => {
//     // TODO: Test redeemFee is properly accounted for in balance checks
//   });
// });
