/**************************************************
1. setting
**********************************************/

--1.1 measurement table에서 weight, height 추출
--    weight concept id : 3025315 
--------------------------(TOTAL record : 2,209,356, distinct id : 596,170)

--SELECT person_id FROM [NHIS_NSC].[dbo].[MEASUREMENT] WHERE measurement_concept_id = 3025315;
--SELECT DISTINCT(person_id) FROM [NHIS_NSC].[dbo].[MEASUREMENT] WHERE measurement_concept_id = 3025315;

--    height concept id : 3036277
--------------------------(TOTAL record : 2,209,462, distinct id : 596,177)

--SELECT person_id FROM [NHIS_NSC].[dbo].[MEASUREMENT] WHERE measurement_concept_id = 3036277 ;
--SELECT DISTINCT(person_id) FROM [NHIS_NSC].[dbo].[MEASUREMENT] WHERE measurement_concept_id = 3036277 ;

--    weight & height at the same time
--------------------------(TOTAL record : 2,209,286, distinct id : 596,163)

--SELECT a.person_id, a.measurement_date, a.value_as_number AS weight, b.value_as_number AS height
	--FROM (SELECT * FROM [NHIS_NSC].[dbo].[MEASUREMENT] WHERE measurement_concept_id = 3025315) a, 
	--	 (SELECT * FROM [NHIS_NSC].[dbo].[MEASUREMENT] WHERE measurement_concept_id = 3036277) b
--	WHERE a.person_id = b.person_id and a.measurement_date = b.measurement_date;

--SELECT DISTINCT(a.person_id)
	--FROM (SELECT * FROM [NHIS_NSC].[dbo].[MEASUREMENT] WHERE measurement_concept_id = 3025315) a, 
	--	 (SELECT * FROM [NHIS_NSC].[dbo].[MEASUREMENT] WHERE measurement_concept_id = 3036277) b
	--WHERE a.person_id = b.person_id and a.measurement_date = b.measurement_date;

--    weight & height from 2002-2003 
--------------------------(TOTAL record : 232,215, distinct id : 189,340)

--SELECT a.person_id, a.measurement_date, a.value_as_number AS weight, b.value_as_number AS height
	--FROM (SELECT * FROM [NHIS_NSC].[dbo].[MEASUREMENT] WHERE measurement_concept_id = 3025315) a, 
	--	 (SELECT * FROM [NHIS_NSC].[dbo].[MEASUREMENT] WHERE measurement_concept_id = 3036277) b
	--WHERE a.person_id = b.person_id and a.measurement_date = b.measurement_date 
			and a.measurement_date BETWEEN '2002-01-01' AND '2003-12-31';


/*************************************
2.1 CREATE TABLE
***************************************/

----기본 테이블 setting
--DROP TABLE [NHIS_NSC].[dbo].[YJPARK_project]
CREATE TABLE [NHIS_NSC].[dbo].[YJPARK_project](
			[person_id] INT NOT NULL,               ---measuremet table
			[gender_concept_id] INT NULL,           ---person table
			[age] INT NULL,                         ---person table & measurement table
			[measurement_date] DATE NOT NULL,       ---measurement table
			[weight] FLOAT NOT NULL,                ---measurement table
			[height] FLOAT NOT NULL,                ---measurement table
			[BMI] FLOAT NOT NULL,                   ---measurement table (weight (kg)/height ^2 (m) )
			[outcome] INT NOT NULL,                 ---death table
			[cohort_end_date] DATE NULL,            ---death table (if outcome 1 -> death date = cohort end date, elss 2013-12-31 = cohort end date)
			[death_date] DATE NULL,                 ---death table 
			[duration] FLOAT NOT NULL                 ---death table & measurement table (cohort end date - measurement table)
			);

/*******************************************
2.2 measurement table / person table / death table insert
**************************************/

INSERT INTO [NHIS_NSC].[dbo].[YJPARK_project]
([person_id], [gender_concept_id], [age], [measurement_date], 
[weight], [height],[BMI], [outcome], [cohort_end_date], [death_date], [duration])
SELECT person_id AS [person_id],
       gender_concept_id AS [gender_concept_id],
	   YEAR(measurement_date) - year_of_birth AS [age],
	   measurement_date AS [measurement_date],
	   weight AS [weight],
	   height AS [height],
	   ROUND(weight / square(height/100), 2) AS [BMI],
	   CASE WHEN death_date is NULL THEN 0
			WHEN death_date is NOT NULL THEN 1 END AS [outcome],
	   cohort_end_date AS [cohort_end_date],
	   death_date AS [death_date],
	   ROUND(CAST(DATEDIFF(DAY, measurement_date, cohort_end_date) AS FLOAT)/365, 3) AS [duration]
FROM(SELECT v.person_id, gender_concept_id, year_of_birth, measurement_date, weight, height, death_date, 
			CASE WHEN death_date is NULL THEN '2013-12-31' 
				 WHEN death_date is NOT NULL THEN death_date END AS cohort_end_date
	 FROM (SELECT ROW_NUMBER() OVER(PARTITION BY a.person_id ORDER BY a.measurement_date) AS row_num,
	       a.person_id, a.measurement_date, a.value_as_number AS weight, b.value_as_number AS height
	       FROM (SELECT * FROM [NHIS_NSC].[dbo].[MEASUREMENT] WHERE measurement_concept_id = 3025315) a, 
			    (SELECT * FROM [NHIS_NSC].[dbo].[MEASUREMENT] WHERE measurement_concept_id = 3036277) b
		   WHERE a.person_id = b.person_id and a.measurement_date = b.measurement_date 
			   	and a.measurement_date BETWEEN '2002-01-01' AND '2003-12-31') v
	 LEFT JOIN [NHIS_NSC].[dbo].[PERSON] ON v.person_id = [NHIS_NSC].[dbo].[PERSON].person_id
	 LEFT JOIN [NHIS_NSC].[dbo].[DEATH] ON v.person_id = [NHIS_NSC].[dbo].[DEATH].person_id
	 WHERE row_num = 1) s ;


/***************************************************
2.2 inclusion criteria
************************************************/

--duration < 3 year인 경우 제외 (187,993)

SELECT * into [NHIS_NSC].[dbo].[YJPARK_project_2]
FROM [NHIS_NSC].[dbo].[YJPARK_project]
WHERE duration >= 3