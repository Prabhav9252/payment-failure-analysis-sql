"""
Generates a synthetic payment gateway transactions dataset for the
Payment Failure Analysis portfolio project.

Planted patterns (the "ground truth" the SQL analysis should uncover):
1. UPI has a higher overall failure rate than other payment methods.
2. Within UPI, failures are heavily concentrated in ONE bank ("Kotak Bank")
   due to a simulated integration issue - not a general UPI problem.
3. Across ALL payment methods, failure rate spikes for transactions
   above Rs. 10,000 (simulated transaction limit / risk-check issue).
4. Device type has a mild, secondary effect (iOS slightly higher failure
   on Credit Card due to a simulated tokenization bug) - a smaller
   red herring pattern to demonstrate drilling down further.
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta

np.random.seed(42)

N = 80000  # total transactions

payment_methods = ["UPI", "Credit Card", "Debit Card", "Net Banking", "Wallet"]
pm_weights = [0.42, 0.20, 0.18, 0.12, 0.08]  # UPI dominates volume, like real Indian e-comm

banks = ["HDFC Bank", "ICICI Bank", "SBI", "Kotak Bank", "Axis Bank", "Yes Bank"]
bank_weights = [0.24, 0.22, 0.20, 0.14, 0.12, 0.08]

device_types = ["Android", "iOS", "Desktop"]
device_weights = [0.55, 0.30, 0.15]

start_date = datetime(2025, 1, 1)
end_date = datetime(2025, 6, 30)
date_range_days = (end_date - start_date).days

rows = []
for i in range(N):
    txn_id = f"TXN{100000 + i}"

    ts = start_date + timedelta(
        days=np.random.randint(0, date_range_days),
        hours=np.random.randint(0, 24),
        minutes=np.random.randint(0, 60),
    )

    method = np.random.choice(payment_methods, p=pm_weights)
    bank = np.random.choice(banks, p=bank_weights)
    device = np.random.choice(device_types, p=device_weights)

    # Amount: mostly small transactions, long tail of high-value ones
    amount = round(np.random.lognormal(mean=7.2, sigma=1.0), 2)
    amount = min(amount, 150000)  # cap extreme outliers

    # ---- Base failure probability by payment method ----
    base_fail_prob = {
        "UPI": 0.09,
        "Credit Card": 0.05,
        "Debit Card": 0.04,
        "Net Banking": 0.06,
        "Wallet": 0.03,
    }[method]

    fail_prob = base_fail_prob

    # ---- Planted pattern 1: UPI + Kotak Bank integration issue ----
    if method == "UPI" and bank == "Kotak Bank":
        fail_prob += 0.35  # big spike, this is the "root cause" to find

    # ---- Planted pattern 2: high amount transactions fail more (all methods) ----
    if amount > 10000:
        fail_prob += 0.18
    elif amount > 5000:
        fail_prob += 0.06

    # ---- Planted pattern 3: mild iOS + Credit Card tokenization issue ----
    if method == "Credit Card" and device == "iOS":
        fail_prob += 0.05

    fail_prob = min(fail_prob, 0.95)

    status = "FAILED" if np.random.random() < fail_prob else "SUCCESS"

    # Failure reason (only populated for failed transactions)
    if status == "FAILED":
        if method == "UPI" and bank == "Kotak Bank":
            reason = np.random.choice(
                ["BANK_TIMEOUT", "INVALID_VPA_RESPONSE", "GATEWAY_ERROR"],
                p=[0.6, 0.25, 0.15],
            )
        elif amount > 10000:
            reason = np.random.choice(
                ["LIMIT_EXCEEDED", "RISK_CHECK_DECLINED", "BANK_TIMEOUT"],
                p=[0.55, 0.3, 0.15],
            )
        elif method == "Credit Card" and device == "iOS":
            reason = np.random.choice(
                ["TOKENIZATION_ERROR", "OTP_TIMEOUT", "BANK_DECLINE"],
                p=[0.5, 0.3, 0.2],
            )
        else:
            reason = np.random.choice(
                ["INSUFFICIENT_FUNDS", "OTP_TIMEOUT", "BANK_DECLINE", "NETWORK_ERROR"],
                p=[0.35, 0.25, 0.25, 0.15],
            )
    else:
        reason = None

    rows.append(
        {
            "transaction_id": txn_id,
            "timestamp": ts.strftime("%Y-%m-%d %H:%M:%S"),
            "payment_method": method,
            "bank": bank,
            "device_type": device,
            "amount": amount,
            "status": status,
            "failure_reason": reason,
        }
    )

df = pd.DataFrame(rows)
df = df.sort_values("timestamp").reset_index(drop=True)

out_path = "/home/claude/payment_failure_project/transactions.csv"
df.to_csv(out_path, index=False)

print(f"Generated {len(df):,} transactions")
print(f"Overall failure rate: {(df['status']=='FAILED').mean()*100:.2f}%")
print(df.groupby("payment_method")["status"].apply(lambda s: (s=="FAILED").mean()*100).round(2))
