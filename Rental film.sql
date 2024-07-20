use film_rental;

# 1. What is the total revenue generated from all rentals in the database?
select sum(amount) as total_revenue from payment;

# 2. How many rentals were made in each month_name?
select monthname(rental_date) as month, count(*) as no_of_rentals from rental group by month;

# 3. What is the rental rate of the film with the longest title in the database?
select title, rental_rate from film where length(title) = (select max(length(title)) from film);

# 4. What is the average rental rate for films that were taken from last 30 days from the date("2005-05-05 22:04:30")?
select avg(amount) from payment
where datediff(payment_date, "2005-05-05 22:04:30") >= 30;

# 5. What is the most popular category of films in terms of the number of rentals?
# rental -> inventory -> film -> film_category -> category
# rental.inventory_id -> inventory.film_id -> film_category.film_id -> category.category_id
select cat.name, count(*) as most_popular_film from inventory inv inner join rental ren inner join film_category fc inner join category cat
on inv.inventory_id = ren.inventory_id and inv.film_id = fc.film_id and fc.category_id = cat.category_id
group by cat.name;

# 6. Find the longest movie duration from the list of films that have not been rented by any customer?
# film -> inventory
select film_id, title, description, length as duration, rating
from film
where film_id not in (select film_id from inventory) order by length desc limit 1; # method 1

select *, max(length) over() as "maximum_duration"
from film as t2 where film_id not in (select film_id from inventory); # method 2


# 7. What is the average rental rate for films, broken down by category?
# film -> film_category -> category
# film.film_id -> film.category.category_id
select category, avg(price) as average_rental_rate from film_list group by category; # method 1
select category.name, avg(film.rental_rate) as average_rental_rate
from film inner join film_category inner join category
on film.film_id = film_category.film_id and film_category.category_id = category.category_id
group by film_category.category_id; # method 2

# 8. What is the total revenue generated from rentals for each actor in the database?
# payment -> rental -> inventory -> film_actor -> actor
# payment.rental_id -> rental.inventory_id -> inventory.film_id -> film_actor.actor_id -> actor.actor_id
select
    concat_ws(" ", actor.first_name, actor.last_name) as actor,
    sum(payment.amount) as total_revenue
from payment inner join rental inner join inventory inner join film_actor inner join actor
on payment.rental_id = rental.rental_id and
   rental.inventory_id = inventory.inventory_id and
   inventory.film_id =  film_actor.film_id and
   film_actor.actor_id = actor.actor_id
group by actor.first_name, actor.last_name;

# 9. Show all the actresses who worked in a film having a "Wrestler" in description
select first_name, last_name
from film_actor inner join film inner join actor
on film_actor.film_id = film.film_id and film_actor.actor_id = actor.actor_id
where description like "%Wrestler%";

# 10. Which customers have rented the same film more than once?
# rental -> inventory | rental -> customer
select concat_ws(" ", customer.first_name, customer.last_name) as actor from rental inner join inventory inner join customer
on rental.inventory_id = inventory.inventory_id and customer.customer_id = rental.customer_id
group by customer.customer_id, film_id
having count(*) > 1;

# 11. How many films in the comedy category have a rental rate higher than the average rental rate?
# category -> film_category -> film
# category.category_id -> film_category.film_id
# film -> avg(rental_rate) (independent-sub_query) | category -> category_id = 'comedy' (correlated-sub_query - 58 rows)
select film.title
from film inner join film_category inner join category
on film_category.category_id = category.category_id and film.film_id = film_category.film_id
where category.name like "%comedy%" and film.rental_rate > (select avg(rental_rate) from film);

# 12. Which films have been rented the most by customers living in each city?
# city -> address -> customer -> rental -> inventory
# inventory.inventory_id -> rental.customer_id -> customer.address_id -> address.city_id
select city.city, count(*) as no_of_films from inventory inner join rental inner join customer inner join address inner join city
on inventory.inventory_id = rental.inventory_id and rental.customer_id = customer.customer_id and customer.address_id = address.address_id and address.city_id = city.city_id
group by 1
order by 2 desc;

# 13. What is the total amount spent by customers whose rental payments exceed $200?
# customer -> payment -> rental -> inventory -> film
select concat_ws(" ", customer.first_name, customer.last_name) as customer, sum(payment.amount) as total_purchase from customer inner join payment inner join rental inner join inventory inner join film
on customer.customer_id = payment.customer_id and payment.rental_id = rental.rental_id and rental.inventory_id = inventory.inventory_id and inventory.film_id = film.film_id
group by customer.customer_id
having total_purchase > 200;

# 14. Display the fields which are having foreign key constraints related to the "rental" table. [Hint: using Information_schema]
SELECT distinct CONSTRAINT_NAME
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
WHERE TABLE_NAME='rental' and CONSTRAINT_TYPE = "FOREIGN KEY";

# 15. Create a View for the total revenue generated by each staff member, broken down by store city with country name?
# payment -> staff -> store -> address | store -> staff
# payment.staff_id -> staff.staff_id -> store.manager_staff_id -> staff.staff_id | store.address_id -> address.city_id
CREATE VIEW sales_by_store
AS
(select
     concat_ws(" ", staff.first_name, staff.last_name) as manager,
     concat_ws(" ", city.city, country.country) as location,
     sum(payment.amount) as total_revenue
from payment inner join store inner join staff inner join address inner join city inner join country
on payment.staff_id = store.manager_staff_id and
   store.address_id = address.address_id and
   store.manager_staff_id = staff.staff_id and
   address.city_id = city.city_id and
   city.country_id = country.country_id
group by payment.staff_id
order by 3 desc);

select * from sales_by_store;

# 16. Create a view based on rental information consisting of visiting_day, customer_name, title of film, no_of_rental_days, amount paid by the customer along with percentage of customer spending.
# visiting_day : ranking based on customer payment history 
# no_of_rental_days : return_date - rental_date
# percentage : total distribution of the customer payment amount
create view customer_rental_info as
(select
    dense_rank() over (partition by rental.customer_id order by rental_date, return_date) as visiting_day,
    concat_ws(" ", first_name, last_name) as customer_name,
    film.title,
    datediff(return_date, rental_date) as no_of_rental_days,
    payment.amount,
    round(cume_dist() over (partition by rental.customer_id order by rental_date, return_date) *100,2) as percentage
from rental inner join customer inner join payment inner join inventory inner join film
    on rental.customer_id = customer.customer_id and rental.rental_id = payment.rental_id and rental.inventory_id = inventory.inventory_id and inventory.film_id = film.film_id);

select * from customer_rental_info;

# 17. Display the customers who paid 50% of their total rental costs within one day.
select *
from customer_rental_info
where percentage = 50 and no_of_rental_days < 1;




