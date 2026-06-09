--1. Show the number of employees and average years of experience for each job role.

SELECT JobRole,
       COUNT(*) AS employee_count,
       ROUND(AVG(TotalWorkingYears), 1) AS avg_years
FROM hr_attrition
GROUP BY JobRole
ORDER BY employee_count DESC;

--2. Divide employees into 3 salary categories: 'Low' (<3000), 'Medium' (3000-7000), 'High' (>7000). Show the number of employees in each category.

SELECT 
  CASE 
    WHEN MonthlyIncome < 3000 THEN 'Low'
    WHEN MonthlyIncome BETWEEN 3000 AND 7000 THEN 'Medium'
    ELSE 'High'
  END AS income_category,
  COUNT(*) AS count
FROM hr_attrition
GROUP BY income_category;

--3. Display work-life balance as text: 1=Poor, 2=Average, 3=Good, 4=Excellent. Show the number of employees in each category.

SELECT 
  CASE WorkLifeBalance
    WHEN 1 THEN 'Poor'
    WHEN 2 THEN 'Average'
    WHEN 3 THEN 'Good'
    WHEN 4 THEN 'Excellent'
  END AS wlb_label,
  COUNT(*) AS count
FROM hr_attrition
GROUP BY WorkLifeBalance
ORDER BY WorkLifeBalance;

--4. Show the employee ID, department, and salary of employees earning above the average monthly salary.

SELECT EmployeeNumber, Department, MonthlyIncome
FROM hr_attrition
WHERE MonthlyIncome > (
  SELECT AVG(MonthlyIncome) FROM hr_attrition
)
ORDER BY MonthlyIncome DESC;

--5. Identify employees who have remained in the same role for a long time: YearsInCurrentRole >= 5 are 'Stable', otherwise 'Dynamic'. Compare with Attrition.

SELECT 
  CASE WHEN YearsInCurrentRole >= 5 THEN 'Stable' ELSE 'Dynamic' END AS stability,
  Attrition,
  COUNT(*) AS count
FROM hr_attrition
GROUP BY stability, Attrition
ORDER BY stability, Attrition;

--6. Find the highest-paid employee in each department.

SELECT a.Department, a.EmployeeNumber, a.MonthlyIncome
FROM hr_attrition a
WHERE a.MonthlyIncome = (
  SELECT MAX(b.MonthlyIncome)
  FROM hr_attrition b
  WHERE b.Department = a.Department
)
ORDER BY a.Department;

--7. What is the attrition rate among employees who work overtime?

SELECT OverTime,
       COUNT(*) AS total,
       SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) AS left_count,
       ROUND(100.0 * SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS attrition_rate
FROM hr_attrition
GROUP BY OverTime;

--8. Calculate the difference between each employee's salary and the average salary of their department.

SELECT EmployeeNumber, Department, MonthlyIncome,
       ROUND(AVG(MonthlyIncome) OVER (PARTITION BY Department), 2) AS dept_avg,
       ROUND(MonthlyIncome - AVG(MonthlyIncome) OVER (PARTITION BY Department), 2) AS diff_from_avg
FROM hr_attrition
ORDER BY Department, diff_from_avg DESC;

--9. Find the top 2 departments with the highest attrition rates.

WITH dept_stats AS (
  SELECT Department,
         COUNT(*) AS total,
         SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) AS left_count,
         ROUND(100.0 * SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS attrition_rate
  FROM hr_attrition
  GROUP BY Department
)
SELECT * FROM dept_stats
ORDER BY attrition_rate DESC
LIMIT 2;

--10. Calculate the proportion of employees who both work overtime and have Attrition = 'Yes' by department.

WITH base AS (
  SELECT Department,
         COUNT(*) AS total,
         SUM(CASE WHEN OverTime = 'Yes' AND Attrition = 'Yes' THEN 1 ELSE 0 END) AS high_risk
  FROM hr_attrition
  GROUP BY Department
)
SELECT Department, total, high_risk,
       ROUND(100.0 * high_risk / total, 2) AS risk_rate
FROM base
ORDER BY risk_rate DESC;

--11. Divide employees into 4 salary quartiles (NTILE). Show the average JobSatisfaction for each quartile.

WITH quartiles AS (
  SELECT EmployeeNumber, MonthlyIncome, JobSatisfaction,
         NTILE(4) OVER (ORDER BY MonthlyIncome) AS income_quartile
  FROM hr_attrition
)
SELECT income_quartile,
       ROUND(AVG(JobSatisfaction), 2) AS avg_satisfaction,
       COUNT(*) AS count
FROM quartiles
GROUP BY income_quartile
ORDER BY income_quartile;

--12. Calculate the difference between each employee's current salary and the maximum salary in their department.

SELECT EmployeeNumber, Department, MonthlyIncome,
       MAX(MonthlyIncome) OVER (PARTITION BY Department) AS dept_max,
       MAX(MonthlyIncome) OVER (PARTITION BY Department) - MonthlyIncome AS gap_to_max
FROM hr_attrition
ORDER BY Department, gap_to_max;

--13. Rank employees by salary hike percentage. Show the top 10 employees with the highest salary increases.

WITH ranked_hike AS (
  SELECT EmployeeNumber, Department, JobRole,
         MonthlyIncome, PercentSalaryHike,
         RANK() OVER (ORDER BY PercentSalaryHike DESC) AS global_rank
  FROM hr_attrition
)
SELECT * FROM ranked_hike
WHERE global_rank <= 10
ORDER BY global_rank;

--14. Compare each employee's salary with the previous employee's salary within the same JobRole using LAG. Calculate the difference.

SELECT EmployeeNumber, JobRole, MonthlyIncome,
       LAG(MonthlyIncome) OVER (PARTITION BY JobRole ORDER BY MonthlyIncome) AS prev_income,
       MonthlyIncome - LAG(MonthlyIncome) OVER (PARTITION BY JobRole ORDER BY MonthlyIncome) AS diff
FROM hr_attrition
ORDER BY JobRole, MonthlyIncome;

--14. Group employees by work experience: 0-5 years = 'Junior', 6-15 years = 'Mid', 16+ years = 'Senior'. Show the average salary for each group.

SELECT 
  CASE 
    WHEN TotalWorkingYears BETWEEN 0 AND 5 THEN 'Junior'
    WHEN TotalWorkingYears BETWEEN 6 AND 15 THEN 'Mid'
    ELSE 'Senior'
  END AS seniority,
  ROUND(AVG(MonthlyIncome), 2) AS avg_income,
  COUNT(*) AS count
FROM hr_attrition
GROUP BY seniority;

--15. Find departments whose attrition rate is higher than the company average.

WITH company AS (
  SELECT ROUND(100.0 * SUM(CASE WHEN Attrition='Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS co_rate
  FROM hr_attrition
),
dept AS (
  SELECT Department,
         ROUND(100.0 * SUM(CASE WHEN Attrition='Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS dept_rate
  FROM hr_attrition
  GROUP BY Department
)
SELECT d.Department, d.dept_rate, c.co_rate
FROM dept d, company c
WHERE d.dept_rate > c.co_rate
ORDER BY d.dept_rate DESC;

--16. Create risk categories for employees: 'High Risk' (OverTime=Yes AND JobSatisfaction<=2), 'Medium Risk' (OverTime=Yes OR JobSatisfaction<=2), and 'Low Risk'. Show the count of employees in each category.

SELECT
  CASE
    WHEN OverTime = 'Yes' AND JobSatisfaction <= 2 THEN 'High Risk'
    WHEN OverTime = 'Yes' OR JobSatisfaction <= 2 THEN 'Medium Risk'
    ELSE 'Low Risk'
  END AS risk_level,
  COUNT(*) AS count,
  SUM(CASE WHEN Attrition='Yes' THEN 1 ELSE 0 END) AS attrited
FROM hr_attrition
GROUP BY risk_level
ORDER BY count DESC;

--17. Find the employee who has worked the longest with the current manager in each job role (maximum YearsWithCurrManager).

SELECT a.EmployeeNumber, a.JobRole, a.YearsWithCurrManager, a.MonthlyIncome
FROM hr_attrition a
WHERE a.YearsWithCurrManager = (
  SELECT MAX(b.YearsWithCurrManager)
  FROM hr_attrition b
  WHERE b.JobRole = a.JobRole
)
ORDER BY a.JobRole;

--18. Using two consecutive CTEs: first calculate the average salary of each department, then list employees earning more than 20% above that average.

WITH dept_avg AS (
  SELECT Department, AVG(MonthlyIncome) AS avg_inc
  FROM hr_attrition
  GROUP BY Department
),
high_earners AS (
  SELECT a.EmployeeNumber, a.Department, a.MonthlyIncome, d.avg_inc,
         ROUND(100.0 * (a.MonthlyIncome - d.avg_inc) / d.avg_inc, 2) AS pct_above
  FROM hr_attrition a
  JOIN dept_avg d ON a.Department = d.Department
  WHERE a.MonthlyIncome > d.avg_inc * 1.20
)
SELECT * FROM high_earners
ORDER BY pct_above DESC;

--19. Compare the average salary of employees who have worked at least 3 companies (NumCompaniesWorked >= 3) and left the company with the overall average salary.

SELECT
  ROUND(AVG(CASE WHEN NumCompaniesWorked >= 3 AND Attrition = 'Yes'
                 THEN MonthlyIncome END), 2) AS mobile_attrited_avg,
  ROUND((SELECT AVG(MonthlyIncome) FROM hr_attrition), 2) AS overall_avg,
  ROUND(AVG(CASE WHEN NumCompaniesWorked >= 3 AND Attrition = 'Yes'
                 THEN MonthlyIncome END)
        - (SELECT AVG(MonthlyIncome) FROM hr_attrition), 2) AS difference
FROM hr_attrition;

--20. Categorize employees by commuting distance: 'Long Distance' (>20), 'Medium Distance' (10-20), and 'Short Distance' (<10). Analyze the relationship with OverTime.

SELECT
  CASE
    WHEN DistanceFromHome > 20 THEN 'Long Distance'
    WHEN DistanceFromHome >= 10 THEN 'Medium Distance'
    ELSE 'Short Distance'
  END AS commute_cat,
  OverTime,
  COUNT(*) AS count,
  ROUND(100.0 * SUM(CASE WHEN Attrition='Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS attrition_rate
FROM hr_attrition
GROUP BY commute_cat, OverTime
ORDER BY commute_cat, OverTime;

--21. Find job roles where the proportion of employees with StockOptionLevel = 0 exceeds 50%.

SELECT JobRole,
       COUNT(*) AS total,
       SUM(CASE WHEN StockOptionLevel = 0 THEN 1 ELSE 0 END) AS no_stock,
       ROUND(100.0 * SUM(CASE WHEN StockOptionLevel = 0 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_no_stock
FROM hr_attrition
GROUP BY JobRole
HAVING pct_no_stock > 50
ORDER BY pct_no_stock DESC;

--22. Show each department's percentage share of the company's total monthly payroll.

SELECT Department,
       SUM(MonthlyIncome) AS dept_payroll,
       ROUND(100.0 * SUM(MonthlyIncome) /
             (SELECT SUM(MonthlyIncome) FROM hr_attrition), 2) AS pct_of_total
FROM hr_attrition
GROUP BY Department
ORDER BY pct_of_total DESC;

--23. Compare attrition rates of employees hired within the last 3 years (YearsAtCompany <= 3) with longer-tenured employees (YearsAtCompany > 3) for each department.

WITH split AS (
  SELECT Department,
         CASE WHEN YearsAtCompany <= 3 THEN 'New' ELSE 'Experienced' END AS tenure_group,
         Attrition
  FROM hr_attrition
)
SELECT Department, tenure_group,
       COUNT(*) AS total,
       SUM(CASE WHEN Attrition='Yes' THEN 1 ELSE 0 END) AS attrited,
       ROUND(100.0 * SUM(CASE WHEN Attrition='Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS rate
FROM split
GROUP BY Department, tenure_group
ORDER BY Department, tenure_group;

--24. Show employee count, average salary, attrition rate, overtime rate, and average job satisfaction by Department and Gender. Sort by highest attrition rate.

SELECT
  Department,
  Gender,
  COUNT(*) AS headcount,
  ROUND(AVG(MonthlyIncome), 2) AS avg_income,
  ROUND(100.0 * SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS attrition_rate,
  ROUND(100.0 * SUM(CASE WHEN OverTime = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS overtime_rate,
  ROUND(AVG(JobSatisfaction), 2) AS avg_job_sat
FROM hr_attrition
GROUP BY Department, Gender
ORDER BY attrition_rate DESC;

--25. Find employees who have worked with their current manager for at least 5 years but have not received a promotion for at least 5 years. Calculate their attrition rate by department.

WITH loyal_no_promo AS (
  SELECT Department, EmployeeNumber, Attrition,
         YearsWithCurrManager, YearsSinceLastPromotion
  FROM hr_attrition
  WHERE YearsWithCurrManager >= 5
    AND YearsSinceLastPromotion >= 5
)
SELECT Department,
       COUNT(*) AS total,
       SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) AS attrited,
       ROUND(100.0 * SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS attrition_rate
FROM loyal_no_promo
GROUP BY Department
ORDER BY attrition_rate DESC;

--26. Analyze the relationship between commuting distance (DistanceFromHome) and attrition: attrition rates for 0-10 km, 11-20 km, and 21+ km groups.

SELECT 
  CASE 
    WHEN DistanceFromHome <= 10 THEN '0-10 km'
    WHEN DistanceFromHome <= 20 THEN '11-20 km'
    ELSE '21+ km'
  END AS distance_group,
  COUNT(*) AS total,
  SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) AS attrited,
  ROUND(100.0 * SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS attrition_rate
FROM hr_attrition
GROUP BY distance_group
ORDER BY distance_group;

--27. For each YearsAtCompany value, calculate average JobSatisfaction and attrition rate. Also include the next year's attrition rate using LEAD for trend analysis.

WITH yearly AS (
  SELECT YearsAtCompany,
         ROUND(AVG(JobSatisfaction), 2) AS avg_sat,
         ROUND(100.0 * SUM(CASE WHEN Attrition='Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS attr_rate,
         COUNT(*) AS headcount
  FROM hr_attrition
  GROUP BY YearsAtCompany
)
SELECT YearsAtCompany, avg_sat, attr_rate, headcount,
       LEAD(attr_rate) OVER (ORDER BY YearsAtCompany) AS next_year_rate
FROM yearly
ORDER BY YearsAtCompany;

--28. Identify 'High Potential' employees: PerformanceRating = 4, JobLevel <= 2, and TotalWorkingYears <= 5. Show their distribution by department and average salary.

WITH hi_pot AS (
  SELECT *
  FROM hr_attrition
  WHERE PerformanceRating = 4
    AND JobLevel <= 2
    AND TotalWorkingYears <= 5
)
SELECT Department,
       COUNT(*) AS count,
       ROUND(AVG(MonthlyIncome), 2) AS avg_income,
       ROUND(100.0 * SUM(CASE WHEN Attrition='Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS attrition_rate
FROM hi_pot
GROUP BY Department
ORDER BY count DESC;

