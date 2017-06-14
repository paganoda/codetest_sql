-- Aledade SQL code test
--
-- edit this file to answer the questions below.
-- send back the entire file, such that it can be run against a PostgreSQL 9.5+ database in the following way to produce results:
-- psql -h foohost < test.sql

begin;

create temporary table person (
    id            serial primary key,
    name          text not null,
    deceased_date date
) on commit drop;

-- association of a person with an address over a timespan
-- if thru_dt is NULL, consider "current"
create temporary table person_address (
    id        serial primary key,
    person_id integer not null references person (id),
    address   text    not null,
    from_dt   date    not null,
    thru_dt   date check (thru_dt >= from_dt or thru_dt is null)
) on commit drop;

insert into person (id, name, deceased_date)
values
    (1, 'Richard Harris', '2002-10-25'::date)
  , (2, 'Maggie Smith',    null)
  , (3, 'Robbie Coltrane', null)
  , (4, 'Vernon Dursley',  null)
  ;

insert into person_address (person_id, address, from_dt, thru_dt)
values
    (1, '100 Main St',         '1989-01-01'::date, '1995-01-01'::date)
  , (1, '5322 Otter Ln',       '1992-01-01'::date, '2002-10-25'::date)
  , (2, '34 Lighthouse Ave',   '1979-01-01'::date, '2007-01-01'::date)
  , (2, '904 Chesterfield St', '2010-01-01'::date, '2016-01-01'::date)
  , (2, '19 Chatham Ave',      '2015-01-01'::date, null)
  , (3, '6 Pearl St',          '1979-01-01'::date, '2001-01-01'::date)
  , (3, '456 Addison Rd',      '2003-01-01'::date, '2003-01-01'::date)
  , (3, '62 Adler St',         '2005-01-01'::date, '2010-12-01'::date)
  , (3, '234 Elizabeth St',    '2011-01-01'::date, null)
  , (4, '4 Privet Drive',      '1994-01-01'::date, null)
  ;

-- TODO 1. list living persons and all person_addresses associated with them on June 5, 2017
select p.name, pa.address
from person p
left outer join person_address pa
on p.id = pa.person_id
and '2017-06-05'::date between pa.from_dt and COALESCE(pa.thru_dt,'2017-06-05'::date)
where p.deceased_date is null
;


-- TODO 2. list top 3 person_address records per person order by longest duration
-- (null thru_dt should be considered todays date, and should be included in consideration)
select name, address, duration
from (
select p.name, pa.address, pa.from_dt, pa.thru_dt, COALESCE(pa.thru_dt,current_date) - pa.from_dt AS duration,
rank() OVER (PARTITION BY p.name ORDER BY COALESCE(pa.thru_dt,current_date) - pa.from_dt DESC) 
from person p
left outer join person_address pa
on p.id = pa.person_id
) x
where rank <= 3
;

-- Given a third table person_address_current (created below), intended to contain a non-deceased person's "current" address
-- person_address_current is intended to be kept up-to-date every day, but due to an error hasn't been updated since 2001-01-01.
-- TODO 3. Write SQL to get person_address_current's data up-to-date
-- a. update/insert living person's address to be current as of June 5, 2017.
-- b. remove deceased persons from the table
-- c. records that have not changed since 2001-01-01 should not change

create temporary table person_address_current (
  id        serial primary key,
  person_id integer not null references person (id),
  address   text    not null,
  from_dt   date    not null
) on commit drop;

insert into person_address_current (person_id, address, from_dt)
  select
    p.id
    , pa.address
    , pa.from_dt
  from person_address pa
  join person p
    on p.id = pa.person_id and (p.deceased_date >= '2001-01-01'::date or p.deceased_date is null)
  where from_dt <= '2001-01-01'::date and (thru_dt >= '2001-01-01'::date or thru_dt is null);

-- update records with current address unless address has not changed.
update person_address_current
set address = pa.address, from_dt = pa.from_dt
from person_address pa
where person_address_current.person_id = pa.person_id
and '2017-06-05'::date between pa.from_dt and COALESCE(pa.thru_dt,'2017-06-05'::date)
and person_address_current.from_dt < pa.from_dt
;

-- delete records for deceased people.
delete from person_address_current where person_id in (select id from person where deceased_date is not null);

-- insert missing people.
insert into person_address_current (person_id, address, from_dt)
select
    p.id
    , pa.address
    , pa.from_dt
  from person_address pa
  join person p
  on p.id = pa.person_id and p.deceased_date is not null
  and (thru_dt >= '2017-06-05'::date or thru_dt is null)
  where pa.person_id not in (select person_id from person_address_current)
  ;



commit;
