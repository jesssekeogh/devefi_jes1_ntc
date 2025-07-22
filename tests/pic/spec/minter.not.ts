// import { Manager } from "../setup/manager.ts";

// describe.skip("Minter", () => {
//   let manager: Manager;

//   beforeAll(async () => {
//     manager = await Manager.beforeAll();
//   });

//   afterAll(async () => {
//     await manager.afterAll();
//   });

//   it.skip("should track cycles balance before and after mint_ntc operations", async () => {
//     // TODO: Test cycles.balance() before/after mint_ntc calls and verify exact amounts
//   });

//   it.skip("should mint exact NTC amount equal to cycles received", async () => {
//     // TODO: Verify NTC minted equals cycles.accept() amount with no fees deducted
//   });

//   it.skip("should maintain cycles balance equal to total NTC supply", async () => {
//     // TODO: Ensure minter cycles balance >= total NTC supply at all times
//   });

//   it.skip("should reject mint_ntc with less than ONE_NTC (1e12) cycles", async () => {
//     // TODO: Test minting with < 1_000_000_000_000 cycles returns error
//   });

//   it.skip("should accept mint_ntc with ONE_NTC or more cycles", async () => {
//     // TODO: Test successful minting with >= 1_000_000_000_000 cycles
//   });

//   it.skip("should return correct error message for insufficient cycles", async () => {
//     // TODO: Verify error message format: "Not enough cycles received. Required: X, received: Y"
//   });

//   it.skip("should process redeem requests in priority order (largest balance first)", async () => {
//     // TODO: Test BTree ordering by (balance/1e8 << 32) | request_id for max-first processing
//   });

//   it.skip("should process maximum 10 redeem requests per timer iteration", async () => {
//     // TODO: Test MAX_CYCLE_SEND_CALLS limit in 30-second timer
//   });

//   it.skip("should skip redeem requests when minter has insufficient cycles", async () => {
//     // TODO: Test timer skips requests when cycles.balance() < request.amount
//   });

//   it.skip("should handle redeem requests when minter cycles are replenished", async () => {
//     // TODO: Test requests process after cycles balance increases
//   });

//   it.skip("should retry failed deposit_cycles calls up to 10 times", async () => {
//     // TODO: Test retry mechanism with exponential backoff for failed IC calls
//   });

//   it.skip("should abandon redeem requests after 10 failed retries", async () => {
//     // TODO: Test requests are permanently dropped after retry > 10
//   });

//   it.skip("should add redeem requests to queue when NTC received via onReceive", async () => {
//     // TODO: Test automatic request creation when NTC sent to canister subaccount
//   });

//   it.skip("should burn NTC tokens after adding redeem request to queue", async () => {
//     // TODO: Test NTC gets sent back to minter (burned) after request queuing
//   });

//   it.skip("should ignore NTC transfers below ONE_NTC threshold", async () => {
//     // TODO: Test onReceive ignores transfers < 1_000_000_000_000 NTC
//   });

//   it.skip("should generate correct subaccount from canister principal", async () => {
//     // TODO: Test canisterToSubaccount conversion with length prefix and padding
//   });

//   it.skip("should convert subaccount back to valid canister principal", async () => {
//     // TODO: Test subaccountToCanister reverses the conversion correctly
//   });

//   it.skip("should handle deposit_cycles to non-existent canister principal", async () => {
//     // TODO: Test IC.deposit_cycles error handling for invalid canister IDs
//   });

//   it.skip("should return correct redeem account for given canister", async () => {
//     // TODO: Test get_redeem_account returns proper Account with canister subaccount
//   });

//   it.skip("should provide paginated ntc_requests with correct metadata", async () => {
//     // TODO: Test get_ntc_requests pagination with page_size and page_number
//   });

//   it.skip("should limit page_size to maximum 1000 entries", async () => {
//     // TODO: Test page_size validation caps at 1000, defaults to 100
//   });

//   it.skip("should return stats with current cycles balance", async () => {
//     // TODO: Test get_ntc_stats returns accurate cycles.balance()
//   });

//   it.skip("should handle concurrent mint_ntc and redeem operations", async () => {
//     // TODO: Test thread safety between mint operations and timer-based redemptions
//   });

//   it.skip("should maintain request ordering with unique_request_id counter", async () => {
//     // TODO: Test unique_request_id increments and maintains request ordering
//   });
// });
