--- Exploring the dataset
Select *
From netflix_raw
order by title; --- Go investigate the junk Char in the titles? (b'coz improper dtype)

--- Checking if show_id is a PK ? (Yes, It is PK)
Select Count(show_id) cnt_show_id
From netflix_raw;
Select Count(DISTINCT show_id) cnt_Uni_show_id
From netflix_raw;


---------------------------------------------------------------------------------------
------------------ Creating a table with proper dtypes (Handling the foreign Char)-----

CREATE TABLE Personal_Projects.dbo.netflix_raw(
	 show_id VARCHAR(10) Null , type VARCHAR(10) Null, 
	title NVARCHAR(200), director NVARCHAR(300), 
	cast VARCHAR(1000), country VARCHAR(300) Null, 
	date_added VARCHAR(25) Null, release_year INT Null, 
	rating VARCHAR(15) Null, duration VARCHAR(10) Null , 
	listed_in VARCHAR(200) Null, description VARCHAR(400) Null);


---------------------------------------------------------------------------------------
---------------------Removing Duplicates in the Table----------------------------------
SELECT show_id, Count(*)
FROM netflix_raw
GROUP BY show_id
HAVING Count(*) > 1;--- No duplicate


SELECT title, Count(*)
FROM netflix_raw
GROUP BY title
HAVING Count(*) > 1; --- there some duplicates. investigate?

SELECT *
FROM netflix_raw
WHERE CONCAT(title,type,release_year) IN (SELECT CONCAT(title,type,release_year) 
				FROM netflix_raw
				GROUP BY CONCAT(title,type,release_year)
				HAVING Count(*) > 1)
ORDER BY title;


with CTE_Net AS (
	SELECT *, ROW_NUMBER() OVER (PARTITION BY title,type,release_year ORDER BY show_id) as row_num
	FROM netflix_raw
)

SELECT *
FROM CTE_Net
WHERE row_num =1;

---------------------------------------------------------------------------------------
---------------------------- Creating tables for easier analysis-----------------------

---Director table
SELECT show_id, trim(Value) director_name
INTO netflix_director
FROM netflix_raw
CROSS APPLY string_split(director,',')

---genre table
SELECT show_id, trim(Value) genre
INTO netflix_genre
FROM netflix_raw
CROSS APPLY string_split(listed_in,',')

---Country table
SELECT show_id, trim(Value) country
INTO netflix_country
FROM netflix_raw
CROSS APPLY string_split(country,',')

---Cast table
SELECT show_id, trim(Value) cast
INTO netflix_cast
FROM netflix_raw
CROSS APPLY string_split(cast,',');



---------------------------------------------------------------------------------------
-----------------------------Handeling missing values----------------------------------
---Country Table (we fill null of the countries by where the director released the most movies)

WITH Countries_null AS(
SELECT x.director ,x.Country,x.cnt,x.max_cnt
FROM (SELECT director ,Country, COUNT(*) cnt, MAX(COUNT(*)) OVER (PARTITION BY director ,Country) as max_cnt
	  FROM netflix_raw
	  WHERE Country IS NOT Null
	  GROUP BY director ,Country
	  HAVING director IS NOT Null
	  ) AS x
WHERE  x.cnt = x.max_cnt)

INSERT INTO netflix_country 
SELECT c.show_id, trim(Value) country
FROM (SELECT nr.show_id, m.country
	  FROM netflix_raw nr inner join Countries_null m
	  ON nr.director = m.director
	  WHERE nr.country is null) AS C
CROSS APPLY string_split(c.country,',')
;

--- Null values for durations (fixed typo mistakes) + convert date into date dtype

SELECT * FROM netflix_raw
WHERE duration IS NULL;

with CTE_Net AS (
	SELECT *, ROW_NUMBER() OVER (PARTITION BY title,type,release_year ORDER BY show_id) as row_num
	FROM netflix_raw
)

SELECT show_id, type, title, CAST(date_added AS date) date_added,rating 
	 ,CASE WHEN duration IS NULL THEN rating ELSE duration END AS duration
	, description
INTO netflix_final
FROM CTE_Net
WHERE row_num =1;




---------------------------------------------------------------------------------------
---------------------------- Deriving insights from the data --------------------------

---	Content Analysis: does popularity depend on the nature of the content? 

---• Identify popular genres, directors among subscribers.
---top 5 popular genre (by Movies & TV shows)
SELECT TOP 5 g.genre top_5_TVShow, COUNT(*) no_of_TVshows
FROM netflix_genre g INNER JOIN netflix_final f
	ON g.show_id = f.show_id
WHERE f.type = 'TV Show'
GROUP BY genre
ORDER BY COUNT(*) Desc;---TV shows

SELECT TOP 5 g.genre top_5_movies, COUNT(*) no_of_movies
FROM netflix_genre g INNER JOIN netflix_final f
	ON g.show_id = f.show_id
WHERE f.type = 'Movie'
GROUP BY genre
ORDER BY COUNT(*) Desc;---Movies



---• Analyze the distribution of content by release year or country.

---• Explore trends in content duration (e.g., are movies getting longer or shorter?).