create database test;                                                         
create table test.users (a int, b char(10));
insert into test.users (a,b) values (5,"25"); 
create user john Identified by 'password';                        
GRANT ALL PRIVILEGES ON test.* TO 'john' WITH GRANT OPTION;

