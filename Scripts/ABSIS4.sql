USE [master]
GO
/****** Object:  Database [ABSIS4]    Script Date: 03/08/2018 14:19:02 ******/
CREATE DATABASE [ABSIS4]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'ABSIS', FILENAME = N'E:\apps\ABSIS4\DATA\ABSIS4.mdf' , SIZE = 399360KB , MAXSIZE = UNLIMITED, FILEGROWTH = 1024KB )
 LOG ON 
( NAME = N'ABSIS_log', FILENAME = N'E:\apps\ABSIS4\DATA\ABSIS4_log.ldf' , SIZE = 1280KB , MAXSIZE = 2048GB , FILEGROWTH = 10%)
GO
ALTER DATABASE [ABSIS4] SET COMPATIBILITY_LEVEL = 90
GO
IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [ABSIS4].[dbo].[sp_fulltext_database] @action = 'enable'
end
GO
ALTER DATABASE [ABSIS4] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [ABSIS4] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [ABSIS4] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [ABSIS4] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [ABSIS4] SET ARITHABORT OFF 
GO
ALTER DATABASE [ABSIS4] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [ABSIS4] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [ABSIS4] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [ABSIS4] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [ABSIS4] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [ABSIS4] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [ABSIS4] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [ABSIS4] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [ABSIS4] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [ABSIS4] SET  DISABLE_BROKER 
GO
ALTER DATABASE [ABSIS4] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [ABSIS4] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [ABSIS4] SET TRUSTWORTHY OFF 
GO
ALTER DATABASE [ABSIS4] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO
ALTER DATABASE [ABSIS4] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [ABSIS4] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [ABSIS4] SET HONOR_BROKER_PRIORITY OFF 
GO
ALTER DATABASE [ABSIS4] SET RECOVERY SIMPLE 
GO
ALTER DATABASE [ABSIS4] SET  MULTI_USER 
GO
ALTER DATABASE [ABSIS4] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [ABSIS4] SET DB_CHAINING OFF 
GO
ALTER DATABASE [ABSIS4] SET FILESTREAM( NON_TRANSACTED_ACCESS = OFF ) 
GO
ALTER DATABASE [ABSIS4] SET TARGET_RECOVERY_TIME = 0 SECONDS 
GO
USE [ABSIS4]
GO
/****** Object:  FullTextCatalog [ABSIS]    Script Date: 03/08/2018 14:19:02 ******/
CREATE FULLTEXT CATALOG [ABSIS]WITH ACCENT_SENSITIVITY = OFF

GO
/****** Object:  FullTextCatalog [ABSIS_ERROR]    Script Date: 03/08/2018 14:19:02 ******/
CREATE FULLTEXT CATALOG [ABSIS_ERROR]WITH ACCENT_SENSITIVITY = OFF

GO
/****** Object:  UserDefinedFunction [dbo].[APP_GetBillClient]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[APP_GetBillClient] 
(
	@clientId bigint,--Potser un departament o un centre
	@issuerUnitId bigint,
	@date datetime
)
RETURNS bigint
AS
BEGIN
	DECLARE @billClientId BIGINT
	
	SET @billClientId = (SELECT TOP 1 id
	FROM [dbo].[BILL_CLIENTS] AS BC
	WHERE id IN (SELECT billclientId
		FROM BILL_MERGES 
		WHERE clientId = @clientId
				AND issuerunitid = @issuerUnitId 
				AND (TT_start_date <= @date  
					AND ((TT_end_date IS NULL) OR (TT_end_date >= @date))))
	AND (TT_start_date <= @date  
		AND ((TT_end_date IS NULL) OR (TT_end_date >= @date)))
	ORDER BY TT_end_date DESC)
	RETURN @billClientId
END

GO
/****** Object:  UserDefinedFunction [dbo].[APP_GetCurrentAmountWithoutDiscounts]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[APP_GetCurrentAmountWithoutDiscounts] 
(
	@billableConceptId bigint,
	@clientAccountId bigint,
	@consumptionAmount decimal(18,2),
	@date date
)
RETURNS money
AS
BEGIN
	DECLARE @rate money
	DECLARE @amount money
	SELECT @rate = dbo.APP_GetCurrentRate(@billableConceptId,@clientAccountId,@date)
	
	RETURN CAST(@rate * @consumptionAmount AS MONEY)
END


GO
/****** Object:  UserDefinedFunction [dbo].[APP_GetCurrentDiscount]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE FUNCTION [dbo].[APP_GetCurrentDiscount] 
(
	@billableConceptId bigint,
	@clientAccountId bigint,
	@isPercentage bit,
	@date date
)
RETURNS money
AS
BEGIN
	RETURN (SELECT TOP 1 unit_cost FROM dbo.SPECIAL_RATESDISCOUNTS_SNAPSHOTS AS SPR_SNS 
		INNER JOIN dbo.SPECIAL_RATEDISCOUNT_ACCOUNTS AS SPR_ACC
			ON SPR_SNS.entity_id = SPR_ACC.id_special_ratediscount INNER JOIN 
			dbo.SPECIAL_RATESDISCOUNTS AS SPR ON SPR.id = SPR_SNS.entity_id
		WHERE SPR_SNS.scope_id = 1 AND (SPR_SNS.AT_start_date <= @date 
			AND SPR_SNS.VT_start_date <= @date 
				AND ((SPR_SNS.AT_end_date IS NULL AND SPR_SNS.VT_end_date IS NULL) OR
					(SPR_SNS.AT_end_date >= @date AND SPR_SNS.VT_end_date IS NULL) OR
					(SPR_SNS.AT_end_date IS NULL AND SPR_SNS.VT_end_date >= @date)))
			AND SPR.billable_concept_id=@billableConceptId 
			AND is_discount=1
			AND SPR_ACC.id_account=@clientAccountId  
		ORDER BY SPR_SNS.sequence)
END


GO
/****** Object:  UserDefinedFunction [dbo].[APP_GetCurrentRate]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE FUNCTION [dbo].[APP_GetCurrentRate] 
(
	@billableConceptId bigint,
	@clientAccountId bigint,
	@date date
)
RETURNS money
AS
BEGIN
	DECLARE @rate money
	SET @rate = (SELECT TOP 1 unit_cost FROM dbo.SPECIAL_RATESDISCOUNTS_SNAPSHOTS AS SPR_SNS 
		INNER JOIN dbo.SPECIAL_RATEDISCOUNT_ACCOUNTS AS SPR_ACC
			ON SPR_SNS.entity_id = SPR_ACC.id_special_ratediscount INNER JOIN dbo.SPECIAL_RATESDISCOUNTS AS SPR ON
				SPR.id = SPR_SNS.entity_id
		WHERE SPR_SNS.scope_id = 1 
			AND (SPR_SNS.AT_start_date <= @date 
				AND SPR_SNS.VT_start_date <= @date 
					AND ((SPR_SNS.AT_end_date IS NULL AND SPR_SNS.VT_end_date IS NULL) OR
						(SPR_SNS.AT_end_date >= @date AND SPR_SNS.VT_end_date IS NULL) OR
						(SPR_SNS.AT_end_date IS NULL AND SPR_SNS.VT_end_date >= @date)))
			AND SPR.billable_concept_id=@billableConceptId 
			AND is_discount=0
			AND SPR_ACC.id_account=@clientAccountId  
		ORDER BY SPR_SNS.sequence)
  
	IF(@rate IS NULL) BEGIN 
		SET @rate = (SELECT TOP 1 unit_cost
			FROM dbo.RATES AS RAT INNER JOIN
				dbo.RATES_SNAPSHOTS AS RAT_SNS ON
					RAT.id = RAT_SNS.entity_id
			WHERE RAT.billable_concept_id=@billableConceptId 
				AND (RAT.TT_end_date IS NULL OR RAT.TT_end_date >= @date) 
				AND (RAT_SNS.AT_start_date <= @date 
					AND RAT_SNS.VT_start_date <= @date 
						AND ((RAT_SNS.AT_end_date IS NULL AND RAT_SNS.VT_end_date IS NULL) OR
							(RAT_SNS.AT_end_date >= @date AND RAT_SNS.VT_end_date IS NULL) OR
							(RAT_SNS.AT_end_date IS NULL AND RAT_SNS.VT_end_date >= @date))))
	END 
	RETURN @rate
END


GO
/****** Object:  UserDefinedFunction [dbo].[CountAccounts]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[CountAccounts] 
(
	@departmentId bigint
)
RETURNS int
AS
BEGIN
	DECLARE @counter money
	SET @counter = (SELECT COUNT(*) FROM ACCOUNT_DEPARTMENTS
		WHERE idDepartment = @departmentId) 
	RETURN @counter
END
GO
/****** Object:  UserDefinedFunction [dbo].[GetBEIDiscountAmount]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[GetBEIDiscountAmount] 
(
	@chargeId bigint,--Id del càrrec en el que estem buscant si te descompte
	@billEntryId bigint
)
RETURNS money
AS
BEGIN
	DECLARE @amount money
	
	SET @amount = (SELECT  TOP 1 discount_amount
		FROM BILL_ENTRY_ITEMS_JDE WHERE charge_id= @chargeId AND discount_id IS NOT NULL AND bill_entry_id=@billEntryId)

	IF(@amount IS NULL) BEGIN 
		SET @amount = 0
	END 

	RETURN @amount
END




GO
/****** Object:  UserDefinedFunction [dbo].[GetBEIDiscountPercentage]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[GetBEIDiscountPercentage] 
(
	@chargeId bigint,--Id del càrrec en el que estem buscant si te descompte
	@billEntryId bigint
)
RETURNS money
AS
BEGIN
	DECLARE @amount money
	
	SET @amount = (SELECT  TOP 1 discount_percentage
		FROM BILL_ENTRY_ITEMS_JDE WHERE charge_id= @chargeId AND discount_id IS NOT NULL AND bill_entry_id=@billEntryId)

	IF(@amount IS NULL) BEGIN 
		SET @amount = 0
	END 

	RETURN @amount
END



GO
/****** Object:  UserDefinedFunction [dbo].[GetBEIOriginalAmount]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[GetBEIOriginalAmount] 
(
	@originalBillEntryItemId bigint--Id del càrrec en el que estem buscant si te descompte
)
RETURNS money
AS
BEGIN
	DECLARE @amount money
	SET @amount = (SELECT TOP 1 charge_amount FROM BILL_ENTRY_ITEMS where id=@originalBillEntryItemId)
	RETURN @amount
END




GO
/****** Object:  UserDefinedFunction [dbo].[GetBEISplitPercentage]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[GetBEISplitPercentage] 
(
	@originalBillEntryItemId bigint,--Id del càrrec en el que estem buscant si te descompte
	@splitDefId bigint
)
RETURNS decimal(18,4)
AS
BEGIN
	DECLARE @IsSplitted bit
	DECLARE @CountSplittedCharges int
	DECLARE @splittedPercentage decimal(18,4)

	SET @CountSplittedCharges = (SELECT COUNT(*) FROM BILL_ENTRY_ITEMS_JDE WHERE original_bill_entry_item_id = @originalBillEntryItemId)

	IF(@CountSplittedCharges = 1) BEGIN 
		SET @splittedPercentage = 1.00
	END
	ELSE
		IF(@splitDefId IS NULL) BEGIN
		--Tenemos que buscar a su pareja para saber que % está splitado
			SET @splitDefId = (SELECT TOP 1 split_def_id FROM BILL_ENTRY_ITEMS_JDE WHERE 
			original_bill_entry_item_id=@originalBillEntryItemId AND split_def_id IS NOT NULL)

			SET @splittedPercentage = (SELECT TOP 1 percentage_of_tax FROM BILL_SPLITS WHERE id = @splitDefId)
			RETURN 1 - @splittedPercentage
		END
		ELSE
			SET @splittedPercentage = (SELECT TOP 1 percentage_of_tax FROM BILL_SPLITS WHERE id = @splitDefId)
			RETURN @splittedPercentage
		END



GO
/****** Object:  UserDefinedFunction [dbo].[GetBEISplitPercentage_v2]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[GetBEISplitPercentage_v2] 
(
	@originalBillEntryItemId bigint,--Id del càrrec en el que estem buscant si te descompte
	@splitDefId bigint,
	@splitted_portion_type varchar(10)
)
RETURNS decimal(18,4)
AS
BEGIN
	DECLARE @CountSplittedCharges int
	DECLARE @splittedPercentage decimal(18,4)
	
	SET @CountSplittedCharges = (SELECT COUNT(*) FROM BILL_ENTRY_ITEMS_JDE WHERE original_bill_entry_item_id = @originalBillEntryItemId AND split_portion_type IS NOT NULL)

	IF(@CountSplittedCharges = 0) BEGIN --No està splitat ha de ser el 100%, per tant tornem 1.00
		SET @splittedPercentage = 1.00
		RETURN @splittedPercentage
	END
	ELSE
		IF(@splitted_portion_type = 'original') BEGIN
			SET @splittedPercentage = (SELECT TOP 1 percentage_of_tax FROM BILL_SPLITS WHERE id = @splitDefId)
			RETURN 1 - @splittedPercentage
		END
		ELSE
		SET @splittedPercentage = (SELECT TOP 1 percentage_of_tax FROM BILL_SPLITS WHERE id = @splitDefId)
			RETURN @splittedPercentage
		END



GO
/****** Object:  UserDefinedFunction [dbo].[GetBEISplitTaxType]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[GetBEISplitTaxType] 
(
	@billEntryId bigint--Id del càrrec en el que estem buscant si te descompte
)
RETURNS nvarchar(50)
AS
BEGIN
	DECLARE @strTaxType AS nvarchar(50)
	DECLARE @taxType AS int
	
	SET @taxType = (SELECT TOP 1 tax_area FROM BILL_ENTRIES_JDE WHERE id = @billEntryId)
	IF(@taxType IS NULL) 
	BEGIN
		SET @taxType = (SELECT TOP 1 tax_area FROM BILL_ENTRIES WHERE id = @billEntryId)
	END
	SET @strTaxType = (SELECT TOP 1 name FROM TAX_AREAS WHERE id=@taxType)

	RETURN @strTaxType
END
GO
/****** Object:  UserDefinedFunction [dbo].[GetCurrentAmountDiscount]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[GetCurrentAmountDiscount] 
(
	@billableConceptId bigint,
	@invoicingMonth int,
	@invoicingYear int,
	@clientAccountId bigint,
	@chargeAmountWithOutDiscount decimal(18,2)
)
RETURNS money
AS
BEGIN
	DECLARE @amount money	
	DECLARE @discount TABLE (unit_cost MONEY, is_percentage BIT)

	INSERT INTO @discount (unit_cost, is_percentage)
        SELECT TOP 1 unit_cost, is_percentage
        FROM dbo.SPECIAL_RATESDISCOUNTS INNER JOIN dbo.SPECIAL_RATEDISCOUNT_ACCOUNTS
		ON dbo.SPECIAL_RATESDISCOUNTS.id = dbo.SPECIAL_RATEDISCOUNT_ACCOUNTS.id_special_ratediscount
		where billable_concept_id=@billableConceptId and is_discount=0
		and start_month <= @invoicingMonth and end_month>=@invoicingMonth and year=@invoicingYear 
		and id_account=@clientAccountId  
		ORDER BY sequence		
		
	IF (SELECT TOP 1 is_percentage FROM @discount) = 1
	BEGIN
		SET @amount = ((SELECT TOP 1 unit_cost FROM @discount) * @chargeAmountWithOutDiscount)/100		
	END
	ELSE
		SET @amount = (SELECT TOP 1 unit_cost FROM @discount)
	
	RETURN @amount
END


GO
/****** Object:  UserDefinedFunction [dbo].[GetCurrentAmountWithoutDiscounts]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[GetCurrentAmountWithoutDiscounts] 
(
	@billableConceptId bigint,
	@invoicingMonth int,
	@invoicingYear int,
	@clientAccountId bigint,
	@consumptionAmount decimal(18,2)
)
RETURNS money
AS
BEGIN
	DECLARE @rate money
	DECLARE @amount money
	SET @rate = (SELECT TOP 1 unit_cost
		FROM dbo.SPECIAL_RATESDISCOUNTS INNER JOIN dbo.SPECIAL_RATEDISCOUNT_ACCOUNTS
		ON dbo.SPECIAL_RATESDISCOUNTS.id = dbo.SPECIAL_RATEDISCOUNT_ACCOUNTS.id_special_ratediscount
		where billable_concept_id=@billableConceptId and is_discount=0
		and start_month <= @invoicingMonth and end_month>=@invoicingMonth and year=@invoicingYear 
		and id_account=@clientAccountId  
		ORDER BY sequence)
  
	IF(@rate IS NULL) BEGIN 
		SET @rate = (SELECT TOP 1 unit_cost
			FROM dbo.RATES
			where billable_concept_id=@billableConceptId
			and start_month <= @invoicingMonth and end_month>=@invoicingMonth and year=@invoicingYear )
	END
	
	RETURN CAST(@rate * @consumptionAmount AS MONEY)
END

GO
/****** Object:  UserDefinedFunction [dbo].[GetCurrentDiscount]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[GetCurrentDiscount] 
(
	@billableConceptId bigint,
	@invoicingMonth int,
	@invoicingYear int,
	@clientAccountId bigint,
	@isPercentage bit
)
RETURNS money
AS
BEGIN
	RETURN (SELECT TOP 1 unit_cost
		FROM dbo.SPECIAL_RATESDISCOUNTS INNER JOIN dbo.SPECIAL_RATEDISCOUNT_ACCOUNTS
		ON dbo.SPECIAL_RATESDISCOUNTS.id = dbo.SPECIAL_RATEDISCOUNT_ACCOUNTS.id_special_ratediscount
		where billable_concept_id=@billableConceptId and is_discount=1 and is_percentage=@isPercentage
		and start_month <= @invoicingMonth and end_month>=@invoicingMonth and year=@invoicingYear 
		and id_account=@clientAccountId  
		ORDER BY sequence)
END

GO
/****** Object:  UserDefinedFunction [dbo].[GetCurrentRate]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[GetCurrentRate] 
(
	@billableConceptId bigint,
	@invoicingMonth int,
	@invoicingYear int,
	@clientAccountId bigint
)
RETURNS money
AS
BEGIN
	DECLARE @rate money
	SET @rate = (SELECT TOP 1 unit_cost
		FROM dbo.SPECIAL_RATESDISCOUNTS INNER JOIN dbo.SPECIAL_RATEDISCOUNT_ACCOUNTS
		ON dbo.SPECIAL_RATESDISCOUNTS.id = dbo.SPECIAL_RATEDISCOUNT_ACCOUNTS.id_special_ratediscount
		where billable_concept_id=@billableConceptId and is_discount=0
		and start_month <= @invoicingMonth and end_month>=@invoicingMonth and year=@invoicingYear 
		and id_account=@clientAccountId  
		ORDER BY sequence)
  
	IF(@rate IS NULL) BEGIN 
		SET @rate = (SELECT TOP 1 unit_cost
			FROM dbo.RATES
			where billable_concept_id=@billableConceptId
			and start_month <= @invoicingMonth and end_month>=@invoicingMonth and year=@invoicingYear )
	END 
	RETURN @rate
END

GO
/****** Object:  UserDefinedFunction [dbo].[VoidNullStrings]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Xavier Lluch	
-- Create date: 15 de Abril de 2009
-- Description:	Evitar los nulls traduciéndolos por blancos
-- =============================================
CREATE FUNCTION [dbo].[VoidNullStrings] 
(
	@value nvarchar(4000)
)
RETURNS nvarchar(4000)
AS
BEGIN
	if @value IS NULL return ''
	return @value
END






/**** PROCEDIMIENTOS ALMACENADOS ******/
/**************************************/

GO
/****** Object:  Table [dbo].[ACCOUNTS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ACCOUNTS](
	[id] [bigint] NOT NULL,
	[enterprise_id] [bigint] NOT NULL,
	[TT_start_date] [datetime2](7) NOT NULL,
	[TT_end_date] [datetime2](7) NULL,
	[TT_start_user] [bigint] NOT NULL,
	[TT_end_user] [bigint] NULL,
	[last_change_date] [datetime2](7) NOT NULL,
	[last_change_user] [bigint] NOT NULL,
 CONSTRAINT [PK_ACCOUNT] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[ACCOUNTS_SNAPSHOTS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ACCOUNTS_SNAPSHOTS](
	[entity_id] [bigint] NOT NULL,
	[name] [nvarchar](100) NOT NULL,
	[receive_bills] [bit] NOT NULL,
	[send_bills] [bit] NOT NULL,
	[code] [nvarchar](12) NULL,
	[abreviatura] [nvarchar](10) NOT NULL,
	[id] [bigint] IDENTITY(1,1) NOT NULL,
	[AT_start_date] [datetime2](7) NULL,
	[AT_end_date] [datetime2](7) NULL,
	[AT_start_user] [bigint] NOT NULL,
	[AT_end_user] [bigint] NULL,
	[VT_start_date] [date] NOT NULL,
	[VT_end_date] [date] NULL,
	[scope_id] [int] NOT NULL,
	[department_id] [bigint] NULL,
	[division_id] [bigint] NULL,
 CONSTRAINT [PK_ACCOUNTS_SNAPSHOTS] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[BILL_CLIENT_MERGE_TYPES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BILL_CLIENT_MERGE_TYPES](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[name] [varchar](50) NOT NULL,
	[description] [nvarchar](100) NOT NULL,
 CONSTRAINT [PK_BILL_>ORDE] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[BILL_CLIENTS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BILL_CLIENTS](
	[id] [bigint] NOT NULL,
	[clientEnterpriseId] [bigint] NOT NULL,
	[issuerEnterpriseId] [bigint] NOT NULL,
	[name] [nvarchar](max) NOT NULL,
	[mergeKey] [nvarchar](max) NOT NULL,
	[mergeType] [int] NOT NULL,
	[isActive] [bit] NOT NULL,
	[updated] [bit] NULL,
	[TT_start_date] [datetime2](7) NOT NULL,
	[TT_end_date] [datetime2](7) NULL,
	[TT_start_user] [bigint] NOT NULL,
	[TT_end_user] [bigint] NULL,
	[last_change_date] [datetime2](7) NOT NULL,
	[last_change_user] [bigint] NOT NULL,
 CONSTRAINT [PK_BILL_ORDER_CLIENTS] PRIMARY KEY CLUSTERED 
(
	[id] ASC,
	[clientEnterpriseId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [dbo].[BILL_DOCUMENT_TYPES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BILL_DOCUMENT_TYPES](
	[id] [int] NOT NULL,
	[name] [nvarchar](50) NOT NULL,
	[jde_label] [nvarchar](10) NULL,
 CONSTRAINT [PK_BILL_DOCUMENT_TYPES] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[BILL_ENTRIES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BILL_ENTRIES](
	[id] [bigint] NOT NULL,
	[bill_order_id] [bigint] NOT NULL,
	[bill_entry_num] [int] NOT NULL,
	[IN_account_id] [bigint] NOT NULL,
	[IN_account_name] [nvarchar](100) NOT NULL,
	[IN_account_code] [nvarchar](12) NOT NULL,
	[IN_account_address] [varchar](5) NOT NULL,
	[service_id] [bigint] NOT NULL,
	[service_description] [nvarchar](100) NOT NULL,
	[amount] [money] NOT NULL,
	[subledger] [varchar](8) NULL,
	[subledger_type] [varchar](1) NULL,
	[tax_area] [int] NOT NULL,
 CONSTRAINT [PK_BILL_ENTRIES] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[BILL_ENTRIES_JDE]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BILL_ENTRIES_JDE](
	[id] [bigint] NOT NULL,
	[bill_order_id] [bigint] NOT NULL,
	[bill_entry_num] [int] NOT NULL,
	[IN_account_id] [bigint] NOT NULL,
	[IN_account_name] [nvarchar](100) NOT NULL,
	[IN_account_code] [nvarchar](12) NOT NULL,
	[IN_account_address] [varchar](5) NOT NULL,
	[service_id] [bigint] NOT NULL,
	[service_description] [nvarchar](100) NOT NULL,
	[amount] [money] NOT NULL,
	[subledger] [varchar](8) NULL,
	[subledger_type] [varchar](1) NULL,
	[tax_area] [int] NOT NULL,
	[original_bill_entry_id] [bigint] NOT NULL
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[BILL_ENTRY_ITEM_TYPES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BILL_ENTRY_ITEM_TYPES](
	[id] [int] NOT NULL,
	[name] [varchar](50) NOT NULL,
 CONSTRAINT [PK_BILL_ENTRY_ITEM_TYPES] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[BILL_ENTRY_ITEMS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BILL_ENTRY_ITEMS](
	[id] [bigint] NOT NULL,
	[bill_entry_item_type_id] [int] NOT NULL,
	[bill_entry_id] [bigint] NOT NULL,
	[item_num] [int] NOT NULL,
	[issuer_department_id] [bigint] NOT NULL,
	[issuer_department_name] [nvarchar](100) NOT NULL,
	[issuer_department_code] [nvarchar](5) NOT NULL,
	[client_account_id] [bigint] NOT NULL,
	[client_account_name] [nvarchar](100) NOT NULL,
	[client_account_code] [nvarchar](12) NOT NULL,
	[client_department_id] [bigint] NULL,
	[client_department_name] [nvarchar](100) NULL,
	[client_department_code] [nvarchar](5) NULL,
	[billable_concept_id] [bigint] NOT NULL,
	[concept_id] [bigint] NOT NULL,
	[concept_description] [nvarchar](200) NOT NULL,
	[concept_unit_id] [bigint] NOT NULL,
	[concept_unit_name] [nvarchar](20) NOT NULL,
	[charge_id] [bigint] NOT NULL,
	[charge_amount] [money] NOT NULL,
	[charge_description] [nvarchar](100) NOT NULL,
	[consumption_id] [bigint] NULL,
	[consumption_amount] [money] NULL,
	[consumption_rate_id] [bigint] NULL,
	[consumption_rate_unit_cost] [money] NULL,
	[discount_id] [bigint] NULL,
	[discount_amount] [money] NULL,
	[discount_percentage] [money] NULL,
	[amount] [money] NOT NULL,
	[OUT_accounting_address] [varchar](5) NULL,
	[subledger] [varchar](8) NULL,
	[subledger_type] [varchar](1) NULL,
 CONSTRAINT [PK_BILL_ENTRY_ITEMS] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[BILL_ENTRY_ITEMS_JDE]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BILL_ENTRY_ITEMS_JDE](
	[id] [bigint] NOT NULL,
	[bill_entry_item_type_id] [int] NOT NULL,
	[bill_entry_id] [bigint] NOT NULL,
	[item_num] [int] NOT NULL,
	[issuer_department_id] [bigint] NOT NULL,
	[issuer_department_name] [nvarchar](100) NOT NULL,
	[issuer_department_code] [nvarchar](5) NOT NULL,
	[client_account_id] [bigint] NOT NULL,
	[client_account_name] [nvarchar](100) NOT NULL,
	[client_account_code] [nvarchar](12) NOT NULL,
	[client_department_id] [bigint] NULL,
	[client_department_name] [nvarchar](100) NULL,
	[client_department_code] [nvarchar](5) NULL,
	[billable_concept_id] [bigint] NOT NULL,
	[concept_id] [bigint] NOT NULL,
	[concept_description] [nvarchar](200) NOT NULL,
	[concept_unit_id] [bigint] NOT NULL,
	[concept_unit_name] [nvarchar](20) NOT NULL,
	[charge_id] [bigint] NOT NULL,
	[charge_amount] [money] NOT NULL,
	[charge_description] [nvarchar](100) NOT NULL,
	[consumption_id] [bigint] NULL,
	[consumption_amount] [money] NULL,
	[consumption_rate_id] [bigint] NULL,
	[consumption_rate_unit_cost] [money] NULL,
	[discount_id] [bigint] NULL,
	[discount_amount] [money] NULL,
	[discount_percentage] [money] NULL,
	[amount] [money] NOT NULL,
	[OUT_accounting_address] [varchar](5) NULL,
	[subledger] [varchar](8) NULL,
	[subledger_type] [varchar](1) NULL,
	[original_bill_entry_item_id] [bigint] NOT NULL,
	[split_def_id] [int] NULL,
	[split_portion_type] [varchar](10) NULL
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[BILL_MERGES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BILL_MERGES](
	[id] [bigint] IDENTITY(1,1) NOT NULL,
	[billClientId] [bigint] NOT NULL,
	[issuerUnitId] [bigint] NOT NULL,
	[clientId] [bigint] NOT NULL,
	[clientEntityType] [bigint] NOT NULL,
	[TT_start_date] [datetime2](7) NOT NULL,
	[TT_end_date] [datetime2](7) NULL,
	[TT_start_user] [bigint] NOT NULL,
	[TT_end_user] [bigint] NULL,
	[last_change_date] [datetime2](7) NOT NULL,
	[last_change_user] [bigint] NOT NULL,
 CONSTRAINT [PK_BILL_ORDERS_MERGES] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[BILL_ORDER_ID_TABLE]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BILL_ORDER_ID_TABLE](
	[id] [numeric](8, 0) IDENTITY(1,1) NOT NULL,
 CONSTRAINT [PK_BILL_ID_TABLE] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[BILL_ORDER_JDE_ID_TABLE]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BILL_ORDER_JDE_ID_TABLE](
	[id] [numeric](8, 0) IDENTITY(1,1) NOT NULL,
 CONSTRAINT [PK_BILL_ORDER_JDE_ID_TABLE] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[BILL_ORDERS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BILL_ORDERS](
	[id] [bigint] NOT NULL,
	[bill_order_num] [int] NOT NULL,
	[issuer_enterprise_id] [bigint] NOT NULL,
	[issuer_enterprise_name] [nvarchar](100) NOT NULL,
	[issuer_enterprise_code] [nvarchar](12) NOT NULL,
	[issuer_foolish_account_code] [nvarchar](12) NOT NULL,
	[client_id] [bigint] NOT NULL,
	[client_name] [nvarchar](100) NOT NULL,
	[client_enterprise_id] [bigint] NOT NULL,
	[client_enterprise_name] [nvarchar](100) NOT NULL,
	[client_enterprise_code] [nvarchar](8) NOT NULL,
	[amount] [money] NOT NULL,
	[billing_date] [datetime2](7) NULL,
	[process_date] [datetime2](7) NULL,
	[scope_id] [int] NOT NULL,
	[bill_doc_type] [int] NOT NULL,
	[bill_month] [int] NULL,
	[bill_year] [int] NULL,
	[locked] [bit] NULL,
 CONSTRAINT [PK_BILLS_ORDERS] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[BILL_ORDERS_JDE]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BILL_ORDERS_JDE](
	[id] [bigint] NOT NULL,
	[bill_order_num] [int] NOT NULL,
	[issuer_enterprise_id] [bigint] NOT NULL,
	[issuer_enterprise_name] [nvarchar](100) NOT NULL,
	[issuer_enterprise_code] [nvarchar](12) NOT NULL,
	[issuer_foolish_account_code] [nvarchar](12) NOT NULL,
	[client_id] [bigint] NOT NULL,
	[client_name] [nvarchar](100) NOT NULL,
	[client_enterprise_id] [bigint] NOT NULL,
	[client_enterprise_name] [nvarchar](100) NOT NULL,
	[client_enterprise_code] [nvarchar](8) NOT NULL,
	[amount] [money] NOT NULL,
	[billing_date] [datetime2](7) NULL,
	[process_date] [datetime2](7) NULL,
	[scope_id] [int] NOT NULL,
	[bill_doc_type] [int] NOT NULL,
	[bill_month] [int] NULL,
	[bill_year] [int] NULL,
	[locked] [bit] NULL,
	[original_bill_order_id] [bigint] NOT NULL
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[BILL_SPLIT_ENTITY_PROPERTY_TYPES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BILL_SPLIT_ENTITY_PROPERTY_TYPES](
	[id] [int] NOT NULL,
	[name] [nvarchar](50) NOT NULL,
	[description] [nvarchar](200) NOT NULL
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[BILL_SPLITS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BILL_SPLITS](
	[id] [int] NOT NULL,
	[issuer_entity_type] [bigint] NOT NULL,
	[issuer_id_to_check] [bigint] NOT NULL,
	[issuer_entity_property_type] [int] NOT NULL,
	[client_entity_type] [bigint] NOT NULL,
	[client_id_to_check] [bigint] NOT NULL,
	[client_entity_property_type] [int] NOT NULL,
	[percentage_of_tax] [decimal](18, 4) NOT NULL,
	[tax_area] [int] NOT NULL,
	[apply] [bit] NOT NULL,
	[sequence] [int] NOT NULL,
	[TT_start_date] [date] NOT NULL,
	[TT_end_date] [date] NULL
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[BILLABLE_CONCEPTS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BILLABLE_CONCEPTS](
	[id] [bigint] NOT NULL,
	[concept_id] [bigint] NOT NULL,
	[service_id] [bigint] NOT NULL,
	[TT_start_date] [datetime2](7) NOT NULL,
	[TT_end_date] [datetime2](7) NULL,
	[TT_start_user] [bigint] NOT NULL,
	[TT_end_user] [bigint] NULL,
	[last_change_date] [datetime2](7) NOT NULL,
	[last_change_user] [bigint] NOT NULL,
 CONSTRAINT [PK_CONCEPT_SERVICE_1] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY],
 CONSTRAINT [IX_CONCEPT_SERVICE] UNIQUE NONCLUSTERED 
(
	[id] ASC,
	[concept_id] ASC,
	[service_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[BILLABLE_CONCEPTS_SNAPSHOTS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BILLABLE_CONCEPTS_SNAPSHOTS](
	[entity_id] [bigint] NOT NULL,
	[IN_account_id] [bigint] NOT NULL,
	[IN_accounting_address] [varchar](5) NULL,
	[OUT_accounting_address] [varchar](5) NULL,
	[INint_accounting_address] [varchar](5) NOT NULL,
	[OUTint_accounting_address] [varchar](5) NOT NULL,
	[id] [bigint] IDENTITY(1,1) NOT NULL,
	[AT_start_date] [datetime2](7) NOT NULL,
	[AT_end_date] [datetime2](7) NULL,
	[AT_start_user] [bigint] NOT NULL,
	[AT_end_user] [bigint] NULL,
	[VT_start_date] [date] NOT NULL,
	[VT_end_date] [date] NULL,
	[scope_id] [int] NOT NULL,
	[tax_type] [int] NOT NULL,
 CONSTRAINT [PK_BILLABLE_CONCEPTS_SNAPSHOTS] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[BILLING_TEMP]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BILLING_TEMP](
	[issuerEnterpriseId] [bigint] NOT NULL,
	[monthEventId] [bigint] NOT NULL,
	[chargeId] [bigint] NOT NULL,
 CONSTRAINT [PK_BILLING_TEMP] PRIMARY KEY CLUSTERED 
(
	[issuerEnterpriseId] ASC,
	[monthEventId] ASC,
	[chargeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[CALENDAR]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CALENDAR](
	[id] [bigint] NOT NULL,
	[target_id] [bigint] NOT NULL,
	[start_event_date] [datetime2](7) NULL,
	[end_event_date] [datetime2](7) NULL,
	[execution_event_datetime] [date] NULL,
	[event_type] [int] NOT NULL,
	[event_text] [nvarchar](150) NOT NULL,
	[event_state] [int] NOT NULL,
	[event_value] [int] NULL,
	[event_description] [nvarchar](100) NULL,
 CONSTRAINT [PK_CALENDAR_1] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[CALENDAR_EVENT_STATES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CALENDAR_EVENT_STATES](
	[id] [int] NOT NULL,
	[description] [nchar](12) NOT NULL,
 CONSTRAINT [PK_CALENDAR_EVENT_STATES] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[CALENDAR_EVENT_TYPES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CALENDAR_EVENT_TYPES](
	[id] [int] NOT NULL,
	[description] [nchar](20) NOT NULL,
	[style_class] [varchar](20) NOT NULL,
	[owner_entity_type] [bigint] NOT NULL,
	[has_value] [bit] NOT NULL,
 CONSTRAINT [PK_CALENDAR_MILESTONE_TYPES] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[CALENDAR_JDE_STATES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CALENDAR_JDE_STATES](
	[id] [int] NOT NULL,
	[description] [nvarchar](30) NOT NULL,
 CONSTRAINT [PK_CALENDAR_GDE_STATES] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[CHARGE_TYPES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CHARGE_TYPES](
	[id] [int] NOT NULL,
	[description] [nvarchar](50) NOT NULL,
	[is_consumption] [bit] NOT NULL,
 CONSTRAINT [PK_CHARGE_TYPES] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[CHARGE_WORKFLOW_STATE]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CHARGE_WORKFLOW_STATE](
	[id] [int] NOT NULL,
	[name] [nvarchar](50) NOT NULL,
	[description] [nvarchar](150) NOT NULL,
 CONSTRAINT [PK_CHARGE_WORKFLOW_STATE] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[CHARGES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CHARGES](
	[id] [bigint] NOT NULL,
	[charge_type_id] [int] NOT NULL,
	[account_id] [bigint] NOT NULL,
	[billable_concept_id] [bigint] NOT NULL,
	[description] [nvarchar](250) NULL,
	[amount] [decimal](18, 2) NULL,
	[value_date] [date] NULL,
	[invoice_date] [date] NULL,
	[invoice_date_planned] [date] NULL,
	[register_date] [datetime2](7) NULL,
	[workflow_state] [int] NULL,
	[is_invoiced] [bit] NOT NULL,
	[is_sent_to_jde] [bit] NOT NULL,
	[budgetary_code] [int] NULL,
	[last_change_date] [datetime2](7) NULL,
	[last_change_user] [bigint] NULL,
	[scope_id] [int] NOT NULL,
	[issuer_unit_id_OLD] [bigint] NULL,
 CONSTRAINT [PK_CHARGES] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[CHARGES_BACKUP]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CHARGES_BACKUP](
	[id] [bigint] NOT NULL,
	[account_id] [bigint] NOT NULL,
	[billable_concept_id] [bigint] NOT NULL,
	[charge_type_id] [int] NOT NULL,
	[description] [nvarchar](250) NULL,
	[amount] [decimal](18, 2) NULL,
	[is_invoiced] [bit] NOT NULL,
	[issuer_unit_id_OLD] [bigint] NULL,
	[value_date] [date] NULL,
	[invoice_date] [date] NULL,
	[register_date] [datetime2](7) NULL,
	[is_sent_to_jde] [bit] NOT NULL,
	[scope_id] [int] NOT NULL,
	[workflow_state] [int] NULL,
	[last_change_date] [datetime2](7) NULL,
	[last_change_user] [bigint] NULL,
	[invoice_date_planned] [date] NULL,
	[budgetary_code] [int] NULL
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[CHARGES_DEV]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CHARGES_DEV](
	[id] [bigint] NOT NULL,
	[account_id] [bigint] NOT NULL,
	[billable_concept_id] [bigint] NOT NULL,
	[charge_type_id] [int] NOT NULL,
	[description] [nvarchar](250) NULL,
	[amount] [decimal](18, 2) NULL,
	[is_invoiced] [bit] NOT NULL,
	[issuer_unit_id_OLD] [bigint] NULL,
	[value_date] [date] NULL,
	[invoice_date] [date] NULL,
	[register_date] [datetime2](7) NULL,
	[is_sent_to_jde] [bit] NOT NULL,
	[scope_id] [int] NOT NULL,
	[workflow_state] [int] NULL,
	[last_change_date] [datetime2](7) NULL,
	[last_change_user] [bigint] NULL,
	[invoice_date_planned] [date] NULL,
	[budgetary_code] [int] NULL
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[CONCEPT_FAMILIES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CONCEPT_FAMILIES](
	[id] [bigint] NOT NULL,
	[description] [nvarchar](200) NOT NULL,
 CONSTRAINT [PK_CONCEPT_FAMILIY] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[CONCEPT_FAMILY_RELATIONSHIPS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CONCEPT_FAMILY_RELATIONSHIPS](
	[concept_family_id] [bigint] NOT NULL,
	[concept_id] [bigint] NOT NULL,
 CONSTRAINT [PK_CONCEPT_FAMILY_RELATIONSHIPS] PRIMARY KEY CLUSTERED 
(
	[concept_family_id] ASC,
	[concept_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[CONCEPTS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CONCEPTS](
	[id] [bigint] NOT NULL,
	[TT_start_date] [datetime2](7) NOT NULL,
	[TT_end_date] [datetime2](7) NULL,
	[TT_start_user] [bigint] NOT NULL,
	[TT_end_user] [bigint] NULL,
	[last_change_date] [datetime2](7) NOT NULL,
	[last_change_user] [bigint] NOT NULL,
 CONSTRAINT [PK_CONCEPTS] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[CONCEPTS_SNAPSHOTS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CONCEPTS_SNAPSHOTS](
	[entity_id] [bigint] NOT NULL,
	[description] [nvarchar](200) NULL,
	[name] [nvarchar](50) NOT NULL,
	[unit_id] [bigint] NOT NULL,
	[id] [bigint] IDENTITY(1,1) NOT NULL,
	[AT_start_date] [datetime2](7) NOT NULL,
	[AT_end_date] [datetime2](7) NULL,
	[AT_start_user] [bigint] NOT NULL,
	[AT_end_user] [bigint] NULL,
	[VT_start_date] [date] NOT NULL,
	[VT_end_date] [date] NULL,
	[scope_id] [int] NOT NULL,
 CONSTRAINT [PK_CONCEPTS_SNAPSHOTS] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[CONDITION_TYPES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CONDITION_TYPES](
	[id] [int] NOT NULL,
	[name] [varchar](10) NOT NULL,
 CONSTRAINT [PK_CONDITION_TYPES] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[CONDITIONS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CONDITIONS](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[entity_type_filter] [bigint] NOT NULL,
	[condition_type] [int] NOT NULL,
	[description] [nvarchar](250) NULL,
 CONSTRAINT [PK_CONDITIONS] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[CONSUMPTIONS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CONSUMPTIONS](
	[id] [bigint] NOT NULL,
	[amount] [decimal](18, 2) NOT NULL,
	[charge_id] [bigint] NOT NULL,
	[infoCharging] [xml] NULL,
	[issuer_unit_id] [bigint] NULL,
	[is_charged] [bit] NOT NULL,
	[scope_id] [int] NOT NULL,
	[last_change_user] [bigint] NULL,
	[last_change_date] [datetime2](7) NULL,
	[sp_rate_unit_cost] [money] NULL,
	[rate_unit_cost] [money] NULL,
	[discount_unit_cost] [money] NULL,
	[is_percentage] [bit] NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [dbo].[CONSUMPTIONS_DEV]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CONSUMPTIONS_DEV](
	[id] [bigint] NOT NULL,
	[amount] [decimal](18, 2) NOT NULL,
	[charge_id] [bigint] NOT NULL,
	[infoCharging] [xml] NULL,
	[issuer_unit_id] [bigint] NULL,
	[is_charged] [bit] NOT NULL,
	[scope_id] [int] NOT NULL,
	[last_change_user] [bigint] NULL,
	[last_change_date] [datetime2](7) NULL,
	[sp_rate_unit_cost] [money] NULL,
	[rate_unit_cost] [money] NULL,
	[discount_unit_cost] [money] NULL,
	[is_percentage] [bit] NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [dbo].[DEPARTMENTS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DEPARTMENTS](
	[id] [bigint] NOT NULL,
	[idEnterprise] [bigint] NOT NULL,
	[TT_start_date] [datetime2](7) NOT NULL,
	[TT_end_date] [datetime2](7) NULL,
	[TT_start_user] [bigint] NOT NULL,
	[TT_end_user] [bigint] NULL,
	[last_change_date] [datetime2](7) NOT NULL,
	[last_change_user] [bigint] NOT NULL,
 CONSTRAINT [PK_DEPARTMENTS] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[DEPARTMENTS_SNAPSHOTS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DEPARTMENTS_SNAPSHOTS](
	[entity_id] [bigint] NOT NULL,
	[code] [nvarchar](5) NOT NULL,
	[name] [nvarchar](100) NOT NULL,
	[hasInterDepartmentAccounting] [bit] NOT NULL,
	[id] [bigint] IDENTITY(1,1) NOT NULL,
	[AT_start_date] [datetime2](7) NOT NULL,
	[AT_end_date] [datetime2](7) NULL,
	[AT_start_user] [bigint] NOT NULL,
	[AT_end_user] [bigint] NULL,
	[VT_start_date] [date] NOT NULL,
	[VT_end_date] [date] NULL,
	[scope_id] [int] NOT NULL,
 CONSTRAINT [PK_DEPARTMENTS_SNAPSHOTS] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[DIVISIONS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DIVISIONS](
	[id] [bigint] NOT NULL,
	[TT_start_date] [datetime2](7) NOT NULL,
	[TT_end_date] [datetime2](7) NULL,
	[TT_start_user] [bigint] NOT NULL,
	[TT_end_user] [bigint] NULL,
	[last_change_date] [datetime2](7) NOT NULL,
	[last_change_user] [bigint] NOT NULL,
 CONSTRAINT [PK_DIVISIONS] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[DIVISIONS_SNAPSHOTS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DIVISIONS_SNAPSHOTS](
	[entity_id] [bigint] NOT NULL,
	[code] [nvarchar](max) NOT NULL,
	[name] [nvarchar](50) NOT NULL,
	[id] [bigint] IDENTITY(1,1) NOT NULL,
	[AT_start_date] [datetime2](7) NOT NULL,
	[AT_end_date] [datetime2](7) NULL,
	[AT_start_user] [bigint] NOT NULL,
	[AT_end_user] [bigint] NULL,
	[VT_start_date] [date] NOT NULL,
	[VT_end_date] [date] NULL,
	[scope_id] [int] NOT NULL,
 CONSTRAINT [PK_DIVISIONS_SNAPSHOTS] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [dbo].[ENTERPRISES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ENTERPRISES](
	[id] [bigint] NOT NULL,
	[TT_start_date] [datetime2](7) NOT NULL,
	[TT_end_date] [datetime2](7) NULL,
	[TT_start_user] [bigint] NOT NULL,
	[TT_end_user] [bigint] NULL,
	[last_change_date] [datetime2](7) NULL,
	[last_change_user] [bigint] NOT NULL,
 CONSTRAINT [PK_ENTERPRISE] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[ENTERPRISES_SNAPSHOTS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ENTERPRISES_SNAPSHOTS](
	[entity_id] [bigint] NOT NULL,
	[name] [nvarchar](100) NOT NULL,
	[receive_bills] [bit] NOT NULL,
	[send_bills] [bit] NOT NULL,
	[code] [nvarchar](12) NULL,
	[isExternal] [bit] NOT NULL,
	[short_name] [nvarchar](20) NULL,
	[id] [bigint] IDENTITY(1,1) NOT NULL,
	[AT_start_date] [datetime2](7) NOT NULL,
	[AT_end_date] [datetime2](7) NULL,
	[AT_start_user] [bigint] NOT NULL,
	[AT_end_user] [bigint] NULL,
	[VT_start_date] [date] NOT NULL,
	[VT_end_date] [date] NULL,
	[scope_id] [int] NOT NULL,
	[tax_client_type] [int] NOT NULL,
 CONSTRAINT [PK_ENTERPRISES_SNAPSHOTS] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[ENTERPRISES_USI_EXCEPTIONS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ENTERPRISES_USI_EXCEPTIONS](
	[enterprise_code] [nvarchar](12) NOT NULL,
	[enterprise_description] [nvarchar](100) NOT NULL,
	[type] [char](3) NULL,
 CONSTRAINT [PK_ENTERPRISES_USI_EXCEPTIONS] PRIMARY KEY CLUSTERED 
(
	[enterprise_code] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[ENTITIES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ENTITIES](
	[id] [bigint] NOT NULL,
	[entity_type_id] [bigint] NOT NULL,
	[creation_date] [datetime2](7) NOT NULL,
	[discarded_date] [datetime2](7) NULL,
	[name] [nvarchar](100) NULL,
 CONSTRAINT [PK_ENTITIES] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[ENTITY_SCOPES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ENTITY_SCOPES](
	[id] [int] NOT NULL,
	[name] [varchar](6) NOT NULL,
 CONSTRAINT [PK_ENTITY_SCOPES] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[ENTITY_TYPES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ENTITY_TYPES](
	[id] [bigint] NOT NULL,
	[name] [nvarchar](50) NOT NULL,
	[description] [nvarchar](150) NULL,
	[table_name] [nvarchar](50) NULL,
	[isVTcalcDependent] [bit] NOT NULL,
	[alias] [nvarchar](50) NULL,
 CONSTRAINT [PK_ENTITY_TYPE] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[ERRORS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ERRORS](
	[error_id] [bigint] IDENTITY(1,1) NOT NULL,
	[entity_type_id] [bigint] NOT NULL,
	[process_id] [bigint] NOT NULL,
	[date] [datetime] NOT NULL,
	[original_data] [nvarchar](50) NULL,
	[original_data_system] [bigint] NOT NULL,
	[error_msg] [nvarchar](1000) NULL,
	[isOK] [bit] NOT NULL,
 CONSTRAINT [PK_ERRORS] PRIMARY KEY CLUSTERED 
(
	[error_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[EXTERNAL_SYSTEM_EQUIVALENCES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[EXTERNAL_SYSTEM_EQUIVALENCES](
	[id] [bigint] NOT NULL,
	[entity_type_id] [bigint] NOT NULL,
	[external_system_id] [bigint] NOT NULL,
	[external_id] [nvarchar](50) NOT NULL,
	[date] [datetime] NOT NULL,
 CONSTRAINT [PK_EXTERNAL_SYSTEM_EQUIVALENCES] PRIMARY KEY CLUSTERED 
(
	[id] ASC,
	[entity_type_id] ASC,
	[external_system_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[ID_TABLE]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ID_TABLE](
	[id] [bigint] IDENTITY(1,1) NOT NULL,
 CONSTRAINT [PK_ID_TABLE] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[IMPORT_ABSIS_ENTITY_PROPERTY_TYPES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[IMPORT_ABSIS_ENTITY_PROPERTY_TYPES](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[name] [nvarchar](50) NOT NULL,
	[description] [nvarchar](100) NULL,
	[with_equivalent_value] [bit] NOT NULL,
	[equivalence_entity_type] [bigint] NULL,
 CONSTRAINT [PK_IMPORT_ABSIS_ENTITY_PROPERTY_TYPES] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[IMPORT_ACTION]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[IMPORT_ACTION](
	[id] [bigint] NOT NULL,
	[name] [nvarchar](150) NULL,
	[exec_date] [datetime2](7) NULL,
	[exec_user_id] [bigint] NOT NULL,
	[issuer_id] [bigint] NOT NULL,
	[importer_id] [bigint] NOT NULL,
	[value_date] [date] NOT NULL,
	[file_path] [nvarchar](200) NULL,
 CONSTRAINT [PK_IMPORT_ACTION] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[IMPORT_ACTION_AUDIT]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[IMPORT_ACTION_AUDIT](
	[import_action_id] [bigint] NOT NULL,
	[absis_entity_id] [bigint] NOT NULL,
	[absis_type] [char](2) NOT NULL,
 CONSTRAINT [PK_IMPORT_ACTION_AUDIT] PRIMARY KEY CLUSTERED 
(
	[absis_entity_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[IMPORT_COLUMN_DEFINITION_TYPES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[IMPORT_COLUMN_DEFINITION_TYPES](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[name] [nvarchar](50) NOT NULL,
 CONSTRAINT [PK_IMPORT_COLUMN_DEFINITION_TYPES] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[IMPORT_ENTITIES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[IMPORT_ENTITIES](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[import_id] [bigint] NOT NULL,
	[entity_type_id] [bigint] NOT NULL,
	[name] [nvarchar](100) NOT NULL,
	[column_name] [nvarchar](50) NULL,
	[table_name] [nvarchar](50) NULL,
 CONSTRAINT [PK_IMPORT_ENTITIES] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[IMPORT_ENTITY_DEFINITIONS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[IMPORT_ENTITY_DEFINITIONS](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[import_entity_id] [int] NOT NULL,
	[column_name] [nvarchar](200) NULL,
	[column_definition] [nvarchar](200) NOT NULL,
	[column_definition_type_id] [int] NOT NULL,
	[absis_property_id] [int] NOT NULL,
	[transform_operation] [varchar](50) NULL,
 CONSTRAINT [PK_IMPORT_ENTITY_DEFINITIONS] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[IMPORT_EQUIVALENCES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[IMPORT_EQUIVALENCES](
	[absis_id] [bigint] NOT NULL,
	[external_id] [nvarchar](100) NOT NULL,
	[import_entity_definition_id] [int] NOT NULL,
	[absis_name] [nvarchar](100) NULL,
	[id] [bigint] IDENTITY(1,1) NOT NULL,
 CONSTRAINT [PK_IMPORT_EQUIVALENCES] PRIMARY KEY CLUSTERED 
(
	[absis_id] ASC,
	[external_id] ASC,
	[import_entity_definition_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[IMPORT_HUB]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[IMPORT_HUB](
	[id] [bigint] NOT NULL,
	[name] [nvarchar](150) NULL,
	[exec_date] [datetime2](7) NULL,
	[exec_user_id] [bigint] NOT NULL,
	[value_date] [date] NOT NULL,
	[mes] [int] NOT NULL,
	[anyo] [int] NOT NULL,
 CONSTRAINT [PK_IMPORT_HUB] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[IMPORT_HUB_AUDIT]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[IMPORT_HUB_AUDIT](
	[import_action_id] [bigint] NOT NULL,
	[absis_entity_id] [bigint] NOT NULL,
 CONSTRAINT [PK_IMPORT_HUB_AUDIT] PRIMARY KEY CLUSTERED 
(
	[absis_entity_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[IMPORT_TABLES_COLUMN_DEFINITION]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[IMPORT_TABLES_COLUMN_DEFINITION](
	[import_table_definition_id] [int] NOT NULL,
	[candidate_column_name] [nvarchar](50) NOT NULL,
	[candidate_column_name_alias] [nvarchar](50) NOT NULL,
 CONSTRAINT [PK_IMPORT_TABLES_COLUMN_DEFINITION] PRIMARY KEY CLUSTERED 
(
	[import_table_definition_id] ASC,
	[candidate_column_name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[IMPORT_TABLES_DEFINITIONS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[IMPORT_TABLES_DEFINITIONS](
	[entity_type_id] [bigint] NOT NULL,
	[id] [int] NOT NULL,
	[table_name] [nvarchar](50) NOT NULL,
	[import_id] [bigint] NULL,
 CONSTRAINT [PK_IMPORT_TABLES_DEFINITIONS] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[IMPORT_TYPES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[IMPORT_TYPES](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[name] [nvarchar](50) NOT NULL,
 CONSTRAINT [PK_IMPORT_TYPES] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[IMPORTS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[IMPORTS](
	[id] [bigint] NOT NULL,
	[name] [nvarchar](100) NOT NULL,
	[import_type_id] [int] NOT NULL,
	[created_by] [bigint] NOT NULL,
	[created_date] [datetime2](7) NOT NULL,
	[last_change_by] [bigint] NOT NULL,
	[last_change_date] [datetime2](7) NOT NULL,
	[mailto] [nvarchar](150) NOT NULL,
	[closed_date] [datetime2](7) NULL,
 CONSTRAINT [PK_IMPORTS] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[IMPORTS_USERS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[IMPORTS_USERS](
	[user_id] [bigint] NOT NULL,
	[import_id] [bigint] NOT NULL,
 CONSTRAINT [PK_IMPORTS_USERS] PRIMARY KEY CLUSTERED 
(
	[user_id] ASC,
	[import_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[ISSUER_UNITS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ISSUER_UNITS](
	[id] [bigint] NOT NULL,
	[enterprise_id] [bigint] NOT NULL,
	[TT_start_date] [datetime2](7) NOT NULL,
	[TT_end_date] [datetime2](7) NULL,
	[TT_start_user] [bigint] NOT NULL,
	[TT_end_user] [bigint] NULL,
	[last_change_date] [datetime2](7) NOT NULL,
	[last_change_user] [bigint] NOT NULL,
 CONSTRAINT [PK_ISSUER_UNITS] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[ISSUER_UNITS_SNAPSHOTS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ISSUER_UNITS_SNAPSHOTS](
	[entity_id] [bigint] NOT NULL,
	[name] [nvarchar](100) NOT NULL,
	[code] [nvarchar](5) NOT NULL,
	[generate_new_bill] [bit] NOT NULL,
	[id] [bigint] IDENTITY(1,1) NOT NULL,
	[AT_start_date] [datetime2](7) NOT NULL,
	[AT_end_date] [datetime2](7) NULL,
	[AT_start_user] [bigint] NOT NULL,
	[AT_end_user] [bigint] NULL,
	[VT_start_date] [date] NOT NULL,
	[VT_end_date] [date] NULL,
	[scope_id] [int] NOT NULL,
 CONSTRAINT [PK_ISSUER_UNITS_SNAPSHOTS] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[NEWS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[NEWS](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[title] [nvarchar](80) NOT NULL,
	[resume] [nvarchar](255) NOT NULL,
	[titleLink] [nvarchar](50) NULL,
	[urlLink] [nvarchar](100) NULL,
	[date] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_NEWS] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[NOTIFICATION_TYPES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[NOTIFICATION_TYPES](
	[id] [int] NOT NULL,
	[description] [nchar](15) NOT NULL,
	[icon_name] [nvarchar](50) NOT NULL,
 CONSTRAINT [PK_NOTIFICATION_TYPES] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[NOTIFICATIONS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[NOTIFICATIONS](
	[id] [bigint] IDENTITY(1,1) NOT NULL,
	[teaser] [nvarchar](150) NOT NULL,
	[text] [nvarchar](150) NOT NULL,
	[date] [datetime2](7) NULL,
	[type] [int] NOT NULL,
 CONSTRAINT [PK_NOTIFICATIONS] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[PERIOD_GROUPING]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PERIOD_GROUPING](
	[id] [bigint] NOT NULL,
	[description] [nvarchar](150) NULL,
	[start_date] [datetime2](7) NULL,
	[end_date] [datetime2](7) NULL,
	[period_type] [int] NOT NULL,
	[value_date] [int] NOT NULL,
 CONSTRAINT [PK_PERIOD_GROUPING] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[PERIOD_GROUPING_RELATIONSHIPS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PERIOD_GROUPING_RELATIONSHIPS](
	[id_group] [bigint] NOT NULL,
	[id_charge] [bigint] NOT NULL,
 CONSTRAINT [PK_PERIOD_GROUPING_RELATIONSHIPS] PRIMARY KEY CLUSTERED 
(
	[id_group] ASC,
	[id_charge] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[PERIOD_TYPES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PERIOD_TYPES](
	[id] [int] NOT NULL,
	[name] [nvarchar](20) NOT NULL,
 CONSTRAINT [PK_PERIOD_TYPES] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[PERMISSION_TYPES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PERMISSION_TYPES](
	[id] [int] NOT NULL,
	[name] [varchar](50) NULL,
	[description] [varchar](250) NULL,
 CONSTRAINT [PK_PERMISSION_TYPES] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[PERMISSIONS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PERMISSIONS](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[name] [nvarchar](50) NOT NULL,
	[entity_type] [bigint] NOT NULL,
	[permission_type] [int] NOT NULL,
 CONSTRAINT [PK_PERMISSIONS] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[PROCESS_ACTIVITY]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PROCESS_ACTIVITY](
	[id] [varchar](18) NOT NULL,
	[process_id] [bigint] NOT NULL,
	[process_state_id] [int] NOT NULL,
	[percentage_performed] [int] NULL,
	[last_message] [nvarchar](350) NULL,
	[process_execution_start_date] [datetime2](7) NOT NULL,
	[process_execution_end_date] [datetime2](7) NULL,
	[owner_id] [bigint] NULL,
	[process_info] [nvarchar](250) NULL,
	[owner_extended_id] [bigint] NULL,
	[pre_process_activity_id] [varchar](18) NULL,
 CONSTRAINT [PK_PROCESS_ACTIVITY] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[PROCESS_STATES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PROCESS_STATES](
	[id] [int] NOT NULL,
	[process_state_name] [varchar](50) NOT NULL,
 CONSTRAINT [PK_PROCESS_STATES] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[PROCESSES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PROCESSES](
	[id] [bigint] NOT NULL,
	[description] [nvarchar](200) NOT NULL,
	[system_id] [bigint] NOT NULL,
	[key_code] [nvarchar](6) NULL,
	[name] [nvarchar](50) NULL,
	[TT_start_date] [datetime2](7) NOT NULL,
	[TT_end_date] [datetime2](7) NULL,
	[TT_start_user] [bigint] NOT NULL,
	[TT_end_user] [bigint] NULL,
	[last_change_date] [datetime2](7) NOT NULL,
	[last_change_user] [bigint] NOT NULL,
 CONSTRAINT [PK_PROCESS] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[RATES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[RATES](
	[id] [bigint] NOT NULL,
	[billable_concept_id] [bigint] NOT NULL,
	[TT_start_date] [datetime2](7) NOT NULL,
	[TT_end_date] [datetime2](7) NULL,
	[TT_start_user] [bigint] NOT NULL,
	[TT_end_user] [bigint] NULL,
	[last_change_date] [datetime2](7) NOT NULL,
	[last_change_user] [bigint] NOT NULL,
 CONSTRAINT [PK_RATE] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[RATES_SNAPSHOTS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[RATES_SNAPSHOTS](
	[entity_id] [bigint] NOT NULL,
	[unit_cost] [money] NOT NULL,
	[id] [bigint] IDENTITY(1,1) NOT NULL,
	[AT_start_date] [datetime2](7) NOT NULL,
	[AT_end_date] [datetime2](7) NULL,
	[AT_start_user] [bigint] NOT NULL,
	[AT_end_user] [bigint] NULL,
	[VT_start_date] [date] NOT NULL,
	[VT_end_date] [date] NULL,
	[scope_id] [int] NOT NULL,
 CONSTRAINT [PK_RATES_SNAPSHOTS] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[ROLE_CONDITION_VALUES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ROLE_CONDITION_VALUES](
	[role] [int] NOT NULL,
	[condition] [int] NOT NULL,
	[value] [nvarchar](max) NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [dbo].[ROLE_PERMISSIONS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ROLE_PERMISSIONS](
	[role] [int] NOT NULL,
	[permission] [int] NOT NULL,
	[condition] [int] NULL,
	[entity_scope] [int] NOT NULL,
 CONSTRAINT [PK_ROLE_PERMISSIONS] PRIMARY KEY CLUSTERED 
(
	[role] ASC,
	[permission] ASC,
	[entity_scope] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[ROLE_TYPES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ROLE_TYPES](
	[id] [int] NOT NULL,
	[description] [nvarchar](100) NOT NULL,
	[name] [nchar](20) NOT NULL,
 CONSTRAINT [PK_ROLE_TYPES] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[ROLES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ROLES](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[name] [nvarchar](40) NOT NULL,
	[description] [nvarchar](250) NOT NULL,
	[type] [int] NOT NULL,
 CONSTRAINT [PK_ROLES] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[SCOPES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SCOPES](
	[id] [int] NOT NULL,
	[name] [nvarchar](50) NOT NULL,
 CONSTRAINT [PK_SCOPES] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[SEARCH_BASIC]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SEARCH_BASIC](
	[id] [bigint] NOT NULL,
	[type_id] [bigint] NOT NULL,
	[name] [nvarchar](50) NOT NULL,
	[code] [nvarchar](12) NOT NULL,
	[all_text] [ntext] NOT NULL,
 CONSTRAINT [PK_SEARCH_BASIC] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [dbo].[SERVICES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SERVICES](
	[id] [bigint] NOT NULL,
	[TT_start_date] [datetime2](7) NOT NULL,
	[TT_end_date] [datetime2](7) NULL,
	[TT_start_user] [bigint] NOT NULL,
	[TT_end_user] [bigint] NULL,
	[last_change_date] [datetime2](7) NOT NULL,
	[last_change_user] [bigint] NOT NULL,
 CONSTRAINT [PK_SERVICES] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[SERVICES_SNAPSHOTS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SERVICES_SNAPSHOTS](
	[entity_id] [bigint] NOT NULL,
	[description] [nvarchar](200) NULL,
	[name] [nvarchar](50) NOT NULL,
	[generate_new_bill] [bit] NOT NULL,
	[issuer_unit_id] [bigint] NOT NULL,
	[id] [bigint] IDENTITY(1,1) NOT NULL,
	[AT_start_date] [datetime2](7) NOT NULL,
	[AT_end_date] [datetime2](7) NULL,
	[AT_start_user] [bigint] NOT NULL,
	[AT_end_user] [bigint] NULL,
	[VT_start_date] [date] NOT NULL,
	[VT_end_date] [date] NULL,
	[scope_id] [int] NOT NULL,
 CONSTRAINT [PK_SERVICES_SNAPSHOTS] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[SPECIAL_RATEDISCOUNT_ACCOUNTS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SPECIAL_RATEDISCOUNT_ACCOUNTS](
	[id_special_ratediscount] [bigint] NOT NULL,
	[id_account] [bigint] NOT NULL,
	[id] [bigint] IDENTITY(1,1) NOT NULL,
	[AT_start_date] [datetime2](7) NOT NULL,
	[AT_end_date] [datetime2](7) NULL,
	[AT_start_user] [bigint] NOT NULL,
	[AT_end_user] [bigint] NULL,
	[VT_start_date] [date] NOT NULL,
	[VT_end_date] [date] NULL,
	[scope_id] [int] NOT NULL,
	[create_date] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_SPECIAL_RATEDISCOUNT_ACCOUNTS] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[SPECIAL_RATESDISCOUNTS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SPECIAL_RATESDISCOUNTS](
	[id] [bigint] NOT NULL,
	[billable_concept_id] [bigint] NOT NULL,
	[TT_start_date] [datetime2](7) NOT NULL,
	[TT_end_date] [datetime2](7) NULL,
	[TT_start_user] [bigint] NOT NULL,
	[TT_end_user] [bigint] NULL,
	[last_change_date] [datetime2](7) NULL,
	[last_change_user] [bigint] NOT NULL,
 CONSTRAINT [PK_SPECIAL_RATESDISCOUNTS] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[SPECIAL_RATESDISCOUNTS_SNAPSHOTS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SPECIAL_RATESDISCOUNTS_SNAPSHOTS](
	[entity_id] [bigint] NOT NULL,
	[sequence] [int] NOT NULL,
	[description] [nvarchar](50) NOT NULL,
	[unit_cost] [money] NOT NULL,
	[is_percentage] [bit] NOT NULL,
	[is_discount] [bit] NOT NULL,
	[is_common] [bit] NOT NULL,
	[id] [bigint] IDENTITY(1,1) NOT NULL,
	[AT_start_date] [datetime2](7) NOT NULL,
	[AT_end_date] [datetime2](7) NULL,
	[AT_start_user] [bigint] NOT NULL,
	[AT_end_user] [bigint] NULL,
	[VT_start_date] [date] NOT NULL,
	[VT_end_date] [date] NULL,
	[scope_id] [int] NOT NULL,
 CONSTRAINT [PK_SPECIAL_RATESDISCOUNTS_SNAPSHOTS] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[SUBLEDGERS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SUBLEDGERS](
	[id] [bigint] NOT NULL,
	[account_id] [bigint] NOT NULL,
	[billable_concept_id] [bigint] NOT NULL,
	[in_subledger] [nvarchar](8) NULL,
	[in_subledger_type] [char](1) NULL,
	[out_subledger] [nvarchar](8) NULL,
	[out_subledger_type] [char](1) NULL,
 CONSTRAINT [PK_SUBLEDGERS] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[SYSTEM_MODULES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SYSTEM_MODULES](
	[id] [bigint] NOT NULL,
	[systemId] [bigint] NOT NULL,
	[name] [nvarchar](50) NOT NULL,
	[sequence] [int] NOT NULL,
	[description] [nvarchar](350) NULL,
	[imageName] [nvarchar](50) NULL,
	[AT_start_date] [datetime2](7) NOT NULL,
	[AT_end_date] [datetime2](7) NULL,
	[AT_start_user] [bigint] NOT NULL,
	[AT_end_user] [bigint] NULL,
	[VT_start_date] [date] NOT NULL,
	[VT_end_date] [date] NULL,
	[scope_id] [int] NOT NULL,
	[nickName] [nvarchar](50) NULL,
	[icon_name] [varchar](50) NULL,
 CONSTRAINT [PK_SYSTEM_MENUS] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[SYSTEMS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SYSTEMS](
	[id] [bigint] NOT NULL,
	[name] [nvarchar](100) NOT NULL,
	[description] [nvarchar](200) NULL,
	[isExternal] [bit] NOT NULL,
	[isWebAccesible] [bit] NOT NULL,
	[nickName] [nvarchar](50) NULL,
	[AT_start_date] [datetime2](7) NOT NULL,
	[AT_end_date] [datetime2](7) NULL,
	[AT_start_user] [bigint] NOT NULL,
	[AT_end_user] [bigint] NULL,
	[VT_start_date] [date] NOT NULL,
	[VT_end_date] [date] NULL,
	[scope_id] [int] NOT NULL,
	[sequence] [int] NULL,
	[icon_name] [varchar](50) NULL,
 CONSTRAINT [PK_SYSTEMS] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[TAX_AREAS]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TAX_AREAS](
	[id] [int] NOT NULL,
	[name] [nvarchar](50) NOT NULL,
	[description] [nvarchar](150) NOT NULL,
	[jde_label] [nvarchar](10) NULL,
	[tax_type_id] [int] NOT NULL,
	[tax_client_type_id] [int] NOT NULL,
	[bill_document_type_id] [int] NOT NULL,
	[label] [nvarchar](50) NULL,
 CONSTRAINT [PK_TAX_AREAS] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[TAX_CLIENT_TYPES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TAX_CLIENT_TYPES](
	[id] [int] NOT NULL,
	[name] [nvarchar](50) NOT NULL,
	[description] [nvarchar](150) NOT NULL,
 CONSTRAINT [PK_TAX_CLIENT_TYPES] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[TAX_TYPES]    Script Date: 03/08/2018 14:19:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TAX_TYPES](
	[id] [int] NOT NULL,
	[name] [nvarchar](40) NOT NULL,
	[description] [nvarchar](150) NOT NULL,
 CONSTRAINT [PK_TAX_TYPES] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[TEMP_STAR_CENTROS]    Script Date: 03/08/2018 14:19:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TEMP_STAR_CENTROS](
	[ID_CENTRO_STAR] [nchar](10) NULL,
	[ID_CENTRO_ABSIS] [bigint] NULL
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[TEMP_STAR_CONCEPTS]    Script Date: 03/08/2018 14:19:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TEMP_STAR_CONCEPTS](
	[ID_CONCEPTO_STAR] [int] NOT NULL,
	[DESCRIPCION] [nvarchar](200) NOT NULL,
	[UNIDAD] [nchar](10) NOT NULL,
	[ID_SERVICIO_STAR] [int] NOT NULL,
	[ID_CONCEPTO_ABSIS] [bigint] NULL
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[TEMP_STAR_SERVICES]    Script Date: 03/08/2018 14:19:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TEMP_STAR_SERVICES](
	[ID_SERVICIO_STAR] [int] NOT NULL,
	[DESCRIPCION] [nvarchar](200) NOT NULL,
	[UNIDAD_EMISORA] [nchar](10) NOT NULL,
	[CENTRO_INGRESO] [nchar](10) NOT NULL,
	[ID_SERVICIO_ABSIS] [bigint] NULL
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[TEMP_STAR_UNITS]    Script Date: 03/08/2018 14:19:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TEMP_STAR_UNITS](
	[ID_UNIDAD_STAR] [nchar](10) NULL,
	[ID_UNIDAD_ABSIS] [bigint] NULL
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[TICKET]    Script Date: 03/08/2018 14:19:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TICKET](
	[ticket_value] [nvarchar](100) NOT NULL,
	[user_id] [bigint] NOT NULL,
	[expiration_minutes] [int] NOT NULL,
	[creation_datetime] [datetime] NOT NULL,
 CONSTRAINT [PK_TICKET] PRIMARY KEY CLUSTERED 
(
	[ticket_value] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[UNITS]    Script Date: 03/08/2018 14:19:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[UNITS](
	[id] [bigint] NOT NULL,
	[name] [nvarchar](20) NOT NULL,
	[symbol] [nvarchar](11) NOT NULL,
	[consumable] [bit] NOT NULL,
 CONSTRAINT [PK_UNITS] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[USER_CONDITION_VALUES]    Script Date: 03/08/2018 14:19:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[USER_CONDITION_VALUES](
	[user] [bigint] NOT NULL,
	[condition] [int] NOT NULL,
	[value] [nchar](200) NOT NULL,
 CONSTRAINT [PK_USER_CONDITION_VALUES] PRIMARY KEY CLUSTERED 
(
	[user] ASC,
	[condition] ASC,
	[value] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[USER_NOTIFICATIONS]    Script Date: 03/08/2018 14:19:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[USER_NOTIFICATIONS](
	[user] [bigint] NOT NULL,
	[notification] [bigint] NOT NULL,
	[seen] [bit] NOT NULL,
 CONSTRAINT [PK_USER_NOTIFICATIONS] PRIMARY KEY CLUSTERED 
(
	[user] ASC,
	[notification] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[USER_ROLES]    Script Date: 03/08/2018 14:19:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[USER_ROLES](
	[user] [bigint] NOT NULL,
	[role] [int] NOT NULL,
 CONSTRAINT [PK_USER_ROLES] PRIMARY KEY CLUSTERED 
(
	[user] ASC,
	[role] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[USER_SHORTCUTS]    Script Date: 03/08/2018 14:19:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[USER_SHORTCUTS](
	[user] [bigint] NOT NULL,
	[path] [nvarchar](max) NOT NULL,
	[sequence] [int] NOT NULL,
	[icon_name] [nchar](30) NULL,
	[title] [nvarchar](15) NULL,
 CONSTRAINT [PK_USER_SHORTCUTS] PRIMARY KEY CLUSTERED 
(
	[user] ASC,
	[sequence] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [dbo].[USERS]    Script Date: 03/08/2018 14:19:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[USERS](
	[id] [bigint] NOT NULL,
	[login] [varchar](50) NOT NULL,
	[password] [varchar](100) NOT NULL,
	[TT_start_date] [datetime2](7) NOT NULL,
	[TT_end_date] [datetime2](7) NULL,
	[TT_start_user] [bigint] NOT NULL,
	[TT_end_user] [bigint] NULL,
	[last_change_date] [datetime2](7) NOT NULL,
	[last_change_user] [bigint] NOT NULL,
 CONSTRAINT [PK_USERS] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[USERS_ONLINE]    Script Date: 03/08/2018 14:19:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[USERS_ONLINE](
	[user_id] [bigint] NOT NULL,
	[date_time] [datetime] NOT NULL,
	[browser] [nvarchar](25) NOT NULL,
 CONSTRAINT [PK_USERS_ONLINE] PRIMARY KEY CLUSTERED 
(
	[user_id] ASC,
	[browser] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[USERS_SNAPSHOTS]    Script Date: 03/08/2018 14:19:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[USERS_SNAPSHOTS](
	[id] [bigint] IDENTITY(1,1) NOT NULL,
	[entity_id] [bigint] NOT NULL,
	[name] [varchar](50) NULL,
	[mail] [varchar](70) NULL,
	[image_name] [varchar](25) NULL,
	[description] [varchar](50) NULL,
	[AT_start_date] [datetime2](7) NOT NULL,
	[AT_end_date] [datetime2](7) NULL,
	[AT_start_user] [bigint] NOT NULL,
	[AT_end_user] [bigint] NULL,
	[VT_start_date] [date] NOT NULL,
	[VT_end_date] [date] NULL,
	[scope_id] [int] NOT NULL,
 CONSTRAINT [PK_USERS_SNAPSHOTS] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  View [dbo].[APP_CLIENT_ENTERPRISES_WITHOUT_BILL_CLIENT_DEFINITION]    Script Date: 03/08/2018 14:19:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[APP_CLIENT_ENTERPRISES_WITHOUT_BILL_CLIENT_DEFINITION]
AS
SELECT        client_ent_id, client_ent_code, client_ent_name, issuer_ent_id, issuer_ent_code, issuer_ent_name
FROM            (SELECT        ENT_CLIENTE.id AS client_ent_id, ENT_CLIENTE.code AS client_ent_code, ENT_CLIENTE.name AS client_ent_name, ENT_EMISOR.id AS issuer_ent_id, ENT_EMISOR.code AS issuer_ent_code, 
                                                    ENT_EMISOR.name AS issuer_ent_name
                          FROM            (SELECT        ENT.id, ENT_SNS.code, ENT_SNS.name
                                                    FROM            dbo.ENTERPRISES AS ENT INNER JOIN
                                                                              dbo.ENTERPRISES_SNAPSHOTS AS ENT_SNS ON ENT_SNS.entity_id = ENT.id
                                                    WHERE        (ENT.TT_start_date < GETDATE()) AND (ENT.TT_end_date >= GETDATE() OR
                                                                              ENT.TT_end_date IS NULL) AND (ENT_SNS.AT_start_date < GETDATE()) AND (ENT_SNS.AT_end_date >= GETDATE() OR
                                                                              ENT_SNS.AT_end_date IS NULL) AND (ENT_SNS.receive_bills = 1)) AS ENT_CLIENTE LEFT OUTER JOIN
                                                        (SELECT        ENT.id, ENT_SNS.code, ENT_SNS.name
                                                          FROM            dbo.ENTERPRISES AS ENT INNER JOIN
                                                                                    dbo.ENTERPRISES_SNAPSHOTS AS ENT_SNS ON ENT_SNS.entity_id = ENT.id
                                                          WHERE        (ENT.TT_start_date < GETDATE()) AND (ENT.TT_end_date >= GETDATE() OR
                                                                                    ENT.TT_end_date IS NULL) AND (ENT_SNS.AT_start_date < GETDATE()) AND (ENT_SNS.AT_end_date >= GETDATE() OR
                                                                                    ENT_SNS.AT_end_date IS NULL) AND (ENT_SNS.send_bills = 1)) AS ENT_EMISOR ON ENT_CLIENTE.id <> ENT_EMISOR.id OR ENT_CLIENTE.id = ENT_EMISOR.id) AS T
WHERE        (NOT EXISTS
                             (SELECT        clientEnterpriseId, issuerEnterpriseId
                               FROM            dbo.BILL_CLIENTS
                               WHERE        (T.client_ent_id = clientEnterpriseId) AND (T.issuer_ent_id = issuerEnterpriseId) AND (TT_start_date < GETDATE()) AND (TT_end_date >= GETDATE() OR
                                                         TT_end_date IS NULL)
                               GROUP BY clientEnterpriseId, issuerEnterpriseId))


GO
/****** Object:  View [dbo].[APP_CLIENTS_WITHOUT_BILL_CLIENT_DEFINITION]    Script Date: 03/08/2018 14:19:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[APP_CLIENTS_WITHOUT_BILL_CLIENT_DEFINITION]
AS

-- ***************************************************************************************************************************************************
-- ************************************ DEPT o ACCOUNTS SENSE DEFINICIÓ A CLIENT FACTURA ************************************************
-- ***************************************************************************************************************************************************

-- **** Query per detectar les relacions DEPARTMENT_CLIENT - IU pendents  ****
SELECT * FROM
(
-- Departaments client actius d'empreses actives
SELECT DP.id AS client_id, DP_SNS.code as client_code, DP_SNS.name as client_name , 'DEPART.' AS client_type, 5 AS client_type_id,
DP.idEnterprise AS client_enterprise_id, ENT_SNS.code AS client_enterprise_code,ENT_SNS.name AS client_enterprise_name
FROM DEPARTMENTS AS DP
INNER JOIN DEPARTMENTS_SNAPSHOTS AS DP_SNS ON DP.id=DP_SNS.entity_id
INNER JOIN ENTERPRISES_SNAPSHOTS AS ENT_SNS ON ENT_SNS.entity_id =DP.idEnterprise
WHERE (DP.TT_start_date < GETDATE()) AND (DP.TT_end_date >= GETDATE() OR DP.TT_end_date IS NULL) 
   AND (DP_SNS.AT_start_date < GETDATE()) AND (DP_SNS.AT_end_date >= GETDATE() OR DP_SNS.AT_end_date IS NULL) 
   AND (ENT_SNS.AT_start_date < GETDATE()) AND (ENT_SNS.AT_end_date >= GETDATE() OR ENT_SNS.AT_end_date IS NULL)
   AND DP.idEnterprise IN 
   (-- Empresas cliente activas
      SELECT ENT.id FROM dbo.ENTERPRISES AS ENT INNER JOIN
      dbo.ENTERPRISES_SNAPSHOTS AS ENT_SNS ON ENT_SNS.entity_id = ENT.id
      WHERE (ENT.TT_start_date < GETDATE()) AND (ENT.TT_end_date >= GETDATE() OR
         ENT.TT_end_date IS NULL) AND (ENT_SNS.AT_start_date < GETDATE()) 
         AND (ENT_SNS.AT_end_date >= GETDATE() OR ENT_SNS.AT_end_date IS NULL) 
         AND (ENT_SNS.receive_bills = 1))
) CLIENT_DEPS
CROSS JOIN
(
-- Unitats emissores actives d'empreses emissores actives
SELECT IU.id AS issuer_unit_id, IU_SNS.code AS issuer_unit_code, IU_SNS.name AS issuer_unit_name, 
   IU.enterprise_id AS issuer_enterprise_id, ENT_SNS.code AS issuer_enterprise_code,ENT_SNS.name AS issuer_enterprise_name FROM ISSUER_UNITS AS IU
   INNER JOIN ISSUER_UNITS_SNAPSHOTS AS IU_SNS ON IU.id = IU_SNS.entity_id
   INNER JOIN ENTERPRISES_SNAPSHOTS AS ENT_SNS ON ENT_SNS.entity_id =IU.enterprise_id
   WHERE (IU.TT_start_date < GETDATE()) AND (IU.TT_end_date >= GETDATE() OR IU.TT_end_date IS NULL) 
      AND (IU_SNS.AT_start_date < GETDATE()) AND (IU_SNS.AT_end_date >= GETDATE() OR IU_SNS.AT_end_date IS NULL) 
      AND (ENT_SNS.AT_start_date < GETDATE()) AND (ENT_SNS.AT_end_date >= GETDATE() OR ENT_SNS.AT_end_date IS NULL)  
      AND IU.enterprise_id IN 
         (-- Empresas emissores activas
            SELECT ENT.id FROM dbo.ENTERPRISES AS ENT INNER JOIN
            dbo.ENTERPRISES_SNAPSHOTS AS ENT_SNS ON ENT_SNS.entity_id = ENT.id
            WHERE (ENT.TT_start_date < GETDATE()) AND (ENT.TT_end_date >= GETDATE() OR ENT.TT_end_date IS NULL) 
               AND (ENT_SNS.AT_start_date < GETDATE()) 
               AND (ENT_SNS.AT_end_date >= GETDATE() OR ENT_SNS.AT_end_date IS NULL) AND (ENT_SNS.send_bills = 1))
) IUS
WHERE
NOT EXISTS
(
-- Clients factura tipus empresa-empresa i detall Unitats Emissores-Clients
SELECT BM.clientId,BM.clientEntityType,BM.issuerUnitId
  FROM [ABSIS2].[dbo].[BILL_CLIENTS] AS BC
  INNER JOIN BILL_MERGES AS BM ON BM.billClientId = BC.id
  WHERE client_id = BM.clientId AND issuer_unit_id=BM.issuerUnitId 
  AND BM.clientEntityType = 5
  AND BC.TT_start_date < GETDATE() and (BC.TT_end_date >= GETDATE() OR BC.TT_end_date IS NULL)
  AND BM.TT_start_date < GETDATE() and (BM.TT_end_date >= GETDATE() OR BM.TT_end_date IS NULL)
)


UNION


-- **** Query per detectar les relacions ACCOUN_CLIENT - IU pendents  ****
SELECT *
FROM
(
-- Centres orfes client actius d'empreses actives
SELECT AC.id AS client_id, AC_SNS.code as client_code, AC_SNS.name as client_name , 'CENTRO' AS client_type, 6 AS client_type_id,
AC.enterprise_id AS client_enterprise_id, ENT_SNS.code AS client_enterprise_code,ENT_SNS.name AS client_enterprise_name
FROM ACCOUNTS AS AC
INNER JOIN ACCOUNTS_SNAPSHOTS AS AC_SNS ON AC.id=AC_SNS.entity_id
INNER JOIN ENTERPRISES_SNAPSHOTS AS ENT_SNS ON ENT_SNS.entity_id =AC.enterprise_id
WHERE (AC.TT_start_date < GETDATE()) AND (AC.TT_end_date >= GETDATE() OR AC.TT_end_date IS NULL) 
   AND (AC_SNS.AT_start_date < GETDATE()) AND (AC_SNS.AT_end_date >= GETDATE() OR AC_SNS.AT_end_date IS NULL) 
   AND (ENT_SNS.AT_start_date < GETDATE()) AND (ENT_SNS.AT_end_date >= GETDATE() OR ENT_SNS.AT_end_date IS NULL)
   AND AC_SNS.department_id IS NULL
   AND AC.enterprise_id IN 
   (-- Empresas cliente activas
      SELECT ENT.id FROM dbo.ENTERPRISES AS ENT INNER JOIN
      dbo.ENTERPRISES_SNAPSHOTS AS ENT_SNS ON ENT_SNS.entity_id = ENT.id
      WHERE (ENT.TT_start_date < GETDATE()) AND (ENT.TT_end_date >= GETDATE() OR
         ENT.TT_end_date IS NULL) AND (ENT_SNS.AT_start_date < GETDATE()) 
         AND (ENT_SNS.AT_end_date >= GETDATE() OR ENT_SNS.AT_end_date IS NULL) 
         AND (ENT_SNS.receive_bills = 1))
) CLIENT_ACCS
CROSS JOIN
(
-- Unitats emissores actives d'empreses emissores actives
SELECT IU.id AS issuer_unit_id, IU_SNS.code AS issuer_unit_code, IU_SNS.name AS issuer_unit_name, 
   IU.enterprise_id AS issuer_enterprise_id, ENT_SNS.code AS issuer_enterprise_code,ENT_SNS.name AS issuer_enterprise_name FROM ISSUER_UNITS AS IU
   INNER JOIN ISSUER_UNITS_SNAPSHOTS AS IU_SNS ON IU.id = IU_SNS.entity_id
   INNER JOIN ENTERPRISES_SNAPSHOTS AS ENT_SNS ON ENT_SNS.entity_id =IU.enterprise_id
   WHERE (IU.TT_start_date < GETDATE()) AND (IU.TT_end_date >= GETDATE() OR IU.TT_end_date IS NULL) 
      AND (IU_SNS.AT_start_date < GETDATE()) AND (IU_SNS.AT_end_date >= GETDATE() OR IU_SNS.AT_end_date IS NULL) 
      AND (ENT_SNS.AT_start_date < GETDATE()) AND (ENT_SNS.AT_end_date >= GETDATE() OR ENT_SNS.AT_end_date IS NULL)  
      AND IU.enterprise_id IN 
         (-- Empresas emissores activas
            SELECT ENT.id FROM dbo.ENTERPRISES AS ENT INNER JOIN
            dbo.ENTERPRISES_SNAPSHOTS AS ENT_SNS ON ENT_SNS.entity_id = ENT.id
            WHERE (ENT.TT_start_date < GETDATE()) AND (ENT.TT_end_date >= GETDATE() OR ENT.TT_end_date IS NULL) 
               AND (ENT_SNS.AT_start_date < GETDATE()) 
               AND (ENT_SNS.AT_end_date >= GETDATE() OR ENT_SNS.AT_end_date IS NULL) AND (ENT_SNS.send_bills = 1))
) IUS
WHERE
NOT EXISTS
(
-- Clients factura tipus empresa-empresa i detall Unitats Emissores-Clients
SELECT BM.clientId,BM.clientEntityType,BM.issuerUnitId
  FROM [ABSIS2].[dbo].[BILL_CLIENTS] AS BC
  INNER JOIN BILL_MERGES AS BM ON BM.billClientId = BC.id
  WHERE client_id = BM.clientId AND issuer_unit_id=BM.issuerUnitId 
  AND BM.clientEntityType = 6
  AND BC.TT_start_date < GETDATE() and (BC.TT_end_date >= GETDATE() OR BC.TT_end_date IS NULL)
  AND BM.TT_start_date < GETDATE() and (BM.TT_end_date >= GETDATE() OR BM.TT_end_date IS NULL)
)


GO
/****** Object:  View [dbo].[APP_COMBI_ENT_EMISORES_CLIENTS]    Script Date: 03/08/2018 14:19:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* EMPRESES ACTIVES EMISORES*/
CREATE VIEW [dbo].[APP_COMBI_ENT_EMISORES_CLIENTS]
AS
SELECT        ENT_CLIENTE.id AS empresa_cliente, ENT_EMISOR.id AS empresa_emisora
FROM            (SELECT        ENT.id
                          FROM            dbo.ENTERPRISES AS ENT INNER JOIN
                                                    dbo.ENTERPRISES_SNAPSHOTS AS ENT_SNS ON ENT_SNS.entity_id = ENT.id
                          WHERE        (ENT.TT_start_date < GETDATE()) AND (ENT.TT_end_date >= GETDATE() OR
                                                    ENT.TT_end_date IS NULL) AND (ENT_SNS.AT_start_date < GETDATE()) AND (ENT_SNS.AT_end_date >= GETDATE() OR
                                                    ENT_SNS.AT_end_date IS NULL) AND (ENT_SNS.receive_bills = 1)) AS ENT_CLIENTE LEFT OUTER JOIN
                             (SELECT        ENT.id
                               FROM            dbo.ENTERPRISES AS ENT INNER JOIN
                                                         dbo.ENTERPRISES_SNAPSHOTS AS ENT_SNS ON ENT_SNS.entity_id = ENT.id
                               WHERE        (ENT.TT_start_date < GETDATE()) AND (ENT.TT_end_date >= GETDATE() OR
                                                         ENT.TT_end_date IS NULL) AND (ENT_SNS.AT_start_date < GETDATE()) AND (ENT_SNS.AT_end_date >= GETDATE() OR
                                                         ENT_SNS.AT_end_date IS NULL) AND (ENT_SNS.send_bills = 1)) AS ENT_EMISOR ON ENT_CLIENTE.id <> ENT_EMISOR.id OR ENT_CLIENTE.id = ENT_EMISOR.id

GO
/****** Object:  View [dbo].[APP_CONSUMPTION_RATES_AND_DISCOUNTS_TO_DELETE]    Script Date: 03/08/2018 14:19:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[APP_CONSUMPTION_RATES_AND_DISCOUNTS_TO_DELETE]
AS
SELECT     id, CAST(REPLACE(infoCharging.value('(/charge/sp_rate/unit_cost/node())[1]', 'nvarchar(MAX)'), ',', '.') AS MONEY) AS sp_rate_unit_cost, 
                      CAST(REPLACE(infoCharging.value('(/charge/rate/unit_cost/node())[1]', 'nvarchar(MAX)'), ',', '.') AS MONEY) AS rate_unit_cost, 
                      CAST(REPLACE(infoCharging.value('(/charge/discount/unit_cost/node())[1]', 'nvarchar(MAX)'), ',', '.') AS MONEY) AS discount_unit_cost, 
                      ISNULL(infoCharging.value('(/charge/discount/is_percentage/node())[1]', 'nvarchar(MAX)'), 'false') AS is_percentage
FROM         dbo.CONSUMPTIONS AS CONS


GO
/****** Object:  View [dbo].[APP_CURRENT_SNAPSHOTS_VIEW]    Script Date: 03/08/2018 14:19:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[APP_CURRENT_SNAPSHOTS_VIEW]
AS
/* ACCOUNTS ***********************************************************/ 
SELECT id, entity_id, 6 AS type_id, AT_start_date, AT_start_user, AT_end_date, AT_end_user, 
                         VT_start_date, VT_end_date, scope_id, name AS name, code + '-' + abreviatura + '-' + name AS smartName
FROM            dbo.ACCOUNTS_SNAPSHOTS
WHERE        scope_id = 1 AND (AT_start_date <= GETDATE() AND VT_start_date <= CAST(GETDATE() AS DATE) AND ((AT_end_date IS NULL AND VT_end_date IS NULL) OR
                         (AT_end_date >= GETDATE() AND VT_end_date IS NULL) OR
                         (AT_end_date IS NULL AND VT_end_date >= CAST(GETDATE() AS DATE))))
UNION ALL

/* BILLABLE_CONCEPTS ****************************************************/ 
SELECT id, entity_id, 9 AS type_id, AT_start_date, AT_start_user, AT_end_date, AT_end_user, 
                         VT_start_date, VT_end_date, scope_id, '' AS name, '' AS smartName
FROM            dbo.BILLABLE_CONCEPTS_SNAPSHOTS
WHERE        scope_id = 1 AND (AT_start_date <= GETDATE() AND VT_start_date <= CAST(GETDATE() AS DATE) AND ((AT_end_date IS NULL AND VT_end_date IS NULL) OR
                         (AT_end_date >= GETDATE() AND VT_end_date IS NULL) OR
                         (AT_end_date IS NULL AND VT_end_date >= CAST(GETDATE() AS DATE))))
UNION ALL

/* CONCEPTS ***********************************************************/ 
SELECT id, entity_id, 8 AS type_id, AT_start_date, AT_start_user, AT_end_date, AT_end_user, 
                         VT_start_date, VT_end_date, scope_id, name AS name, name AS smartName
FROM            dbo.CONCEPTS_SNAPSHOTS
WHERE        scope_id = 1 AND (AT_start_date <= GETDATE() AND VT_start_date <= CAST(GETDATE() AS DATE) AND ((AT_end_date IS NULL AND VT_end_date IS NULL) OR
                         (AT_end_date >= GETDATE() AND VT_end_date IS NULL) OR
                         (AT_end_date IS NULL AND VT_end_date >= CAST(GETDATE() AS DATE))))
UNION ALL

/* DEPARTMENTS ***********************************************************/ 
SELECT id, entity_id, 5 AS type_id, AT_start_date, AT_start_user, AT_end_date, AT_end_user, 
                         VT_start_date, VT_end_date, scope_id, name AS name, code + '-' + name AS smartName
FROM            dbo.DEPARTMENTS_SNAPSHOTS
WHERE        scope_id = 1 AND (AT_start_date <= GETDATE() AND VT_start_date <= CAST(GETDATE() AS DATE) AND ((AT_end_date IS NULL AND VT_end_date IS NULL) OR
                         (AT_end_date >= GETDATE() AND VT_end_date IS NULL) OR
                         (AT_end_date IS NULL AND VT_end_date >= CAST(GETDATE() AS DATE))))
UNION ALL

/* ENTERPRISES ***********************************************************/ 
SELECT id, entity_id, 4 AS type_id, AT_start_date, AT_start_user, AT_end_date, AT_end_user, 
                         VT_start_date, VT_end_date, scope_id, name AS name, code + '-' + name AS smartName
FROM            dbo.ENTERPRISES_SNAPSHOTS
WHERE        scope_id = 1 AND (AT_start_date <= GETDATE() AND VT_start_date <= CAST(GETDATE() AS DATE) AND ((AT_end_date IS NULL AND VT_end_date IS NULL) OR
                         (AT_end_date >= GETDATE() AND VT_end_date IS NULL) OR
                         (AT_end_date IS NULL AND VT_end_date >= CAST(GETDATE() AS DATE))))
UNION ALL

/* DIVISIONS ***********************************************************/ 
SELECT id, entity_id, 3 AS type_id, AT_start_date, AT_start_user, AT_end_date, AT_end_user, 
                         VT_start_date, VT_end_date, scope_id, name AS name, code + '-' + name AS smartName
FROM            dbo.DIVISIONS_SNAPSHOTS
WHERE        scope_id = 1 AND (AT_start_date <= GETDATE() AND VT_start_date <= CAST(GETDATE() AS DATE) AND ((AT_end_date IS NULL AND VT_end_date IS NULL) OR
                         (AT_end_date >= GETDATE() AND VT_end_date IS NULL) OR
                         (AT_end_date IS NULL AND VT_end_date >= CAST(GETDATE() AS DATE))))
UNION ALL

/* ISSUER_UNITS ***********************************************************/ 
SELECT id, entity_id, 24 AS type_id, AT_start_date, AT_start_user, AT_end_date, AT_end_user, 
                         VT_start_date, VT_end_date, scope_id, name AS name, code + '-' + name AS smartName
FROM            dbo.ISSUER_UNITS_SNAPSHOTS
WHERE        scope_id = 1 AND (AT_start_date <= GETDATE() AND VT_start_date <= CAST(GETDATE() AS DATE) AND ((AT_end_date IS NULL AND VT_end_date IS NULL) OR
                         (AT_end_date >= GETDATE() AND VT_end_date IS NULL) OR
                         (AT_end_date IS NULL AND VT_end_date >= CAST(GETDATE() AS DATE))))
UNION ALL

/* RATES ***********************************************************/ 
SELECT id, entity_id, 10 AS type_id, AT_start_date, AT_start_user, AT_end_date, AT_end_user, VT_start_date, 
                         VT_end_date, scope_id, '' AS name, '' AS smartName
FROM            dbo.RATES_SNAPSHOTS
WHERE        scope_id = 1 AND (AT_start_date <= GETDATE() AND VT_start_date <= CAST(GETDATE() AS DATE) AND ((AT_end_date IS NULL AND VT_end_date IS NULL) OR
                         (AT_end_date >= GETDATE() AND VT_end_date IS NULL) OR
                         (AT_end_date IS NULL AND VT_end_date >= CAST(GETDATE() AS DATE))))
UNION ALL

/* SERVICES ***********************************************************/ 
SELECT id, entity_id, 7 AS type_id, AT_start_date, AT_start_user, AT_end_date, AT_end_user, 
                         VT_start_date, VT_end_date, scope_id, name AS name, '' AS smartName
FROM            dbo.SERVICES_SNAPSHOTS
WHERE        scope_id = 1 AND (AT_start_date <= GETDATE() AND VT_start_date <= CAST(GETDATE() AS DATE) AND ((AT_end_date IS NULL AND VT_end_date IS NULL) OR
                         (AT_end_date >= GETDATE() AND VT_end_date IS NULL) OR
                         (AT_end_date IS NULL AND VT_end_date >= CAST(GETDATE() AS DATE))))
UNION ALL
SELECT        id, entity_id, 11 AS type_id, AT_start_date, AT_start_user, AT_end_date, AT_end_user, VT_start_date, VT_end_date, scope_id, description AS name, 
                         description AS smartName
FROM            dbo.SPECIAL_RATESDISCOUNTS_SNAPSHOTS
WHERE        scope_id = 1 AND (AT_start_date <= GETDATE() AND VT_start_date <= CAST(GETDATE() AS DATE) AND ((AT_end_date IS NULL AND VT_end_date IS NULL) OR
                         (AT_end_date >= GETDATE() AND VT_end_date IS NULL) OR
                         (AT_end_date IS NULL AND VT_end_date >= CAST(GETDATE() AS DATE))))
UNION ALL
SELECT        id, entity_id, 2 AS type_id, AT_start_date, AT_start_user, AT_end_date, AT_end_user, VT_start_date, VT_end_date, scope_id, description AS name, 
                         description AS smartName
FROM            dbo.USERS_SNAPSHOTS
WHERE        scope_id = 1 AND (AT_start_date <= GETDATE() AND VT_start_date <= CAST(GETDATE() AS DATE) AND ((AT_end_date IS NULL AND VT_end_date IS NULL) OR
                         (AT_end_date >= GETDATE() AND VT_end_date IS NULL) OR
                         (AT_end_date IS NULL AND VT_end_date >= CAST(GETDATE() AS DATE))))

GO
/****** Object:  View [dbo].[APP_ENTITIES_VIEW]    Script Date: 03/08/2018 14:19:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[APP_ENTITIES_VIEW]
AS
SELECT     id, 6 AS type_id, TT_start_date, TT_end_date, TT_start_user, TT_end_user, last_change_date, last_change_user
FROM         dbo.ACCOUNTS
UNION ALL
SELECT     id, 9 AS type_id, TT_start_date, TT_end_date, TT_start_user, TT_end_user, last_change_date, last_change_user
FROM         dbo.BILLABLE_CONCEPTS
UNION ALL
SELECT     id, 8 AS type_id, TT_start_date, TT_end_date, TT_start_user, TT_end_user, last_change_date, last_change_user
FROM         dbo.CONCEPTS
UNION ALL
SELECT     id, 5 AS type_id, TT_start_date, TT_end_date, TT_start_user, TT_end_user, last_change_date, last_change_user
FROM         dbo.DEPARTMENTS
UNION ALL
SELECT     id, 3 AS type_id, TT_start_date, TT_end_date, TT_start_user, TT_end_user, last_change_date, last_change_user
FROM         dbo.DIVISIONS
UNION ALL
SELECT     id, 4 AS type_id, TT_start_date, TT_end_date, TT_start_user, TT_end_user, last_change_date, last_change_user
FROM         dbo.ENTERPRISES
UNION ALL
SELECT     id, 24 AS type_id, TT_start_date, TT_end_date, TT_start_user, TT_end_user, last_change_date, last_change_user
FROM         dbo.ISSUER_UNITS
UNION ALL
SELECT     id, 10 AS type_id, TT_start_date, TT_end_date, TT_start_user, TT_end_user, last_change_date, last_change_user
FROM         dbo.RATES
UNION ALL
SELECT     id, 7 AS type_id, TT_start_date, TT_end_date, TT_start_user, TT_end_user, last_change_date, last_change_user
FROM         dbo.SERVICES
UNION ALL
SELECT     id, 11 AS type_id, TT_start_date, TT_end_date, TT_start_user, TT_end_user, last_change_date, last_change_user
FROM         dbo.SPECIAL_RATESDISCOUNTS
UNION ALL
SELECT     id, 2 AS type_id, TT_start_date, TT_end_date, TT_start_user, TT_end_user, last_change_date, last_change_user
FROM         dbo.USERS

GO
/****** Object:  View [dbo].[APP_EXPORT_CARGOS]    Script Date: 03/08/2018 14:19:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* SUBSTITUITS TOTS ELS CHARS.register_date PER GETDATE()*/
CREATE VIEW [dbo].[APP_EXPORT_CARGOS]
AS
SELECT        CHARS.id AS CHARGE_ID, CHARS.value_date AS FECHA_VALOR, CASE CHARS.workflow_state WHEN 3 THEN 'facturado' WHEN 4 THEN 'facturado' ELSE 'pendiente' END AS ESTADO, 
                         IUS_ENTS.code AS COD_EMISOR, DIV_SNS.name AS DIV_CLIENTE, ISNULL(DEP_SNS.code, ACC_SNS.code) AS COD_CLIENTE, DEP_SNS.code AS COD_DEP, ISNULL(DEP_SNS.name, ACC_SNS.name) 
                         AS CLIENTE, ACC_SNS.code AS CC_CLIENTE, ACC_SNS.abreviatura AS ABRV_CLIENTE, ACC_SNS.name AS DESCRIPCION_CC_CLIENTE, IUS_SNS.name AS DPTO_EMISOR, SER_SNS.name AS SERVICIO, 
                         CON_SNS.name AS CONCEPTO, CHARS.description AS DESCRIPCION, CASE CHARS.charge_type_id WHEN 3 THEN NULL WHEN 4 THEN NULL ELSE CONS.amount END AS CANTIDAD, 
                         CASE CHARS.charge_type_id WHEN 3 THEN NULL WHEN 4 THEN NULL ELSE ISNULL(CONS.rate_unit_cost, CONS.sp_rate_unit_cost) END AS TARIFA, CHARS.amount AS IMP_TOTAL, 
                         CASE WHEN ENT_SNS_CLIENT.entity_id = ACCS_ISSUER.enterprise_id THEN BC_SNS.OUTint_accounting_address ELSE BC_SNS.OUT_accounting_address END AS CTA_GTO, 
                         CASE WHEN ENT_SNS_CLIENT.entity_id = ACCS_ISSUER.enterprise_id THEN BC_SNS.INint_accounting_address ELSE BC_SNS.IN_accounting_address END AS CTA_ING, 
                         ACC_SNS_ISSUER.code AS CC_INGRESO, ACC_SNS_ISSUER.name AS DESCRIPCION_CC_INGRESO, ENT_SNS_CLIENT.name AS DESC_EMP_CLIENTE, 
                         CASE CHARS.charge_type_id WHEN 1 THEN 'consumo' WHEN 2 THEN 'consumo' WHEN 3 THEN 'cargo' WHEN 4 THEN 'cargo' WHEN 5 THEN 'consumo' END AS TIPO, UNI.name AS TIPO_UNIDAD, 
                         CASE CHARS.charge_type_id WHEN 3 THEN CHARS.amount WHEN 4 THEN CHARS.amount ELSE CAST(ISNULL(CONS.rate_unit_cost, CONS.sp_rate_unit_cost) * CONS.amount AS DECIMAL(18, 2)) 
                         END AS TOTAL_SIN_DESCUENTO, CONS.discount_unit_cost * CAST(CONS.is_percentage AS INT) AS DTO_PORCENTAJE, CONS.discount_unit_cost * (1 - CAST(CONS.is_percentage AS INT)) AS DTO_EUROS, 
                         SBL.in_subledger AS SUBLEDGER_I, SBL.out_subledger AS SUBLEDGER_G, IUS.id AS ISSUER_ID, dbo.APP_GetBillClient(ISNULL(ACC_SNS.department_id, ACC_SNS.entity_id), IUS.id, 
                         ISNULL(DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date)))), DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, 
                         CONVERT(DATETIME, GETDATE())))))) AS CLIENT_ID, CHARS.workflow_state AS CHAR_WFSTATE_ID, ENT_SNS_CLIENT.entity_id AS CLIENT_ENTERPRISE_ID, 
                         ACCS_ISSUER.enterprise_id AS ISSUER_ENTERPRISE_ID, ACC_SNS.department_id AS CLIENT_DEPARTMENT_ID, ACC_SNS.entity_id AS CLIENT_ACCOUNT_ID
FROM            dbo.CHARGES AS CHARS INNER JOIN
                         dbo.BILLABLE_CONCEPTS_SNAPSHOTS AS BC_SNS ON CHARS.billable_concept_id = BC_SNS.entity_id AND BC_SNS.scope_id = 1 AND BC_SNS.VT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, 
                         DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date)))) AND (BC_SNS.VT_end_date IS NULL OR
                         BC_SNS.VT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date))))) AND (CHARS.invoice_date IS NULL AND 
                         BC_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND BC_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) AND 
                         (BC_SNS.AT_end_date IS NULL OR
                         CHARS.invoice_date IS NULL AND BC_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND BC_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) INNER JOIN
                         dbo.BILLABLE_CONCEPTS AS BCS ON BCS.id = BC_SNS.entity_id INNER JOIN
                         dbo.SERVICES_SNAPSHOTS AS SER_SNS ON BCS.service_id = SER_SNS.entity_id AND SER_SNS.scope_id = 1 AND SER_SNS.VT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 
                         23, CONVERT(DATETIME, CHARS.value_date)))) AND (SER_SNS.VT_end_date IS NULL OR
                         SER_SNS.VT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date))))) AND (CHARS.invoice_date IS NULL AND 
                         SER_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND SER_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) AND 
                         (SER_SNS.AT_end_date IS NULL OR
                         CHARS.invoice_date IS NULL AND SER_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND SER_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) INNER JOIN
                         dbo.CONCEPTS_SNAPSHOTS AS CON_SNS ON BCS.concept_id = CON_SNS.entity_id AND CON_SNS.scope_id = 1 AND CON_SNS.VT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, 
                         DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date)))) AND (CON_SNS.VT_end_date IS NULL OR
                         CON_SNS.VT_end_date >= CHARS.value_date) AND (CHARS.invoice_date IS NULL AND CON_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, 
                         GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND CON_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) AND 
                         (CON_SNS.AT_end_date IS NULL OR
                         CHARS.invoice_date IS NULL AND CON_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND CON_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) INNER JOIN
                         dbo.ISSUER_UNITS_SNAPSHOTS AS IUS_SNS ON SER_SNS.issuer_unit_id = IUS_SNS.entity_id AND IUS_SNS.scope_id = 1 AND IUS_SNS.VT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, 
                         DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date)))) AND (IUS_SNS.VT_end_date IS NULL OR
                         IUS_SNS.VT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date))))) AND (CHARS.invoice_date IS NULL AND 
                         IUS_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND IUS_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) AND 
                         (IUS_SNS.AT_end_date IS NULL OR
                         CHARS.invoice_date IS NULL AND IUS_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND IUS_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) INNER JOIN
                         dbo.ISSUER_UNITS AS IUS ON IUS_SNS.entity_id = IUS.id INNER JOIN
                         dbo.ENTERPRISES_SNAPSHOTS AS IUS_ENTS ON IUS.enterprise_id = IUS_ENTS.entity_id AND IUS_ENTS.scope_id = 1 AND IUS_ENTS.VT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, 
                         DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date)))) AND (IUS_ENTS.VT_end_date IS NULL OR
                         IUS_ENTS.VT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date))))) AND (CHARS.invoice_date IS NULL AND 
                         IUS_ENTS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND IUS_ENTS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) AND 
                         (IUS_ENTS.AT_end_date IS NULL OR
                         CHARS.invoice_date IS NULL AND IUS_ENTS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND IUS_ENTS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) INNER JOIN
                         dbo.ACCOUNTS_SNAPSHOTS AS ACC_SNS_ISSUER ON BC_SNS.IN_account_id = ACC_SNS_ISSUER.entity_id AND ACC_SNS_ISSUER.scope_id = 1 AND ACC_SNS_ISSUER.VT_start_date <= DATEADD(SECOND, 
                         59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date)))) AND (ACC_SNS_ISSUER.VT_end_date IS NULL OR
                         ACC_SNS_ISSUER.VT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date))))) AND (CHARS.invoice_date IS NULL AND 
                         ACC_SNS_ISSUER.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND ACC_SNS_ISSUER.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) AND 
                         (ACC_SNS_ISSUER.AT_end_date IS NULL OR
                         CHARS.invoice_date IS NULL AND ACC_SNS_ISSUER.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND ACC_SNS_ISSUER.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) INNER JOIN
                         dbo.ACCOUNTS AS ACCS_ISSUER ON ACCS_ISSUER.id = ACC_SNS_ISSUER.entity_id INNER JOIN
                         dbo.ACCOUNTS_SNAPSHOTS AS ACC_SNS ON CHARS.account_id = ACC_SNS.entity_id AND ACC_SNS.scope_id = 1 AND ACC_SNS.VT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, 
                         DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date)))) AND (ACC_SNS.VT_end_date IS NULL OR
                         ACC_SNS.VT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date))))) AND (CHARS.invoice_date IS NULL AND 
                         ACC_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND ACC_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) AND 
                         (ACC_SNS.AT_end_date IS NULL OR
                         CHARS.invoice_date IS NULL AND ACC_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND ACC_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) INNER JOIN
                         dbo.ACCOUNTS AS ACCS ON ACCS.id = ACC_SNS.entity_id LEFT OUTER JOIN
                         dbo.DEPARTMENTS_SNAPSHOTS AS DEP_SNS ON ACC_SNS.department_id = DEP_SNS.entity_id AND DEP_SNS.scope_id = 1 AND DEP_SNS.VT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, 
                         DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date)))) AND (DEP_SNS.VT_end_date IS NULL OR
                         DEP_SNS.VT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date))))) AND (CHARS.invoice_date IS NULL AND 
                         DEP_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND DEP_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) AND 
                         (DEP_SNS.AT_end_date IS NULL OR
                         CHARS.invoice_date IS NULL AND DEP_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND DEP_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) LEFT OUTER JOIN
                         dbo.DEPARTMENTS AS DEPS ON DEP_SNS.entity_id = DEPS.id INNER JOIN
                         dbo.DIVISIONS_SNAPSHOTS AS DIV_SNS ON ACC_SNS.division_id = DIV_SNS.entity_id AND DIV_SNS.scope_id = 1 AND DIV_SNS.VT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, 
                         DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date)))) AND (DIV_SNS.VT_end_date IS NULL OR
                         DIV_SNS.VT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date))))) AND (CHARS.invoice_date IS NULL AND 
                         DIV_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND DIV_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) AND 
                         (DIV_SNS.AT_end_date IS NULL OR
                         CHARS.invoice_date IS NULL AND DIV_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND DIV_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) INNER JOIN
                         dbo.ENTERPRISES_SNAPSHOTS AS ENT_SNS_CLIENT ON ACCS.enterprise_id = ENT_SNS_CLIENT.entity_id AND ENT_SNS_CLIENT.scope_id = 1 AND ENT_SNS_CLIENT.VT_start_date <= DATEADD(SECOND, 59,
                          DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date)))) AND (ENT_SNS_CLIENT.VT_end_date IS NULL OR
                         ENT_SNS_CLIENT.VT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date))))) AND (CHARS.invoice_date IS NULL AND 
                         ENT_SNS_CLIENT.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND ENT_SNS_CLIENT.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) AND 
                         (ENT_SNS_CLIENT.AT_end_date IS NULL OR
                         CHARS.invoice_date IS NULL AND ENT_SNS_CLIENT.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND ENT_SNS_CLIENT.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) INNER JOIN
                         dbo.UNITS AS UNI ON CON_SNS.unit_id = UNI.id LEFT OUTER JOIN
                         dbo.SUBLEDGERS AS SBL ON BCS.id = SBL.billable_concept_id AND CHARS.account_id = SBL.account_id LEFT OUTER JOIN
                         dbo.CONSUMPTIONS AS CONS ON CHARS.id = CONS.charge_id

GO
/****** Object:  View [dbo].[APP_EXPORT_CARGOS_NOLOCK]    Script Date: 03/08/2018 14:19:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[APP_EXPORT_CARGOS_NOLOCK]
AS
SELECT        CHARS.id AS CHARGE_ID, CHARS.value_date AS FECHA_VALOR, CASE CHARS.workflow_state WHEN 3 THEN 'facturado' WHEN 4 THEN 'facturado' ELSE 'pendiente' END AS ESTADO, 
                         IUS_ENTS.code AS COD_EMISOR, DIV_SNS.name AS DIV_CLIENTE, ISNULL(DEP_SNS.code, ACC_SNS.code) AS COD_CLIENTE, DEP_SNS.code AS COD_DEP, ISNULL(DEP_SNS.name, ACC_SNS.name) 
                         AS CLIENTE, ACC_SNS.code AS CC_CLIENTE, ACC_SNS.abreviatura AS ABRV_CLIENTE, ACC_SNS.name AS DESCRIPCION_CC_CLIENTE, IUS_SNS.name AS DPTO_EMISOR, SER_SNS.name AS SERVICIO, 
                         CON_SNS.name AS CONCEPTO, CHARS.description AS DESCRIPCION, CASE CHARS.charge_type_id WHEN 3 THEN NULL WHEN 4 THEN NULL ELSE CONS.amount END AS CANTIDAD, 
                         CASE CHARS.charge_type_id WHEN 3 THEN NULL WHEN 4 THEN NULL ELSE ISNULL(CONS.rate_unit_cost, CONS.sp_rate_unit_cost) END AS TARIFA, CHARS.amount AS IMP_TOTAL, 
                         CASE WHEN ENT_SNS_CLIENT.entity_id = ACCS_ISSUER.enterprise_id THEN BC_SNS.OUTint_accounting_address ELSE BC_SNS.OUT_accounting_address END AS CTA_GTO, 
                         CASE WHEN ENT_SNS_CLIENT.entity_id = ACCS_ISSUER.enterprise_id THEN BC_SNS.INint_accounting_address ELSE BC_SNS.IN_accounting_address END AS CTA_ING, 
                         ACC_SNS_ISSUER.code AS CC_INGRESO, ACC_SNS_ISSUER.name AS DESCRIPCION_CC_INGRESO, ENT_SNS_CLIENT.name AS DESC_EMP_CLIENTE, 
                         CASE CHARS.charge_type_id WHEN 1 THEN 'consumo' WHEN 2 THEN 'consumo' WHEN 3 THEN 'cargo' WHEN 4 THEN 'cargo' WHEN 5 THEN 'consumo' END AS TIPO, UNI.name AS TIPO_UNIDAD, 
                         CASE CHARS.charge_type_id WHEN 3 THEN CHARS.amount WHEN 4 THEN CHARS.amount ELSE CAST(ISNULL(CONS.rate_unit_cost, CONS.sp_rate_unit_cost) * CONS.amount AS DECIMAL(18, 2)) 
                         END AS TOTAL_SIN_DESCUENTO, CONS.discount_unit_cost * CAST(CONS.is_percentage AS INT) AS DTO_PORCENTAJE, CONS.discount_unit_cost * (1 - CAST(CONS.is_percentage AS INT)) AS DTO_EUROS, 
                         SBL.in_subledger AS SUBLEDGER_I, SBL.out_subledger AS SUBLEDGER_G, IUS.id AS ISSUER_ID, dbo.APP_GetBillClient(ISNULL(ACC_SNS.department_id, ACC_SNS.entity_id), IUS.id, 
                         ISNULL(DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date)))), DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, 
                         CONVERT(DATETIME, GETDATE())))))) AS CLIENT_ID, CHARS.workflow_state AS CHAR_WFSTATE_ID, ENT_SNS_CLIENT.entity_id AS CLIENT_ENTERPRISE_ID, 
                         ACCS_ISSUER.enterprise_id AS ISSUER_ENTERPRISE_ID, ACC_SNS.department_id AS CLIENT_DEPARTMENT_ID, ACC_SNS.entity_id AS CLIENT_ACCOUNT_ID
FROM            dbo.CHARGES AS CHARS WITH (NOLOCK) INNER JOIN
                         dbo.BILLABLE_CONCEPTS_SNAPSHOTS AS BC_SNS WITH (NOLOCK) ON CHARS.billable_concept_id = BC_SNS.entity_id AND BC_SNS.scope_id = 1 AND BC_SNS.VT_start_date <= DATEADD(SECOND, 59, 
                         DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date)))) AND (BC_SNS.VT_end_date IS NULL OR
                         BC_SNS.VT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date))))) AND (CHARS.invoice_date IS NULL AND 
                         BC_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND BC_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) AND 
                         (BC_SNS.AT_end_date IS NULL OR
                         CHARS.invoice_date IS NULL AND BC_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND BC_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) INNER JOIN
                         dbo.BILLABLE_CONCEPTS AS BCS WITH (NOLOCK) ON BCS.id = BC_SNS.entity_id INNER JOIN
                         dbo.SERVICES_SNAPSHOTS AS SER_SNS WITH (NOLOCK) ON BCS.service_id = SER_SNS.entity_id AND SER_SNS.scope_id = 1 AND SER_SNS.VT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, 
                         DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date)))) AND (SER_SNS.VT_end_date IS NULL OR
                         SER_SNS.VT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date))))) AND (CHARS.invoice_date IS NULL AND 
                         SER_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND SER_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) AND 
                         (SER_SNS.AT_end_date IS NULL OR
                         CHARS.invoice_date IS NULL AND SER_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND SER_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) INNER JOIN
                         dbo.CONCEPTS_SNAPSHOTS AS CON_SNS WITH (NOLOCK) ON BCS.concept_id = CON_SNS.entity_id AND CON_SNS.scope_id = 1 AND CON_SNS.VT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, 
                         DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date)))) AND (CON_SNS.VT_end_date IS NULL OR
                         CON_SNS.VT_end_date >= CHARS.value_date) AND (CHARS.invoice_date IS NULL AND CON_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, 
                         GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND CON_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) AND 
                         (CON_SNS.AT_end_date IS NULL OR
                         CHARS.invoice_date IS NULL AND CON_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND CON_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) INNER JOIN
                         dbo.ISSUER_UNITS_SNAPSHOTS AS IUS_SNS WITH (NOLOCK) ON SER_SNS.issuer_unit_id = IUS_SNS.entity_id AND IUS_SNS.scope_id = 1 AND IUS_SNS.VT_start_date <= DATEADD(SECOND, 59, 
                         DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date)))) AND (IUS_SNS.VT_end_date IS NULL OR
                         IUS_SNS.VT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date))))) AND (CHARS.invoice_date IS NULL AND 
                         IUS_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND IUS_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) AND 
                         (IUS_SNS.AT_end_date IS NULL OR
                         CHARS.invoice_date IS NULL AND IUS_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND IUS_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) INNER JOIN
                         dbo.ISSUER_UNITS AS IUS WITH (NOLOCK) ON IUS_SNS.entity_id = IUS.id INNER JOIN
                         dbo.ENTERPRISES_SNAPSHOTS AS IUS_ENTS WITH (NOLOCK) ON IUS.enterprise_id = IUS_ENTS.entity_id AND IUS_ENTS.scope_id = 1 AND IUS_ENTS.VT_start_date <= DATEADD(SECOND, 59, 
                         DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date)))) AND (IUS_ENTS.VT_end_date IS NULL OR
                         IUS_ENTS.VT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date))))) AND (CHARS.invoice_date IS NULL AND 
                         IUS_ENTS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND IUS_ENTS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) AND 
                         (IUS_ENTS.AT_end_date IS NULL OR
                         CHARS.invoice_date IS NULL AND IUS_ENTS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND IUS_ENTS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) INNER JOIN
                         dbo.ACCOUNTS_SNAPSHOTS AS ACC_SNS_ISSUER WITH (NOLOCK) ON BC_SNS.IN_account_id = ACC_SNS_ISSUER.entity_id AND ACC_SNS_ISSUER.scope_id = 1 AND 
                         ACC_SNS_ISSUER.VT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date)))) AND (ACC_SNS_ISSUER.VT_end_date IS NULL OR
                         ACC_SNS_ISSUER.VT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date))))) AND (CHARS.invoice_date IS NULL AND 
                         ACC_SNS_ISSUER.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND ACC_SNS_ISSUER.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) AND 
                         (ACC_SNS_ISSUER.AT_end_date IS NULL OR
                         CHARS.invoice_date IS NULL AND ACC_SNS_ISSUER.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND ACC_SNS_ISSUER.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) INNER JOIN
                         dbo.ACCOUNTS AS ACCS_ISSUER WITH (NOLOCK) ON ACCS_ISSUER.id = ACC_SNS_ISSUER.entity_id INNER JOIN
                         dbo.ACCOUNTS_SNAPSHOTS AS ACC_SNS WITH (NOLOCK) ON CHARS.account_id = ACC_SNS.entity_id AND ACC_SNS.scope_id = 1 AND ACC_SNS.VT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 
                         59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date)))) AND (ACC_SNS.VT_end_date IS NULL OR
                         ACC_SNS.VT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date))))) AND (CHARS.invoice_date IS NULL AND 
                         ACC_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND ACC_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) AND 
                         (ACC_SNS.AT_end_date IS NULL OR
                         CHARS.invoice_date IS NULL AND ACC_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND ACC_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) INNER JOIN
                         dbo.ACCOUNTS AS ACCS WITH (NOLOCK) ON ACCS.id = ACC_SNS.entity_id LEFT OUTER JOIN
                         dbo.DEPARTMENTS_SNAPSHOTS AS DEP_SNS WITH (NOLOCK) ON ACC_SNS.department_id = DEP_SNS.entity_id AND DEP_SNS.scope_id = 1 AND DEP_SNS.VT_start_date <= DATEADD(SECOND, 59, 
                         DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date)))) AND (DEP_SNS.VT_end_date IS NULL OR
                         DEP_SNS.VT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date))))) AND (CHARS.invoice_date IS NULL AND 
                         DEP_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND DEP_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) AND 
                         (DEP_SNS.AT_end_date IS NULL OR
                         CHARS.invoice_date IS NULL AND DEP_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND DEP_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) LEFT OUTER JOIN
                         dbo.DEPARTMENTS AS DEPS WITH (NOLOCK) ON DEP_SNS.entity_id = DEPS.id INNER JOIN
                         dbo.DIVISIONS_SNAPSHOTS AS DIV_SNS WITH (NOLOCK) ON ACC_SNS.division_id = DIV_SNS.entity_id AND DIV_SNS.scope_id = 1 AND DIV_SNS.VT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 
                         59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date)))) AND (DIV_SNS.VT_end_date IS NULL OR
                         DIV_SNS.VT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date))))) AND (CHARS.invoice_date IS NULL AND 
                         DIV_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND DIV_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) AND 
                         (DIV_SNS.AT_end_date IS NULL OR
                         CHARS.invoice_date IS NULL AND DIV_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND DIV_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) INNER JOIN
                         dbo.ENTERPRISES_SNAPSHOTS AS ENT_SNS_CLIENT WITH (NOLOCK) ON ACCS.enterprise_id = ENT_SNS_CLIENT.entity_id AND ENT_SNS_CLIENT.scope_id = 1 AND 
                         ENT_SNS_CLIENT.VT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date)))) AND (ENT_SNS_CLIENT.VT_end_date IS NULL OR
                         ENT_SNS_CLIENT.VT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date))))) AND (CHARS.invoice_date IS NULL AND 
                         ENT_SNS_CLIENT.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND ENT_SNS_CLIENT.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) AND 
                         (ENT_SNS_CLIENT.AT_end_date IS NULL OR
                         CHARS.invoice_date IS NULL AND ENT_SNS_CLIENT.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND ENT_SNS_CLIENT.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) INNER JOIN
                         dbo.UNITS AS UNI WITH (NOLOCK) ON CON_SNS.unit_id = UNI.id LEFT OUTER JOIN
                         dbo.SUBLEDGERS AS SBL WITH (NOLOCK) ON BCS.id = SBL.billable_concept_id AND CHARS.account_id = SBL.account_id LEFT OUTER JOIN
                         dbo.CONSUMPTIONS AS CONS WITH (NOLOCK) ON CHARS.id = CONS.charge_id

GO
/****** Object:  View [dbo].[APP_EXPORT_CARGOS_TEMPORAL_CUADRES_ENERO]    Script Date: 03/08/2018 14:19:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[APP_EXPORT_CARGOS_TEMPORAL_CUADRES_ENERO]
AS
SELECT        CHARS.id AS CHARGE_ID, CHARS.value_date AS FECHA_VALOR, CASE CHARS.workflow_state WHEN 3 THEN 'facturado' WHEN 4 THEN 'facturado' ELSE 'pendiente' END AS ESTADO, 
                         IUS_ENTS.code AS COD_EMISOR, DIV_SNS.name AS DIV_CLIENTE, ISNULL(DEP_SNS.code, ACC_SNS.code) AS COD_CLIENTE, DEP_SNS.code AS COD_DEP, ISNULL(DEP_SNS.name, ACC_SNS.name) 
                         AS CLIENTE, ACC_SNS.code AS CC_CLIENTE, ACC_SNS.abreviatura AS ABRV_CLIENTE, ACC_SNS.name AS DESCRIPCION_CC_CLIENTE, IUS_SNS.name AS DPTO_EMISOR, SER_SNS.name AS SERVICIO, 
                         CON_SNS.name AS CONCEPTO, CHARS.description AS DESCRIPCION, CASE CHARS.charge_type_id WHEN 3 THEN NULL WHEN 4 THEN NULL ELSE CONS.amount END AS CANTIDAD, 
                         CASE CHARS.charge_type_id WHEN 3 THEN NULL WHEN 4 THEN NULL ELSE ISNULL(CONS.rate_unit_cost, CONS.sp_rate_unit_cost) END AS TARIFA, CHARS.amount AS IMP_TOTAL, 
                         CASE WHEN ENT_SNS_CLIENT.entity_id = ACCS_ISSUER.enterprise_id THEN BC_SNS.OUTint_accounting_address ELSE BC_SNS.OUT_accounting_address END AS CTA_GTO, 
                         CASE WHEN ENT_SNS_CLIENT.entity_id = ACCS_ISSUER.enterprise_id THEN BC_SNS.INint_accounting_address ELSE BC_SNS.IN_accounting_address END AS CTA_ING, 
                         ACC_SNS_ISSUER.code AS CC_INGRESO, ACC_SNS_ISSUER.name AS DESCRIPCION_CC_INGRESO, ENT_SNS_CLIENT.name AS DESC_EMP_CLIENTE, 
                         CASE CHARS.charge_type_id WHEN 1 THEN 'consumo' WHEN 2 THEN 'consumo' WHEN 3 THEN 'cargo' WHEN 4 THEN 'cargo' WHEN 5 THEN 'consumo' END AS TIPO, UNI.name AS TIPO_UNIDAD, 
                         CASE CHARS.charge_type_id WHEN 3 THEN CHARS.amount WHEN 4 THEN CHARS.amount ELSE CAST(ISNULL(CONS.rate_unit_cost, CONS.sp_rate_unit_cost) * CONS.amount AS DECIMAL(18, 2)) 
                         END AS TOTAL_SIN_DESCUENTO, CONS.discount_unit_cost * CAST(CONS.is_percentage AS INT) AS DTO_PORCENTAJE, CONS.discount_unit_cost * (1 - CAST(CONS.is_percentage AS INT)) AS DTO_EUROS, 
                         SBL.in_subledger AS SUBLEDGER_I, SBL.out_subledger AS SUBLEDGER_G, IUS.id AS ISSUER_ID, dbo.APP_GetBillClient(ISNULL(ACC_SNS.department_id, ACC_SNS.entity_id), IUS.id, 
                         ISNULL(DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date)))), DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, 
                         CONVERT(DATETIME, GETDATE())))))) AS CLIENT_ID, CHARS.workflow_state AS CHAR_WFSTATE_ID, ENT_SNS_CLIENT.entity_id AS CLIENT_ENTERPRISE_ID, 
                         ACCS_ISSUER.enterprise_id AS ISSUER_ENTERPRISE_ID, ACC_SNS.department_id AS CLIENT_DEPARTMENT_ID, ACC_SNS.entity_id AS CLIENT_ACCOUNT_ID, CHARS.budgetary_code
FROM            dbo.CHARGES AS CHARS INNER JOIN
                         dbo.BILLABLE_CONCEPTS_SNAPSHOTS AS BC_SNS ON CHARS.billable_concept_id = BC_SNS.entity_id AND BC_SNS.scope_id = 1 AND BC_SNS.VT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, 
                         DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date)))) AND (BC_SNS.VT_end_date IS NULL OR
                         BC_SNS.VT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date))))) AND (CHARS.invoice_date IS NULL AND 
                         BC_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND BC_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) AND 
                         (BC_SNS.AT_end_date IS NULL OR
                         CHARS.invoice_date IS NULL AND BC_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND BC_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) INNER JOIN
                         dbo.BILLABLE_CONCEPTS AS BCS ON BCS.id = BC_SNS.entity_id INNER JOIN
                         dbo.SERVICES_SNAPSHOTS AS SER_SNS ON BCS.service_id = SER_SNS.entity_id AND SER_SNS.scope_id = 1 AND SER_SNS.VT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 
                         23, CONVERT(DATETIME, CHARS.value_date)))) AND (SER_SNS.VT_end_date IS NULL OR
                         SER_SNS.VT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date))))) AND (CHARS.invoice_date IS NULL AND 
                         SER_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND SER_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) AND 
                         (SER_SNS.AT_end_date IS NULL OR
                         CHARS.invoice_date IS NULL AND SER_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND SER_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) INNER JOIN
                         dbo.CONCEPTS_SNAPSHOTS AS CON_SNS ON BCS.concept_id = CON_SNS.entity_id AND CON_SNS.scope_id = 1 AND CON_SNS.VT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, 
                         DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date)))) AND (CON_SNS.VT_end_date IS NULL OR
                         CON_SNS.VT_end_date >= CHARS.value_date) AND (CHARS.invoice_date IS NULL AND CON_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, 
                         GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND CON_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) AND 
                         (CON_SNS.AT_end_date IS NULL OR
                         CHARS.invoice_date IS NULL AND CON_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND CON_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) INNER JOIN
                         dbo.ISSUER_UNITS_SNAPSHOTS AS IUS_SNS ON SER_SNS.issuer_unit_id = IUS_SNS.entity_id AND IUS_SNS.scope_id = 1 AND IUS_SNS.VT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, 
                         DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date)))) AND (IUS_SNS.VT_end_date IS NULL OR
                         IUS_SNS.VT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date))))) AND (CHARS.invoice_date IS NULL AND 
                         IUS_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND IUS_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) AND 
                         (IUS_SNS.AT_end_date IS NULL OR
                         CHARS.invoice_date IS NULL AND IUS_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND IUS_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) INNER JOIN
                         dbo.ISSUER_UNITS AS IUS ON IUS_SNS.entity_id = IUS.id INNER JOIN
                         dbo.ENTERPRISES_SNAPSHOTS AS IUS_ENTS ON IUS.enterprise_id = IUS_ENTS.entity_id AND IUS_ENTS.scope_id = 1 AND IUS_ENTS.VT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, 
                         DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date)))) AND (IUS_ENTS.VT_end_date IS NULL OR
                         IUS_ENTS.VT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date))))) AND (CHARS.invoice_date IS NULL AND 
                         IUS_ENTS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND IUS_ENTS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) AND 
                         (IUS_ENTS.AT_end_date IS NULL OR
                         CHARS.invoice_date IS NULL AND IUS_ENTS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND IUS_ENTS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) INNER JOIN
                         dbo.ACCOUNTS_SNAPSHOTS AS ACC_SNS_ISSUER ON BC_SNS.IN_account_id = ACC_SNS_ISSUER.entity_id AND ACC_SNS_ISSUER.scope_id = 1 AND ACC_SNS_ISSUER.VT_start_date <= DATEADD(SECOND, 
                         59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date)))) AND (ACC_SNS_ISSUER.VT_end_date IS NULL OR
                         ACC_SNS_ISSUER.VT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date))))) AND (CHARS.invoice_date IS NULL AND 
                         ACC_SNS_ISSUER.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND ACC_SNS_ISSUER.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) AND 
                         (ACC_SNS_ISSUER.AT_end_date IS NULL OR
                         CHARS.invoice_date IS NULL AND ACC_SNS_ISSUER.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND ACC_SNS_ISSUER.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) INNER JOIN
                         dbo.ACCOUNTS AS ACCS_ISSUER ON ACCS_ISSUER.id = ACC_SNS_ISSUER.entity_id INNER JOIN
                         dbo.ACCOUNTS_SNAPSHOTS AS ACC_SNS ON CHARS.account_id = ACC_SNS.entity_id AND ACC_SNS.scope_id = 1 AND ACC_SNS.VT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, 
                         DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date)))) AND (ACC_SNS.VT_end_date IS NULL OR
                         ACC_SNS.VT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date))))) AND (CHARS.invoice_date IS NULL AND 
                         ACC_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND ACC_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) AND 
                         (ACC_SNS.AT_end_date IS NULL OR
                         CHARS.invoice_date IS NULL AND ACC_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND ACC_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) INNER JOIN
                         dbo.ACCOUNTS AS ACCS ON ACCS.id = ACC_SNS.entity_id LEFT OUTER JOIN
                         dbo.DEPARTMENTS_SNAPSHOTS AS DEP_SNS ON ACC_SNS.department_id = DEP_SNS.entity_id AND DEP_SNS.scope_id = 1 AND DEP_SNS.VT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, 
                         DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date)))) AND (DEP_SNS.VT_end_date IS NULL OR
                         DEP_SNS.VT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date))))) AND (CHARS.invoice_date IS NULL AND 
                         DEP_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND DEP_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) AND 
                         (DEP_SNS.AT_end_date IS NULL OR
                         CHARS.invoice_date IS NULL AND DEP_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND DEP_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) LEFT OUTER JOIN
                         dbo.DEPARTMENTS AS DEPS ON DEP_SNS.entity_id = DEPS.id INNER JOIN
                         dbo.DIVISIONS_SNAPSHOTS AS DIV_SNS ON ACC_SNS.division_id = DIV_SNS.entity_id AND DIV_SNS.scope_id = 1 AND DIV_SNS.VT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, 
                         DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date)))) AND (DIV_SNS.VT_end_date IS NULL OR
                         DIV_SNS.VT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date))))) AND (CHARS.invoice_date IS NULL AND 
                         DIV_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND DIV_SNS.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) AND 
                         (DIV_SNS.AT_end_date IS NULL OR
                         CHARS.invoice_date IS NULL AND DIV_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND DIV_SNS.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) INNER JOIN
                         dbo.ENTERPRISES_SNAPSHOTS AS ENT_SNS_CLIENT ON ACCS.enterprise_id = ENT_SNS_CLIENT.entity_id AND ENT_SNS_CLIENT.scope_id = 1 AND ENT_SNS_CLIENT.VT_start_date <= DATEADD(SECOND, 59,
                          DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date)))) AND (ENT_SNS_CLIENT.VT_end_date IS NULL OR
                         ENT_SNS_CLIENT.VT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.value_date))))) AND (CHARS.invoice_date IS NULL AND 
                         ENT_SNS_CLIENT.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND ENT_SNS_CLIENT.AT_start_date <= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) AND 
                         (ENT_SNS_CLIENT.AT_end_date IS NULL OR
                         CHARS.invoice_date IS NULL AND ENT_SNS_CLIENT.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, GETDATE())))) OR
                         CHARS.invoice_date IS NOT NULL AND ENT_SNS_CLIENT.AT_end_date >= DATEADD(SECOND, 59, DATEADD(MINUTE, 59, DATEADD(HOUR, 23, CONVERT(DATETIME, CHARS.invoice_date))))) INNER JOIN
                         dbo.UNITS AS UNI ON CON_SNS.unit_id = UNI.id LEFT OUTER JOIN
                         dbo.SUBLEDGERS AS SBL ON BCS.id = SBL.billable_concept_id AND CHARS.account_id = SBL.account_id LEFT OUTER JOIN
                         dbo.CONSUMPTIONS AS CONS ON CHARS.id = CONS.charge_id

GO
/****** Object:  View [dbo].[APP_SNAPSHOTS_VIEW]    Script Date: 03/08/2018 14:19:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[APP_SNAPSHOTS_VIEW]
AS
SELECT        id, entity_id, 6 AS type_id, AT_start_date, AT_start_user, AT_end_date, AT_end_user, VT_start_date, VT_end_date, scope_id
FROM            dbo.ACCOUNTS_SNAPSHOTS
UNION ALL
SELECT        id, entity_id, 9 AS type_id, AT_start_date, AT_start_user, AT_end_date, AT_end_user, VT_start_date, VT_end_date, scope_id
FROM            dbo.BILLABLE_CONCEPTS_SNAPSHOTS
UNION ALL
SELECT        id, entity_id, 8 AS type_id, AT_start_date, AT_start_user, AT_end_date, AT_end_user, VT_start_date, VT_end_date, scope_id
FROM            dbo.CONCEPTS_SNAPSHOTS
UNION ALL
SELECT        id, entity_id, 5 AS type_id, AT_start_date, AT_start_user, AT_end_date, AT_end_user, VT_start_date, VT_end_date, scope_id
FROM            dbo.DEPARTMENTS_SNAPSHOTS
UNION ALL
SELECT        id, entity_id, 4 AS type_id, AT_start_date, AT_start_user, AT_end_date, AT_end_user, VT_start_date, VT_end_date, scope_id
FROM            dbo.ENTERPRISES_SNAPSHOTS
UNION ALL
SELECT        id, entity_id, 24 AS type_id, AT_start_date, AT_start_user, AT_end_date, AT_end_user, VT_start_date, VT_end_date, scope_id
FROM            dbo.ISSUER_UNITS_SNAPSHOTS
UNION ALL
SELECT        id, entity_id, 10 AS type_id, AT_start_date, AT_start_user, AT_end_date, AT_end_user, VT_start_date, VT_end_date, scope_id
FROM            dbo.RATES_SNAPSHOTS
UNION ALL
SELECT        id, entity_id, 7 AS type_id, AT_start_date, AT_start_user, AT_end_date, AT_end_user, VT_start_date, VT_end_date, scope_id
FROM            dbo.SERVICES_SNAPSHOTS
UNION ALL
SELECT        id, entity_id, 11 AS type_id, AT_start_date, AT_start_user, AT_end_date, AT_end_user, VT_start_date, VT_end_date, scope_id
FROM            dbo.SPECIAL_RATESDISCOUNTS_SNAPSHOTS
UNION ALL
SELECT        id, entity_id, 2 AS type_id, AT_start_date, AT_start_user, AT_end_date, AT_end_user, VT_start_date, VT_end_date, scope_id
FROM            dbo.USERS_SNAPSHOTS
UNION ALL
SELECT        id, entity_id, 3 AS type_id, AT_start_date, AT_start_user, AT_end_date, AT_end_user, VT_start_date, VT_end_date, scope_id
FROM            dbo.DIVISIONS_SNAPSHOTS

GO
/****** Object:  View [dbo].[GET_ESTRUCTURA_ORGANIZATIVA]    Script Date: 03/08/2018 14:19:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[GET_ESTRUCTURA_ORGANIZATIVA]
AS
SELECT        TOP (100) PERCENT sp.id,
                             (SELECT        code
                               FROM            dbo.ENTERPRISES_SNAPSHOTS AS ee
                               WHERE        (entity_id = ac.enterprise_id) AND (AT_end_date IS NULL)) AS EMP,
                             (SELECT        name
                               FROM            dbo.ENTERPRISES_SNAPSHOTS AS ee
                               WHERE        (entity_id = ac.enterprise_id) AND (AT_end_date IS NULL)) AS EMP_DESC, sp.code AS JDE, sp.abreviatura, sp.name AS DescCC,
                             (SELECT        name
                               FROM            dbo.DEPARTMENTS_SNAPSHOTS AS dp
                               WHERE        (entity_id = sp.department_id) AND (AT_end_date IS NULL)) AS DEP, sp.department_id, sp.division_id,
                             (SELECT        name
                               FROM            dbo.DIVISIONS_SNAPSHOTS AS DIV
                               WHERE        (entity_id = sp.division_id) AND (AT_end_date IS NULL)) AS DIVI, sp.AT_end_date, sp.entity_id
FROM            dbo.ACCOUNTS_SNAPSHOTS AS sp INNER JOIN
                         dbo.ACCOUNTS AS ac ON ac.id = sp.entity_id
WHERE        (ac.TT_end_date IS NULL) AND (sp.AT_end_date IS NULL)
ORDER BY DIVI, EMP, DEP, sp.abreviatura

GO
/****** Object:  View [dbo].[NEW_DIVISIONS]    Script Date: 03/08/2018 14:19:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[NEW_DIVISIONS]
AS
SELECT        TOP (100) PERCENT dbo.DIVISIONS.id, dbo.DIVISIONS_SNAPSHOTS.code, dbo.DIVISIONS_SNAPSHOTS.name, dbo.DIVISIONS.TT_start_date, dbo.DIVISIONS.TT_end_date, dbo.DIVISIONS.TT_start_user, 
                         dbo.DIVISIONS.TT_end_user, dbo.DIVISIONS_SNAPSHOTS.VT_start_date, dbo.DIVISIONS_SNAPSHOTS.VT_end_date, dbo.DIVISIONS.last_change_date, dbo.DIVISIONS.last_change_user
FROM            dbo.DIVISIONS INNER JOIN
                         dbo.DIVISIONS_SNAPSHOTS ON dbo.DIVISIONS.id = dbo.DIVISIONS_SNAPSHOTS.entity_id AND (dbo.DIVISIONS_SNAPSHOTS.AT_end_date IS NULL OR
                         dbo.DIVISIONS_SNAPSHOTS.AT_end_date >= dbo.DIVISIONS.TT_end_date)
ORDER BY dbo.DIVISIONS.id

GO
/****** Object:  Index [IX_SUBLEDGERS]    Script Date: 03/08/2018 14:19:03 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_SUBLEDGERS] ON [dbo].[SUBLEDGERS]
(
	[account_id] ASC,
	[billable_concept_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ACCOUNTS] ADD  CONSTRAINT [DF__ACCOUNTS__TT_sta__22F50DB0]  DEFAULT ('2001-01-01 00:00:00') FOR [TT_start_date]
GO
ALTER TABLE [dbo].[ACCOUNTS] ADD  CONSTRAINT [DF__ACCOUNTS__TT_sta__23E931E9]  DEFAULT ((44542)) FOR [TT_start_user]
GO
ALTER TABLE [dbo].[ACCOUNTS] ADD  CONSTRAINT [DF__ACCOUNTS__last_c__24DD5622]  DEFAULT (getdate()) FOR [last_change_date]
GO
ALTER TABLE [dbo].[ACCOUNTS] ADD  CONSTRAINT [DF__ACCOUNTS__last_c__25D17A5B]  DEFAULT ((44542)) FOR [last_change_user]
GO
ALTER TABLE [dbo].[ACCOUNTS_SNAPSHOTS] ADD  CONSTRAINT [DF__ACCOUNTS___AT_st__5A7A4CC4]  DEFAULT ('2001-01-01 00:00:00') FOR [AT_start_date]
GO
ALTER TABLE [dbo].[ACCOUNTS_SNAPSHOTS] ADD  CONSTRAINT [DF__ACCOUNTS___AT_st__5B6E70FD]  DEFAULT ((44542)) FOR [AT_start_user]
GO
ALTER TABLE [dbo].[ACCOUNTS_SNAPSHOTS] ADD  CONSTRAINT [DF__ACCOUNTS___VT_st__5C629536]  DEFAULT ('2001-01-01') FOR [VT_start_date]
GO
ALTER TABLE [dbo].[ACCOUNTS_SNAPSHOTS] ADD  CONSTRAINT [DF__ACCOUNTS___scope__5D56B96F]  DEFAULT ((1)) FOR [scope_id]
GO
ALTER TABLE [dbo].[BILL_CLIENT_MERGE_TYPES] ADD  DEFAULT (' ') FOR [description]
GO
ALTER TABLE [dbo].[BILL_CLIENTS] ADD  CONSTRAINT [DF_BILL_ORDER_CLIENTS_isActive]  DEFAULT ((1)) FOR [isActive]
GO
ALTER TABLE [dbo].[BILL_CLIENTS] ADD  CONSTRAINT [DF_BILL_ORDER_CLIENTS_updated]  DEFAULT ((0)) FOR [updated]
GO
ALTER TABLE [dbo].[BILL_CLIENTS] ADD  CONSTRAINT [DF__BILL_CLIE__TT_st__79BDEDF3]  DEFAULT ('2001-01-01 00:00:00') FOR [TT_start_date]
GO
ALTER TABLE [dbo].[BILL_CLIENTS] ADD  CONSTRAINT [DF__BILL_CLIE__TT_st__7AB2122C]  DEFAULT ((44542)) FOR [TT_start_user]
GO
ALTER TABLE [dbo].[BILL_CLIENTS] ADD  CONSTRAINT [DF__BILL_CLIE__last___7BA63665]  DEFAULT ('2014-11-06 11:04:00') FOR [last_change_date]
GO
ALTER TABLE [dbo].[BILL_CLIENTS] ADD  CONSTRAINT [DF__BILL_CLIE__last___7C9A5A9E]  DEFAULT ((44542)) FOR [last_change_user]
GO
ALTER TABLE [dbo].[BILL_ENTRIES] ADD  DEFAULT ((1)) FOR [tax_area]
GO
ALTER TABLE [dbo].[BILL_MERGES] ADD  CONSTRAINT [DF__BILL_MERG__TT_st__7D8E7ED7]  DEFAULT ('2001-01-01 00:00:00') FOR [TT_start_date]
GO
ALTER TABLE [dbo].[BILL_MERGES] ADD  CONSTRAINT [DF__BILL_MERG__TT_st__7E82A310]  DEFAULT ((44542)) FOR [TT_start_user]
GO
ALTER TABLE [dbo].[BILL_MERGES] ADD  CONSTRAINT [DF__BILL_MERG__last___7F76C749]  DEFAULT (getdate()) FOR [last_change_date]
GO
ALTER TABLE [dbo].[BILL_MERGES] ADD  CONSTRAINT [DF__BILL_MERG__last___006AEB82]  DEFAULT ((44542)) FOR [last_change_user]
GO
ALTER TABLE [dbo].[BILL_ORDERS] ADD  DEFAULT ((1)) FOR [scope_id]
GO
ALTER TABLE [dbo].[BILL_ORDERS] ADD  DEFAULT ((1)) FOR [bill_doc_type]
GO
ALTER TABLE [dbo].[BILLABLE_CONCEPTS] ADD  CONSTRAINT [DF__BILLABLE___TT_st__2E66C05C]  DEFAULT ('2001-01-01 00:00:00') FOR [TT_start_date]
GO
ALTER TABLE [dbo].[BILLABLE_CONCEPTS] ADD  CONSTRAINT [DF__BILLABLE___TT_st__2F5AE495]  DEFAULT ((44542)) FOR [TT_start_user]
GO
ALTER TABLE [dbo].[BILLABLE_CONCEPTS] ADD  CONSTRAINT [DF__BILLABLE___last___304F08CE]  DEFAULT (getdate()) FOR [last_change_date]
GO
ALTER TABLE [dbo].[BILLABLE_CONCEPTS] ADD  CONSTRAINT [DF__BILLABLE___last___31432D07]  DEFAULT ((44542)) FOR [last_change_user]
GO
ALTER TABLE [dbo].[BILLABLE_CONCEPTS_SNAPSHOTS] ADD  CONSTRAINT [DF__BILLABLE___AT_st__76226739]  DEFAULT ('2001-01-01 00:00:00.000') FOR [AT_start_date]
GO
ALTER TABLE [dbo].[BILLABLE_CONCEPTS_SNAPSHOTS] ADD  CONSTRAINT [DF__BILLABLE___AT_st__77168B72]  DEFAULT ((44542)) FOR [AT_start_user]
GO
ALTER TABLE [dbo].[BILLABLE_CONCEPTS_SNAPSHOTS] ADD  CONSTRAINT [DF__BILLABLE___VT_st__780AAFAB]  DEFAULT ('2001-01-01') FOR [VT_start_date]
GO
ALTER TABLE [dbo].[BILLABLE_CONCEPTS_SNAPSHOTS] ADD  CONSTRAINT [DF__BILLABLE___scope__78FED3E4]  DEFAULT ((1)) FOR [scope_id]
GO
ALTER TABLE [dbo].[BILLABLE_CONCEPTS_SNAPSHOTS] ADD  DEFAULT ((1)) FOR [tax_type]
GO
ALTER TABLE [dbo].[CHARGES] ADD  CONSTRAINT [DF_CHARGES_workflow_state]  DEFAULT ((1)) FOR [workflow_state]
GO
ALTER TABLE [dbo].[CHARGES] ADD  CONSTRAINT [DF_CHARGES_isInvoiced]  DEFAULT ((0)) FOR [is_invoiced]
GO
ALTER TABLE [dbo].[CHARGES] ADD  CONSTRAINT [DF__CHARGES__is_sent__39D87308]  DEFAULT ((0)) FOR [is_sent_to_jde]
GO
ALTER TABLE [dbo].[CHARGES] ADD  CONSTRAINT [DF__CHARGES__scope_i__3ACC9741]  DEFAULT ((1)) FOR [scope_id]
GO
ALTER TABLE [dbo].[CONCEPTS] ADD  CONSTRAINT [DF__CONCEPTS__TT_sta__2A962F78]  DEFAULT ('2001-01-01 00:00:00') FOR [TT_start_date]
GO
ALTER TABLE [dbo].[CONCEPTS] ADD  CONSTRAINT [DF__CONCEPTS__TT_sta__2B8A53B1]  DEFAULT ((44542)) FOR [TT_start_user]
GO
ALTER TABLE [dbo].[CONCEPTS] ADD  CONSTRAINT [DF__CONCEPTS__last_c__2C7E77EA]  DEFAULT (getdate()) FOR [last_change_date]
GO
ALTER TABLE [dbo].[CONCEPTS] ADD  CONSTRAINT [DF__CONCEPTS__last_c__2D729C23]  DEFAULT ((44542)) FOR [last_change_user]
GO
ALTER TABLE [dbo].[CONCEPTS_SNAPSHOTS] ADD  CONSTRAINT [DF__CONCEPTS___AT_st__6C98FCFF]  DEFAULT ('2001-01-01 00:00:00') FOR [AT_start_date]
GO
ALTER TABLE [dbo].[CONCEPTS_SNAPSHOTS] ADD  CONSTRAINT [DF__CONCEPTS___AT_st__6D8D2138]  DEFAULT ((44542)) FOR [AT_start_user]
GO
ALTER TABLE [dbo].[CONCEPTS_SNAPSHOTS] ADD  CONSTRAINT [DF__CONCEPTS___VT_st__6E814571]  DEFAULT ('2001-01-01') FOR [VT_start_date]
GO
ALTER TABLE [dbo].[CONCEPTS_SNAPSHOTS] ADD  CONSTRAINT [DF__CONCEPTS___scope__6F7569AA]  DEFAULT ((1)) FOR [scope_id]
GO
ALTER TABLE [dbo].[CONSUMPTIONS] ADD  CONSTRAINT [DF__CONSUMPTI__is_ch__3CB4DFB3]  DEFAULT ((0)) FOR [is_charged]
GO
ALTER TABLE [dbo].[CONSUMPTIONS] ADD  CONSTRAINT [DF__CONSUMPTI__scope__3DA903EC]  DEFAULT ((1)) FOR [scope_id]
GO
ALTER TABLE [dbo].[CONSUMPTIONS] ADD  CONSTRAINT [DF_CONSUMPTIONS_is_percentage]  DEFAULT ((0)) FOR [is_percentage]
GO
ALTER TABLE [dbo].[DEPARTMENTS] ADD  CONSTRAINT [DF__DEPARTMEN__TT_st__1B53EBE8]  DEFAULT ('2001-01-01 00:00:00') FOR [TT_start_date]
GO
ALTER TABLE [dbo].[DEPARTMENTS] ADD  CONSTRAINT [DF__DEPARTMEN__TT_st__1C481021]  DEFAULT ((44542)) FOR [TT_start_user]
GO
ALTER TABLE [dbo].[DEPARTMENTS] ADD  CONSTRAINT [DF__DEPARTMEN__last___1D3C345A]  DEFAULT (getdate()) FOR [last_change_date]
GO
ALTER TABLE [dbo].[DEPARTMENTS] ADD  CONSTRAINT [DF__DEPARTMEN__last___1E305893]  DEFAULT ((44542)) FOR [last_change_user]
GO
ALTER TABLE [dbo].[DEPARTMENTS_SNAPSHOTS] ADD  CONSTRAINT [DF__DEPARTMEN__AT_st__494FC0C2]  DEFAULT ('2001-01-01 00:00:00') FOR [AT_start_date]
GO
ALTER TABLE [dbo].[DEPARTMENTS_SNAPSHOTS] ADD  CONSTRAINT [DF__DEPARTMEN__AT_st__4A43E4FB]  DEFAULT ((44542)) FOR [AT_start_user]
GO
ALTER TABLE [dbo].[DEPARTMENTS_SNAPSHOTS] ADD  CONSTRAINT [DF__DEPARTMEN__VT_st__4B380934]  DEFAULT ('2001-01-01') FOR [VT_start_date]
GO
ALTER TABLE [dbo].[DEPARTMENTS_SNAPSHOTS] ADD  CONSTRAINT [DF__DEPARTMEN__scope__4C2C2D6D]  DEFAULT ((1)) FOR [scope_id]
GO
ALTER TABLE [dbo].[DIVISIONS] ADD  CONSTRAINT [DF__DIVISIONS__TT_st__13B2CA20]  DEFAULT ('2001-01-01 00:00:00') FOR [TT_start_date]
GO
ALTER TABLE [dbo].[DIVISIONS] ADD  CONSTRAINT [DF__DIVISIONS__TT_st__14A6EE59]  DEFAULT ((44542)) FOR [TT_start_user]
GO
ALTER TABLE [dbo].[DIVISIONS] ADD  CONSTRAINT [DF__DIVISIONS__last___159B1292]  DEFAULT (getdate()) FOR [last_change_date]
GO
ALTER TABLE [dbo].[DIVISIONS] ADD  CONSTRAINT [DF__DIVISIONS__last___168F36CB]  DEFAULT ((44542)) FOR [last_change_user]
GO
ALTER TABLE [dbo].[DIVISIONS_SNAPSHOTS] ADD  CONSTRAINT [DF__DIVISIONS__AT_st__3548C815]  DEFAULT ('2001-01-01 00:00:00') FOR [AT_start_date]
GO
ALTER TABLE [dbo].[DIVISIONS_SNAPSHOTS] ADD  CONSTRAINT [DF__DIVISIONS__AT_st__363CEC4E]  DEFAULT ((44542)) FOR [AT_start_user]
GO
ALTER TABLE [dbo].[DIVISIONS_SNAPSHOTS] ADD  CONSTRAINT [DF__DIVISIONS__VT_st__37311087]  DEFAULT ('2001-01-01') FOR [VT_start_date]
GO
ALTER TABLE [dbo].[DIVISIONS_SNAPSHOTS] ADD  CONSTRAINT [DF__DIVISIONS__scope__382534C0]  DEFAULT ((1)) FOR [scope_id]
GO
ALTER TABLE [dbo].[ENTERPRISES] ADD  CONSTRAINT [DF__ENTERPRIS__TT_st__17835B04]  DEFAULT ('2001-01-01 00:00:00') FOR [TT_start_date]
GO
ALTER TABLE [dbo].[ENTERPRISES] ADD  CONSTRAINT [DF__ENTERPRIS__TT_st__18777F3D]  DEFAULT ((44542)) FOR [TT_start_user]
GO
ALTER TABLE [dbo].[ENTERPRISES] ADD  CONSTRAINT [DF__ENTERPRIS__last___196BA376]  DEFAULT (getdate()) FOR [last_change_date]
GO
ALTER TABLE [dbo].[ENTERPRISES] ADD  CONSTRAINT [DF__ENTERPRIS__last___1A5FC7AF]  DEFAULT ((44542)) FOR [last_change_user]
GO
ALTER TABLE [dbo].[ENTERPRISES_SNAPSHOTS] ADD  CONSTRAINT [DF_ENTERPRISES_SNAPSHOTS_receives_bills]  DEFAULT ((0)) FOR [receive_bills]
GO
ALTER TABLE [dbo].[ENTERPRISES_SNAPSHOTS] ADD  CONSTRAINT [DF_ENTERPRISES_SNAPSHOTS_discarded]  DEFAULT ((0)) FOR [send_bills]
GO
ALTER TABLE [dbo].[ENTERPRISES_SNAPSHOTS] ADD  CONSTRAINT [DF_ENTERPRISES_SNAPSHOTS_isExternal]  DEFAULT ((0)) FOR [isExternal]
GO
ALTER TABLE [dbo].[ENTERPRISES_SNAPSHOTS] ADD  CONSTRAINT [DF__ENTERPRIS__AT_st__3DDE0E16]  DEFAULT ('2001-01-01 00:00:00') FOR [AT_start_date]
GO
ALTER TABLE [dbo].[ENTERPRISES_SNAPSHOTS] ADD  CONSTRAINT [DF__ENTERPRIS__AT_st__3ED2324F]  DEFAULT ((44542)) FOR [AT_start_user]
GO
ALTER TABLE [dbo].[ENTERPRISES_SNAPSHOTS] ADD  CONSTRAINT [DF__ENTERPRIS__VT_st__3FC65688]  DEFAULT ('2001-01-01') FOR [VT_start_date]
GO
ALTER TABLE [dbo].[ENTERPRISES_SNAPSHOTS] ADD  CONSTRAINT [DF__ENTERPRIS__scope__40BA7AC1]  DEFAULT ((1)) FOR [scope_id]
GO
ALTER TABLE [dbo].[ENTERPRISES_SNAPSHOTS] ADD  DEFAULT ((1)) FOR [tax_client_type]
GO
ALTER TABLE [dbo].[ENTITY_TYPES] ADD  DEFAULT ((0)) FOR [isVTcalcDependent]
GO
ALTER TABLE [dbo].[ERRORS] ADD  CONSTRAINT [DF_ERRORS_isOK]  DEFAULT ((0)) FOR [isOK]
GO
ALTER TABLE [dbo].[IMPORT_ABSIS_ENTITY_PROPERTY_TYPES] ADD  DEFAULT ((0)) FOR [with_equivalent_value]
GO
ALTER TABLE [dbo].[ISSUER_UNITS] ADD  CONSTRAINT [DF__ISSUER_UN__TT_st__1F247CCC]  DEFAULT ('2001-01-01 00:00:00') FOR [TT_start_date]
GO
ALTER TABLE [dbo].[ISSUER_UNITS] ADD  CONSTRAINT [DF__ISSUER_UN__TT_st__2018A105]  DEFAULT ((44542)) FOR [TT_start_user]
GO
ALTER TABLE [dbo].[ISSUER_UNITS] ADD  CONSTRAINT [DF__ISSUER_UN__last___210CC53E]  DEFAULT (getdate()) FOR [last_change_date]
GO
ALTER TABLE [dbo].[ISSUER_UNITS] ADD  CONSTRAINT [DF__ISSUER_UN__last___2200E977]  DEFAULT ((44542)) FOR [last_change_user]
GO
ALTER TABLE [dbo].[ISSUER_UNITS_SNAPSHOTS] ADD  CONSTRAINT [DF__ISSUER_UN__AT_st__51E506C3]  DEFAULT ('2001-01-01 00:00:00') FOR [AT_start_date]
GO
ALTER TABLE [dbo].[ISSUER_UNITS_SNAPSHOTS] ADD  CONSTRAINT [DF__ISSUER_UN__AT_st__52D92AFC]  DEFAULT ((44542)) FOR [AT_start_user]
GO
ALTER TABLE [dbo].[ISSUER_UNITS_SNAPSHOTS] ADD  CONSTRAINT [DF__ISSUER_UN__VT_st__53CD4F35]  DEFAULT ('2001-01-01') FOR [VT_start_date]
GO
ALTER TABLE [dbo].[ISSUER_UNITS_SNAPSHOTS] ADD  CONSTRAINT [DF__ISSUER_UN__scope__54C1736E]  DEFAULT ((1)) FOR [scope_id]
GO
ALTER TABLE [dbo].[PERIOD_GROUPING] ADD  DEFAULT ((1)) FOR [period_type]
GO
ALTER TABLE [dbo].[PERIOD_GROUPING] ADD  DEFAULT ((0)) FOR [value_date]
GO
ALTER TABLE [dbo].[PROCESSES] ADD  CONSTRAINT [DF__PROCESSES__TT_st__025333F4]  DEFAULT ('2001-01-01 00:00:00.000') FOR [TT_start_date]
GO
ALTER TABLE [dbo].[PROCESSES] ADD  CONSTRAINT [DF__PROCESSES__TT_st__0347582D]  DEFAULT ((44542)) FOR [TT_start_user]
GO
ALTER TABLE [dbo].[PROCESSES] ADD  CONSTRAINT [DF__PROCESSES__last___043B7C66]  DEFAULT (getdate()) FOR [last_change_date]
GO
ALTER TABLE [dbo].[PROCESSES] ADD  CONSTRAINT [DF__PROCESSES__last___052FA09F]  DEFAULT ((44542)) FOR [last_change_user]
GO
ALTER TABLE [dbo].[RATES] ADD  CONSTRAINT [DF__RATES__TT_start___32375140]  DEFAULT ('2001-01-01 00:00:00') FOR [TT_start_date]
GO
ALTER TABLE [dbo].[RATES] ADD  CONSTRAINT [DF__RATES__TT_start___332B7579]  DEFAULT ((44542)) FOR [TT_start_user]
GO
ALTER TABLE [dbo].[RATES] ADD  CONSTRAINT [DF__RATES__last_chan__341F99B2]  DEFAULT (getdate()) FOR [last_change_date]
GO
ALTER TABLE [dbo].[RATES] ADD  CONSTRAINT [DF__RATES__last_chan__3513BDEB]  DEFAULT ((44542)) FOR [last_change_user]
GO
ALTER TABLE [dbo].[RATES_SNAPSHOTS] ADD  CONSTRAINT [DF__RATES_SNA__AT_st__7FABD173]  DEFAULT ('2001-01-01 00:00:00') FOR [AT_start_date]
GO
ALTER TABLE [dbo].[RATES_SNAPSHOTS] ADD  CONSTRAINT [DF__RATES_SNA__AT_st__009FF5AC]  DEFAULT ((44542)) FOR [AT_start_user]
GO
ALTER TABLE [dbo].[RATES_SNAPSHOTS] ADD  CONSTRAINT [DF__RATES_SNA__VT_st__019419E5]  DEFAULT ('2001-01-01') FOR [VT_start_date]
GO
ALTER TABLE [dbo].[RATES_SNAPSHOTS] ADD  CONSTRAINT [DF__RATES_SNA__scope__02883E1E]  DEFAULT ((1)) FOR [scope_id]
GO
ALTER TABLE [dbo].[ROLE_PERMISSIONS] ADD  DEFAULT ((0)) FOR [entity_scope]
GO
ALTER TABLE [dbo].[SERVICES] ADD  CONSTRAINT [DF__SERVICES__TT_sta__26C59E94]  DEFAULT ('2001-01-01 00:00:00') FOR [TT_start_date]
GO
ALTER TABLE [dbo].[SERVICES] ADD  CONSTRAINT [DF__SERVICES__TT_sta__27B9C2CD]  DEFAULT ((44542)) FOR [TT_start_user]
GO
ALTER TABLE [dbo].[SERVICES] ADD  CONSTRAINT [DF__SERVICES__last_c__28ADE706]  DEFAULT (getdate()) FOR [last_change_date]
GO
ALTER TABLE [dbo].[SERVICES] ADD  CONSTRAINT [DF__SERVICES__last_c__29A20B3F]  DEFAULT ((44542)) FOR [last_change_user]
GO
ALTER TABLE [dbo].[SERVICES_SNAPSHOTS] ADD  CONSTRAINT [DF__SERVICES___AT_st__630F92C5]  DEFAULT ('2001-01-01 00:00:00') FOR [AT_start_date]
GO
ALTER TABLE [dbo].[SERVICES_SNAPSHOTS] ADD  CONSTRAINT [DF__SERVICES___AT_st__6403B6FE]  DEFAULT ((44542)) FOR [AT_start_user]
GO
ALTER TABLE [dbo].[SERVICES_SNAPSHOTS] ADD  CONSTRAINT [DF__SERVICES___VT_st__64F7DB37]  DEFAULT ('2001-01-01') FOR [VT_start_date]
GO
ALTER TABLE [dbo].[SERVICES_SNAPSHOTS] ADD  CONSTRAINT [DF__SERVICES___scope__65EBFF70]  DEFAULT ((1)) FOR [scope_id]
GO
ALTER TABLE [dbo].[SPECIAL_RATEDISCOUNT_ACCOUNTS] ADD  CONSTRAINT [DF__SPECIAL_R__AT_st__4826925F]  DEFAULT ('2001-01-01 00:00:00') FOR [AT_start_date]
GO
ALTER TABLE [dbo].[SPECIAL_RATEDISCOUNT_ACCOUNTS] ADD  CONSTRAINT [DF__SPECIAL_R__AT_st__491AB698]  DEFAULT ((44542)) FOR [AT_start_user]
GO
ALTER TABLE [dbo].[SPECIAL_RATEDISCOUNT_ACCOUNTS] ADD  CONSTRAINT [DF__SPECIAL_R__VT_st__4A0EDAD1]  DEFAULT ('2001-01-01') FOR [VT_start_date]
GO
ALTER TABLE [dbo].[SPECIAL_RATEDISCOUNT_ACCOUNTS] ADD  CONSTRAINT [DF__SPECIAL_R__scope__4B02FF0A]  DEFAULT ((1)) FOR [scope_id]
GO
ALTER TABLE [dbo].[SPECIAL_RATEDISCOUNT_ACCOUNTS] ADD  CONSTRAINT [DF_SPECIAL_RATEDISCOUNT_ACCOUNTS_create_date]  DEFAULT (getdate()) FOR [create_date]
GO
ALTER TABLE [dbo].[SPECIAL_RATESDISCOUNTS] ADD  CONSTRAINT [DF__SPECIAL_R__TT_st__3607E224]  DEFAULT ('2001-01-01 00:00:00') FOR [TT_start_date]
GO
ALTER TABLE [dbo].[SPECIAL_RATESDISCOUNTS] ADD  CONSTRAINT [DF__SPECIAL_R__TT_st__36FC065D]  DEFAULT ((44542)) FOR [TT_start_user]
GO
ALTER TABLE [dbo].[SPECIAL_RATESDISCOUNTS] ADD  CONSTRAINT [DF__SPECIAL_R__last___37F02A96]  DEFAULT (getdate()) FOR [last_change_date]
GO
ALTER TABLE [dbo].[SPECIAL_RATESDISCOUNTS] ADD  CONSTRAINT [DF__SPECIAL_R__last___38E44ECF]  DEFAULT ((44542)) FOR [last_change_user]
GO
ALTER TABLE [dbo].[SPECIAL_RATESDISCOUNTS_SNAPSHOTS] ADD  CONSTRAINT [DF__SPECIAL_R__AT_st__08411774]  DEFAULT ('2001-01-01 00:00:00') FOR [AT_start_date]
GO
ALTER TABLE [dbo].[SPECIAL_RATESDISCOUNTS_SNAPSHOTS] ADD  CONSTRAINT [DF__SPECIAL_R__AT_st__09353BAD]  DEFAULT ((44542)) FOR [AT_start_user]
GO
ALTER TABLE [dbo].[SPECIAL_RATESDISCOUNTS_SNAPSHOTS] ADD  CONSTRAINT [DF__SPECIAL_R__VT_st__0A295FE6]  DEFAULT ('2001-01-01') FOR [VT_start_date]
GO
ALTER TABLE [dbo].[SPECIAL_RATESDISCOUNTS_SNAPSHOTS] ADD  CONSTRAINT [DF__SPECIAL_R__scope__0B1D841F]  DEFAULT ((1)) FOR [scope_id]
GO
ALTER TABLE [dbo].[SYSTEM_MODULES] ADD  CONSTRAINT [DF__SYSTEM_MO__AT_st__4FC7B427]  DEFAULT ('2001-01-01 00:00:00') FOR [AT_start_date]
GO
ALTER TABLE [dbo].[SYSTEM_MODULES] ADD  CONSTRAINT [DF__SYSTEM_MO__AT_st__50BBD860]  DEFAULT ((44542)) FOR [AT_start_user]
GO
ALTER TABLE [dbo].[SYSTEM_MODULES] ADD  CONSTRAINT [DF__SYSTEM_MO__VT_st__51AFFC99]  DEFAULT ('2001-01-01') FOR [VT_start_date]
GO
ALTER TABLE [dbo].[SYSTEM_MODULES] ADD  CONSTRAINT [DF__SYSTEM_MO__scope__52A420D2]  DEFAULT ((1)) FOR [scope_id]
GO
ALTER TABLE [dbo].[SYSTEMS] ADD  CONSTRAINT [DF__SYSTEMS__AT_star__55808D7D]  DEFAULT ('2001-01-01 00:00:00') FOR [AT_start_date]
GO
ALTER TABLE [dbo].[SYSTEMS] ADD  CONSTRAINT [DF__SYSTEMS__AT_star__5674B1B6]  DEFAULT ((44542)) FOR [AT_start_user]
GO
ALTER TABLE [dbo].[SYSTEMS] ADD  CONSTRAINT [DF__SYSTEMS__VT_star__5768D5EF]  DEFAULT ('2001-01-01') FOR [VT_start_date]
GO
ALTER TABLE [dbo].[SYSTEMS] ADD  CONSTRAINT [DF__SYSTEMS__scope_i__585CFA28]  DEFAULT ((1)) FOR [scope_id]
GO
ALTER TABLE [dbo].[TAX_AREAS] ADD  DEFAULT ((1)) FOR [bill_document_type_id]
GO
ALTER TABLE [dbo].[TICKET] ADD  CONSTRAINT [DF_TICKET_creation_datetime]  DEFAULT (getdate()) FOR [creation_datetime]
GO
ALTER TABLE [dbo].[UNITS] ADD  DEFAULT ((1)) FOR [consumable]
GO
ALTER TABLE [dbo].[USER_NOTIFICATIONS] ADD  CONSTRAINT [DF_USER_NOTIFICATIONS_seen]  DEFAULT ((0)) FOR [seen]
GO
ALTER TABLE [dbo].[USERS] ADD  CONSTRAINT [DF__USERS__TT_start___0EEE1503]  DEFAULT ('2001-01-01 00:00:00') FOR [TT_start_date]
GO
ALTER TABLE [dbo].[USERS] ADD  CONSTRAINT [DF__USERS__TT_start___0FE2393C]  DEFAULT ((44542)) FOR [TT_start_user]
GO
ALTER TABLE [dbo].[USERS] ADD  CONSTRAINT [DF__USERS__last_chan__10D65D75]  DEFAULT (getdate()) FOR [last_change_date]
GO
ALTER TABLE [dbo].[USERS] ADD  CONSTRAINT [DF__USERS__last_chan__11CA81AE]  DEFAULT ((44542)) FOR [last_change_user]
GO
ALTER TABLE [dbo].[USERS_SNAPSHOTS] ADD  CONSTRAINT [DF__USERS_SNA__AT_st__2CB38214]  DEFAULT ('2001-01-01 00:00:00') FOR [AT_start_date]
GO
ALTER TABLE [dbo].[USERS_SNAPSHOTS] ADD  CONSTRAINT [DF__USERS_SNA__AT_st__2DA7A64D]  DEFAULT ((44542)) FOR [AT_start_user]
GO
ALTER TABLE [dbo].[USERS_SNAPSHOTS] ADD  CONSTRAINT [DF__USERS_SNA__VT_st__2E9BCA86]  DEFAULT ('2001-01-01') FOR [VT_start_date]
GO
ALTER TABLE [dbo].[USERS_SNAPSHOTS] ADD  CONSTRAINT [DF__USERS_SNA__scope__2F8FEEBF]  DEFAULT ((1)) FOR [scope_id]
GO
ALTER TABLE [dbo].[ACCOUNTS]  WITH CHECK ADD  CONSTRAINT [FK_ACCOUNTS_ENTERPRISES] FOREIGN KEY([enterprise_id])
REFERENCES [dbo].[ENTERPRISES] ([id])
GO
ALTER TABLE [dbo].[ACCOUNTS] CHECK CONSTRAINT [FK_ACCOUNTS_ENTERPRISES]
GO
ALTER TABLE [dbo].[ACCOUNTS_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_ACCOUNTS_SNAPSHOTS_ACCOUNTS] FOREIGN KEY([entity_id])
REFERENCES [dbo].[ACCOUNTS] ([id])
GO
ALTER TABLE [dbo].[ACCOUNTS_SNAPSHOTS] CHECK CONSTRAINT [FK_ACCOUNTS_SNAPSHOTS_ACCOUNTS]
GO
ALTER TABLE [dbo].[ACCOUNTS_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_ACCOUNTS_SNAPSHOTS_END_USERS] FOREIGN KEY([AT_end_user])
REFERENCES [dbo].[USERS] ([id])
GO
ALTER TABLE [dbo].[ACCOUNTS_SNAPSHOTS] CHECK CONSTRAINT [FK_ACCOUNTS_SNAPSHOTS_END_USERS]
GO
ALTER TABLE [dbo].[ACCOUNTS_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_ACCOUNTS_SNAPSHOTS_START_USERS] FOREIGN KEY([AT_start_user])
REFERENCES [dbo].[USERS] ([id])
GO
ALTER TABLE [dbo].[ACCOUNTS_SNAPSHOTS] CHECK CONSTRAINT [FK_ACCOUNTS_SNAPSHOTS_START_USERS]
GO
ALTER TABLE [dbo].[BILL_CLIENTS]  WITH CHECK ADD  CONSTRAINT [FK_BILL_ORDER_CLIENTS_BILL_ORDER_CLIENTS1] FOREIGN KEY([id], [clientEnterpriseId])
REFERENCES [dbo].[BILL_CLIENTS] ([id], [clientEnterpriseId])
GO
ALTER TABLE [dbo].[BILL_CLIENTS] CHECK CONSTRAINT [FK_BILL_ORDER_CLIENTS_BILL_ORDER_CLIENTS1]
GO
ALTER TABLE [dbo].[BILL_ENTRIES]  WITH CHECK ADD  CONSTRAINT [FK_BILL_ENTRIES_BILL_ORDERS] FOREIGN KEY([bill_order_id])
REFERENCES [dbo].[BILL_ORDERS] ([id])
GO
ALTER TABLE [dbo].[BILL_ENTRIES] CHECK CONSTRAINT [FK_BILL_ENTRIES_BILL_ORDERS]
GO
ALTER TABLE [dbo].[BILL_ENTRIES]  WITH CHECK ADD  CONSTRAINT [FK_BILL_ENTRIES_TAX_AREAS] FOREIGN KEY([tax_area])
REFERENCES [dbo].[TAX_AREAS] ([id])
GO
ALTER TABLE [dbo].[BILL_ENTRIES] CHECK CONSTRAINT [FK_BILL_ENTRIES_TAX_AREAS]
GO
ALTER TABLE [dbo].[BILL_ENTRY_ITEMS]  WITH CHECK ADD  CONSTRAINT [FK_BILL_ENTRY_ITEMS_BILL_ENTRIES] FOREIGN KEY([bill_entry_id])
REFERENCES [dbo].[BILL_ENTRIES] ([id])
GO
ALTER TABLE [dbo].[BILL_ENTRY_ITEMS] CHECK CONSTRAINT [FK_BILL_ENTRY_ITEMS_BILL_ENTRIES]
GO
ALTER TABLE [dbo].[BILL_ENTRY_ITEMS]  WITH CHECK ADD  CONSTRAINT [FK_BILL_ENTRY_ITEMS_BILL_ENTRY_ITEM_TYPES] FOREIGN KEY([bill_entry_item_type_id])
REFERENCES [dbo].[BILL_ENTRY_ITEM_TYPES] ([id])
GO
ALTER TABLE [dbo].[BILL_ENTRY_ITEMS] CHECK CONSTRAINT [FK_BILL_ENTRY_ITEMS_BILL_ENTRY_ITEM_TYPES]
GO
ALTER TABLE [dbo].[BILL_MERGES]  WITH CHECK ADD  CONSTRAINT [FK_BILL_ORDERS_MERGES_ENTITY_TYPES] FOREIGN KEY([clientEntityType])
REFERENCES [dbo].[ENTITY_TYPES] ([id])
GO
ALTER TABLE [dbo].[BILL_MERGES] CHECK CONSTRAINT [FK_BILL_ORDERS_MERGES_ENTITY_TYPES]
GO
ALTER TABLE [dbo].[BILL_ORDERS]  WITH CHECK ADD  CONSTRAINT [FK_BILL_ORDERS_BILL_DOCUMENT_TYPES] FOREIGN KEY([bill_doc_type])
REFERENCES [dbo].[BILL_DOCUMENT_TYPES] ([id])
GO
ALTER TABLE [dbo].[BILL_ORDERS] CHECK CONSTRAINT [FK_BILL_ORDERS_BILL_DOCUMENT_TYPES]
GO
ALTER TABLE [dbo].[BILLABLE_CONCEPTS]  WITH CHECK ADD  CONSTRAINT [FK_BILLABLE_CONCEPT_CONCEPTS] FOREIGN KEY([concept_id])
REFERENCES [dbo].[CONCEPTS] ([id])
GO
ALTER TABLE [dbo].[BILLABLE_CONCEPTS] CHECK CONSTRAINT [FK_BILLABLE_CONCEPT_CONCEPTS]
GO
ALTER TABLE [dbo].[BILLABLE_CONCEPTS]  WITH CHECK ADD  CONSTRAINT [FK_BILLABLE_CONCEPT_SERVICES] FOREIGN KEY([service_id])
REFERENCES [dbo].[SERVICES] ([id])
GO
ALTER TABLE [dbo].[BILLABLE_CONCEPTS] CHECK CONSTRAINT [FK_BILLABLE_CONCEPT_SERVICES]
GO
ALTER TABLE [dbo].[BILLABLE_CONCEPTS_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_BILLABLE_CONCEPTS_SNAPSHOTS_ACCOUNTS] FOREIGN KEY([IN_account_id])
REFERENCES [dbo].[ACCOUNTS] ([id])
GO
ALTER TABLE [dbo].[BILLABLE_CONCEPTS_SNAPSHOTS] CHECK CONSTRAINT [FK_BILLABLE_CONCEPTS_SNAPSHOTS_ACCOUNTS]
GO
ALTER TABLE [dbo].[BILLABLE_CONCEPTS_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_BILLABLE_CONCEPTS_SNAPSHOTS_BILLABLE_CONCEPTS] FOREIGN KEY([entity_id])
REFERENCES [dbo].[BILLABLE_CONCEPTS] ([id])
GO
ALTER TABLE [dbo].[BILLABLE_CONCEPTS_SNAPSHOTS] CHECK CONSTRAINT [FK_BILLABLE_CONCEPTS_SNAPSHOTS_BILLABLE_CONCEPTS]
GO
ALTER TABLE [dbo].[BILLABLE_CONCEPTS_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_BILLABLE_CONCEPTS_SNAPSHOTS_END_USERS] FOREIGN KEY([AT_end_user])
REFERENCES [dbo].[USERS] ([id])
GO
ALTER TABLE [dbo].[BILLABLE_CONCEPTS_SNAPSHOTS] CHECK CONSTRAINT [FK_BILLABLE_CONCEPTS_SNAPSHOTS_END_USERS]
GO
ALTER TABLE [dbo].[BILLABLE_CONCEPTS_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_BILLABLE_CONCEPTS_SNAPSHOTS_START_USERS] FOREIGN KEY([AT_start_user])
REFERENCES [dbo].[USERS] ([id])
GO
ALTER TABLE [dbo].[BILLABLE_CONCEPTS_SNAPSHOTS] CHECK CONSTRAINT [FK_BILLABLE_CONCEPTS_SNAPSHOTS_START_USERS]
GO
ALTER TABLE [dbo].[CALENDAR]  WITH CHECK ADD  CONSTRAINT [FK_CALENDAR_CALENDAR_EVENT_STATES] FOREIGN KEY([event_state])
REFERENCES [dbo].[CALENDAR_EVENT_STATES] ([id])
GO
ALTER TABLE [dbo].[CALENDAR] CHECK CONSTRAINT [FK_CALENDAR_CALENDAR_EVENT_STATES]
GO
ALTER TABLE [dbo].[CALENDAR]  WITH CHECK ADD  CONSTRAINT [FK_CALENDAR_CALENDAR_EVENT_TYPES] FOREIGN KEY([event_type])
REFERENCES [dbo].[CALENDAR_EVENT_TYPES] ([id])
GO
ALTER TABLE [dbo].[CALENDAR] CHECK CONSTRAINT [FK_CALENDAR_CALENDAR_EVENT_TYPES]
GO
ALTER TABLE [dbo].[CHARGES]  WITH CHECK ADD  CONSTRAINT [FK_CHARGES_ACCOUNTS] FOREIGN KEY([account_id])
REFERENCES [dbo].[ACCOUNTS] ([id])
GO
ALTER TABLE [dbo].[CHARGES] CHECK CONSTRAINT [FK_CHARGES_ACCOUNTS]
GO
ALTER TABLE [dbo].[CHARGES]  WITH CHECK ADD  CONSTRAINT [FK_CHARGES_BILLABLE_CONCEPTS] FOREIGN KEY([billable_concept_id])
REFERENCES [dbo].[BILLABLE_CONCEPTS] ([id])
GO
ALTER TABLE [dbo].[CHARGES] CHECK CONSTRAINT [FK_CHARGES_BILLABLE_CONCEPTS]
GO
ALTER TABLE [dbo].[CHARGES]  WITH CHECK ADD  CONSTRAINT [FK_CHARGES_CHARGE_TYPES] FOREIGN KEY([charge_type_id])
REFERENCES [dbo].[CHARGE_TYPES] ([id])
GO
ALTER TABLE [dbo].[CHARGES] CHECK CONSTRAINT [FK_CHARGES_CHARGE_TYPES]
GO
ALTER TABLE [dbo].[CHARGES]  WITH CHECK ADD  CONSTRAINT [FK_CHARGES_ISSUER_UNITS] FOREIGN KEY([issuer_unit_id_OLD])
REFERENCES [dbo].[ISSUER_UNITS] ([id])
GO
ALTER TABLE [dbo].[CHARGES] CHECK CONSTRAINT [FK_CHARGES_ISSUER_UNITS]
GO
ALTER TABLE [dbo].[CONCEPT_FAMILY_RELATIONSHIPS]  WITH CHECK ADD  CONSTRAINT [FK_CONCEPT_FAMILY_RELATIONSHIPS_CONCEPT_FAMILIY] FOREIGN KEY([concept_family_id])
REFERENCES [dbo].[CONCEPT_FAMILIES] ([id])
GO
ALTER TABLE [dbo].[CONCEPT_FAMILY_RELATIONSHIPS] CHECK CONSTRAINT [FK_CONCEPT_FAMILY_RELATIONSHIPS_CONCEPT_FAMILIY]
GO
ALTER TABLE [dbo].[CONCEPT_FAMILY_RELATIONSHIPS]  WITH CHECK ADD  CONSTRAINT [FK_CONCEPT_FAMILY_RELATIONSHIPS_CONCEPTS] FOREIGN KEY([concept_id])
REFERENCES [dbo].[CONCEPTS] ([id])
GO
ALTER TABLE [dbo].[CONCEPT_FAMILY_RELATIONSHIPS] CHECK CONSTRAINT [FK_CONCEPT_FAMILY_RELATIONSHIPS_CONCEPTS]
GO
ALTER TABLE [dbo].[CONCEPTS_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_CONCEPTS_SNAPSHOTS_CONCEPTS] FOREIGN KEY([entity_id])
REFERENCES [dbo].[CONCEPTS] ([id])
GO
ALTER TABLE [dbo].[CONCEPTS_SNAPSHOTS] CHECK CONSTRAINT [FK_CONCEPTS_SNAPSHOTS_CONCEPTS]
GO
ALTER TABLE [dbo].[CONCEPTS_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_CONCEPTS_SNAPSHOTS_END_USERS] FOREIGN KEY([AT_end_user])
REFERENCES [dbo].[USERS] ([id])
GO
ALTER TABLE [dbo].[CONCEPTS_SNAPSHOTS] CHECK CONSTRAINT [FK_CONCEPTS_SNAPSHOTS_END_USERS]
GO
ALTER TABLE [dbo].[CONCEPTS_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_CONCEPTS_SNAPSHOTS_START_USERS] FOREIGN KEY([AT_start_user])
REFERENCES [dbo].[USERS] ([id])
GO
ALTER TABLE [dbo].[CONCEPTS_SNAPSHOTS] CHECK CONSTRAINT [FK_CONCEPTS_SNAPSHOTS_START_USERS]
GO
ALTER TABLE [dbo].[CONCEPTS_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_CONCEPTS_SNAPSHOTS_UNITS] FOREIGN KEY([unit_id])
REFERENCES [dbo].[UNITS] ([id])
GO
ALTER TABLE [dbo].[CONCEPTS_SNAPSHOTS] CHECK CONSTRAINT [FK_CONCEPTS_SNAPSHOTS_UNITS]
GO
ALTER TABLE [dbo].[CONDITIONS]  WITH CHECK ADD  CONSTRAINT [FK_CONDITIONS_CONDITION_TYPES] FOREIGN KEY([condition_type])
REFERENCES [dbo].[CONDITION_TYPES] ([id])
GO
ALTER TABLE [dbo].[CONDITIONS] CHECK CONSTRAINT [FK_CONDITIONS_CONDITION_TYPES]
GO
ALTER TABLE [dbo].[CONDITIONS]  WITH CHECK ADD  CONSTRAINT [FK_CONDITIONS_CONDITIONS] FOREIGN KEY([id])
REFERENCES [dbo].[CONDITIONS] ([id])
GO
ALTER TABLE [dbo].[CONDITIONS] CHECK CONSTRAINT [FK_CONDITIONS_CONDITIONS]
GO
ALTER TABLE [dbo].[CONDITIONS]  WITH CHECK ADD  CONSTRAINT [FK_CONDITIONS_ENTITY_TYPES] FOREIGN KEY([entity_type_filter])
REFERENCES [dbo].[ENTITY_TYPES] ([id])
GO
ALTER TABLE [dbo].[CONDITIONS] CHECK CONSTRAINT [FK_CONDITIONS_ENTITY_TYPES]
GO
ALTER TABLE [dbo].[CONSUMPTIONS]  WITH CHECK ADD  CONSTRAINT [FK_CONSUMPTION_CHARGES] FOREIGN KEY([charge_id])
REFERENCES [dbo].[CHARGES] ([id])
GO
ALTER TABLE [dbo].[CONSUMPTIONS] CHECK CONSTRAINT [FK_CONSUMPTION_CHARGES]
GO
ALTER TABLE [dbo].[CONSUMPTIONS]  WITH CHECK ADD  CONSTRAINT [FK_CONSUMPTION_ISSUER_UNITS] FOREIGN KEY([issuer_unit_id])
REFERENCES [dbo].[ISSUER_UNITS] ([id])
GO
ALTER TABLE [dbo].[CONSUMPTIONS] CHECK CONSTRAINT [FK_CONSUMPTION_ISSUER_UNITS]
GO
ALTER TABLE [dbo].[DEPARTMENTS]  WITH CHECK ADD  CONSTRAINT [FK_DEPARTMENTS_ENTERPRISES] FOREIGN KEY([idEnterprise])
REFERENCES [dbo].[ENTERPRISES] ([id])
GO
ALTER TABLE [dbo].[DEPARTMENTS] CHECK CONSTRAINT [FK_DEPARTMENTS_ENTERPRISES]
GO
ALTER TABLE [dbo].[DEPARTMENTS_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_DEPARTMENTS_SNAPSHOTS_DEPARTMENTS] FOREIGN KEY([entity_id])
REFERENCES [dbo].[DEPARTMENTS] ([id])
GO
ALTER TABLE [dbo].[DEPARTMENTS_SNAPSHOTS] CHECK CONSTRAINT [FK_DEPARTMENTS_SNAPSHOTS_DEPARTMENTS]
GO
ALTER TABLE [dbo].[DEPARTMENTS_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_DEPARTMENTS_SNAPSHOTS_END_USERS] FOREIGN KEY([AT_end_user])
REFERENCES [dbo].[USERS] ([id])
GO
ALTER TABLE [dbo].[DEPARTMENTS_SNAPSHOTS] CHECK CONSTRAINT [FK_DEPARTMENTS_SNAPSHOTS_END_USERS]
GO
ALTER TABLE [dbo].[DEPARTMENTS_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_DEPARTMENTS_SNAPSHOTS_START_USERS] FOREIGN KEY([AT_start_user])
REFERENCES [dbo].[USERS] ([id])
GO
ALTER TABLE [dbo].[DEPARTMENTS_SNAPSHOTS] CHECK CONSTRAINT [FK_DEPARTMENTS_SNAPSHOTS_START_USERS]
GO
ALTER TABLE [dbo].[DIVISIONS_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_DIVISIONS_SNAPSHOTS_DIVISIONS] FOREIGN KEY([entity_id])
REFERENCES [dbo].[DIVISIONS] ([id])
GO
ALTER TABLE [dbo].[DIVISIONS_SNAPSHOTS] CHECK CONSTRAINT [FK_DIVISIONS_SNAPSHOTS_DIVISIONS]
GO
ALTER TABLE [dbo].[DIVISIONS_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_DIVISIONS_SNAPSHOTS_END_USERS] FOREIGN KEY([AT_end_user])
REFERENCES [dbo].[USERS] ([id])
GO
ALTER TABLE [dbo].[DIVISIONS_SNAPSHOTS] CHECK CONSTRAINT [FK_DIVISIONS_SNAPSHOTS_END_USERS]
GO
ALTER TABLE [dbo].[DIVISIONS_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_DIVISIONS_SNAPSHOTS_START_USERS] FOREIGN KEY([AT_start_user])
REFERENCES [dbo].[USERS] ([id])
GO
ALTER TABLE [dbo].[DIVISIONS_SNAPSHOTS] CHECK CONSTRAINT [FK_DIVISIONS_SNAPSHOTS_START_USERS]
GO
ALTER TABLE [dbo].[ENTERPRISES_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_ENTERPRISES_SNAPSHOTS_END_USERS] FOREIGN KEY([AT_end_user])
REFERENCES [dbo].[USERS] ([id])
GO
ALTER TABLE [dbo].[ENTERPRISES_SNAPSHOTS] CHECK CONSTRAINT [FK_ENTERPRISES_SNAPSHOTS_END_USERS]
GO
ALTER TABLE [dbo].[ENTERPRISES_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_ENTERPRISES_SNAPSHOTS_ENTERPRISES] FOREIGN KEY([entity_id])
REFERENCES [dbo].[ENTERPRISES] ([id])
GO
ALTER TABLE [dbo].[ENTERPRISES_SNAPSHOTS] CHECK CONSTRAINT [FK_ENTERPRISES_SNAPSHOTS_ENTERPRISES]
GO
ALTER TABLE [dbo].[ENTERPRISES_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_ENTERPRISES_SNAPSHOTS_START_USERS] FOREIGN KEY([AT_start_user])
REFERENCES [dbo].[USERS] ([id])
GO
ALTER TABLE [dbo].[ENTERPRISES_SNAPSHOTS] CHECK CONSTRAINT [FK_ENTERPRISES_SNAPSHOTS_START_USERS]
GO
ALTER TABLE [dbo].[ENTERPRISES_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_ENTERPRISES_SNAPSHOTS_TAX_CLIENT_TYPES] FOREIGN KEY([tax_client_type])
REFERENCES [dbo].[TAX_CLIENT_TYPES] ([id])
GO
ALTER TABLE [dbo].[ENTERPRISES_SNAPSHOTS] CHECK CONSTRAINT [FK_ENTERPRISES_SNAPSHOTS_TAX_CLIENT_TYPES]
GO
ALTER TABLE [dbo].[ERRORS]  WITH CHECK ADD  CONSTRAINT [FK_ERRORS_ENTITY_TYPES] FOREIGN KEY([entity_type_id])
REFERENCES [dbo].[ENTITY_TYPES] ([id])
GO
ALTER TABLE [dbo].[ERRORS] CHECK CONSTRAINT [FK_ERRORS_ENTITY_TYPES]
GO
ALTER TABLE [dbo].[EXTERNAL_SYSTEM_EQUIVALENCES]  WITH CHECK ADD  CONSTRAINT [FK_EXTERNAL_SYSTEM_EQUIVALENCES_ENTITY_TYPES] FOREIGN KEY([entity_type_id])
REFERENCES [dbo].[ENTITY_TYPES] ([id])
GO
ALTER TABLE [dbo].[EXTERNAL_SYSTEM_EQUIVALENCES] CHECK CONSTRAINT [FK_EXTERNAL_SYSTEM_EQUIVALENCES_ENTITY_TYPES]
GO
ALTER TABLE [dbo].[IMPORT_ACTION]  WITH CHECK ADD  CONSTRAINT [FK_IMPORT_ACTION_ENTERPRISES] FOREIGN KEY([issuer_id])
REFERENCES [dbo].[ENTERPRISES] ([id])
GO
ALTER TABLE [dbo].[IMPORT_ACTION] CHECK CONSTRAINT [FK_IMPORT_ACTION_ENTERPRISES]
GO
ALTER TABLE [dbo].[IMPORT_ACTION]  WITH CHECK ADD  CONSTRAINT [FK_IMPORT_ACTION_IMPORTS] FOREIGN KEY([importer_id])
REFERENCES [dbo].[IMPORTS] ([id])
GO
ALTER TABLE [dbo].[IMPORT_ACTION] CHECK CONSTRAINT [FK_IMPORT_ACTION_IMPORTS]
GO
ALTER TABLE [dbo].[IMPORT_ENTITIES]  WITH CHECK ADD  CONSTRAINT [FK_IMPORT_ENTITIES_ENTITY_TYPES] FOREIGN KEY([entity_type_id])
REFERENCES [dbo].[ENTITY_TYPES] ([id])
GO
ALTER TABLE [dbo].[IMPORT_ENTITIES] CHECK CONSTRAINT [FK_IMPORT_ENTITIES_ENTITY_TYPES]
GO
ALTER TABLE [dbo].[IMPORT_ENTITIES]  WITH CHECK ADD  CONSTRAINT [FK_IMPORT_ENTITIES_IMPORTS] FOREIGN KEY([import_id])
REFERENCES [dbo].[IMPORTS] ([id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[IMPORT_ENTITIES] CHECK CONSTRAINT [FK_IMPORT_ENTITIES_IMPORTS]
GO
ALTER TABLE [dbo].[IMPORT_ENTITY_DEFINITIONS]  WITH CHECK ADD  CONSTRAINT [FK_IMPORT_ENTITY_DEFINITIONS_IMPORT_ABSIS_ENTITY_PROPERTY_TYPES] FOREIGN KEY([absis_property_id])
REFERENCES [dbo].[IMPORT_ABSIS_ENTITY_PROPERTY_TYPES] ([id])
GO
ALTER TABLE [dbo].[IMPORT_ENTITY_DEFINITIONS] CHECK CONSTRAINT [FK_IMPORT_ENTITY_DEFINITIONS_IMPORT_ABSIS_ENTITY_PROPERTY_TYPES]
GO
ALTER TABLE [dbo].[IMPORT_ENTITY_DEFINITIONS]  WITH CHECK ADD  CONSTRAINT [FK_IMPORT_ENTITY_DEFINITIONS_IMPORT_COLUMN_DEFINITION_TYPES] FOREIGN KEY([column_definition_type_id])
REFERENCES [dbo].[IMPORT_COLUMN_DEFINITION_TYPES] ([id])
GO
ALTER TABLE [dbo].[IMPORT_ENTITY_DEFINITIONS] CHECK CONSTRAINT [FK_IMPORT_ENTITY_DEFINITIONS_IMPORT_COLUMN_DEFINITION_TYPES]
GO
ALTER TABLE [dbo].[IMPORT_ENTITY_DEFINITIONS]  WITH CHECK ADD  CONSTRAINT [FK_IMPORT_ENTITY_DEFINITIONS_IMPORT_ENTITIES] FOREIGN KEY([import_entity_id])
REFERENCES [dbo].[IMPORT_ENTITIES] ([id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[IMPORT_ENTITY_DEFINITIONS] CHECK CONSTRAINT [FK_IMPORT_ENTITY_DEFINITIONS_IMPORT_ENTITIES]
GO
ALTER TABLE [dbo].[IMPORT_EQUIVALENCES]  WITH CHECK ADD  CONSTRAINT [FK_IMPORT_EQUIVALENCES_IMPORT_ENTITY_DEFINITIONS] FOREIGN KEY([import_entity_definition_id])
REFERENCES [dbo].[IMPORT_ENTITY_DEFINITIONS] ([id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[IMPORT_EQUIVALENCES] CHECK CONSTRAINT [FK_IMPORT_EQUIVALENCES_IMPORT_ENTITY_DEFINITIONS]
GO
ALTER TABLE [dbo].[IMPORT_TABLES_DEFINITIONS]  WITH CHECK ADD  CONSTRAINT [FK_IMPORT_TABLES_DEFINITIONS_ENTITY_TYPES] FOREIGN KEY([entity_type_id])
REFERENCES [dbo].[ENTITY_TYPES] ([id])
GO
ALTER TABLE [dbo].[IMPORT_TABLES_DEFINITIONS] CHECK CONSTRAINT [FK_IMPORT_TABLES_DEFINITIONS_ENTITY_TYPES]
GO
ALTER TABLE [dbo].[IMPORT_TABLES_DEFINITIONS]  WITH CHECK ADD  CONSTRAINT [FK_IMPORT_TABLES_DEFINITIONS_IMPORTS] FOREIGN KEY([import_id])
REFERENCES [dbo].[IMPORTS] ([id])
GO
ALTER TABLE [dbo].[IMPORT_TABLES_DEFINITIONS] CHECK CONSTRAINT [FK_IMPORT_TABLES_DEFINITIONS_IMPORTS]
GO
ALTER TABLE [dbo].[IMPORTS]  WITH CHECK ADD  CONSTRAINT [FK_IMPORTS_IMPORT_TYPES] FOREIGN KEY([import_type_id])
REFERENCES [dbo].[IMPORT_TYPES] ([id])
GO
ALTER TABLE [dbo].[IMPORTS] CHECK CONSTRAINT [FK_IMPORTS_IMPORT_TYPES]
GO
ALTER TABLE [dbo].[IMPORTS_USERS]  WITH CHECK ADD  CONSTRAINT [FK_IMPORTS_USERS_IMPORTS] FOREIGN KEY([import_id])
REFERENCES [dbo].[IMPORTS] ([id])
GO
ALTER TABLE [dbo].[IMPORTS_USERS] CHECK CONSTRAINT [FK_IMPORTS_USERS_IMPORTS]
GO
ALTER TABLE [dbo].[IMPORTS_USERS]  WITH CHECK ADD  CONSTRAINT [FK_IMPORTS_USERS_USERS] FOREIGN KEY([user_id])
REFERENCES [dbo].[USERS] ([id])
GO
ALTER TABLE [dbo].[IMPORTS_USERS] CHECK CONSTRAINT [FK_IMPORTS_USERS_USERS]
GO
ALTER TABLE [dbo].[ISSUER_UNITS]  WITH CHECK ADD  CONSTRAINT [FK_ISSUER_UNITS_ENTERPRISES] FOREIGN KEY([enterprise_id])
REFERENCES [dbo].[ENTERPRISES] ([id])
GO
ALTER TABLE [dbo].[ISSUER_UNITS] CHECK CONSTRAINT [FK_ISSUER_UNITS_ENTERPRISES]
GO
ALTER TABLE [dbo].[ISSUER_UNITS_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_ISSUER_UNITS_SNAPSHOTS_END_USERS] FOREIGN KEY([AT_end_user])
REFERENCES [dbo].[USERS] ([id])
GO
ALTER TABLE [dbo].[ISSUER_UNITS_SNAPSHOTS] CHECK CONSTRAINT [FK_ISSUER_UNITS_SNAPSHOTS_END_USERS]
GO
ALTER TABLE [dbo].[ISSUER_UNITS_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_ISSUER_UNITS_SNAPSHOTS_ISSUER_UNITS] FOREIGN KEY([entity_id])
REFERENCES [dbo].[ISSUER_UNITS] ([id])
GO
ALTER TABLE [dbo].[ISSUER_UNITS_SNAPSHOTS] CHECK CONSTRAINT [FK_ISSUER_UNITS_SNAPSHOTS_ISSUER_UNITS]
GO
ALTER TABLE [dbo].[ISSUER_UNITS_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_ISSUER_UNITS_SNAPSHOTS_START_USERS] FOREIGN KEY([AT_start_user])
REFERENCES [dbo].[USERS] ([id])
GO
ALTER TABLE [dbo].[ISSUER_UNITS_SNAPSHOTS] CHECK CONSTRAINT [FK_ISSUER_UNITS_SNAPSHOTS_START_USERS]
GO
ALTER TABLE [dbo].[NOTIFICATIONS]  WITH CHECK ADD  CONSTRAINT [FK_NOTIFICATIONS_NOTIFICATION_TYPES] FOREIGN KEY([type])
REFERENCES [dbo].[NOTIFICATION_TYPES] ([id])
GO
ALTER TABLE [dbo].[NOTIFICATIONS] CHECK CONSTRAINT [FK_NOTIFICATIONS_NOTIFICATION_TYPES]
GO
ALTER TABLE [dbo].[PERIOD_GROUPING_RELATIONSHIPS]  WITH CHECK ADD  CONSTRAINT [FK_PERIOD_GROUPING_RELATIONSHIPS_CHARGES] FOREIGN KEY([id_charge])
REFERENCES [dbo].[CHARGES] ([id])
GO
ALTER TABLE [dbo].[PERIOD_GROUPING_RELATIONSHIPS] CHECK CONSTRAINT [FK_PERIOD_GROUPING_RELATIONSHIPS_CHARGES]
GO
ALTER TABLE [dbo].[PERIOD_GROUPING_RELATIONSHIPS]  WITH CHECK ADD  CONSTRAINT [FK_PERIOD_GROUPING_RELATIONSHIPS_PERIOD_GROUPING] FOREIGN KEY([id_group])
REFERENCES [dbo].[PERIOD_GROUPING] ([id])
GO
ALTER TABLE [dbo].[PERIOD_GROUPING_RELATIONSHIPS] CHECK CONSTRAINT [FK_PERIOD_GROUPING_RELATIONSHIPS_PERIOD_GROUPING]
GO
ALTER TABLE [dbo].[PERMISSIONS]  WITH CHECK ADD  CONSTRAINT [FK_PERMISSIONS_ENTITY_TYPES] FOREIGN KEY([entity_type])
REFERENCES [dbo].[ENTITY_TYPES] ([id])
GO
ALTER TABLE [dbo].[PERMISSIONS] CHECK CONSTRAINT [FK_PERMISSIONS_ENTITY_TYPES]
GO
ALTER TABLE [dbo].[PERMISSIONS]  WITH CHECK ADD  CONSTRAINT [FK_PERMISSIONS_PERMISSIONS] FOREIGN KEY([permission_type])
REFERENCES [dbo].[PERMISSION_TYPES] ([id])
GO
ALTER TABLE [dbo].[PERMISSIONS] CHECK CONSTRAINT [FK_PERMISSIONS_PERMISSIONS]
GO
ALTER TABLE [dbo].[PROCESS_ACTIVITY]  WITH CHECK ADD  CONSTRAINT [FK_PROCESS_ACTIVITY_PROCESS] FOREIGN KEY([process_id])
REFERENCES [dbo].[PROCESSES] ([id])
GO
ALTER TABLE [dbo].[PROCESS_ACTIVITY] CHECK CONSTRAINT [FK_PROCESS_ACTIVITY_PROCESS]
GO
ALTER TABLE [dbo].[PROCESS_ACTIVITY]  WITH CHECK ADD  CONSTRAINT [FK_PROCESS_ACTIVITY_PROCESS_STATES] FOREIGN KEY([process_state_id])
REFERENCES [dbo].[PROCESS_STATES] ([id])
GO
ALTER TABLE [dbo].[PROCESS_ACTIVITY] CHECK CONSTRAINT [FK_PROCESS_ACTIVITY_PROCESS_STATES]
GO
ALTER TABLE [dbo].[PROCESSES]  WITH CHECK ADD  CONSTRAINT [FK_PROCESS_SYSTEMS] FOREIGN KEY([system_id])
REFERENCES [dbo].[SYSTEMS] ([id])
GO
ALTER TABLE [dbo].[PROCESSES] CHECK CONSTRAINT [FK_PROCESS_SYSTEMS]
GO
ALTER TABLE [dbo].[RATES]  WITH CHECK ADD  CONSTRAINT [FK_RATES_BILLABLE_CONCEPTS] FOREIGN KEY([billable_concept_id])
REFERENCES [dbo].[BILLABLE_CONCEPTS] ([id])
GO
ALTER TABLE [dbo].[RATES] CHECK CONSTRAINT [FK_RATES_BILLABLE_CONCEPTS]
GO
ALTER TABLE [dbo].[RATES_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_RATES_SNAPSHOTS_END_USERS] FOREIGN KEY([AT_end_user])
REFERENCES [dbo].[USERS] ([id])
GO
ALTER TABLE [dbo].[RATES_SNAPSHOTS] CHECK CONSTRAINT [FK_RATES_SNAPSHOTS_END_USERS]
GO
ALTER TABLE [dbo].[RATES_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_RATES_SNAPSHOTS_RATES] FOREIGN KEY([entity_id])
REFERENCES [dbo].[RATES] ([id])
GO
ALTER TABLE [dbo].[RATES_SNAPSHOTS] CHECK CONSTRAINT [FK_RATES_SNAPSHOTS_RATES]
GO
ALTER TABLE [dbo].[RATES_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_RATES_SNAPSHOTS_START_USERS] FOREIGN KEY([AT_start_user])
REFERENCES [dbo].[USERS] ([id])
GO
ALTER TABLE [dbo].[RATES_SNAPSHOTS] CHECK CONSTRAINT [FK_RATES_SNAPSHOTS_START_USERS]
GO
ALTER TABLE [dbo].[ROLE_CONDITION_VALUES]  WITH CHECK ADD  CONSTRAINT [FK_ROLE_CONDITION_VALUES_CONDITIONS] FOREIGN KEY([condition])
REFERENCES [dbo].[CONDITIONS] ([id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[ROLE_CONDITION_VALUES] CHECK CONSTRAINT [FK_ROLE_CONDITION_VALUES_CONDITIONS]
GO
ALTER TABLE [dbo].[ROLE_CONDITION_VALUES]  WITH CHECK ADD  CONSTRAINT [FK_ROLE_CONDITION_VALUES_ROLES] FOREIGN KEY([role])
REFERENCES [dbo].[ROLES] ([id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[ROLE_CONDITION_VALUES] CHECK CONSTRAINT [FK_ROLE_CONDITION_VALUES_ROLES]
GO
ALTER TABLE [dbo].[ROLE_PERMISSIONS]  WITH CHECK ADD  CONSTRAINT [FK_ROLE_PERMISSIONS_CONDITIONS] FOREIGN KEY([condition])
REFERENCES [dbo].[CONDITIONS] ([id])
GO
ALTER TABLE [dbo].[ROLE_PERMISSIONS] CHECK CONSTRAINT [FK_ROLE_PERMISSIONS_CONDITIONS]
GO
ALTER TABLE [dbo].[ROLE_PERMISSIONS]  WITH CHECK ADD  CONSTRAINT [FK_ROLE_PERMISSIONS_ENTITY_SCOPES] FOREIGN KEY([entity_scope])
REFERENCES [dbo].[ENTITY_SCOPES] ([id])
GO
ALTER TABLE [dbo].[ROLE_PERMISSIONS] CHECK CONSTRAINT [FK_ROLE_PERMISSIONS_ENTITY_SCOPES]
GO
ALTER TABLE [dbo].[ROLE_PERMISSIONS]  WITH CHECK ADD  CONSTRAINT [FK_ROLE_PERMISSIONS_ROLE_PERMISSIONS] FOREIGN KEY([permission])
REFERENCES [dbo].[PERMISSIONS] ([id])
GO
ALTER TABLE [dbo].[ROLE_PERMISSIONS] CHECK CONSTRAINT [FK_ROLE_PERMISSIONS_ROLE_PERMISSIONS]
GO
ALTER TABLE [dbo].[ROLE_PERMISSIONS]  WITH CHECK ADD  CONSTRAINT [FK_ROLE_PERMISSIONS_ROLES] FOREIGN KEY([role])
REFERENCES [dbo].[ROLES] ([id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[ROLE_PERMISSIONS] CHECK CONSTRAINT [FK_ROLE_PERMISSIONS_ROLES]
GO
ALTER TABLE [dbo].[ROLES]  WITH CHECK ADD  CONSTRAINT [FK_ROLES_ROLE_TYPES] FOREIGN KEY([type])
REFERENCES [dbo].[ROLE_TYPES] ([id])
GO
ALTER TABLE [dbo].[ROLES] CHECK CONSTRAINT [FK_ROLES_ROLE_TYPES]
GO
ALTER TABLE [dbo].[SEARCH_BASIC]  WITH CHECK ADD  CONSTRAINT [FK_SEARCH_BASIC_ENTITY_TYPES] FOREIGN KEY([type_id])
REFERENCES [dbo].[ENTITY_TYPES] ([id])
GO
ALTER TABLE [dbo].[SEARCH_BASIC] CHECK CONSTRAINT [FK_SEARCH_BASIC_ENTITY_TYPES]
GO
ALTER TABLE [dbo].[SERVICES_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_SERVICES_SNAPSHOTS_END_USERS] FOREIGN KEY([AT_end_user])
REFERENCES [dbo].[USERS] ([id])
GO
ALTER TABLE [dbo].[SERVICES_SNAPSHOTS] CHECK CONSTRAINT [FK_SERVICES_SNAPSHOTS_END_USERS]
GO
ALTER TABLE [dbo].[SERVICES_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_SERVICES_SNAPSHOTS_ISSUER_UNITS] FOREIGN KEY([issuer_unit_id])
REFERENCES [dbo].[ISSUER_UNITS] ([id])
GO
ALTER TABLE [dbo].[SERVICES_SNAPSHOTS] CHECK CONSTRAINT [FK_SERVICES_SNAPSHOTS_ISSUER_UNITS]
GO
ALTER TABLE [dbo].[SERVICES_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_SERVICES_SNAPSHOTS_SERVICES] FOREIGN KEY([entity_id])
REFERENCES [dbo].[SERVICES] ([id])
GO
ALTER TABLE [dbo].[SERVICES_SNAPSHOTS] CHECK CONSTRAINT [FK_SERVICES_SNAPSHOTS_SERVICES]
GO
ALTER TABLE [dbo].[SERVICES_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_SERVICES_SNAPSHOTS_START_USERS] FOREIGN KEY([AT_start_user])
REFERENCES [dbo].[USERS] ([id])
GO
ALTER TABLE [dbo].[SERVICES_SNAPSHOTS] CHECK CONSTRAINT [FK_SERVICES_SNAPSHOTS_START_USERS]
GO
ALTER TABLE [dbo].[SPECIAL_RATEDISCOUNT_ACCOUNTS]  WITH CHECK ADD  CONSTRAINT [FK_SPECIAL_RATEDISCOUNT_ACCOUNTS_ACCOUNTS] FOREIGN KEY([id_account])
REFERENCES [dbo].[ACCOUNTS] ([id])
GO
ALTER TABLE [dbo].[SPECIAL_RATEDISCOUNT_ACCOUNTS] CHECK CONSTRAINT [FK_SPECIAL_RATEDISCOUNT_ACCOUNTS_ACCOUNTS]
GO
ALTER TABLE [dbo].[SPECIAL_RATEDISCOUNT_ACCOUNTS]  WITH CHECK ADD  CONSTRAINT [FK_SPECIAL_RATEDISCOUNT_ACCOUNTS_END_USERS] FOREIGN KEY([AT_end_user])
REFERENCES [dbo].[USERS] ([id])
GO
ALTER TABLE [dbo].[SPECIAL_RATEDISCOUNT_ACCOUNTS] CHECK CONSTRAINT [FK_SPECIAL_RATEDISCOUNT_ACCOUNTS_END_USERS]
GO
ALTER TABLE [dbo].[SPECIAL_RATEDISCOUNT_ACCOUNTS]  WITH CHECK ADD  CONSTRAINT [FK_SPECIAL_RATEDISCOUNT_ACCOUNTS_START_USERS] FOREIGN KEY([AT_start_user])
REFERENCES [dbo].[USERS] ([id])
GO
ALTER TABLE [dbo].[SPECIAL_RATEDISCOUNT_ACCOUNTS] CHECK CONSTRAINT [FK_SPECIAL_RATEDISCOUNT_ACCOUNTS_START_USERS]
GO
ALTER TABLE [dbo].[SPECIAL_RATESDISCOUNTS]  WITH CHECK ADD  CONSTRAINT [FK_SPECIAL_RATESDISCOUNTS_BILLABLE_CONCEPTS] FOREIGN KEY([billable_concept_id])
REFERENCES [dbo].[BILLABLE_CONCEPTS] ([id])
GO
ALTER TABLE [dbo].[SPECIAL_RATESDISCOUNTS] CHECK CONSTRAINT [FK_SPECIAL_RATESDISCOUNTS_BILLABLE_CONCEPTS]
GO
ALTER TABLE [dbo].[SPECIAL_RATESDISCOUNTS_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_SPECIAL_RATESDISCOUNTS_SNAPSHOTS_END_USERS] FOREIGN KEY([AT_end_user])
REFERENCES [dbo].[USERS] ([id])
GO
ALTER TABLE [dbo].[SPECIAL_RATESDISCOUNTS_SNAPSHOTS] CHECK CONSTRAINT [FK_SPECIAL_RATESDISCOUNTS_SNAPSHOTS_END_USERS]
GO
ALTER TABLE [dbo].[SPECIAL_RATESDISCOUNTS_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_SPECIAL_RATESDISCOUNTS_SNAPSHOTS_SPECIAL_RATESDISCOUNTS] FOREIGN KEY([entity_id])
REFERENCES [dbo].[SPECIAL_RATESDISCOUNTS] ([id])
GO
ALTER TABLE [dbo].[SPECIAL_RATESDISCOUNTS_SNAPSHOTS] CHECK CONSTRAINT [FK_SPECIAL_RATESDISCOUNTS_SNAPSHOTS_SPECIAL_RATESDISCOUNTS]
GO
ALTER TABLE [dbo].[SPECIAL_RATESDISCOUNTS_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_SPECIAL_RATESDISCOUNTS_SNAPSHOTS_START_USERS] FOREIGN KEY([AT_start_user])
REFERENCES [dbo].[USERS] ([id])
GO
ALTER TABLE [dbo].[SPECIAL_RATESDISCOUNTS_SNAPSHOTS] CHECK CONSTRAINT [FK_SPECIAL_RATESDISCOUNTS_SNAPSHOTS_START_USERS]
GO
ALTER TABLE [dbo].[SUBLEDGERS]  WITH CHECK ADD  CONSTRAINT [FK_SUBLEDGERS_ACCOUNTS] FOREIGN KEY([account_id])
REFERENCES [dbo].[ACCOUNTS] ([id])
GO
ALTER TABLE [dbo].[SUBLEDGERS] CHECK CONSTRAINT [FK_SUBLEDGERS_ACCOUNTS]
GO
ALTER TABLE [dbo].[SUBLEDGERS]  WITH CHECK ADD  CONSTRAINT [FK_SUBLEDGERS_BILLABLE_CONCEPTS] FOREIGN KEY([billable_concept_id])
REFERENCES [dbo].[BILLABLE_CONCEPTS] ([id])
GO
ALTER TABLE [dbo].[SUBLEDGERS] CHECK CONSTRAINT [FK_SUBLEDGERS_BILLABLE_CONCEPTS]
GO
ALTER TABLE [dbo].[SYSTEM_MODULES]  WITH CHECK ADD  CONSTRAINT [FK_SYSTEM_MENUS_SYSTEMS] FOREIGN KEY([systemId])
REFERENCES [dbo].[SYSTEMS] ([id])
GO
ALTER TABLE [dbo].[SYSTEM_MODULES] CHECK CONSTRAINT [FK_SYSTEM_MENUS_SYSTEMS]
GO
ALTER TABLE [dbo].[SYSTEM_MODULES]  WITH CHECK ADD  CONSTRAINT [FK_SYSTEM_MODULES_END_USERS] FOREIGN KEY([AT_end_user])
REFERENCES [dbo].[USERS] ([id])
GO
ALTER TABLE [dbo].[SYSTEM_MODULES] CHECK CONSTRAINT [FK_SYSTEM_MODULES_END_USERS]
GO
ALTER TABLE [dbo].[SYSTEM_MODULES]  WITH CHECK ADD  CONSTRAINT [FK_SYSTEM_MODULES_START_USERS] FOREIGN KEY([AT_start_user])
REFERENCES [dbo].[USERS] ([id])
GO
ALTER TABLE [dbo].[SYSTEM_MODULES] CHECK CONSTRAINT [FK_SYSTEM_MODULES_START_USERS]
GO
ALTER TABLE [dbo].[SYSTEMS]  WITH CHECK ADD  CONSTRAINT [FK_SYSTEMS_END_USERS] FOREIGN KEY([AT_end_user])
REFERENCES [dbo].[USERS] ([id])
GO
ALTER TABLE [dbo].[SYSTEMS] CHECK CONSTRAINT [FK_SYSTEMS_END_USERS]
GO
ALTER TABLE [dbo].[SYSTEMS]  WITH CHECK ADD  CONSTRAINT [FK_SYSTEMS_START_USERS] FOREIGN KEY([AT_start_user])
REFERENCES [dbo].[USERS] ([id])
GO
ALTER TABLE [dbo].[SYSTEMS] CHECK CONSTRAINT [FK_SYSTEMS_START_USERS]
GO
ALTER TABLE [dbo].[SYSTEMS]  WITH CHECK ADD  CONSTRAINT [FK_SYSTEMS_SYSTEMS] FOREIGN KEY([id])
REFERENCES [dbo].[SYSTEMS] ([id])
GO
ALTER TABLE [dbo].[SYSTEMS] CHECK CONSTRAINT [FK_SYSTEMS_SYSTEMS]
GO
ALTER TABLE [dbo].[TAX_AREAS]  WITH CHECK ADD  CONSTRAINT [FK_TAX_AREAS_TAX_CLIENT_TYPES] FOREIGN KEY([tax_client_type_id])
REFERENCES [dbo].[TAX_CLIENT_TYPES] ([id])
GO
ALTER TABLE [dbo].[TAX_AREAS] CHECK CONSTRAINT [FK_TAX_AREAS_TAX_CLIENT_TYPES]
GO
ALTER TABLE [dbo].[TAX_AREAS]  WITH CHECK ADD  CONSTRAINT [FK_TAX_AREAS_TAX_TYPES] FOREIGN KEY([tax_type_id])
REFERENCES [dbo].[TAX_TYPES] ([id])
GO
ALTER TABLE [dbo].[TAX_AREAS] CHECK CONSTRAINT [FK_TAX_AREAS_TAX_TYPES]
GO
ALTER TABLE [dbo].[TICKET]  WITH CHECK ADD  CONSTRAINT [FK_TICKET_USERS] FOREIGN KEY([user_id])
REFERENCES [dbo].[USERS] ([id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[TICKET] CHECK CONSTRAINT [FK_TICKET_USERS]
GO
ALTER TABLE [dbo].[USER_CONDITION_VALUES]  WITH CHECK ADD  CONSTRAINT [FK_USER_CONDITION_VALUES_CONDITIONS] FOREIGN KEY([condition])
REFERENCES [dbo].[CONDITIONS] ([id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[USER_CONDITION_VALUES] CHECK CONSTRAINT [FK_USER_CONDITION_VALUES_CONDITIONS]
GO
ALTER TABLE [dbo].[USER_NOTIFICATIONS]  WITH CHECK ADD  CONSTRAINT [FK_USER_NOTIFICATIONS_NOTIFICATIONS] FOREIGN KEY([notification])
REFERENCES [dbo].[NOTIFICATIONS] ([id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[USER_NOTIFICATIONS] CHECK CONSTRAINT [FK_USER_NOTIFICATIONS_NOTIFICATIONS]
GO
ALTER TABLE [dbo].[USER_NOTIFICATIONS]  WITH CHECK ADD  CONSTRAINT [FK_USER_NOTIFICATIONS_USERS] FOREIGN KEY([user])
REFERENCES [dbo].[USERS] ([id])
GO
ALTER TABLE [dbo].[USER_NOTIFICATIONS] CHECK CONSTRAINT [FK_USER_NOTIFICATIONS_USERS]
GO
ALTER TABLE [dbo].[USER_ROLES]  WITH CHECK ADD  CONSTRAINT [FK_USER_ROLES_ROLES] FOREIGN KEY([role])
REFERENCES [dbo].[ROLES] ([id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[USER_ROLES] CHECK CONSTRAINT [FK_USER_ROLES_ROLES]
GO
ALTER TABLE [dbo].[USER_ROLES]  WITH CHECK ADD  CONSTRAINT [FK_USER_ROLES_USERS] FOREIGN KEY([user])
REFERENCES [dbo].[USERS] ([id])
GO
ALTER TABLE [dbo].[USER_ROLES] CHECK CONSTRAINT [FK_USER_ROLES_USERS]
GO
ALTER TABLE [dbo].[USER_SHORTCUTS]  WITH CHECK ADD  CONSTRAINT [FK_USER_SHORTCUTS_USERS] FOREIGN KEY([user])
REFERENCES [dbo].[USERS] ([id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[USER_SHORTCUTS] CHECK CONSTRAINT [FK_USER_SHORTCUTS_USERS]
GO
ALTER TABLE [dbo].[USERS_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_USERS_SNAPSHOTS_END_USERS] FOREIGN KEY([AT_end_user])
REFERENCES [dbo].[USERS] ([id])
GO
ALTER TABLE [dbo].[USERS_SNAPSHOTS] CHECK CONSTRAINT [FK_USERS_SNAPSHOTS_END_USERS]
GO
ALTER TABLE [dbo].[USERS_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_USERS_SNAPSHOTS_START_USERS] FOREIGN KEY([AT_start_user])
REFERENCES [dbo].[USERS] ([id])
GO
ALTER TABLE [dbo].[USERS_SNAPSHOTS] CHECK CONSTRAINT [FK_USERS_SNAPSHOTS_START_USERS]
GO
ALTER TABLE [dbo].[USERS_SNAPSHOTS]  WITH CHECK ADD  CONSTRAINT [FK_USERS_SNAPSHOTS_USERS] FOREIGN KEY([entity_id])
REFERENCES [dbo].[USERS] ([id])
GO
ALTER TABLE [dbo].[USERS_SNAPSHOTS] CHECK CONSTRAINT [FK_USERS_SNAPSHOTS_USERS]
GO
/****** Object:  StoredProcedure [dbo].[GENERATE_BILL_ORDER_ID]    Script Date: 03/08/2018 14:19:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE   PROCEDURE [dbo].[GENERATE_BILL_ORDER_ID]
	@id numeric(8,0) OUTPUT
AS
	BEGIN TRAN
	INSERT INTO BILL_ORDER_ID_TABLE WITH (TABLOCKX, HOLDLOCK) DEFAULT VALUES
	SET @id=IDENT_CURRENT('BILL_ORDER_ID_TABLE')
	COMMIT TRAN
	SELECT @id

GO
/****** Object:  StoredProcedure [dbo].[GENERATE_BILL_ORDER_JDE_ID]    Script Date: 03/08/2018 14:19:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE   PROCEDURE [dbo].[GENERATE_BILL_ORDER_JDE_ID]
	@id numeric(8,0) OUTPUT
AS
	BEGIN TRAN
	INSERT INTO BILL_ORDER_JDE_ID_TABLE WITH (TABLOCKX, HOLDLOCK) DEFAULT VALUES
	SET @id=IDENT_CURRENT('BILL_ORDER_JDE_ID_TABLE')
	COMMIT TRAN
	SELECT @id
GO
/****** Object:  StoredProcedure [dbo].[GENERATE_ID]    Script Date: 03/08/2018 14:19:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE   PROCEDURE [dbo].[GENERATE_ID]
	@id bigint OUTPUT
AS
BEGIN
	BEGIN TRAN
	INSERT INTO ID_TABLE WITH (TABLOCKX, HOLDLOCK) DEFAULT VALUES
	SET @id=IDENT_CURRENT('ID_TABLE')
	COMMIT TRAN
	SELECT @id
END

/**************************************************************************************************************************/
/************************** ACTUALITZACIÓ DE TOTS ELS DATETIME A DATETIME2 ************************************************/
/**************************************************************************************************************************/

GO
/****** Object:  StoredProcedure [dbo].[GENERATE_ID_ENTITY_FRAMEWORK]    Script Date: 03/08/2018 14:19:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[GENERATE_ID_ENTITY_FRAMEWORK]
	@id bigint OUTPUT
AS
	BEGIN TRAN
	INSERT INTO ID_TABLE WITH (TABLOCKX, HOLDLOCK) DEFAULT VALUES
	SET @id=IDENT_CURRENT('ID_TABLE')
	COMMIT TRAN
	SELECT @id

GO
/****** Object:  StoredProcedure [dbo].[INDEX_FOR_SEARCH]    Script Date: 03/08/2018 14:19:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Xavier lluch
-- Create date: 15 de Abril de 2009
-- Description:	Recopilación de datos de las tablas de entidades para informar la tabla SEARCH_BASIC
-- =============================================
CREATE PROCEDURE [dbo].[INDEX_FOR_SEARCH] 
	@id as bigint,
	@idType as bigint,
    @name as nvarchar(50),
    @code as nvarchar(10),
	@all_text as ntext
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SET @all_text=dbo.VoidNullStrings(@all_text)
	SET @name=dbo.VoidNullStrings(@name)
	SET @code=dbo.VoidNullStrings(@code)

    --Justo antes de insertar el nuevo registro, borramos el antiguo (si lo hay)	
	--Esto debería ir en una transacción
	DECLARE @ERR int
	BEGIN TRAN
		DELETE FROM SEARCH_BASIC WHERE id=@id
		SET @ERR=@@ERROR
		IF (@ERR<>0)
		BEGIN
			ROLLBACK TRAN
			RETURN
		END
		INSERT INTO SEARCH_BASIC (id, type_id, [name], code, all_text)
						VALUES  (@id,@idType,@name,@code,@all_text)
		SET @ERR=@@ERROR
		IF (@ERR<>0)
		BEGIN
			ROLLBACK TRAN
			RETURN
		END
	COMMIT TRAN
END

GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Centro de Coste y otros centros' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ACCOUNTS', @level2type=N'COLUMN',@level2name=N'id'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Id empresa a la que pertany el centre' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ACCOUNTS', @level2type=N'COLUMN',@level2name=N'enterprise_id'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Percentatge "splitat" al 0% IVA' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'BILL_SPLITS', @level2type=N'COLUMN',@level2name=N'percentage_of_tax'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Id del concepte. Tbl. CONCEPTS' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'BILLABLE_CONCEPTS', @level2type=N'COLUMN',@level2name=N'concept_id'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Id del Servei. Tbl. SERVICES' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'BILLABLE_CONCEPTS', @level2type=N'COLUMN',@level2name=N'service_id'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Partida Presupuestária (si la lleva)' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'CHARGES', @level2type=N'COLUMN',@level2name=N'budgetary_code'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Descripció de la familia (sota la que s''agruparan els conceptes)' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'CONCEPT_FAMILIES', @level2type=N'COLUMN',@level2name=N'description'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Id ABSIS de l''empresa a la que pertany el departament. Tbl. ENTERPRISES' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DEPARTMENTS', @level2type=N'COLUMN',@level2name=N'idEnterprise'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Id empresa' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ENTERPRISES', @level2type=N'COLUMN',@level2name=N'id'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Tipus entitat FK ENTITY_TYPES' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ENTITIES', @level2type=N'COLUMN',@level2name=N'entity_type_id'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Data de creació' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ENTITIES', @level2type=N'COLUMN',@level2name=N'creation_date'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'id del tipo de entidad' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ENTITY_TYPES', @level2type=N'COLUMN',@level2name=N'id'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'nombre que define al tipo de entidad' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ENTITY_TYPES', @level2type=N'COLUMN',@level2name=N'name'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'descripción del tipo de entidad y función dentro del sistema' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ENTITY_TYPES', @level2type=N'COLUMN',@level2name=N'description'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Valor que determina si la entidad calcula el inicio de validez del calendario a partir del calendario de una empresa emisora o de toto el sistema. Si es 1 calcula la fecha inicio del calendario a partir de su empresa emisora. Si es 0 busca el 1er mes abierto en el sistema.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ENTITY_TYPES', @level2type=N'COLUMN',@level2name=N'isVTcalcDependent'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Id heretat del sistema d''on s''ha migrat.??' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'EXTERNAL_SYSTEM_EQUIVALENCES', @level2type=N'COLUMN',@level2name=N'external_id'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Defineix quines són les possibles columnes que es poden utilitzar per definir les equivalencies. Cada taula pot tenir més un candidat' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'IMPORT_TABLES_COLUMN_DEFINITION', @level2type=N'COLUMN',@level2name=N'import_table_definition_id'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Defineix per a cada ENTITAT que es pugui importar a quina taula per defecte ha d''anar a buscar els valors d'' equivalencia ("com li diem-identifiquem a l''Excel o arxiu de text")' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'IMPORT_TABLES_DEFINITIONS', @level2type=N'COLUMN',@level2name=N'entity_type_id'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Id del billable_concept al que s''aplicarà el (unit_cost) preu d''aquesta tarifa. Tbl. BILLABLE_CONCEPTS' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'RATES', @level2type=N'COLUMN',@level2name=N'billable_concept_id'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Id ABSIS de la entitat' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'SEARCH_BASIC', @level2type=N'COLUMN',@level2name=N'id'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Tipus entitat FK ENTITY_TYPES' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'SEARCH_BASIC', @level2type=N'COLUMN',@level2name=N'type_id'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Nom o descripció de la entitat' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'SEARCH_BASIC', @level2type=N'COLUMN',@level2name=N'name'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Codi alfa. o alternatiu de la entitat, cas de que en tingui' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'SEARCH_BASIC', @level2type=N'COLUMN',@level2name=N'code'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Camp de text que agrupa la info de contingut de cada entitat i es manté indexat FTS' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'SEARCH_BASIC', @level2type=N'COLUMN',@level2name=N'all_text'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Nombre de la unidad: página, hora, metro cuadrado, ...' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UNITS', @level2type=N'COLUMN',@level2name=N'name'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Símbolo para representar la unidad: pag., h, m2, ...' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UNITS', @level2type=N'COLUMN',@level2name=N'symbol'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "T"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 136
               Right = 214
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'APP_CLIENT_ENTERPRISES_WITHOUT_BILL_CLIENT_DEFINITION'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'APP_CLIENT_ENTERPRISES_WITHOUT_BILL_CLIENT_DEFINITION'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[21] 4[8] 2[52] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'APP_CLIENTS_WITHOUT_BILL_CLIENT_DEFINITION'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'APP_CLIENTS_WITHOUT_BILL_CLIENT_DEFINITION'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "ENT_CLIENTE"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 85
               Right = 208
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ENT_EMISOR"
            Begin Extent = 
               Top = 6
               Left = 246
               Bottom = 85
               Right = 416
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'APP_COMBI_ENT_EMISORES_CLIENTS'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'APP_COMBI_ENT_EMISORES_CLIENTS'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[15] 4[3] 2[75] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = -288
         Left = 0
      End
      Begin Tables = 
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 9
         Width = 284
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'APP_CURRENT_SNAPSHOTS_VIEW'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'APP_CURRENT_SNAPSHOTS_VIEW'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[7] 4[4] 2[60] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "CHARS"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 136
               Right = 228
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "BC_SNS"
            Begin Extent = 
               Top = 6
               Left = 266
               Bottom = 136
               Right = 503
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "BCS"
            Begin Extent = 
               Top = 6
               Left = 541
               Bottom = 136
               Right = 720
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "SER_SNS"
            Begin Extent = 
               Top = 6
               Left = 758
               Bottom = 136
               Right = 941
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "CON_SNS"
            Begin Extent = 
               Top = 138
               Left = 38
               Bottom = 268
               Right = 208
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "IUS_SNS"
            Begin Extent = 
               Top = 138
               Left = 246
               Bottom = 268
               Right = 429
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "IUS"
            Begin Extent = 
               Top = 138
               Left = 467
               Bottom = 268
               Right = 646
            End
            DisplayFlags = 280
            Top' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'APP_EXPORT_CARGOS'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane2', @value=N'Column = 0
         End
         Begin Table = "IUS_ENTS"
            Begin Extent = 
               Top = 138
               Left = 684
               Bottom = 268
               Right = 854
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ACC_SNS_ISSUER"
            Begin Extent = 
               Top = 138
               Left = 892
               Bottom = 268
               Right = 1062
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ACCS_ISSUER"
            Begin Extent = 
               Top = 270
               Left = 38
               Bottom = 400
               Right = 217
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ACC_SNS"
            Begin Extent = 
               Top = 270
               Left = 255
               Bottom = 400
               Right = 425
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ACCS"
            Begin Extent = 
               Top = 270
               Left = 463
               Bottom = 400
               Right = 642
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "DEP_SNS"
            Begin Extent = 
               Top = 270
               Left = 680
               Bottom = 400
               Right = 936
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "DEPS"
            Begin Extent = 
               Top = 402
               Left = 38
               Bottom = 532
               Right = 217
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "DIV_SNS"
            Begin Extent = 
               Top = 402
               Left = 255
               Bottom = 532
               Right = 425
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ENT_SNS_CLIENT"
            Begin Extent = 
               Top = 402
               Left = 463
               Bottom = 532
               Right = 633
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "UNI"
            Begin Extent = 
               Top = 402
               Left = 671
               Bottom = 532
               Right = 841
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "SBL"
            Begin Extent = 
               Top = 402
               Left = 879
               Bottom = 532
               Right = 1071
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "CONS"
            Begin Extent = 
               Top = 534
               Left = 38
               Bottom = 664
               Right = 226
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 9
         Width = 284
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'APP_EXPORT_CARGOS'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane3', @value=N'170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'APP_EXPORT_CARGOS'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=3 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'APP_EXPORT_CARGOS'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4[30] 2[40] 3) )"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2[66] 3) )"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 5
   End
   Begin DiagramPane = 
      PaneHidden = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "CHARS"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 136
               Right = 241
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "BC_SNS"
            Begin Extent = 
               Top = 6
               Left = 279
               Bottom = 136
               Right = 516
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "BCS"
            Begin Extent = 
               Top = 6
               Left = 554
               Bottom = 136
               Right = 733
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "SER_SNS"
            Begin Extent = 
               Top = 6
               Left = 771
               Bottom = 136
               Right = 954
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "CON_SNS"
            Begin Extent = 
               Top = 138
               Left = 38
               Bottom = 268
               Right = 208
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "IUS_SNS"
            Begin Extent = 
               Top = 138
               Left = 246
               Bottom = 268
               Right = 429
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "IUS"
            Begin Extent = 
               Top = 138
               Left = 467
               Bottom = 268
               Right = 646
            End
            DisplayFlags ' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'APP_EXPORT_CARGOS_NOLOCK'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane2', @value=N'= 280
            TopColumn = 0
         End
         Begin Table = "IUS_ENTS"
            Begin Extent = 
               Top = 138
               Left = 684
               Bottom = 268
               Right = 854
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ACC_SNS_ISSUER"
            Begin Extent = 
               Top = 138
               Left = 892
               Bottom = 268
               Right = 1062
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ACCS_ISSUER"
            Begin Extent = 
               Top = 270
               Left = 38
               Bottom = 400
               Right = 217
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ACC_SNS"
            Begin Extent = 
               Top = 270
               Left = 255
               Bottom = 400
               Right = 425
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ACCS"
            Begin Extent = 
               Top = 270
               Left = 463
               Bottom = 400
               Right = 642
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "DEP_SNS"
            Begin Extent = 
               Top = 270
               Left = 680
               Bottom = 400
               Right = 936
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "DEPS"
            Begin Extent = 
               Top = 402
               Left = 38
               Bottom = 532
               Right = 217
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "DIV_SNS"
            Begin Extent = 
               Top = 402
               Left = 255
               Bottom = 532
               Right = 425
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ENT_SNS_CLIENT"
            Begin Extent = 
               Top = 402
               Left = 463
               Bottom = 532
               Right = 633
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "UNI"
            Begin Extent = 
               Top = 402
               Left = 671
               Bottom = 532
               Right = 841
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "SBL"
            Begin Extent = 
               Top = 402
               Left = 879
               Bottom = 532
               Right = 1071
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "CONS"
            Begin Extent = 
               Top = 534
               Left = 38
               Bottom = 664
               Right = 226
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
   End
   Begin CriteriaPane = 
      PaneHidden = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'APP_EXPORT_CARGOS_NOLOCK'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=2 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'APP_EXPORT_CARGOS_NOLOCK'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[20] 4[10] 2[52] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = -1106
      End
      Begin Tables = 
         Begin Table = "CHARS"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 136
               Right = 241
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "BC_SNS"
            Begin Extent = 
               Top = 6
               Left = 279
               Bottom = 136
               Right = 516
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "BCS"
            Begin Extent = 
               Top = 6
               Left = 554
               Bottom = 136
               Right = 733
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "SER_SNS"
            Begin Extent = 
               Top = 6
               Left = 771
               Bottom = 136
               Right = 954
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "CON_SNS"
            Begin Extent = 
               Top = 138
               Left = 38
               Bottom = 268
               Right = 208
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "IUS_SNS"
            Begin Extent = 
               Top = 138
               Left = 246
               Bottom = 268
               Right = 429
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "IUS"
            Begin Extent = 
               Top = 138
               Left = 467
               Bottom = 268
               Right = 646
            End
            DisplayFlags = 280
         ' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'APP_EXPORT_CARGOS_TEMPORAL_CUADRES_ENERO'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane2', @value=N'   TopColumn = 0
         End
         Begin Table = "IUS_ENTS"
            Begin Extent = 
               Top = 138
               Left = 684
               Bottom = 268
               Right = 854
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ACC_SNS_ISSUER"
            Begin Extent = 
               Top = 138
               Left = 892
               Bottom = 268
               Right = 1062
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ACCS_ISSUER"
            Begin Extent = 
               Top = 270
               Left = 38
               Bottom = 400
               Right = 217
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ACC_SNS"
            Begin Extent = 
               Top = 270
               Left = 255
               Bottom = 400
               Right = 425
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ACCS"
            Begin Extent = 
               Top = 270
               Left = 463
               Bottom = 400
               Right = 642
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "DEP_SNS"
            Begin Extent = 
               Top = 270
               Left = 680
               Bottom = 400
               Right = 936
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "DEPS"
            Begin Extent = 
               Top = 402
               Left = 38
               Bottom = 532
               Right = 217
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "DIV_SNS"
            Begin Extent = 
               Top = 402
               Left = 255
               Bottom = 532
               Right = 425
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ENT_SNS_CLIENT"
            Begin Extent = 
               Top = 402
               Left = 463
               Bottom = 532
               Right = 633
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "UNI"
            Begin Extent = 
               Top = 402
               Left = 671
               Bottom = 532
               Right = 841
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "SBL"
            Begin Extent = 
               Top = 402
               Left = 879
               Bottom = 532
               Right = 1071
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "CONS"
            Begin Extent = 
               Top = 534
               Left = 38
               Bottom = 664
               Right = 226
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'APP_EXPORT_CARGOS_TEMPORAL_CUADRES_ENERO'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=2 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'APP_EXPORT_CARGOS_TEMPORAL_CUADRES_ENERO'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[12] 4[3] 2[66] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = -288
         Left = 0
      End
      Begin Tables = 
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'APP_SNAPSHOTS_VIEW'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'APP_SNAPSHOTS_VIEW'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[25] 4[20] 2[24] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4[30] 2[40] 3) )"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2[66] 3) )"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 5
   End
   Begin DiagramPane = 
      PaneHidden = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "sp"
            Begin Extent = 
               Top = 6
               Left = 255
               Bottom = 135
               Right = 425
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ac"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 135
               Right = 217
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 9
         Width = 284
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
      End
   End
   Begin CriteriaPane = 
      PaneHidden = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'GET_ESTRUCTURA_ORGANIZATIVA'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'GET_ESTRUCTURA_ORGANIZATIVA'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[8] 4[53] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "DIVISIONS"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 136
               Right = 217
            End
            DisplayFlags = 280
            TopColumn = 3
         End
         Begin Table = "DIVISIONS_SNAPSHOTS"
            Begin Extent = 
               Top = 6
               Left = 255
               Bottom = 226
               Right = 425
            End
            DisplayFlags = 280
            TopColumn = 2
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 2400
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'NEW_DIVISIONS'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'NEW_DIVISIONS'
GO
USE [master]
GO
ALTER DATABASE [ABSIS4] SET  READ_WRITE 
GO
