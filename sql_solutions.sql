-- Q1: how many olympics games have been held?
SELECT COUNT(distinct games) AS total_olypmpic_games
FROM events

-- Q2: List down all Olympics games held so far
SELECT distinct year, season, city
FROM events
ORDER BY year


-- Q3: Mention the total no of nations who participated in each olympics game?
SELECT games, COUNT(DISTINCT(r.region)) as total_countries 
FROM events as e
JOIN regions as r
ON e.noc = r.noc
GROUP BY games 
ORDER BY games


-- Q4: Which year saw the highest and lowest no of countries participating in olympics?

WITH all_countries AS (
			SELECT games, r.region AS total_countries
			FROM events AS e
			INNER JOIN regions AS r
			ON e.noc = r.noc
			GROUP BY games, r.region
			ORDER BY games),
				
      no_of_countries AS (
		SELECT games, COUNT(DISTINCT total_countries) AS total_countries
		FROM all_countries
		GROUP BY games
		ORDER BY games)
			
			
SELECT DISTINCT 
	   CONCAT((FIRST_VALUE(games) OVER(ORDER BY total_countries DESC)),'-', 
	          (FIRST_VALUE(total_countries) OVER(ORDER BY total_countries DESC))) AS highest_countries,
			   
	   CONCAT((FIRST_VALUE(games) OVER(ORDER BY total_countries)),'-', 
		  (FIRST_VALUE(total_countries) OVER(ORDER BY total_countries))) AS lowest_countries
			   
FROM no_of_countries

-- Q5: Which nations has participated in all of the olympic games?

SELECT region as country, COUNT(region)
FROM (SELECT DISTINCT games, r.region
      FROM events AS e
	JOIN regions AS r
	ON e.noc = r.noc
	GROUP BY games, r.region
	ORDER BY games) AS t1

GROUP BY region
HAVING COUNT(region) = (SELECT COUNT(DISTINCT games) FROM events)

-- Q6: Identify the sport which was played in all summer olympics

SELECT DISTINCT sport, COUNT(sport)
FROM (SELECT DISTINCT games, sport   -- table of summers and each sport
	FROM events
	WHERE season ='Summer'
	ORDER by games) AS t1
GROUP BY sport
HAVING COUNT(sport) = (SELECT COUNT (DISTINCT games) -- total_no of Summers
		       FROM events
		       WHERE season = 'Summer') 

-- Q7: Which Sports were just played only once in the olympics

WITH t1 AS (SELECT DISTINCT games, sport
		FROM events	
		ORDER BY games),
			
t2 AS (SELECT sport, COUNT(sport) AS times_played
	FROM t1
	GROUP BY sport
	HAVING COUNT(sport) = 1
	ORDER BY sport)

SELECT t1.games, t2.*
FROM t2
JOIN t1 ON t2.sport = t1.sport
ORDER BY games

-- Q8: Fetch the total no of sports played in each olympic games.
SELECT DISTINCT games, COUNT (*)
FROM (SELECT games, sport
	FROM events
	GROUP BY games,sport
	ORDER BY games) as t1
	
GROUP BY games
ORDER BY count(*) DESC

-- Q9: Fetch oldest athletes to win a gold medal
WITH formatted AS (SELECT name, sex, noc, age::int
				  FROM events
				  WHERE age != 'NA' AND medal = 'Gold'),
				  
		ranks AS (SELECT *, RANK() OVER(ORDER BY age DESC) AS age_rank
				 FROM formatted)
				 
SELECT name,sex, noc AS country, age
FROM ranks
WHERE age_rank = 1 

-- Q10: Find the Ratio of male and female athletes participated in all olympic games.
WITH male AS (SELECT COUNT(*) AS male
FROM events 
WHERE sex = 'M'),

female AS(SELECT COUNT(*) AS female
FROM events
WHERE sex = 'F')

SELECT CONCAT('1: ',ROUND((male/female::decimal),2)) AS ratio
FROM male,female

-- Q11: Fetch top 5 athletes who have won the most gold medals
WITH t1 AS (SELECT name, sex, team, COUNT(*) AS total_gold_medals
	    FROM events 
	    WHERE medal = 'Gold'
       	    GROUP BY name, sex,team 
	    ORDER BY total_gold_medals DESC),
			
	t2 AS (SELECT *, DENSE_RANK() OVER(ORDER BY total_gold_medals DESC) AS rnk 
	       FROM t1)
	
SELECT name, team, total_gold_medals 
FROM t2 WHERE rnk <= 5

-- Q12: Fetch the top 5 athletes who have won the most medals (gold/silver/bronze)
WITH t1 AS (SELECT name, sex, team, COUNT(*) AS total_medals
		FROM events 
		WHERE medal IN ('Gold','Silver','Bronze')
		GROUP BY name, sex,team 
		ORDER BY total_medals DESC),
			
	t2 AS (SELECT *, DENSE_RANK() OVER(ORDER BY total_medals DESC) AS rnk 
		   FROM t1)
	
SELECT name, team, total_medals 
FROM t2 WHERE rnk <= 5

-- Q13: Fetch the top 5 most successful countries in olympics. Success is defined by no of medals won
WITH t1 AS (SELECT r.region, COUNT(*) AS total_medals
	 	FROM events AS e
		JOIN regions AS r ON e.noc = r.noc
		WHERE medal != 'NA'
		GROUP BY r.region
		ORDER BY total_medals DESC),
			
	t2 AS (SELECT *, DENSE_RANK() OVER(ORDER BY total_medals DESC) AS rnk 
	       FROM t1)
	
SELECT *
FROM t2
WHERE rnk <= 5

--Q14:  List down total gold, silver and bronze medals won by each country

    SELECT country
    	, coalesce(gold, 0) as gold
    	, coalesce(silver, 0) as silver
    	, coalesce(bronze, 0) as bronze
    FROM CROSSTAB('SELECT r.region as country
    			, medal
    			, count(1) as total_medals
    			FROM events e
    			JOIN regions r  ON r.noc = e.noc
    			where medal <> ''NA''
    			GROUP BY r.region,medal
    			order BY r.region,medal',
            'values (''Bronze''), (''Gold''), (''Silver'')')
    AS FINAL_RESULT(country varchar, bronze bigint, gold bigint, silver bigint)
    order by gold desc, silver desc, bronze desc

-- Q15:List down total gold, silver and bronze medals won by each country corresponding to each olympic games.
CREATE EXTENSION TABLEFUNC;

    SELECT substring(games,1,position(' - ' in games) - 1) as games
        , substring(games,position(' - ' in games) + 3) as country
        , coalesce(gold, 0) as gold
        , coalesce(silver, 0) as silver
        , coalesce(bronze, 0) as bronze
    FROM CROSSTAB('SELECT concat(games, '' - '', r.region) as games
                , medal
                , count(1) as total_medals
                FROM events AS e
                JOIN regions AS r ON r.noc = e.noc
                where medal <> ''NA''
                GROUP BY games,r.region,medal
                order BY games,medal',
            'values (''Bronze''), (''Gold''), (''Silver'')')
    AS FINAL_RESULT(games text, bronze bigint, gold bigint, silver bigint);

-- Q18: Which countries have never won gold medal but have won silver/bronze medals?
    select * from (
    	SELECT country, coalesce(gold,0) as gold, coalesce(silver,0) as silver, coalesce(bronze,0) as bronze
    		FROM CROSSTAB('SELECT r.region as country
    					, medal, count(1) as total_medals
    					FROM events e
    					JOIN regions r ON r.noc= e.noc
    					where medal <> ''NA''
    					GROUP BY r.region, medal order BY r.region,medal',
                    'values (''Bronze''), (''Gold''), (''Silver'')')
    		AS FINAL_RESULT(country varchar,
    		bronze bigint, gold bigint, silver bigint)) x
    where gold = 0 and (silver > 0 or bronze > 0)
    order by gold desc nulls last, silver desc nulls last, bronze desc nulls last;

-- Q19: In which Sport/event, India has won highest medals

WITH t1 AS (SELECT games, r.region, sport, medal
		FROM events e
		JOIN regions r ON e.noc = r.noc
		ORDER BY games,region, sport, medal)

SELECT sport, COUNT(*) AS total_medal
FROM t1 
WHERE region = 'India' AND medal != 'NA'
GROUP BY sport
ORDER BY total_medals DESC
LIMIT 1;

-- Q20: Break down all olympic games where India won medal for Hockey and how many medals in each olympic games
WITH t1 AS (SELECT games, r.region, sport, medal
FROM events e
JOIN regions r ON e.noc = r.noc
ORDER BY games,region, sport, medal)

SELECT region, games, sport, COUNT(*) AS total_medals
FROM t1
WHERE region = 'India' AND medal != 'NA' AND sport = 'Hockey'
GROUP BY games, sport, region 
ORDER BY total_medals DESC
