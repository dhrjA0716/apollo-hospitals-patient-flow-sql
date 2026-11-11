-- Apollo Hospitals Patient Flow SQL Lab: all 15 analysis queries
-- Run apollo_patient_flow.sql first, then: USE apollo_patient_flow;

USE apollo_patient_flow;

-- Q1 Get to know the database
DESCRIBE hospitals;
DESCRIBE departments;
DESCRIBE patients;
DESCRIBE doctors;
DESCRIBE admissions;
DESCRIBE bed_occupancy;

-- Q1 Row counts
SELECT 'hospitals' AS table_name, COUNT(*) AS total_rows FROM hospitals
UNION ALL SELECT 'departments', COUNT(*) FROM departments
UNION ALL SELECT 'patients', COUNT(*) FROM patients
UNION ALL SELECT 'doctors', COUNT(*) FROM doctors
UNION ALL SELECT 'admissions', COUNT(*) FROM admissions
UNION ALL SELECT 'bed_occupancy', COUNT(*) FROM bed_occupancy;

-- Q2   How many admissions has each hospital handled? Which one is busiest?
SELECT
h.hospital_name,
COUNT(a.admission_id) AS total_admissions
FROM admissions a
JOIN hospitals h ON a.hospital_id = h.hospital_id
GROUP BY h.hospital_id, h.hospital_name
ORDER BY total_admissions DESC;

-- Q3 Total admissions per department, and the top 5 departments by patient volume.
select
d.department_name, d.department_id, h.hospital_name,
count(a.admission_id) as total_admissions
from admissions a
join departments d
on d.department_id = a.department_id
join hospitals h
on h.hospital_id = a.hospital_id
group by d.department_name, d.department_id, h.hospital_name
order by total_admissions desc limit 5;

-- Q4  Average, minimum and maximum wait time per department. Which department keeps patients waiting the longest, on average?
select
h.hospital_name,
d.department_name,
ROUND(AVG(a.wait_time_minutes), 2) AS average_waiting_time,
MIN(a.wait_time_minutes) AS minimum_waiting_time,
MAX(a.wait_time_minutes) AS maximum_waiting_time
FROM admissions a
JOIN departments d ON d.department_id = a.department_id
JOIN hospitals h ON h.hospital_id = d.hospital_id
GROUP BY d.department_id, d.department_name, h.hospital_name
ORDER BY average_waiting_time DESC;

-- Q5  Use a CASE statement to bucket patients into Low, Moderate, High and Critical wait categories. Which department has the most Critical cases? (bucketing)
select
d.department_id,
d.department_name,
a.admission_id,
a.wait_time_minutes,
case
when wait_time_minutes >= 120 then 'Critical'
when wait_time_minutes >= 60 then 'High'
when wait_time_minutes >= 30 then 'Moderate'
else 'Low'
end as wait_category
from admissions a
join departments d
on d.department_id = a.department_id
order by wait_time_minutes desc;

-- Q5 Which department has the most Critical cases
SELECT
h.hospital_name,
d.department_name,
COUNT(*) AS critical_cases
FROM admissions a
JOIN departments d ON d.department_id = a.department_id
JOIN hospitals h ON h.hospital_id = d.hospital_id
WHERE a.wait_time_minutes >= 120
GROUP BY d.department_id, d.department_name, h.hospital_name
ORDER BY critical_cases DESC;

-- Q6 Work out average length of stay per department from the admission and discharge dates. Which department keeps patients longest?
select
h.hospital_name,
d.department_name,
round(avg(datediff(a.discharge_date, a.admission_date)),2) as avg_length_of_stay
from admissions a
join departments d
on d.department_id = a.department_id
join hospitals h
on h.hospital_id = d.hospital_id
group by d.department_name, d.department_id, h.hospital_name
order by avg_length_of_stay desc;

-- Q7 Overall readmission rate
COUNT(*) AS total_admissions,
SUM(readmission_flag) AS total_readmissions,
ROUND(100 * SUM(readmission_flag) / COUNT(*), 2) AS overall_readmission_rate_pct
FROM admissions;

-- Q7 Overall hospital readmission rate, and how it compares department to department. (by department)
SELECT
h.hospital_name,
d.department_name,
COUNT(*) AS total_admissions,
SUM(a.readmission_flag) AS total_readmissions,
ROUND(100 * SUM(a.readmission_flag) / COUNT(*), 2) AS readmission_rate_pct
FROM admissions a
JOIN departments d ON d.department_id = a.department_id
JOIN hospitals h ON h.hospital_id = a.hospital_id
GROUP BY d.department_id, d.department_name, h.hospital_name
ORDER BY readmission_rate_pct DESC;

-- Q8 Find patients admitted more than once, and rank them by total admissions.
SELECT
p.patient_id,
p.patient_name,
COUNT(a.admission_id) AS total_admissions,
DENSE_RANK() OVER (ORDER BY COUNT(a.admission_id) DESC) AS admission_rank
FROM admissions a
JOIN patients p ON p.patient_id = a.patient_id
GROUP BY p.patient_id, p.patient_name
HAVING COUNT(a.admission_id) > 1
ORDER BY admission_rank, p.patient_id;

-- Q9 Bed utilisation % per department from available vs. occupied beds. Flag anything running above 90% — that's a Critical utilisation department.
select
h.hospital_name,
d.department_name,
round(100 * SUM(b.occupied_beds) / SUM(b.available_beds), 2) as utilisation_pct,
case
when 100 * SUM(b.occupied_beds) / SUM(b.available_beds) > 90 then 'Critical'
else 'Normal'
end as utilisation_status
from bed_occupancy b
join departments d
on d.department_id = b.department_id
join hospitals h
on h.hospital_id = b.hospital_id
group by d.department_name,d.department_id, h.hospital_name
order by utilisation_pct desc;

-- Q10  Build a department-level report — hospital name, department name, total beds, total admissions, average wait time, average bed utilisation — using multi-table JOINs.
SELECT
h.hospital_name,
d.department_name,
d.total_beds,
COUNT(DISTINCT a.admission_id) AS total_admissions,
ROUND(AVG(a.wait_time_minutes), 2) AS average_waiting_time,
ROUND(100 * SUM(b.occupied_beds) / SUM(b.available_beds), 2) AS average_bed_utilisation
FROM admissions a
JOIN departments d ON d.department_id = a.department_id
JOIN hospitals h ON h.hospital_id = a.hospital_id
JOIN bed_occupancy b ON b.department_id = a.department_id
GROUP BY d.department_id, h.hospital_name, d.department_name, d.total_beds
ORDER BY h.hospital_name, d.department_name;

-- Q11  Which departments have an average wait time higher than the hospital-wide average? Use a subquery.
SELECT
h.hospital_name,
d.department_name,
ROUND(AVG(a.wait_time_minutes), 2) AS average_time,
(SELECT ROUND(AVG(wait_time_minutes), 2) FROM admissions) AS hospital_avg
FROM admissions a
JOIN departments d ON d.department_id = a.department_id
JOIN hospitals h ON h.hospital_id = a.hospital_id
GROUP BY d.department_id, d.department_name, h.hospital_name
HAVING AVG(a.wait_time_minutes) > (
SELECT AVG(wait_time_minutes) FROM admissions
)
ORDER BY average_time DESC;

-- Q12 Build a CTE that pulls together admission volume, average wait time, average length of stay, and readmission rate per department — use it to flag which departments need attention.
with department_stats as (
select
h.hospital_name,
d.department_name,
count(a.admission_id) as admission_volume,
round(avg(a.wait_time_minutes),2) as average_wait_time,
round(avg(datediff(a.discharge_date, a.admission_date)),2) as average_length_of_stay,
ROUND(100 * SUM(a.readmission_flag) / COUNT(a.admission_id), 2) as readmission_rate_pct
from admissions a
join departments d on d.department_id = a.department_id
join hospitals h on h.hospital_id = a.hospital_id
group by h.hospital_id, h.hospital_name ,d.department_id, d.department_name
)
select
*,
case
when (average_wait_time > (select AVG(wait_time_minutes) FROM admissions))
+ ( readmission_rate_pct >(select 100 * SUM(readmission_flag) / COUNT(*) FROM admissions))
+ ( average_length_of_stay >(select avg(datediff(discharge_date, admission_date)) from admissions))
>=2
then 'Needs Attention'
else 'Ok'
end as status
from department_stats
order by status, average_wait_time desc;

-- Q13 Use ROW_NUMBER(), RANK() or DENSE_RANK() to rank departments on wait time, readmission rate, and bed utilisation.
with admission_stats as(
select department_id,
round(avg(wait_time_minutes),2) as avg_wait,
ROUND(100 * SUM(readmission_flag) / COUNT(*), 2) AS readmission_rate
from admissions
group by department_id
),
bed_stats as(
select department_id ,
round(100 * SUM(occupied_beds) / SUM(available_beds), 2) as utilisation_pct
from bed_occupancy
group by department_id
)
select
h.hospital_name,
d.department_name,
s.avg_wait,
dense_rank() over(order by  s.avg_wait desc ) as wait_rank,
s.readmission_rate,
dense_rank() over(order by s.readmission_rate desc) as readmission_rank,
b.utilisation_pct,
dense_rank() over(order by b.utilisation_pct desc) as utilisation_rank
from departments d
join hospitals h on h.hospital_id = d.hospital_id
join admission_stats s on s.department_id = d.department_id
join bed_stats b on b.department_id = d.department_id
order by  wait_rank, readmission_rank, utilisation_rank;

-- Q14 Combine wait time, length of stay, readmission rate and bed utilisation into one query that surfaces the top 5 departments with the worst overall patient-flow problems.
with admission_stats as (
select department_id,
round(avg(wait_time_minutes),2) as avg_wait,
round(avg(datediff(discharge_date, admission_date)),2) as avg_length_of_stay,
round(100 * SUM(readmission_flag) / COUNT(*), 2) AS readmission_rate
from admissions
group by department_id
),
bed_stats as(
select
department_id,
round(100 * SUM(occupied_beds) / SUM(available_beds), 2) as utilisation_pct
from bed_occupancy
group by department_id
),
ranked as (
select
h.hospital_name,
d.department_name,
s.avg_wait,
dense_rank() over(order by s.avg_wait desc) as wait_rank,
s.avg_length_of_stay,
dense_rank() over(order by s.avg_length_of_stay desc ) as stay_rank,
s.readmission_rate,
dense_rank() over(order by s.readmission_rate desc ) as readmission_rank,
b.utilisation_pct,
dense_rank() over(order by b.utilisation_pct desc ) as utilisation_rank
from departments d
join hospitals h on h.hospital_id = d.hospital_id
join admission_stats s on s.department_id = d.department_id
join bed_stats b on b.department_id = d.department_id
)
select
*,
(wait_rank + stay_rank + readmission_rank + utilisation_rank) as total_score
from ranked
order by total_score
limit 5;

-- Q15  Pick one of your more complex queries and run EXPLAIN on it. What's slow about it?  Fix it — indexing, filtering earlier, cutting unnecessary joins — and show the execution plan before and after. (optimised version; EXPLAIN the Q10 query for the BEFORE plan)
with adm as(
select
department_id,
count(*) AS total_admissions,
round(AVG(wait_time_minutes), 2) AS average_wait_time
FROM admissions
GROUP BY department_id
),
bed as (
select
department_id,
ROUND(100 * SUM(occupied_beds) / SUM(available_beds), 2) AS average_bed_utilisation
from bed_occupancy
group by department_id
)
select
h.hospital_name,
d.department_name,
d.total_beds,
a.total_admissions,
a.average_wait_time,
b.average_bed_utilisation
from departments d
join hospitals h on h.hospital_id = d.hospital_id
join adm a on a.department_id = d.department_id
join bed b on b.department_id = d.department_id;
