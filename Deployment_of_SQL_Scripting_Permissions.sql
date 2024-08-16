-- Deployment of Scripting out permissions. this will create the SQL Agent job plus SQL tables and SQL PROC. 

USE [msdb]
GO

/****** Object:  Job [DBA - ScriptOutPermissions]    Script Date: 9/7/2021 3:34:39 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 9/7/2021 3:34:39 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA - ScriptOutPermissions', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [ScriptOutAllPermissions]    Script Date: 9/7/2021 3:34:39 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'ScriptOutAllPermissions', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
/********************************************************************************************************************/
-- Scripting Out the Logins, Server Role Assignments, and Server Permissions
/********************************************************************************************************************/
SET NOCOUNT ON
-- Scripting Out the Logins To Be Created
USE DBA 
-- Creating Table is not exists
IF  NOT EXISTS (SELECT * FROM sys.objects 
WHERE object_id = OBJECT_ID(N''DBA.dbo.tbl_DBA_logins'') AND type in (N''U''))
BEGIN
CREATE TABLE DBA.dbo.tbl_DBA_logins(
DATE Datetime,
Logins_to_be_created NVARCHAR(MAX)
) 
END

INSERT INTO  DBA.dbo.tbl_DBA_logins
SELECT GETDATE() AS DATE,''IF (SUSER_ID(''+QUOTENAME(SP.name,'''''''')+'') IS NULL) BEGIN CREATE LOGIN '' +QUOTENAME(SP.name)+
			   CASE 
					WHEN SP.type_desc = ''SQL_LOGIN'' THEN '' WITH PASSWORD = '' +CONVERT(NVARCHAR(MAX),SL.password_hash,1)+ '' HASHED, CHECK_EXPIRATION = '' 
						+ CASE WHEN SL.is_expiration_checked = 1 THEN ''ON'' ELSE ''OFF'' END +'', CHECK_POLICY = '' +CASE WHEN SL.is_policy_checked = 1 THEN ''ON,'' ELSE ''OFF,'' END
					ELSE '' FROM WINDOWS WITH''
				END 
	   +'' DEFAULT_DATABASE=['' +SP.default_database_name+ ''], DEFAULT_LANGUAGE=['' +SP.default_language_name+ ''] END;'' COLLATE SQL_Latin1_General_CP1_CI_AS AS [-- Logins To Be Created --]
FROM sys.server_principals AS SP LEFT JOIN sys.sql_logins AS SL
		ON SP.principal_id = SL.principal_id
WHERE SP.type IN (''S'',''G'',''U'')
		AND SP.name NOT LIKE ''##%##''
		AND SP.name NOT LIKE ''NT AUTHORITY%''
		AND SP.name NOT LIKE ''NT SERVICE%''
		AND SP.name <> (''sa'')

		-- Creating Table is not exists
IF  NOT EXISTS (SELECT * FROM sys.objects 
WHERE object_id = OBJECT_ID(N''DBA.dbo.tbl_DBA_Server_roles'') AND type in (N''U''))

BEGIN
CREATE TABLE DBA.dbo.tbl_DBA_server_roles(
DATE Datetime,
server_roles Nvarchar(max)
)
END


-- Scripting Out the Role Membership to Be Added
INSERT INTO DBA.dbo.tbl_DBA_server_roles
SELECT GETDATE() AS DATE,
''EXEC master..sp_addsrvrolemember @loginame = N'''''' + SL.name + '''''', @rolename = N'''''' + SR.name + ''''''
'' AS [-- Server Roles the Logins Need to be Added --]
FROM master.sys.server_role_members SRM
	JOIN master.sys.server_principals SR ON SR.principal_id = SRM.role_principal_id
	JOIN master.sys.server_principals SL ON SL.principal_id = SRM.member_principal_id
WHERE SL.type IN (''S'',''G'',''U'')
		AND SL.name NOT LIKE ''##%##''
		AND SL.name NOT LIKE ''NT AUTHORITY%''
		AND SL.name NOT LIKE ''NT SERVICE%''
		AND SL.name <> (''sa'')


-- Creating Table is not exists
IF  NOT EXISTS (SELECT * FROM sys.objects 
WHERE object_id = OBJECT_ID(N''DBA.dbo.tbl_DBA_Server_level_permissions'') AND type in (N''U''))

BEGIN
CREATE TABLE DBA.dbo.tbl_DBA_Server_level_permissions(
DATE Datetime,
Server_level_Permissions NVARCHAR(MAX)
) 
END

INSERT INTO  DBA.dbo.tbl_DBA_Server_level_permissions
SELECT GETDATE() AS DATE,
	CASE WHEN SrvPerm.state_desc <> ''GRANT_WITH_GRANT_OPTION'' 
		THEN SrvPerm.state_desc 
		ELSE ''GRANT'' 
	END
    + '' '' + SrvPerm.permission_name + '' TO ['' + SP.name + '']'' + 
	CASE WHEN SrvPerm.state_desc <> ''GRANT_WITH_GRANT_OPTION'' 
		THEN '''' 
		ELSE '' WITH GRANT OPTION'' 
	END collate database_default AS [-- Server Level Permissions to Be Granted --] 
FROM sys.server_permissions AS SrvPerm 
	JOIN sys.server_principals AS SP ON SrvPerm.grantee_principal_id = SP.principal_id 
WHERE   SP.type IN ( ''S'', ''U'', ''G'' ) 
		AND SP.name NOT LIKE ''##%##''
		AND SP.name NOT LIKE ''NT AUTHORITY%''
		AND SP.name NOT LIKE ''NT SERVICE%''
		AND SP.name <> (''sa'')

		
/********************************************************************************************************************/
-- Scripting Out the user permissions for all DB 
/********************************************************************************************************************/
-- Creating Table is not exists
IF  NOT EXISTS (SELECT * FROM sys.objects 
WHERE object_id = OBJECT_ID(N''DBA.dbo.tbl_DBA_User_level_permissions'') AND type in (N''U''))

BEGIN
CREATE TABLE DBA.dbo.tbl_DBA_User_level_permissions(
DATE Datetime,
DBName NVarchar(max),
User_level_Permissions NVARCHAR(MAX)
) 
END

IF  NOT EXISTS (SELECT * FROM sys.objects 
WHERE object_id = OBJECT_ID(N''DBA.dbo.tbl_DBA_role_level_permissions'') AND type in (N''U''))

BEGIN
CREATE TABLE DBA.dbo.tbl_DBA_role_level_permissions(
DATE Datetime,
DBName NVarchar(max),
role_level_Permissions NVARCHAR(MAX)
) 
END

IF  NOT EXISTS (SELECT * FROM sys.objects 
WHERE object_id = OBJECT_ID(N''DBA.dbo.tbl_DBA_Users_per_db'') AND type in (N''U''))

BEGIN
CREATE TABLE DBA.dbo.tbl_DBA_Users_per_db(
DATE Datetime,
DBName NVarchar(max),
User_per_db NVARCHAR(MAX)
) 
END

IF  NOT EXISTS (SELECT * FROM sys.objects 
WHERE object_id = OBJECT_ID(N''DBA.dbo.tbl_DBA_Object_level_permissions'') AND type in (N''U''))

BEGIN
CREATE TABLE DBA.dbo.tbl_DBA_Object_level_permissions(
DATE Datetime,
DBName NVarchar(max),
Object_level_permission NVARCHAR(MAX)
) 
END



PRINT ''--Scripting out the User Permissions to Be Granted''

DECLARE @command NVARCHAR(MAX) 
SELECT @command =


 
''USE [?] 

DECLARE @dbname VARCHAR(250) 
SELECT @dbname = DB_NAME() 

PRINT ''''use '''' + @dbname

insert into DBA.dbo.tbl_DBA_Users_per_db
SELECT GETDATE() AS DATE,
DB_NAME(),
''''CREATE USER '''' + ''''['''' + NAME + '''']'''' + '''' FOR LOGIN '''' + ''''['''' + NAME + '''']''''
FROM sys.database_principals
WHERE	[NAME] NOT IN (''''dbo'''',''''guest'''',''''sys'''',''''INFORMATION_SCHEMA'''')


PRINT ''''use '''' + @dbname

insert into  DBA.dbo.tbl_DBA_role_level_permissions
SELECT GETDATE() AS DATE,  
DB_NAME(),
''''EXEC sp_AddRoleMember '''' + ''''['''' + DBRole.NAME + '''']'''' + '''','''' + ''''['''' + DBP.NAME + '''']''''
FROM sys.database_principals DBP
INNER JOIN sys.database_role_members DBM ON DBM.member_principal_id = DBP.principal_id
INNER JOIN sys.database_principals DBRole ON DBRole.principal_id = DBM.role_principal_id
WHERE DBP.NAME <> ''''dbo''''


PRINT ''''use '''' + @dbname
 
insert into  DBA.dbo.tbl_DBA_User_level_permissions
SELECT  	GETDATE() AS DATE,
		DB_NAME(),
		CASE WHEN DBP.state <> ''''W'''' THEN DBP.state_desc ELSE ''''GRANT'''' END
		+ SPACE(1) + DBP.permission_name + SPACE(1)
		+ SPACE(1) + ''''TO'''' + SPACE(1) + QUOTENAME(USR.name) COLLATE database_default
		+ CASE WHEN DBP.state <> ''''W'''' THEN SPACE(0) ELSE SPACE(1) + ''''WITH GRANT OPTION'''' END + '''';'''' 
FROM	sys.database_permissions AS DBP
		INNER JOIN	sys.database_principals AS USR	ON DBP.grantee_principal_id = USR.principal_id
WHERE	DBP.major_id = 0 and USR.name <> ''''dbo''''
ORDER BY DBP.permission_name ASC, DBP.state_desc ASC
''

 EXEC sp_MSforeachdb @command


 PRINT ''--Scripting out the object Permissions to Be Granted (In its own quey due to syntax errors''

DECLARE @command1 NVARCHAR(MAX) 
SELECT @command1 =



 ''USE [?] 

DECLARE @dbname VARCHAR(250) 
SELECT @dbname = DB_NAME() 

insert into  DBA.dbo.tbl_DBA_object_level_permissions 
 SELECT  
 GETDATE() AS DATE,
		DB_NAME(),  
		CASE 
            WHEN sys.database_permissions.state <> ''''W'''' THEN sys.database_permissions.state_desc 
            ELSE ''''GRANT''''
        END
        + SPACE(1) + sys.database_permissions.permission_name + SPACE(1) + ''''ON '''' + QUOTENAME(SCHEMA_NAME(objects.schema_id)) + ''''.'''' + QUOTENAME(objects.name) --select, execute, etc on specific objects
        + CASE
                WHEN sys.columns.column_id IS NULL THEN SPACE(0)
                ELSE ''''('''' + QUOTENAME(sys.columns.name) + '''')''''
          END
        + SPACE(1) + ''''TO'''' + SPACE(1) + QUOTENAME(USER_NAME(sys.database_principals.principal_id)) COLLATE database_default
        + CASE 
                WHEN sys.database_permissions.state <> ''''W'''' THEN SPACE(0)
                ELSE SPACE(1) + ''''WITH GRANT OPTION''''
          END
FROM    
    sys.database_permissions
        INNER JOIN
    sys.objects 
            ON sys.database_permissions.major_id = objects.[object_id]
        INNER JOIN
    sys.database_principals
            ON sys.database_permissions.grantee_principal_id = sys.database_principals.principal_id
        LEFT JOIN
    sys.columns
            ON sys.columns.column_id = sys.database_permissions.minor_id AND sys.columns.[object_id] = sys.database_permissions.major_id''
 
  EXEC sp_MSforeachdb @command1
SET NOCOUNT OFF;
', 
		@database_name=N'DBA', 
		@output_file_name=N'E:\SQLDATA\BACKUP\All_SQL_Permissions.sql', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Daily', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20210329, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'7b6b6da8-9c46-4c35-bfba-a9d48b9bb9b5'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

--Create all Tables

USE [DBA]
GO

/****** Object:  Table [dbo].[tbl_DBA_Object_level_permissions]    Script Date: 9/7/2021 3:38:22 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[tbl_DBA_Object_level_permissions](
	[DATE] [datetime] NULL,
	[DBName] [nvarchar](max) NULL,
	[Object_level_permission] [nvarchar](max) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

USE [DBA]
GO

/****** Object:  Table [dbo].[tbl_DBA_role_level_permissions]    Script Date: 9/7/2021 3:38:27 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[tbl_DBA_role_level_permissions](
	[DATE] [datetime] NULL,
	[DBName] [nvarchar](max) NULL,
	[role_level_Permissions] [nvarchar](max) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

USE [DBA]
GO

/****** Object:  Table [dbo].[tbl_DBA_Server_level_permissions]    Script Date: 9/7/2021 3:38:32 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[tbl_DBA_Server_level_permissions](
	[DATE] [datetime] NULL,
	[Server_level_Permissions] [nvarchar](max) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

USE [DBA]
GO

/****** Object:  Table [dbo].[tbl_DBA_server_roles]    Script Date: 9/7/2021 3:38:40 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[tbl_DBA_server_roles](
	[DATE] [datetime] NULL,
	[server_roles] [nvarchar](max) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
USE [DBA]
GO

/****** Object:  Table [dbo].[tbl_DBA_User_level_permissions]    Script Date: 9/7/2021 3:38:46 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[tbl_DBA_User_level_permissions](
	[DATE] [datetime] NULL,
	[DBName] [nvarchar](max) NULL,
	[User_level_Permissions] [nvarchar](max) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

USE [DBA]
GO

/****** Object:  Table [dbo].[tbl_DBA_Users_per_db]    Script Date: 9/7/2021 3:38:51 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[tbl_DBA_Users_per_db](
	[DATE] [datetime] NULL,
	[DBName] [nvarchar](max) NULL,
	[User_per_db] [nvarchar](max) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

USE [DBA]
GO

/****** Object:  Table [dbo].[tbl_DBA_logins]    Script Date: 9/7/2021 4:09:45 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[tbl_DBA_logins](
	[DATE] [datetime] NULL,
	[Logins_to_be_created] [nvarchar](max) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO



--Script out SQL SPROC

USE [DBA]
GO

/****** Object:  StoredProcedure [dbo].[sp_DBA_Script_All_Permissions]    Script Date: 9/7/2021 3:33:42 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE [dbo].[sp_DBA_Script_All_Permissions]
@returndays int = -1,
@Dbname nvarchar(max) = null
AS 
IF @returndays > 0 
BEGIN     
	raiserror('Whoops! you tried to go in the future. please enter a minus number for example -1 then you shall be granted your wish. DOEI', 18, 1)
    return -1
end
DECLARE @daysminus datetime = (SELECT DATEADD(day,@returndays,GETDATE()))

SELECT [DATE]
      ,[server_roles]
  FROM [DBA].[dbo].[tbl_DBA_server_roles]
  WHERE date > @daysminus


 
 SELECT [DATE]
      ,[Server_level_Permissions]
  FROM [DBA].[dbo].[tbl_DBA_Server_level_permissions]
  WHERE date > @daysminus

  
SELECT [DATE]
      ,[Logins_to_be_created]
  FROM [DBA].[dbo].[tbl_DBA_logins]
  WHERE date > @daysminus

IF @Dbname IS NULL
BEGIN
	SELECT [DATE]
      ,[DBName]
      ,[role_level_Permissions]
	FROM [DBA].[dbo].[tbl_DBA_role_level_permissions]
	WHERE date > @daysminus


	SELECT [DATE]
      ,[DBName]
      ,[User_per_db]
	FROM [DBA].[dbo].[tbl_DBA_Users_per_db]
	WHERE date > @daysminus

	SELECT [DATE]
	  ,[DBName]
      ,[User_level_Permissions]
	FROM [DBA].[dbo].[tbl_DBA_User_level_permissions]
	WHERE date > @daysminus
    SELECT [DATE]
      ,[DBName]
      ,Object_level_permission
  FROM [DBA].[dbo].[tbl_DBA_Object_level_permissions]
  WHERE date > @daysminus
END 
  ELSE 
Begin
  SELECT [DATE]
      ,[DBName]
      ,[role_level_Permissions]
  FROM [DBA].[dbo].[tbl_DBA_role_level_permissions]
  WHERE date > @daysminus
  AND DBName = @Dbname


SELECT [DATE]
      ,[DBName]
      ,[User_per_db]
  FROM [DBA].[dbo].[tbl_DBA_Users_per_db]
  WHERE date > @daysminus
  AND DBName = @Dbname

  SELECT [DATE]
      ,[DBName]
      ,[User_level_Permissions]
  FROM [DBA].[dbo].[tbl_DBA_User_level_permissions]
  WHERE date > @daysminus
  AND DBName = @Dbname

    SELECT [DATE]
      ,[DBName]
      ,Object_level_permission
  FROM [DBA].[dbo].[tbl_DBA_Object_level_permissions]
  WHERE date > @daysminus
  AND DBName = @Dbname
END
GO












