create table dbo.redis
(
r_key varchar(64) not null,
r_value varchar(max) ,
r_expire_dt datetime
constraint [idx_r_k] primary key clustered
(
r_key asc
)

grant select, update, delete, insert on dbo.redis to asp_user



create view dbo.vwredis as select r_key,r_value,datediff(SECOND,getdate(),r_expire_dt) as r_ttl from dbo.redis with (nolock) where r_expire_dt > getdate()

grant select on dbo.vwredis to asp_user

insert into redis (R_KEY,R_VALUE,R_EXPIRE_DT) VALUES ('KEY:DELME Invisible','VALUE:DELME invisible','2020-1-1') 

select * from dbo.redis where r_key='DUH'
select * from dbo.vwredis
select r_value from dbo.vwredis where r_key='DUH'
select r_ttl from dbo.vwredis where r_key='DUH'
update dbo.redis set r_expire_dt =dateadd(second,5,getdate()) where r_key ='DUH' and  r_key in (select r_key from dbo.vwredis)
MERGE INTO dbo.redis AS r
USING ( VALUES ('DUH', 'DADA', 60) ) AS s ( rkey, rval, rexpire )  
ON r.r_key = s.rkey
WHEN MATCHED THEN
    UPDATE SET  r_key= s.rkey, r_value=s.rval,r_expire_dt =dateadd(second,rexpire,getdate())
WHEN NOT MATCHED  THEN
    INSERT (r_key, r_value,r_expire_dt) VALUES (s.rkey, s.rval,dateadd(second,rexpire,getdate()));



--