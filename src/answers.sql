-- Your answers here:
-- 1
SELECT
    c.name AS name,
    COUNT(s.id) AS count
FROM
    countries AS c
        INNER JOIN states AS s
            ON c.id = s.country_id
GROUP BY
    c.id;

-- 2
SELECT
    count(*)
FROM
    public.employees AS e
WHERE
    e.supervisor_id IS NULL;

-- 3
SELECT
    c.name,
    o.address,
    COUNT(*) AS empleyees_count
FROM
    employees AS e
        INNER JOIN offices AS o
            ON o.id = e.office_id
        INNER JOIN countries AS c
            ON c.id = o.country_id
GROUP BY
    c.name, o.address
ORDER BY
    empleyees_count DESC, c.name DESC
LIMIT 5;

-- 4
SELECT
    e.supervisor_id,
    count(e.id) AS count
FROM
    employees AS e
WHERE
    e.supervisor_id IS NOT NULL
GROUP BY
    e.supervisor_id
ORDER BY
    count DESC
LIMIT 3;

-- 5
CREATE OR REPLACE FUNCTION getStateIdByName(_state_name TEXT)
    RETURNS INT
    LANGUAGE plpgsql
AS $$
DECLARE
    _state_id INT;
BEGIN
    SELECT
        s.id
    INTO
        _state_id
    FROM
        states AS s
    WHERE
        s.name = _state_name;

    RETURN _state_id;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE NOTICE 'State not found: %', _state_name;
        RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION getCountOfficesByStateName(_state_name TEXT)
    RETURNS INT
    LANGUAGE plpgsql
AS $$
DECLARE
    _state_id INT;
BEGIN
    _state_id := getStateIdByName(_state_name);
    IF _state_id IS NULL THEN
        RETURN 0;
    END IF;

    RETURN (
        SELECT
            COUNT(*)
        FROM
            offices AS o
        WHERE
            o.state_id = _state_id
    );
END;
$$;

SELECT getCountOfficesByStateName('Colorado') AS list_of_office;

-- 6
SELECT
    o.name,
    COUNT(e.id) AS employees_count
FROM
    offices AS o
        INNER JOIN employees AS e
            ON o.id = e.office_id
GROUP BY
    o.name
ORDER BY
    employees_count DESC;

-- 7
DROP TABLE IF EXISTS office_employee_count;
CREATE TEMPORARY TABLE office_employee_count AS
SELECT
    o.address,
    COUNT(e.id) AS employees_count
FROM
    offices AS o
        INNER JOIN employees AS e
            ON o.id = e.office_id
GROUP BY
    o.address;

(
    SELECT *
    FROM office_employee_count
    WHERE employees_count = (SELECT MAX(employees_count) FROM office_employee_count)
    LIMIT 1
)
UNION
(
    SELECT *
    FROM office_employee_count
    WHERE employees_count = (SELECT MIN(employees_count) FROM office_employee_count)
    LIMIT 1
);

DROP TABLE IF EXISTS office_employee_count;

-- 8
SELECT
    e.uuid,
    e.first_name || ' ' || e.last_name AS full_name,
    e.email,
    e.job_title,
    o.name AS company,
    c.name AS country,
    s.name AS state,
    sup.first_name AS boss_name
FROM
    employees AS e
        INNER JOIN employees AS sup
            ON e.supervisor_id = sup.id
        INNER JOIN offices AS o
            ON e.office_id = o.id
        INNER JOIN states AS s
            ON s.id = o.state_id
        INNER JOIN countries AS c
            ON c.id = o.country_id;
