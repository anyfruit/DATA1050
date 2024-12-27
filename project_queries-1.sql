USE project1;

# TRIGGER
# RUN TRIGGER BEFORE POPULATE DATA INTO DATABASE
DROP TRIGGER IF EXISTS alerts;

DELIMITER //

CREATE TRIGGER alerts
AFTER INSERT ON project1.prescriptions
FOR EACH ROW
BEGIN
	INSERT INTO project1.alerts (patient_id, physician_id, alert_date, drug1, drug2)
	SELECT DISTINCT P.patient_id, NEW.physician_id, NEW.date, P.drug_name, NEW.drug_name
	FROM project1.prescriptions AS P
	INNER JOIN project1.adverse_interactions A ON
		(A.drug_name = P.drug_name AND A.drug_name_2 = NEW.drug_name)
		OR (A.drug_name = NEW.drug_name AND A.drug_name_2 = P.drug_name)
	WHERE P.patient_id = NEW.patient_id;
END //

DELIMITER ;

#PROCEDURE
DROP PROCEDURE IF EXISTS retrieve_phy;

DELIMITER //

CREATE PROCEDURE retrieve_phy (
	IN ssn_in VARCHAR(11),
	OUT out_primary_specialty VARCHAR(256),
	OUT out_experience_years DECIMAL(5, 2)
)
BEGIN
	SELECT primary_specialty, experience_years 
	INTO out_primary_specialty, out_experience_years
	FROM physicians
	WHERE ssn = ssn_in;
END //

DELIMITER ;

#Q1
SELECT N.physician_id
FROM (SELECT A.physician_id, COUNT(A.physician_id) AS physician_count
	  FROM project1.alerts  AS A
      GROUP BY A.physician_id) AS N
WHERE N.physician_count = (
	SELECT MAX(physician_count)
    FROM (
        SELECT COUNT(A.physician_id) AS physician_count
        FROM project1.alerts AS A
        GROUP BY A.physician_id
    ) AS M
    );
    
#Q2
SELECT DISTINCT physician_id
FROM alerts;

#Q3
SELECT physician_id
FROM (
	SELECT P.physician_id, COUNT(P.physician_id) AS physician_count
	FROM prescriptions AS P
	JOIN contracts AS C ON P.drug_name = C.drug_name
	JOIN companies AS CO ON C.company_id = CO.id
    WHERE CO.name = 'DRUGXO'
    GROUP BY physician_id
) AS physician_counts
WHERE physician_count = (
	SELECT MAX(physician_count)
    FROM (
		SELECT P.physician_id, COUNT(P.physician_id) AS physician_count
		FROM prescriptions AS P
		JOIN contracts AS C ON P.drug_name = C.drug_name
		JOIN companies AS CO ON C.company_id = CO.id
        WHERE CO.name = 'DRUGXO'
		GROUP BY P.physician_id
	) AS inner_counts
);

#Q4
SELECT 
    C.drug_name, 
    SUM(C.price) / SUM(C.quantity) AS price_per_unit,
    (SELECT SUM(price) / SUM(quantity) 
     FROM contracts 
     WHERE drug_name = C.drug_name) AS avg_price
FROM contracts AS C
JOIN companies AS CO ON C.company_id = CO.id
WHERE CO.name = 'PHARMASEE'
GROUP BY C.drug_name;

#Q5
SELECT P.drug_name, PF.pharmacy_id, (((PF.cost/P.quantity)-(C.price/C.quantity))/(C.price/C.quantity))*100 AS markup
FROM prescriptions AS P
LEFT JOIN pharmacy_fills AS PF ON PF.prescription_id = P.id
LEFT JOIN contracts AS C ON (C.pharmacy_id, C.drug_name) = (PF.pharmacy_id, P.drug_name);


#Q6
SELECT D.name, AVG(DATEDIFF(PF.date, P.date)) AS avg_day_between
FROM drugs AS D
LEFT JOIN prescriptions AS P ON D.name = P.drug_name
LEFT JOIN pharmacy_fills AS PF ON P.id = PF.prescription_id
GROUP BY D.name;

#Q7
SELECT DISTINCT P.id AS pharmacy_id, D.name AS drug_name
FROM pharmacies P
CROSS JOIN drugs D
LEFT JOIN (
	SELECT PR.drug_name, PF.pharmacy_id
	FROM pharmacy_fills PF
	JOIN prescriptions PR ON PF.prescription_id = PR.id) AS PF 
    ON P.id = PF.pharmacy_id AND D.name = PF.drug_name
	WHERE 
		NOT EXISTS (
        #Filled x drug at x pharmacy
        SELECT 1
        FROM pharmacy_fills PF
        WHERE PF.pharmacy_id = P.id AND PF.drug_name = D.name
    )
AND EXISTS (
    #Existed prescription for the drug
    SELECT 1
    FROM prescriptions PR
    WHERE PR.drug_name = D.name
);

