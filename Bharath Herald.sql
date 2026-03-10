CREATE DATABASE Bharat_Herald;

USE Bharat_Herald;

SHOW TABLES;

/* BusINess Request – 1: Monthlt CirculatiON Drop Check
Generate a report showing the top 3 Months (2019–2024) where any city recorded the sharpest Month-over-Month decline in net_circulation.
Fields: city_name, Month (YYYY-MM), net_circulation*/

SELECT * FROM dim_city;
SELECT * FROM fact_print_sales;

SELECT
	city_id, 
    Month,
    net_circulation,
    LAG(net_circulation) OVER(PARTITION BY city_id ORDER BY STR_TO_DATE(Month, '%m/%d/%Y')) AS prev_Month_circulatiON
FROM fact_print_sales;

WITH Month_format AS
(SELECT 
	DISTINCT Month,
		CASE 
			WHEN Month = '2019/05' THEN 'May-19'
            WHEN Month = '2020/03' THEN 'Mar-20'
            WHEN Month = '2020/08' THEN 'Aug-20'
            WHEN Month = '2021/02' THEN 'Feb-21'
            ELSE Month
            END AS New_Month
FROM fact_print_sales ORDER BY New_Month)
SELECT DISTINCT new_Month FROM Month_format;

ALTER TABLE fact_print_sales 
ADD COLUMN Month_Year VARCHAR(30);

SELECT * FROM fact_print_sales;

UPDATE fact_print_sales SET
Month_year = CASE 
			WHEN Month = '2019/05' THEN 'May-19'
            WHEN Month = '2020/03' THEN 'Mar-20'
            WHEN Month = '2020/08' THEN 'Aug-20'
            WHEN Month = '2021/02' THEN 'Feb-21'
            ELSE Month
            END;

ALTER TABLE fact_print_sales 
ADD COLUMN Year INT;

UPDATE fact_print_sales 
SET year = RIGHT(Month_year, 2);

UPDATE fact_print_sales
SET year = CASE 
				WHEN year = 19 THEN 2019
				WHEN year = 20 THEN 2020
                WHEN year = 21 THEN 2021
                WHEN year = 22 THEN 2022
                WHEN year = 23 THEN 2023
                WHEN year = 24 THEN 2024
                END;
                
ALTER TABLE fact_print_sales 
ADD COLUMN Month_order INT;

SELECT * FROM fact_print_sales;

UPDATE fact_print_sales SET 
Month_order = Month(STR_TO_DATE(CONCAT(Month_year, '-01'), '%b-%y-%d'));
WITH circulation_drop AS
(SELECT
	c.city,
    Month_year,
    net_circulation,
    LAG(net_circulation) OVER(PARTITION BY ps.city_id ORDER BY year, Month_order) AS prev_Month_circulatiON,
    (net_circulation - LAG(net_circulation) OVER(PARTITION BY ps.city_id ORDER BY year, Month_order)) AS circular_change
FROM fact_print_sales ps
JOIN dim_city c
ON ps.city_id = c.city_id
ORDER BY circular_change ASC)
SELECT 
	city,
	Month_year,
	net_circulation
FROM circulation_drop
WHERE circular_change IS NOT NULL
LIMIT 3;

/* BusINess Request – 2: Yearly Revenue concentratiON by Category
Identify ad categories that contributed > 50% of total yearly ad revenue.
Fields: year, category_name, category_revenue, total_revenue_year, pct_of_year_total. */

SELECT * FROM dim_ad_category;
SELECT * FROM fact_ad_revenue;

SELECT DISTINCT quarter FROM fact_ad_revenue;

ALTER TABLE fact_ad_revenue
ADD COLUMN quarter_year VARCHAR(10);

ALTER TABLE fact_ad_revenue
ADD COLUMN Qtr VARCHAR(10);

ALTER TABLE fact_ad_revenue
ADD COLUMN year INT;

ALTER TABLE fact_ad_revenue
ADD COLUMN ad_revenue_in_inr DECIMAL(10,2);

UPDATE fact_ad_revenue
SET quarter_year =
CASE
    -- Format: Q3-2024 (already correct)
    WHEN quarter REGEXP '^Q[1-4]-[0-9]{4}$' THEN quarter
    -- Format: 4th Qtr 2024
    WHEN quarter REGEXP '^[1-4]th Qtr [0-9]{4}$' THEN
        CONCAT(
            'Q',
            LEFT(quarter, 1),
            '-',
            RIGHT(quarter, 4)
        )

    -- Format: 2024-Q2
    WHEN quarter REGEXP '^[0-9]{4}-Q[1-4]$' THEN
        CONCAT(
            'Q',
            RIGHT(quarter, 1),
            '-',
            LEFT(quarter, 4)
        )
END;

UPDATE fact_ad_revenue 
SET Qtr = LEFT(quarter_year,2);

UPDATE fact_ad_revenue 
SET year = RIGHT(quarter_year,4);

UPDATE fact_ad_revenue
SET ad_revenue_IN_INR = CASE
							WHEN currency = 'INR' THEN ad_revenue
                            WHEN currency = 'IN RUPEES' THEN ad_revenue
							WHEN currency = 'EUR' THEN ad_revenue * 110
                            WHEN currency = 'USD' THEN ad_revenue * 90
                            END
;                            
                            
                            
/* BusINess Request – 2: Yearly Revenue ConcentratiON by Category
Identify ad categories that contributed > 50% of total yearly ad revenue.
Fields: year, category_name, category_revenue, total_revenue_year, pct_of_year_total. */

WITH total_category_revenue AS
(SELECT
	ad.year,
    c.category_group,
    SUM(ad_revenue_IN_INR) AS category_revenue,
    SUM(SUM(ad_revenue_IN_INR)) OVER(PARTITION BY year) AS total_revenue_year
FROM fact_ad_revenue ad
JOIN dim_ad_category c
ON ad.ad_category = c.ad_category_id
GROUP BY 1, 2)
SELECT
	year,
    category_group AS category_name,
    category_revenue,
    total_revenue_year,
    ROUND(category_revenue * 100 / total_revenue_year, 2) AS pct_of_year_total
FROM total_category_revenue
WHERE category_revenue * 100 / total_revenue_year > 50
ORDER BY year, pct_of_year_total DESC
;

/* BusINess Request – 3: 2024 Print Efficiency Leaderboard
For 2024, rank cities by print efficiency = net_circulation / copies_printed. Return top 5.
Fields: city_name, copies_printed_2024, net_circulation_2024, efficiency_ratio = net_circulation_2024 / copies_printed_2024
efficiency_rank_2024 */

SELECT * FROM fact_print_sales;
SELECT * FROM dim_city;

WITH 2024_print_efficiency AS
(SELECT
	c.city AS city_name,
    SUM(`copies sold` + copies_returned) AS copies_printed_2024,
    SUM(net_circulation) AS net_circulation_2024,
    SUM(net_circulation) / (SUM(`copies sold` + copies_returned)) AS efficiency_ratio
FROM fact_print_sales ps
JOIN dim_city c
ON ps.city_id = c.city_id
WHERE year = 24
GROUP BY city_name)

SELECT 
	city_name,
    copies_printed_2024,
    net_circulation_2024,
    efficiency_ratio,
    DENSE_RANK() OVER(ORDER BY efficiency_ratio DESC) AS efficiency_rank_2024
FROM 2024_print_efficiency
LIMIT 5;

SELECT 
city_id,
SUM(`copies sold` + copies_returned) FROM fact_print_sales
WHERE year = 24
GROUP BY city_id;

/* BusINess Request – 4 : Internet Readiness Growth (2021)
For each city, compute the change in Internet penetration from Q1-2021 to Q4-2021 and identify the city with the highest improvement.
Fields: city_name, internet_rate_q1_2021, internet_rate_q4_2021,delta_internet_rate = internet_rate_q4_2021 − internet_rate_q1_2021.*/

SELECT * FROM dim_city;
SELECT * FROM fact_city_readINess;

SELECT
	c.city,
    MAX(CASE WHEN RIGHT(cr.quarter,2) = 'Q1' THEN cr.internet_penetration END) AS internet_rate_q1_2021,
	MAX(CASE WHEN RIGHT(cr.quarter,2) = 'Q4' THEN cr.internet_penetration END) AS internet_rate_q4_2021,
    ROUND(
    MAX(CASE WHEN RIGHT(cr.quarter,2) = 'Q4' THEN cr.internet_penetration END) -
    MAX(CASE WHEN RIGHT(cr.quarter,2) = 'Q1' THEN cr.internet_penetration END), 2
    ) AS delta_internet_rate
FROM fact_city_readiness cr
JOIN dim_city c
ON cr.city_id = c. city_id
WHERE LEFT(cr.quarter,4) = 2021 AND RIGHT(cr.quarter,2) IN ('Q1', 'Q4')
GROUP BY c.city
ORDER BY delta_internet_rate DESC;

/* Business Request – 5: Consistent Multi-Year Decline (2019→2024)
Find cities where both net_circulation and ad_revenue decreased every year from 2019 through 2024 (strictly decreasing sequences).
Fields: city_name, year, yearly_net_circulation, yearly_ad_revenue, is_declining_print (Yes/No per city OVER 2019–2024),
is_declining_ad_revenue (Yes/No), is_declining_both (Yes/No) */

SELECT * FROM dim_city;
SELECT * FROM fact_print_sales;
SELECT * FROM fact_ad_revenue;

WITH total_circulatiON_revenue AS
		(SELECT
			c.city AS city_name,
			ps.year,
			SUM(ps.net_circulation) AS yearly_net_circulation,
			SUM(ar.ad_revenue_IN_INr) AS yearly_ad_revenue
		FROM dim_city c
		JOIN fact_print_sales ps
			ON c.city_id = ps.city_id
		JOIN fact_ad_revenue ar
			ON ps.edition_id = ar.edition_id
			AND ps.year = ar.year
		GROUP BY c.city, ps.year
		ORDER BY 1,2),
	prev_year AS
			(SELECT
				city_name,
                year,
                yearly_net_circulation,
                yearly_ad_revenue,
                LAG(yearly_net_circulation) OVER(PARTITION BY city_name ORDER BY year) AS prev_year_circulation,
				LAG(yearly_ad_revenue) OVER(PARTITION BY city_name ORDER BY year) AS prev_year_revenue
			FROM total_circulation_revenue),
		decline_flags AS
			(SELECT
				city_name,
                year,
                yearly_net_circulation,
                yearly_ad_revenue,
                CASE
					WHEN prev_year_circulation IS NOT NULL AND yearly_net_circulation < prev_year_circulation THEN 1 ELSE 0
                    END	AS print_decline_flag,
				CASE
					WHEN prev_year_revenue IS NOT NULL AND yearly_ad_revenue < prev_year_revenue THEN 1 ELSE 0
                    END	AS ad_revenue_decline_flag
				FROM prev_year)
SELECT
	df.city_name,
    df.year,
    df.yearly_net_circulation,
    df.yearly_ad_revenue,
    CASE
		WHEN SUM(df.print_decline_flag) = 5 THEN 'Yes' ELSE 'No' END AS is_declining_print,
    CASE    
        WHEN SUM(df.ad_revenue_decline_flag) = 5 THEN 'Yes' ELSE 'No' END AS is_declining_ad_revenue,
	CASE
		WHEN SUM(df.print_decline_flag) = 5
        AND SUM(df.ad_revenue_decline_flag) = 5 THEN 'Yes' ELSE 'No' END AS IS_declning_both
FROM decline_flags df
JOIN prev_year py
	ON df.city_name = py.city_name AND df.year = py.year 
GROUP BY city_name, year
ORDER BY city_name, year;
        
/* Business Request – 6 : 2021 Readiness vs Pilot Engagement Outlier
IN 2021, identify the city with the highest digital readiness score but among the bottom 3 in digital pilot engagement.
readiness_score = AVG(smartphone_rate, internet_rate, literacy_rate)
“Bottom 3 engagement” uses the chosen engagement metric provided (e.g., engagement_rate, active_users, or sessions).
Fields: city_name, readiness_score_2021, engagement_metric_2021, readiness_rank_DESC, engagement_rank_ASC, is_outlier (Yes/No) */

SELECT * FROM dim_city;
SELECT * FROM fact_city_readiness;
SELECT * FROM fact_digital_pilot;

WITH readiness AS
			(SELECT
				c.city AS city_name,
				ROUND(AVG((cr.literacy_rate + cr.smartphone_penetration + cr.internet_penetration)/3),2) AS readiness_score_2021
			FROM fact_city_readiness cr
            JOIN dim_city c
				ON cr.city_id = c.city_id
			WHERE LEFT(cr.quarter,4) = 2021
            GROUP BY c.city),
		engagement AS 
			(SELECT
				c.city AS city_name,
                SUM(dp.users_reached) AS engagement_metric_2021
			FROM fact_digital_pilot dp
            JOIN dim_city c
				ON dp.city_id = c.city_id
			WHERE year(STR_TO_DATE(CONCAT(dp.launch_Month, '-01'), '%Y-%m-%d')) = 2021
            GROUP BY c.city
            ),
		combained AS
			(SELECT
				r.city_name,
                r.readiness_score_2021,
                e.engagement_metric_2021
			FROM readiness r
            JOIN engagement e
				ON r.city_name = e.city_name),
		ranked AS
			(SELECT
				city_name,
                readiness_score_2021,
				engagement_metric_2021,
                DENSE_RANK() OVER(ORDER BY readiness_score_2021 DESC) AS readiness_rank_DESC,
                DENSE_RANK() OVER(ORDER BY engagement_metric_2021) AS engagement_rank_ASC
			FROM combained)
SELECT
	city_name,
    readiness_score_2021,
    engagement_metric_2021,
    readiness_rank_DESC,
    engagement_rank_ASC,
    CASE
		WHEN engagement_rank_ASC <= 3 THEN "Yes" 
        ELSE 'No'
        END AS is_outlier
FROM ranked
ORDER BY engagement_rank_ASC, readiness_rank_DESC;