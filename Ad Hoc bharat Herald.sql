CREATE DATABASE if not exists bharat_herald;
USE bharat_herald;
 


/* Business Request – 1: Monthly Circulation Drop Check
Generate a report showing the top 3 months (2019–2024) where any city recorded the 
sharpest month-over-month decline in net_circulation.
Fields:
• city_name
• month (YYYY-MM)
• net_circulation */ 
            
With CTE1 as (	
select 
	dc.city_id,dc.city as city_name, fs.month_num,fs.net_circulation,fs.year,
	lag(net_circulation) 
    over (partition by dc.city_id order by fs.month_num,fs.year) 
    as prev_month_circulation
from fact_print_sales fs inner join  dim_city dc
on fs.city_id = dc.city_id
)
select City_name, concat(year,'-',lpad(month_num,2,'0')) as month,net_circulation,
prev_month_circulation,
(net_circulation - prev_month_circulation) as MOM_change
from CTE1
WHERE prev_month_circulation IS  NOT NULL
ORDER BY MOM_change, mONTH 
LIMIT 3;


/*Business Request – 2: Yearly Revenue Concentration by Category
Identify ad categories that contributed > 50% of total yearly ad revenue.
Fields:
• year
• category_name
• category_revenue 
• total_revenue_year 
• pct_of_year_total */

with total_revenue as (
select year,sum(ad_revenue) as total_revenue_year
from fact_ad_revenue 
group by year
),
category_revenues as (
select far.year, t1.standard_ad_category as category_name, 
SUM(far.ad_revenue) AS category_revenue,y.total_revenue_year,
round((sum(far.ad_revenue)*100/y.total_revenue_year),2) as pct_of_year_total
from  fact_ad_revenue far 
join dim_ad_category t1
 on t1.ad_category_id = far.ad_category
join total_revenue y on y.year = far.year
group by t1.standard_ad_category , far.year,y.total_revenue_year ), 
rankd as (
select year, category_name, category_revenue,total_revenue_year,pct_of_year_total,
rank() over(partition by year order by category_revenue desc) as category_rnk
from category_revenues )
select year, category_name, category_revenue,total_revenue_year,pct_of_year_total,
   case when pct_of_year_total > 50 then 'yes' else 'No'
   end as excces_50_pt
   from rankd
where category_rnk = 1
order by year,pct_of_year_total desc;


/*Business Request – 3: 2024 Print Efficiency Leaderboard
For 2024, rank cities by print efficiency = net_circulation / copies_printed. Return top 5.
Fields:
• city_name
• copies_printed_2024
• net_circulation_2024
• efficiency_ratio = net_circulation_2024 / copies_printed_2024
• efficiency_rank_2024 */ 

with cte1 as (
select fps.city_id,
    sum(fps.Copies_Sold+fps.copies_returned) as copies_printed_2024,
	sum(fps.net_circulation) as net_circulation_2024
    -- round(sum(fps.Net_Circulation)/sum(fps.Copies_Sold+fps.copies_returned),4)
    -- as efficiency_ratio
from fact_print_sales fps 
where fps.year= 2024
group by fps.city_id
), 
city_efficiency_ratio as (
 select dc.city as city_name,
     copies_printed_2024,
	 net_circulation_2024,
 round(t1.Net_Circulation_2024*1.0/nullif(copies_printed_2024,0),4) as efficiency_ratio
from  cte1 t1
join  dim_city dc using(city_id)
),
rankd_efficiency_ratio as (
select city_name,copies_printed_2024,net_circulation_2024,efficiency_ratio,
rank() over(order by efficiency_ratio desc) as efficiency_ratio_2024
from city_efficiency_ratio  )
select upper(city_name) as city_name,copies_printed_2024,net_circulation_2024,
efficiency_ratio,efficiency_ratio_2024
from rankd_efficiency_ratio
where efficiency_ratio_2024 <=5
order by efficiency_ratio_2024 ;


/*Business Request – 4 : Internet Readiness Growth (2021)
For each city, compute the change in internet penetration from Q1-2021 to Q4-2021 
and identify the city with the highest improvement.
Fields:
• city_name
• internet_rate_q1_2021
• internet_rate_q4_2021
• delta_internet_rate = internet_rate_q4_2021 − internet_rate_q1_2021 */

SELECT upper(city) as city_name ,
max(case when quarter ='Q1-2021' then internet_penetration end) 
as internet_penetration_q1_2021,
max(case when quarter ='Q4-2021' then internet_penetration end)
as internet_penetration_q4_2021,
round((max(case when quarter = 'Q4-2021' then internet_penetration end) -
max(case when quarter = 'Q1-2021' then internet_penetration end) ),2) 
as delta_internet_rate
from fact_city_readiness fcr 
join dim_city c
on fcr.city_id = c.city_id
group by city
order by delta_internet_rate desc;

/*
Business Request – 5: Consistent Multi-Year Decline (2019→2024)
Find cities where both net_circulation and ad_revenue decreased every year from 2019 through 2024 (strictly decreasing sequences).
Fields:
city_name,year,yearly_net_circulation,yearly_ad_revenue,
is_declining_print (Yes/No per city over 2019–2024),is_declining_ad_revenue (Yes/No),
is_declining_both (Yes/No) */

with yrly_print as (
SELECT p.city as city_nam, fps.year, 
sum(fps.Net_Circulation) as yearly_net_circulation ,
round(sum(far.ad_revenue),2) as yearly_ad_revenue
from fact_print_sales fps 
join dim_city p on p.city_id = fps.City_ID
join fact_ad_revenue far 
on fps.edition_id = far.edition_id and fps.year = far.year
whErE fps.year in (2019,2024)
group by p.city, fps.year

), 
yrly_ad as (
SELECT city_nam, year, yearly_net_circulation, yearly_ad_revenue,
lag(yearly_net_circulation) 
over(partition by city_nam order by year) as priv_Net_Circulation,
lag(yearly_ad_revenue) over(partition by city_nam order by year ) as priv_ad_rvnu 
from yrly_print
),
final_data as (
select city_nam, year, yearly_ad_revenue,yearly_net_circulation,
case  when yearly_net_circulation < priv_Net_Circulation then 'yes' else 'No' end as is_declining_print,
case when yearly_ad_revenue <   priv_ad_rvnu then 'yes' else 'No' end  as is_declining_ad_revenue from yrly_ad
),
final_rport as (
 select *, case  when is_declining_ad_revenue='yes' and is_declining_print= 'yes' 
then 'yes' else 'No' end as is_declining_both
from final_data )
select * from final_rport where  is_declining_both = 'yes'
order by city_nam, year;

/* Business Request – 6 : 2021 Readiness vs Pilot Engagement Outlier
In 2021, identify the city with the highest digital readiness score but among the bottom 3 
in digital pilot engagement.
readiness_score = AVG(smartphone_rate, internet_rate, literacy_rate)
“Bottom 3 engagement” uses the chosen engagement metric provided (e.g., 
engagement_rate, active_users, or sessions).
Fields:
• city_name
• readiness_score_2021
• engagement_metric_2021
• readiness_rank_desc
• engagement_rank_asc
• is_outlier (Yes/No) */
with readiness as (
select p.city,round(avg(literacy_rate+smartphone_penetration+internet_penetration)/3,2) as readiness_score
from fact_city_readiness fp join dim_city p  on fp.city_id  = p.city_id where fp.year = 2021 group by p.city
),
engagement_rank as (
select p.city, coalesce(sum(downloads_or_accesses),0) as engagement_metric from fact_digital_pilot fp 
join dim_city p on fp.city_id = p.city_id group by p.city 
)
select r.city, r.readiness_score, f.engagement_metric,
rank() over( order by r.readiness_score desc) as readiness_rank_desc,
rank() over( order by f.engagement_metric asc) as engagement_rank_asc,
case when 
rank() over( order by r.readiness_score desc) = 1
and rank() over( order by f.engagement_metric asc) <=3 
then 'Yes' else 'No' end as is_outlier 
from readiness r 
join engagement_rank f on r.city = f.city;

