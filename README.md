# DeVeFi NTC Vector
This package operates within the context of a pylon system and the ICRC-55 standard. Modules within the DeVeFi framework follow the naming convention: `devefi` _ `<author>` _ `<module>`.

Note: This README assumes familiarity with ICP, NTC (Neutrinite Cycles), and the cycles minting process. Not all concepts are explained in detail.

This module provides two complementary vectors for NTC operations: **Mint Vector** for converting ICP to NTC, and **Redeem Vector** for distributing NTC to multiple canisters.

## Mint Vector – Practical Benefits
- Exchange ICP for NTC so you can set aside compute today and redeem them whenever you need cycles.

- Buy cycles in advance to keep budgets on course and avoid surprise price swings.

- Slot Mint Vector into neuron vectors, exchange vectors, or other ICP processes (e.g., ckBTC → ICP → NTC → cycles) to automate top‑ups.

- Ideal for bulk buying or trading systems that must convert large amounts of cycles on demand (DAO treasuries).

## Redeem Vector – Practical Benefits
- Split NTC among multiple canisters, each with its own label and percentage share.

- Manage all top ups from one place instead of juggling individual canister balances.

- Build pipelines that top up canisters as soon as they need cycles no manual checks required.

## Powerful Combinations
- Stream Mint + Redeem for end‑to‑end automation or add on other vectors such as an ICP neuron vector disburses ICP and mints NTC; Redeem Vector then distributes cycles to canisters exactly where you want them.

- Connect to the broader DeVeFi ecosystem. Accept top‑ups from any supported token and mix in other vectors (throttle, liquidity, and more) for sophisticated cycles management.

## NTC Mint Vector

The Mint Vector continuously monitors the "Mint" source for ICP deposits. When sufficient ICP is received (minimum 1 ICP), it automatically:
1. Sends ICP to the Cycles Minting Canister with a top-up notification
2. Waits for cycles to be credited to the vector's canister
3. Calls the NTC Minter to convert cycles to NTC tokens
4. Forwards the minted NTC to your configured destination

**"Mint" source**

This ICRC-1 account accepts ICP tokens. When you send ICP above the minimum threshold (1 ICP), the vector automatically forwards the tokens to the Cycles Minting Canister (CMC) and initiates the top-up process. The vector then converts the received cycles to NTC tokens through the NTC Minter.

**"_To" source**

This hidden ICRC-1 account is used internally to forward newly minted NTC tokens to your destination account.

The Mint Vector includes one configurable destination account:

**"To" destination**

The ICRC-1 account where your newly minted NTC tokens are sent after the conversion process completes.

## NTC Redeem Vector

The Redeem Vector continuously monitors the "Redeem" source for NTC deposits. When NTC is received, it automatically calculates the split amounts based on your configured percentages and sends NTC to each destination canister's redemption subaccount on the NTC Minter.

**"Redeem" source**

This ICRC-1 account accepts NTC tokens for distribution to your configured canister destinations.

**Multiple destinations**

You can configure multiple destination canisters with custom names and allocation percentages. The vector automatically calculates the split amounts and sends NTC to each canister's redemption subaccount on the NTC Minter. For example, you might configure:
- "Canister 1" (50%)
- "Canister 2" (30%) 
- "Canister 3" (20%)

The Redeem Vector supports up to 50 characters for destination names and ensures fair distribution by sending any remaining dust to the destination with the largest allocation percentage.

```javascript
'variables': {
    'split': [50, 30, 20],
    'names': ["Canister 1", "Canister 2", "Canister 3"],
},
```

## Billing

To cover operational costs and reward the pylon, author, platform, and affiliates, the module and pylon charge fees:

**Mint Vector**
- 0.1 NTC flat fee per transaction (20x fee multiplier)

**Redeem Vector**  
- 0.025 NTC flat fee per transaction (5x fee multiplier; this fee is not yet activated)

## Running the Tests

This repository includes a compressed copy of the `nns_state`, which is decompressed during the npm install process via the postinstall script. The script uses command `tar -xvf ./state/nns_state.tar.xz -C ./` to extract the file. The tests use multiple canisters along with the module to perform operations such as creating vectors, minting NTC from ICP, redeeming NTC to multiple canisters, and simulating various transaction scenarios. As a result, the tests may take a while to complete.

These instructions have been tested on macOS. Ensure that the necessary CLI tools (e.g., git, npm) are installed before proceeding.

```bash
# clone the repo
git clone https://github.com/jesssekeogh/devefi_jes1_ntc.git

# change directory
cd devefi_jes1_ntc/tests/pic

# install the required packages
npm install

# run the tests
npx jest
```

## License

*To be decided*