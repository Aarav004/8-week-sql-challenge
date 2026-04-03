
-- What is the total amount each customer spent at the restaurant?
select s.customer_id, Sum(m.price) as total_amount
from dannys_diner.sales s
inner join  dannys_diner.menu m 
	on m.product_id = s.product_id
group by s.customer_id

-- How many days has each customer visited the restaurant?
SELECT customer_id, COUNT(order_date) as days_visited
FROM dannys_diner.sales 
GROUP BY customer_id

--What was the first item from the menu purchased by each customer?
SELECT DISTINCT customer_id, FIRST_VALUE(product_id) 
	OVER(PARTITION BY customer_id ORDER BY order_date)
FROM dannys_diner.sales

-- What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT product_name, COUNT(order_date) as times_purchased
FROM dannys_diner.sales s
inner join dannys_diner.menu m on m.product_id = s.product_id
group by product_name
order by times_purchased desc
limit 1;

--Which item was the most popular for each customer?
select customer_id, m.product_name
from (
	select customer_id, product_id,
		rank() over(partition by customer_id 
					order by count DESC) as rnk
	from (
		SELECT customer_id,product_id, COUNT(*)

		FROM dannys_diner.sales 
		group by customer_id, product_id
		order by customer_id, count desc) as t) as u
inner join dannys_diner.menu m on m.product_id = u.product_id

where rnk = 1

--Which item was purchased first by the customer after they became a member?
with cte as(
	select m.customer_id, 
	first_value(product_id) over(partition by m.customer_id order by order_date) as first_order
	from dannys_diner.members m
	left join dannys_diner.sales s on s.customer_id = m.customer_id
	where s.order_date > m.join_date)

select customer_id, product_name
from cte
inner join dannys_diner.menu m on m.product_id= cte.first_order
group by customer_id, product_name

--Which item was purchased just before the customer became a member?
with last_orders as (
	select m.customer_id, order_date,
	last_value(product_id) over(partition by s.customer_id 
								order by order_date 
								rows between unbounded preceding and unbounded following) as last_order
	from dannys_diner.sales s
	inner join dannys_diner.members m on m.customer_id = s.customer_id
	where join_date > order_date)

select customer_id, product_name
from last_orders l
inner join dannys_diner.menu m on m.product_id = l.last_order
group by customer_id, product_name


--What is the total items and amount spent for each member before they became a member?
select s.customer_id, count(s.product_id) as total_items,
	sum(price) as amount_spent
from dannys_diner.sales s
inner join dannys_diner.members m 
	on m.customer_id = s.customer_id
inner join dannys_diner.menu mn 
	on mn.product_id = s.product_id
where join_date > order_date
group by s.customer_id


-- If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
with amount as(
	select customer_id,m.product_name,
		sum(price) as amount_spent
	from dannys_diner.sales s
	inner join dannys_diner.menu m on m.product_id = s.product_id
	group by customer_id, product_name),
points as(
	select customer_id, product_name, amount_spent,
	CASE WHEN product_name = 'sushi' then amount_spent *2*10 
		else amount_spent * 10 end as points
	from amount)
select customer_id, sum(points)
from points
group by customer_id

--In the first week after a customer joins the program (including their join date) 
--they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?


with amount as(
	select customer_id,m.product_name,order_date,
		sum(price) as amount_spent
	from dannys_diner.sales s
	inner join dannys_diner.menu m on m.product_id = s.product_id
	group by customer_id, product_name, order_date),
points as(
	select mb.customer_id, product_name,order_date, amount_spent,
		CASE WHEN order_date between join_date and join_date + interval '7 days'
				then amount_spent *2*10
			WHEN product_name = 'sushi' then amount_spent *2*10 
			else amount_spent * 10 
		end as points
	from amount a
	inner join dannys_diner.members mb on mb.customer_id = a.customer_id	
)

select customer_id, sum(points)
from points
group by customer_id

--Recreate the following table output using the available data:

--customer_id	order_date	product_name	price	member
--A				2021-01-01		curry		15		N
--A				2021-01-01		sushi		10		N


select customer_id, order_date, product_name, price, 
	case when mb.join_date <= order_date then 'Y'
		else 'N' end as member
from dannys_diner.sales s
left join dannys_diner.menu mn using(product_id)
left join dannys_diner.members mb using(customer_id)
order by customer_id, order_date, product_name

-- Danny also requires further information about the ranking of customer products,
--but he purposely does not need the ranking for non-member purchases 
--so he expects null ranking values for the records 
--when customers are not yet part of the loyalty program.
with ranking as(
	select t.customer_id, t.order_date,
	rank() over(partition by t.customer_id 
				order by t.order_date) as ranking
	from (select distinct s.customer_id, s.order_date -- to make sure that rows are not duplicated when we join
		  from dannys_diner.sales s
		 inner join dannys_diner.members m on m.customer_id = s.customer_id
		 where order_date >=  join_date) as t
)

select s.customer_id, s.order_date, product_name, price, 
	case when mb.join_date <= s.order_date then 'Y'
		else 'N' end as member,
	ranking
from dannys_diner.sales s
left join dannys_diner.menu mn using(product_id)
left join dannys_diner.members mb using(customer_id)
left join ranking r on r.customer_id = s.customer_id and r.order_date = s.order_date
order by s.customer_id, s.order_date, product_name
































