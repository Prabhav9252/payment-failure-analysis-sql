# Payment Failure Analysis: Isolating a Bank-Specific Integration Issue

## Business Question
Which payment methods fail most often, and is the failure a genuine product
problem or concentrated in a specific bank, device, or transaction amount range?

## Dataset
80,000 synthetic payment gateway transactions (Jan–Jun 2025) with payment
method, bank, device type, amount, and status. Structured to mirror a
real Indian e-commerce/fintech payment gateway log. *(Synthetic data, built
to practice root-cause drill-down methodology on a realistic failure pattern.)*

## The Investigation

**Step 1 — Aggregate view.** UPI shows a 14.65% failure rate, roughly 2x
every other payment method. At face value, this reads as "UPI is broken."

**Step 2 — Drill into UPI by bank.** UPI transactions routed through
**Kotak Bank fail at 44.80%** — every other bank's UPI transactions fail
at a normal 9.6–10.1%. The problem isn't UPI. It's one bank's UPI integration.

**Step 3 — Rule out "Kotak Bank is just unreliable."** Kotak Bank's failure
rate on Credit Card, Debit Card, Net Banking, and Wallet is 4–8%, in line
with every other bank. The issue is specific to the UPI × Kotak Bank
combination, not the bank generally.

**Step 4 — Size the impact.** UPI × Kotak Bank is only 5.9% of total
transaction volume but accounts for **42.56% of all UPI failures** — a
small segment driving nearly half the problem.

**Step 5 — Failure reason breakdown.** Within this segment, 61% of failures
are `BANK_TIMEOUT` — consistent with a latency/integration issue on the
bank's side rather than a customer-side error (wrong PIN, insufficient
funds, etc.).

**Step 6 — Secondary pattern (amount).** Independent of the bank issue,
transactions above ₹10,000 fail at 29.0% vs. an 8–9% baseline for
everything under ₹5,000 — consistent with a transaction-limit or
risk-check trigger. This is a separate issue from the Kotak Bank problem
and needs its own fix.

**Step 7 — Minor pattern (device).** Credit Card transactions on iOS fail
at 10.5% vs. 6.2–6.3% on Android/Desktop — a smaller effect, flagged for
follow-up but not the primary driver.

## Key Finding
> The UPI failure spike is not a UPI product issue. **42.56% of all UPI
> failures trace to a single bank integration (Kotak Bank), driven
> primarily by timeout errors**, despite that segment being under 6% of
> UPI volume. A second, unrelated issue affects high-value transactions
> (>₹10,000) across all payment methods.

## Recommendation
1. Escalate the Kotak Bank UPI integration to the payments engineering
   team as a P1 — timeout-dominated failures at 44.8% suggest a specific
   technical fault, not a fluke.
2. Review the risk-check/limit logic for transactions above ₹10,000
   separately — conflating this with the UPI issue would misdiagnose
   the fix.
3. Monitor Credit Card + iOS as a lower-priority follow-up.

## What This Demonstrates
- Multi-dimensional segmentation (payment method → bank → device → amount)
- The discipline of drilling down before concluding — the headline number
  ("UPI is broken") would have led to the wrong fix
- Distinguishing correlation from a genuinely isolated root cause (Step 3
  ruling out "Kotak is just bad")
- Quantifying impact, not just flagging a pattern (the 42.56%-of-failures
  framing is what makes this actionable for a decision-maker)

## Files
- `transactions.csv` — raw synthetic dataset
- `generate_data.py` — dataset generation script (documents assumptions/patterns)
- `analysis.sql` — full SQL drill-down, in the order an analyst would run it
- `failure_analysis_charts.png` — summary visual
