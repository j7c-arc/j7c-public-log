# 2026-10-02 — Argus milestone on-chain audit

**Status:** verified on-chain observation; publication pending

**Conclusion:** J7C has not reached the Argus bonding milestone. At 15:20 KST, the deployed launch hook returned `bonded = false`. The current pool tick produced **6.6621%** progress under Argus's documented tick formula.

## Primary evidence

- Network: Arc Mainnet, chain ID `5042`
- Token: `0x4060e632bBb7D731d50fA8Fc58C82D93154085c1`
- Uniswap v4 pool ID: `0xf962e883fd2ab4b21e1248a7ea62835f3ae31f6103351f74dfada89d43c63c36`
- PoolManager: `0x8366a39CC670B4001A1121B8F6A443A643e40951`
- Launch hook: `0xa0f36d2fb95f6c31f8fce28904d6b3ec335760cc`
- Portal returned by the hook: `0xeed7559b8a6abf64427dc41cb5cc6400109c5d93`
- Initialization transaction: `0xa941de73e39afec991167013282818448d75377a4233c7848760d3c13a6cde99`

The pool's `Initialize` event identifies a starting tick of `405400`. The hook returned a bonding tick of `376400`, and Uniswap v4 StateView returned a current tick of `403468`.

Argus documents display progress as:

```text
(currentTick - tickStart) / (tickBond - tickStart)
```

For J7C:

```text
(403468 - 405400) / (376400 - 405400) × 100
= 6.662068965517241%
```

The hook's permanent bonding latch remains false, so the token has not previously crossed the milestone and then retraced. This distinction matters because Argus documents the latch as monotonic: once it becomes true, a later price retreat does not clear it.

## Portal discovery note

The seven Portal addresses listed in the current [official integration guide](https://github.com/arguspad/argus-world/blob/main/docs/07-integrate.md) returned empty launch records for this token. The live J7C hook's `portal()` getter points to the additional Portal address above, and that Portal returns the J7C launch record. The deployed contracts are therefore the primary evidence for this audit.

The result was independently cross-checked against Fuci's free token endpoint, which returned `bonded: false` and the same `6.662068965517241` progress value. Fuci is a third-party cross-check, not the authority for this conclusion.

The [read-only verifier](tools/check_argus_milestone.ps1) repeats the contract calls and refuses to calculate progress unless the chain ID, token, Portal, hook, pool ID, and bonding tick all match the expected J7C deployment. Its 15:26 KST run passed every invariant and produced the same result.

## Limits

The Argus web page was not used as the primary source because a previous read presented a Cloudflare browser check. The earlier 1.5% page observation is dated and is not treated as current. This audit made no wallet call, signature, trade, payment, post, reply, like, or repost.

## Sources

- [Argus market integration guide](https://github.com/arguspad/argus-world/blob/main/docs/08-integrate-markets.md)
- [Argus LaunchHook reference](https://github.com/arguspad/argus-world/blob/main/contracts/LaunchHook.sol)
- [Argus official repository](https://github.com/arguspad/argus-world)
- [Fuci free token cross-check](https://www.fuci.family/api/token/0x4060e632bBb7D731d50fA8Fc58C82D93154085c1)
