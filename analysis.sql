-- Overall Data View
select * from transactions

-- ============================================================
-- Payment Failure Analysis
-- Business Problem to solve:-  Which payment methods fail most, and is the failure
-- concentrated in a specific bank, device, or amount range?
-- ============================================================
-- Q1 :- calculate failure rate by payment method

select payment_method,count(*) as total_txns,
sum(case when status='FAILED' then 1 else 0 end) as failed_txns,
ROUND(sum(case when status='FAILED' then 1 else 0 end)*100.0/count(*),2) as failure_pct_rate
from transactions
group by payment_method
order by failure_pct_rate desc

-- Q2 :- now we go deeper into segment like for each bank we gonna calculate no of UPI transactions and their failure rate
select bank,
count(*) as upi_txns,
sum(case when status='FAILED' then 1 else 0 end) as failed_txns,
ROUND(sum(case when status='FAILED' then 1 else 0 end)*100.0/count(*),2) as failure_pct_rate
from transactions
where payment_method = 'UPI'
group by bank
order by failure_pct_rate desc

-- Q3:-  Confirm the finding is UPI x Bank specific, not just that
-- bank being bad in general (rules out "Kotak Bank is just unreliable")

select bank,
payment_method,
count(*) as total_txns,
sum(case when status='FAILED' then 1 else 0 end) as failed_txns,
ROUND(sum(case when status='FAILED' then 1 else 0 end)*100.0/count(*),2) as failure_pct_rate
from transactions
group by bank,payment_method
order by failure_pct_rate desc

--Q4 now we check whether if it is a device specific problem or not

select 
payment_method,device_type,
count(*) as total_txns,
sum(case when status='FAILED' then 1 else 0 end) as failed_txns,
ROUND(sum(case when status='FAILED' then 1 else 0 end)*100.0/count(*),2) as failure_pct_rate
from transactions
group by payment_method,device_type
order by payment_method,failure_pct_rate desc

-- Q5 -- Now we bucket transactions by amount range and check failure concentration
with cte as (
select 
	case
		WHEN amount < 500 THEN '1. Under 500'
        WHEN amount < 2000 THEN '2. 500-2000'
        WHEN amount < 5000 THEN '3. 2000-5000'
        WHEN amount < 10000 THEN '4. 5000-10000'
        ELSE '5. Above 10000'
    END AS amount_bucket,
*
from transactions)
select amount_bucket,
count(*) as total_txns,
sum(case when status='FAILED' then 1 else 0 end) as failed_txns,
ROUND(sum(case when status='FAILED' then 1 else 0 end)*100.0/count(*),2) as failure_pct_rate
from cte
group by amount_bucket
order by amount_bucket

-- Q6: The real diagnostic would be to isolate UPI+kotak bank failures from
-- everything else, to size EXACTLY how much of the "UPI problem" is
-- actually this one integration issue.
with cte as (
select case
		when payment_method='UPI' and bank='Kotak Bank' then 'UPI+Kotak Bank'
		when payment_method = 'UPI'then 'UPI + all other banks'
		else 'Non UPI' end as segment,
*
from transactions
)
select segment
,count(*) as total_txns,
sum(case when status='FAILED' then 1 else 0 end) as failed_txns,
ROUND(sum(case when status='FAILED' then 1 else 0 end)*100.0/count(*),2) as failure_pct_rate,
    -- what share of ALL UPI failures does this segment account for
    ROUND(100.0 * SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) /
        (SELECT SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) FROM transactions WHERE payment_method = 'UPI'), 2
    ) AS pct_of_total_upi_failures
FROM cte
WHERE payment_method = 'UPI'
GROUP BY segment;
-- Q7: Top failure reasons within the isolated problem segment which is UPI + Kotak Bank Segment
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
