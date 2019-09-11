whenever sqlerror exit failure
-- 2216771.1 ---------------------
-- O/S Message: No child processes
--whenever oserror exit failure
--------------------------------------
conn / as sysdba
set echo off
set feedback off
set pagesize 0
set serveroutput on size unlimited
set linesize 256
set verify off
set define on

alter session set nls_date_format='YYYY.MM.DD HH24:MI:SS';
!hostname -f
Prompt current datetime is: 
select sysdate from dual;

exit

