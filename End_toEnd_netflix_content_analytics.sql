
USE Netflix_Content_Analytics
SELECT * 
FROM netflix_raw
ORDER BY show_id


-- Handle foreign characters (ex: Korean letters)
-- Done by replacing varchar to nvarchar  in title datatype.


-- Remove duplicates
SELECT show_id, count(*)  
FROM netflix_raw
GROUP BY show_id
HAVING count(*)>1

--
SELECT * FROM netflix_raw
WHERE CONCAT(title, type) IN (
SELECT CONCAT(title, type)
FROM netflix_raw
GROUP BY title, type
HAVING count(*)>1)
ORDER BY title 

WITH cte as (
SELECT *, row_number() OVER (PARTITION BY title, type ORDER BY show_id) as rn
FROM netflix_raw
)
SELECT *
FROM cte
WHERE rn=1            -- After executing this, you can find 3 less rows coz the duplicates were dropped.



-- new table for listed in, director, country, cast
SELECT show_id, trim(value) as director
INTO netflix_director
FROM netflix_raw
cross apply string_split(director, ',')

SELECT * FROM netflix_director           -- Verify by running this
--

SELECT show_id, trim(value) as country
INTO netflix_country
FROM netflix_raw
cross apply string_split(country, ',')

SELECT * FROM netflix_country            -- Verify by running this
--

SELECT show_id, trim(value) as cast
INTO netflix_cast
FROM netflix_raw
cross apply string_split(cast, ',')

SELECT * FROM netflix_cast               -- Verify by running this
--

SELECT show_id, trim(value) as genre
INTO netflix_genre
FROM  netflix_raw
cross apply string_split(listed_in, ',')

SELECT * FROM netflix_genre				  -- Verify by running this
--

-- Convert the date_added column to "date" data type from varchar
	-- "cast(date_added as date) as date_added" 

WITH cte as (
SELECT *, row_number() OVER (PARTITION BY title, type ORDER BY show_id) as rn
FROM netflix_raw
)
SELECT show_id, type, title, cast(date_added as date) as date_added, release_year, rating, duration, description  
FROM cte
WHERE rn=1


-- Populate missing values in country & duration columns 

INSERT INTO netflix_country
SELECT show_id, m.country 
FROM netflix_raw nr INNER JOIN (
	SELECT director, country 
	FROM netflix_country nc INNER JOIN netflix_director nd ON nc.show_id = nd.show_id
	GROUP BY director, country) m ON nr.director=m.director  
WHERE nr.country IS NULL
------

WITH cte as (
SELECT *, row_number() OVER (PARTITION BY title, type ORDER BY show_id) as rn
FROM netflix_raw
)
SELECT show_id, type, title, cast(date_added as date) as date_added, release_year, rating, 
		case when duration IS NULL then rating else duration end as duration, description  
INTO netflix
FROM cte
-- WHERE rn=1 AND date_added IS NULL

SELECT * FROM netflix			-- netflix is the final table (analytics ready) ready for analysis




--------------------------------------
----------- DATA ANALYSIS ------------
--------------------------------------


/*  1) For each director count the # of movies and tv shows created by them in separate columns for directors who have ceated 
       both tv shows and movies */

SELECT d.director, count(case when n.type='Movie' then 1 end) as no_of_movies, count(case when type='Tv Show' then 1 end) as no_of_tv_shows
FROM netflix_director d JOIN netflix n ON d.show_id = n.show_id
GROUP BY d.director
HAVING count(distinct type)>1


-- 2) Which country has the highest # of comedy movies?

SELECT TOP 1 nc.country, count(g.genre) as no_of_comedy_movies 
FROM netflix n JOIN netflix_country nc ON n.show_id = nc.show_id JOIN netflix_genre g ON n.show_id = g.show_id AND n.type = 'Movie' AND g.genre = 'Comedies'
GROUP BY nc.country
ORDER BY no_of_comedy_movies desc


-- 3) For each year (as per date added to netflix) which director has maximum number of movies released?

SELECT director, year, cnt as max_no_of_movies 
FROM(
SELECT d.director, YEAR(n.date_added) as year, count(*) as cnt, RANK() OVER (PARTITION BY YEAR(n.date_added) ORDER BY count(*) desc) as rn
FROM netflix n JOIN netflix_director d ON n.show_id = d.show_id AND n.type='Movie'
GROUP BY YEAR(n.date_added), d.director) x
WHERE rn = 1


-- 4) What is the average duration of movies in each genre

SELECT genre, AVG(duration_in_min) as avg_duration
FROM(
SELECT n.title, g.genre, CAST(REPLACE(n.duration, ' min', '') AS INT) AS duration_in_min
FROM netflix n JOIN netflix_genre g ON n.show_id = g.show_id AND type='Movie') x
GROUP BY genre


/* 5) Find the list of directors who have created both horror and comedy movies. Display the director names along with the number of 
      comedy and horror movies directed by them */

SELECT d.director, count(case when g.genre='Comedies' then 1 end) as comedy_movies, count(case when g.genre='Horror Movies' then 1 end) as horror_movies
FROM netflix n JOIN netflix_genre g ON n.show_id = g.show_id JOIN netflix_director d ON n.show_id = d.show_id AND n.type = 'Movie' 
	 AND g.genre IN ('Comedies', 'Horror Movies')
GROUP BY d.director
HAVING count(distinct g.genre)=2















