-- ============================================================
-- Payment Failure Analysis
-- Question: Which payment methods fail most, and is the failure
-- concentrated in a specific bank, device, or amount range?
-- ============================================================

-- STEP 1: Aggregate failure rate by payment method
-- (This is the number that would show up on a leadership dashboard
--  and trigger the investigation)
SELECT
    payment_method,
    COUNT(*) AS total_txns,
    SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) AS failed_txns,
    ROUND(100.0 * SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) / COUNT(*), 2) AS failure_rate_pct
FROM transactions
GROUP BY payment_method
ORDER BY failure_rate_pct DESC;


-- STEP 2: Drill into the worst offender (UPI) by bank
-- This is where "UPI is broken" either gets confirmed or falsified
SELECT
    bank,
    COUNT(*) AS total_upi_txns,
    SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) AS failed_txns,
    ROUND(100.0 * SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) / COUNT(*), 2) AS failure_rate_pct
FROM transactions
WHERE payment_method = 'UPI'
GROUP BY bank
ORDER BY failure_rate_pct DESC;


-- STEP 3: Confirm the finding is UPI x Bank specific, not just that
-- bank being bad in general (rules out "Kotak Bank is just unreliable")
SELECT
    bank,
    payment_method,
    COUNT(*) AS total_txns,
    ROUND(100.0 * SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) / COUNT(*), 2) AS failure_rate_pct
FROM transactions
WHERE bank = 'Kotak Bank'
GROUP BY payment_method
ORDER BY failure_rate_pct DESC;


-- STEP 4: Check device type as a secondary factor
SELECT
    payment_method,
    device_type,
    COUNT(*) AS total_txns,
    ROUND(100.0 * SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) / COUNT(*), 2) AS failure_rate_pct
FROM transactions
GROUP BY payment_method, device_type
ORDER BY payment_method, failure_rate_pct DESC;


-- STEP 5: Bucket transactions by amount range and check failure concentration
SELECT
    CASE
        WHEN amount < 500 THEN '1. Under 500'
        WHEN amount < 2000 THEN '2. 500-2000'
        WHEN amount < 5000 THEN '3. 2000-5000'
        WHEN amount < 10000 THEN '4. 5000-10000'
        ELSE '5. Above 10000'
    END AS amount_bucket,
    COUNT(*) AS total_txns,
    SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) AS failed_txns,
    ROUND(100.0 * SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) / COUNT(*), 2) AS failure_rate_pct
FROM transactions
GROUP BY amount_bucket
ORDER BY amount_bucket;


-- STEP 6: The real diagnostic - isolate UPI+Kotak Bank failures from
-- everything else, to size EXACTLY how much of the "UPI problem" is
-- actually this one integration issue.
SELECT
    CASE
        WHEN payment_method = 'UPI' AND bank = 'Kotak Bank' THEN 'UPI x Kotak Bank (suspected root cause)'
        WHEN payment_method = 'UPI' THEN 'UPI x All other banks'
        ELSE 'Non-UPI'
    END AS segment,
    COUNT(*) AS total_txns,
    SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) AS failed_txns,
    ROUND(100.0 * SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) / COUNT(*), 2) AS failure_rate_pct,
    -- what share of ALL UPI failures does this segment account for
    ROUND(100.0 * SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) /
        (SELECT SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) FROM transactions WHERE payment_method = 'UPI'), 2
    ) AS pct_of_total_upi_failures
FROM transactions
WHERE payment_method = 'UPI'
GROUP BY segment;


-- STEP 7: Top failure reasons within the isolated problem segment
SELECT
    failure_reason,
    COUNT(*) AS occurrences,
    ROUND(100.0 * COUNT(*) / (
        SELECT COUNT(*) FROM transactions
        WHERE payment_method = 'UPI' AND bank = 'Kotak Bank' AND status = 'FAILED'
    ), 2) AS pct_of_segment_failures
FROM transactions
WHERE payment_method = 'UPI' AND bank = 'Kotak Bank' AND status = 'FAILED'
GROUP BY failure_reason
ORDER BY occurrences DESC;
