# SqlServerScriptPermissions
Automated Scripting of Permissions

What is it? 
In the below i ran this against StackOverflow2010 from Brant Ozar, It will not only script all permissions but generate the correct SQL Statement so you can recreate them if needed. 
This allows for Audit and traceability of all SQL permissions and a source of truth. 
It will script : 
Sever Roles
Server Level Permissions
Logins to be created
Role Level Permissions
Users per DB
User Level Permissions
Object Level Permissions

How to install? 
Easy copy and paste the script into a per SQL Instance basis or via Central Management Servers to install on multiple. Hit f5 or Execute and its done. 
If you do not want or have a DBA DB then open the code within notepad for example and search and replace all DBA to what ever you like. 
What will be installed? 
Tables for storage of different permissions in the DB of your choice, 
SQL Server Agent Job for automated daily runs, 
Stored procedure to run the Script to report from. 
How to use it? 
The below will return all permissions across all DBs, All History. Quite a lot of information will be returned. 
```
USE [DBA]
GO
 
EXEC [dbo].[sp_sbp_Script_All_Permissions]
```
Per DB and a Selection of Days or How many Days? Choose as you wish :) 
```
USE [DBA]
GO
 -- Just 1 day to return and only Master DB
DECLARE @return_value int
 
EXEC    @return_value = [dbo].[sp_sbp_Script_All_Permissions]
        @returndays = -1,
        @Dbname = "master"
 
SELECT  'Return Value' = @return_value
 
GO
-- Just -1 day for all DBs
USE [SBP]
GO
 
DECLARE @return_value int
 
EXEC    @return_value = [dbo].[sp_sbp_Script_All_Permissions]
        @returndays = -1
    --  @Dbname = "master"
 
SELECT  'Return Value' = @return_value
 
GO
 
-- Just Master DB all history
USE [SBP]
GO
 
DECLARE @return_value int
 
EXEC    @return_value = [dbo].[sp_sbp_Script_All_Permissions]
    --  @returndays = -1
        @Dbname = "master"
 
SELECT  'Return Value' = @return_value
 
GO
```
