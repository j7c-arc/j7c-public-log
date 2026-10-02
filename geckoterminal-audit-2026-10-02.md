# 2026-10-02 — GeckoTerminal index and metadata audit

**Status:** verified observation; publication pending

**What changed:** We verified that GeckoTerminal's public API resolves the exact J7C contract on Arc to the J7C/USDC pool. This was a read-only audit; no listing request, metadata update, payment, trade, or wallet action was made.

**Evidence:** At 2026-10-02 14:46 KST, the [pool search endpoint](https://api.geckoterminal.com/api/v2/search/pools?query=0x4060e632bbb7d731d50fa8fc58c82d93154085c1) returned the Arc pool `0xf962e883fd2ab4b21e1248a7ea62835f3ae31f6103351f74dfada89d43c63c36` for token `0x4060e632bBb7D731d50fA8Fc58C82D93154085c1`. The [token endpoint](https://api.geckoterminal.com/api/v2/networks/arc/tokens/0x4060e632bbb7d731d50fa8fc58c82d93154085c1) identified the token as Joan of ARC (`J7C`) with 18 decimals, while `image_url` and `coingecko_coin_id` were null. The [pool endpoint](https://api.geckoterminal.com/api/v2/networks/arc/pools/0xf962e883fd2ab4b21e1248a7ea62835f3ae31f6103351f74dfada89d43c63c36) reported a price of about $0.000003007609436, FDV of about $3,007.61, no buys or sells, and $0.00 volume across its 24-hour fields.

**What we learned:** J7C is indexable by its exact contract and pool address, but its GeckoTerminal branding metadata is incomplete. Search results for the name “Joan of Arc” can surface an unrelated `JOAN` token with a different contract, so every link and public note must use the full J7C contract. The token endpoint's `total_reserve_in_usd` did not match the pool endpoint's `reserve_in_usd`; we preserve the two field names rather than treating them as the same liquidity measure.

**Open questions:** GeckoTerminal does not expose a J7C image or CoinGecko coin ID in the token response. The current metadata-update flow previously presented a paid Fast Pass, and no free review path has been verified. The audit does not establish a current Argus milestone value.

**Next experiment:** Keep the full contract and direct pool link prominent in public project materials. Submit accurate logo and project metadata only if GeckoTerminal provides a verified no-payment route; do not pay for a listing or imply that GeckoTerminal endorses the project.

**Correction history:** None.
