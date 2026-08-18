drop table dbo.tally
go
Create Table dbo.Tally(
       TID int not null,
constraint idx_t_t primary key (tid)
)
go
--Generate some data for it
SET NOCOUNT ON
Declare @i int
Set @i = 1
WHILE @i <= 8000
     BEGIN
         Insert Into Tally Values (@i)
         Set @i = @i + 1
     END
SET NOCOUNT OFF   
go
select top 100 * from tally
go