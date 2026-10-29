-- ============================================================================
-- Enterprise Asset & Maintenance Management System (ApexCMMS)
-- Target Database: SQL Server / Azure SQL
-- Schema: Projects
-- Author: Antigravity Engineering
-- Date: 2026-10-29
-- ============================================================================

-- 1. SCHEMA CREATION
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Projects')
BEGIN
    EXEC('CREATE SCHEMA Projects');
END
GO

-- ============================================================================
-- 2. DROP EXISTING OBJECTS IN SAFE ORDER (IF RE-RUNNING)
-- ============================================================================
IF OBJECT_ID('Projects.sp_RotateRefreshToken', 'P') IS NOT NULL DROP PROCEDURE Projects.sp_RotateRefreshToken;
IF OBJECT_ID('Projects.sp_GetAssetMaintenanceSummary', 'P') IS NOT NULL DROP PROCEDURE Projects.sp_GetAssetMaintenanceSummary;
IF OBJECT_ID('Projects.sp_AllocateSparePart', 'P') IS NOT NULL DROP PROCEDURE Projects.sp_AllocateSparePart;
IF OBJECT_ID('Projects.sp_ApproveWorkOrder', 'P') IS NOT NULL DROP PROCEDURE Projects.sp_ApproveWorkOrder;
IF OBJECT_ID('Projects.sp_CreateWorkOrder', 'P') IS NOT NULL DROP PROCEDURE Projects.sp_CreateWorkOrder;
GO

IF OBJECT_ID('Projects.AuditLogs', 'U') IS NOT NULL DROP TABLE Projects.AuditLogs;
IF OBJECT_ID('Projects.WorkOrderPartAllocations', 'U') IS NOT NULL DROP TABLE Projects.WorkOrderPartAllocations;
IF OBJECT_ID('Projects.WorkOrderChecklistItems', 'U') IS NOT NULL DROP TABLE Projects.WorkOrderChecklistItems;
IF OBJECT_ID('Projects.WorkOrders', 'U') IS NOT NULL DROP TABLE Projects.WorkOrders;
IF OBJECT_ID('Projects.SpareParts', 'U') IS NOT NULL DROP TABLE Projects.SpareParts;
IF OBJECT_ID('Projects.Assets', 'U') IS NOT NULL DROP TABLE Projects.Assets;
IF OBJECT_ID('Projects.AssetCategories', 'U') IS NOT NULL DROP TABLE Projects.AssetCategories;
IF OBJECT_ID('Projects.RefreshTokens', 'U') IS NOT NULL DROP TABLE Projects.RefreshTokens;
IF OBJECT_ID('Projects.AspNetUserTokens', 'U') IS NOT NULL DROP TABLE Projects.AspNetUserTokens;
IF OBJECT_ID('Projects.AspNetUserLogins', 'U') IS NOT NULL DROP TABLE Projects.AspNetUserLogins;
IF OBJECT_ID('Projects.AspNetUserClaims', 'U') IS NOT NULL DROP TABLE Projects.AspNetUserClaims;
IF OBJECT_ID('Projects.AspNetRoleClaims', 'U') IS NOT NULL DROP TABLE Projects.AspNetRoleClaims;
IF OBJECT_ID('Projects.AspNetUserRoles', 'U') IS NOT NULL DROP TABLE Projects.AspNetUserRoles;
IF OBJECT_ID('Projects.AspNetUsers', 'U') IS NOT NULL DROP TABLE Projects.AspNetUsers;
IF OBJECT_ID('Projects.AspNetRoles', 'U') IS NOT NULL DROP TABLE Projects.AspNetRoles;
IF OBJECT_ID('Projects.Departments', 'U') IS NOT NULL DROP TABLE Projects.Departments;
GO

-- ============================================================================
-- 3. TABLES DEFINITION (DDL)
-- ============================================================================

-- Table 1: Departments
CREATE TABLE Projects.Departments (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Projects_Departments PRIMARY KEY DEFAULT NEWID(),
    Code NVARCHAR(20) NOT NULL,
    Name NVARCHAR(100) NOT NULL,
    Location NVARCHAR(150) NULL,
    IsActive BIT NOT NULL CONSTRAINT DF_Projects_Departments_IsActive DEFAULT 1,
    CreatedAtUtc DATETIME2(7) NOT NULL CONSTRAINT DF_Projects_Departments_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
    UpdatedAtUtc DATETIME2(7) NULL,
    CONSTRAINT UQ_Projects_Departments_Code UNIQUE (Code)
);
GO

-- Table 2: AspNetRoles (Identity Role)
CREATE TABLE Projects.AspNetRoles (
    Id NVARCHAR(450) NOT NULL CONSTRAINT PK_Projects_AspNetRoles PRIMARY KEY,
    Name NVARCHAR(256) NULL,
    NormalizedName NVARCHAR(256) NULL,
    ConcurrencyStamp NVARCHAR(MAX) NULL,
    Description NVARCHAR(250) NULL,
    CreatedAtUtc DATETIME2(7) NOT NULL CONSTRAINT DF_Projects_AspNetRoles_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_Projects_AspNetRoles_NormalizedName UNIQUE (NormalizedName)
);
GO

-- Table 3: AspNetUsers (Identity User Extended)
CREATE TABLE Projects.AspNetUsers (
    Id NVARCHAR(450) NOT NULL CONSTRAINT PK_Projects_AspNetUsers PRIMARY KEY,
    DepartmentId UNIQUEIDENTIFIER NULL,
    EmployeeCode NVARCHAR(20) NOT NULL,
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL,
    JobTitle NVARCHAR(100) NULL,
    IsActive BIT NOT NULL CONSTRAINT DF_Projects_AspNetUsers_IsActive DEFAULT 1,
    CreatedAtUtc DATETIME2(7) NOT NULL CONSTRAINT DF_Projects_AspNetUsers_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
    UpdatedAtUtc DATETIME2(7) NULL,
    UserName NVARCHAR(256) NULL,
    NormalizedUserName NVARCHAR(256) NULL,
    Email NVARCHAR(256) NULL,
    NormalizedEmail NVARCHAR(256) NULL,
    EmailConfirmed BIT NOT NULL,
    PasswordHash NVARCHAR(MAX) NULL,
    SecurityStamp NVARCHAR(MAX) NULL,
    ConcurrencyStamp NVARCHAR(MAX) NULL,
    PhoneNumber NVARCHAR(MAX) NULL,
    PhoneNumberConfirmed BIT NOT NULL,
    TwoFactorEnabled BIT NOT NULL,
    LockoutEnd DATETIMEOFFSET(7) NULL,
    LockoutEnabled BIT NOT NULL,
    AccessFailedCount INT NOT NULL,
    CONSTRAINT UQ_Projects_AspNetUsers_EmployeeCode UNIQUE (EmployeeCode),
    CONSTRAINT FK_Projects_AspNetUsers_Departments FOREIGN KEY (DepartmentId) REFERENCES Projects.Departments(Id) ON DELETE SET NULL
);
GO

CREATE NONCLUSTERED INDEX IX_Projects_AspNetUsers_DepartmentId ON Projects.AspNetUsers (DepartmentId);
CREATE NONCLUSTERED INDEX IX_Projects_AspNetUsers_NormalizedUserName ON Projects.AspNetUsers (NormalizedUserName);
CREATE NONCLUSTERED INDEX IX_Projects_AspNetUsers_NormalizedEmail ON Projects.AspNetUsers (NormalizedEmail);
GO

-- Table 4: AspNetUserRoles (User <-> Role Many-to-Many)
CREATE TABLE Projects.AspNetUserRoles (
    UserId NVARCHAR(450) NOT NULL,
    RoleId NVARCHAR(450) NOT NULL,
    CONSTRAINT PK_Projects_AspNetUserRoles PRIMARY KEY (UserId, RoleId),
    CONSTRAINT FK_Projects_AspNetUserRoles_AspNetUsers FOREIGN KEY (UserId) REFERENCES Projects.AspNetUsers (Id) ON DELETE CASCADE,
    CONSTRAINT FK_Projects_AspNetUserRoles_AspNetRoles FOREIGN KEY (RoleId) REFERENCES Projects.AspNetRoles (Id) ON DELETE CASCADE
);
GO

CREATE NONCLUSTERED INDEX IX_Projects_AspNetUserRoles_RoleId ON Projects.AspNetUserRoles (RoleId);
GO

-- Table 5: AspNetRoleClaims
CREATE TABLE Projects.AspNetRoleClaims (
    Id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Projects_AspNetRoleClaims PRIMARY KEY,
    RoleId NVARCHAR(450) NOT NULL,
    ClaimType NVARCHAR(MAX) NULL,
    ClaimValue NVARCHAR(MAX) NULL,
    CONSTRAINT FK_Projects_AspNetRoleClaims_AspNetRoles FOREIGN KEY (RoleId) REFERENCES Projects.AspNetRoles (Id) ON DELETE CASCADE
);
GO

CREATE NONCLUSTERED INDEX IX_Projects_AspNetRoleClaims_RoleId ON Projects.AspNetRoleClaims (RoleId);
GO

-- Table 6: AspNetUserClaims
CREATE TABLE Projects.AspNetUserClaims (
    Id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Projects_AspNetUserClaims PRIMARY KEY,
    UserId NVARCHAR(450) NOT NULL,
    ClaimType NVARCHAR(MAX) NULL,
    ClaimValue NVARCHAR(MAX) NULL,
    CONSTRAINT FK_Projects_AspNetUserClaims_AspNetUsers FOREIGN KEY (UserId) REFERENCES Projects.AspNetUsers (Id) ON DELETE CASCADE
);
GO

CREATE NONCLUSTERED INDEX IX_Projects_AspNetUserClaims_UserId ON Projects.AspNetUserClaims (UserId);
GO

-- Table 7: AspNetUserLogins
CREATE TABLE Projects.AspNetUserLogins (
    LoginProvider NVARCHAR(128) NOT NULL,
    ProviderKey NVARCHAR(128) NOT NULL,
    ProviderDisplayName NVARCHAR(MAX) NULL,
    UserId NVARCHAR(450) NOT NULL,
    CONSTRAINT PK_Projects_AspNetUserLogins PRIMARY KEY (LoginProvider, ProviderKey),
    CONSTRAINT FK_Projects_AspNetUserLogins_AspNetUsers FOREIGN KEY (UserId) REFERENCES Projects.AspNetUsers (Id) ON DELETE CASCADE
);
GO

CREATE NONCLUSTERED INDEX IX_Projects_AspNetUserLogins_UserId ON Projects.AspNetUserLogins (UserId);
GO

-- Table 8: AspNetUserTokens
CREATE TABLE Projects.AspNetUserTokens (
    UserId NVARCHAR(450) NOT NULL,
    LoginProvider NVARCHAR(128) NOT NULL,
    Name NVARCHAR(128) NOT NULL,
    Value NVARCHAR(MAX) NULL,
    CONSTRAINT PK_Projects_AspNetUserTokens PRIMARY KEY (UserId, LoginProvider, Name),
    CONSTRAINT FK_Projects_AspNetUserTokens_AspNetUsers FOREIGN KEY (UserId) REFERENCES Projects.AspNetUsers (Id) ON DELETE CASCADE
);
GO

-- Table 9: RefreshTokens (JWT Rotation & Revocation)
CREATE TABLE Projects.RefreshTokens (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Projects_RefreshTokens PRIMARY KEY DEFAULT NEWID(),
    UserId NVARCHAR(450) NOT NULL,
    Token NVARCHAR(256) NOT NULL,
    JwtId NVARCHAR(128) NOT NULL,
    IsUsed BIT NOT NULL CONSTRAINT DF_Projects_RefreshTokens_IsUsed DEFAULT 0,
    IsRevoked BIT NOT NULL CONSTRAINT DF_Projects_RefreshTokens_IsRevoked DEFAULT 0,
    CreatedAtUtc DATETIME2(7) NOT NULL CONSTRAINT DF_Projects_RefreshTokens_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
    ExpiresAtUtc DATETIME2(7) NOT NULL,
    ReplacedByToken NVARCHAR(256) NULL,
    CONSTRAINT UQ_Projects_RefreshTokens_Token UNIQUE (Token),
    CONSTRAINT FK_Projects_RefreshTokens_AspNetUsers FOREIGN KEY (UserId) REFERENCES Projects.AspNetUsers (Id) ON DELETE CASCADE
);
GO

CREATE NONCLUSTERED INDEX IX_Projects_RefreshTokens_UserId ON Projects.RefreshTokens (UserId);
CREATE NONCLUSTERED INDEX IX_Projects_RefreshTokens_Token ON Projects.RefreshTokens (Token);
GO

-- Table 10: AssetCategories
CREATE TABLE Projects.AssetCategories (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Projects_AssetCategories PRIMARY KEY DEFAULT NEWID(),
    Name NVARCHAR(100) NOT NULL,
    Description NVARCHAR(250) NULL,
    CreatedAtUtc DATETIME2(7) NOT NULL CONSTRAINT DF_Projects_AssetCategories_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_Projects_AssetCategories_Name UNIQUE (Name)
);
GO

-- Table 11: Assets
CREATE TABLE Projects.Assets (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Projects_Assets PRIMARY KEY DEFAULT NEWID(),
    AssetTag NVARCHAR(50) NOT NULL,
    Name NVARCHAR(150) NOT NULL,
    Description NVARCHAR(500) NULL,
    SerialNumber NVARCHAR(100) NULL,
    CategoryId UNIQUEIDENTIFIER NOT NULL,
    DepartmentId UNIQUEIDENTIFIER NOT NULL,
    Status INT NOT NULL CONSTRAINT DF_Projects_Assets_Status DEFAULT 0, -- 0: Operational, 1: Degraded, 2: UnderMaintenance, 3: Decommissioned
    Criticality INT NOT NULL CONSTRAINT DF_Projects_Assets_Criticality DEFAULT 1, -- 0: Low, 1: Medium, 2: High, 3: MissionCritical
    PurchaseDate DATETIME2(7) NOT NULL,
    WarrantyExpiryDate DATETIME2(7) NULL,
    RowVersion ROWVERSION NOT NULL,
    CreatedAtUtc DATETIME2(7) NOT NULL CONSTRAINT DF_Projects_Assets_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
    UpdatedAtUtc DATETIME2(7) NULL,
    CONSTRAINT UQ_Projects_Assets_AssetTag UNIQUE (AssetTag),
    CONSTRAINT FK_Projects_Assets_AssetCategories FOREIGN KEY (CategoryId) REFERENCES Projects.AssetCategories (Id),
    CONSTRAINT FK_Projects_Assets_Departments FOREIGN KEY (DepartmentId) REFERENCES Projects.Departments (Id)
);
GO

CREATE NONCLUSTERED INDEX IX_Projects_Assets_DepartmentId ON Projects.Assets (DepartmentId);
CREATE NONCLUSTERED INDEX IX_Projects_Assets_CategoryId ON Projects.Assets (CategoryId);
CREATE NONCLUSTERED INDEX IX_Projects_Assets_Status ON Projects.Assets (Status);
GO

-- Table 12: WorkOrders
CREATE TABLE Projects.WorkOrders (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Projects_WorkOrders PRIMARY KEY DEFAULT NEWID(),
    WorkOrderNumber NVARCHAR(50) NOT NULL,
    Title NVARCHAR(200) NOT NULL,
    Description NVARCHAR(MAX) NOT NULL,
    AssetId UNIQUEIDENTIFIER NOT NULL,
    Priority INT NOT NULL CONSTRAINT DF_Projects_WorkOrders_Priority DEFAULT 1, -- 0: Low, 1: Medium, 2: High, 3: Emergency
    Status INT NOT NULL CONSTRAINT DF_Projects_WorkOrders_Status DEFAULT 0, -- 0: Draft, 1: Submitted, 2: Approved, 3: InProgress, 4: OnHold, 5: Completed, 6: Cancelled
    CreatedById NVARCHAR(450) NOT NULL,
    ApprovedById NVARCHAR(450) NULL,
    AssignedTechnicianId NVARCHAR(450) NULL,
    EstimatedHours DECIMAL(5,2) NOT NULL CONSTRAINT DF_Projects_WorkOrders_EstimatedHours DEFAULT 0.00,
    ActualHours DECIMAL(5,2) NULL,
    ScheduledDate DATETIME2(7) NULL,
    CompletedAtUtc DATETIME2(7) NULL,
    RowVersion ROWVERSION NOT NULL,
    CreatedAtUtc DATETIME2(7) NOT NULL CONSTRAINT DF_Projects_WorkOrders_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
    UpdatedAtUtc DATETIME2(7) NULL,
    CONSTRAINT UQ_Projects_WorkOrders_WorkOrderNumber UNIQUE (WorkOrderNumber),
    CONSTRAINT FK_Projects_WorkOrders_Assets FOREIGN KEY (AssetId) REFERENCES Projects.Assets (Id),
    CONSTRAINT FK_Projects_WorkOrders_CreatedBy FOREIGN KEY (CreatedById) REFERENCES Projects.AspNetUsers (Id),
    CONSTRAINT FK_Projects_WorkOrders_ApprovedBy FOREIGN KEY (ApprovedById) REFERENCES Projects.AspNetUsers (Id),
    CONSTRAINT FK_Projects_WorkOrders_AssignedTechnician FOREIGN KEY (AssignedTechnicianId) REFERENCES Projects.AspNetUsers (Id)
);
GO

CREATE NONCLUSTERED INDEX IX_Projects_WorkOrders_AssetId ON Projects.WorkOrders (AssetId);
CREATE NONCLUSTERED INDEX IX_Projects_WorkOrders_Status ON Projects.WorkOrders (Status);
CREATE NONCLUSTERED INDEX IX_Projects_WorkOrders_Priority ON Projects.WorkOrders (Priority);
CREATE NONCLUSTERED INDEX IX_Projects_WorkOrders_AssignedTechnicianId ON Projects.WorkOrders (AssignedTechnicianId);
CREATE NONCLUSTERED INDEX IX_Projects_WorkOrders_CreatedById ON Projects.WorkOrders (CreatedById);
GO

-- Table 13: WorkOrderChecklistItems
CREATE TABLE Projects.WorkOrderChecklistItems (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Projects_WorkOrderChecklistItems PRIMARY KEY DEFAULT NEWID(),
    WorkOrderId UNIQUEIDENTIFIER NOT NULL,
    StepNumber INT NOT NULL,
    Description NVARCHAR(300) NOT NULL,
    IsCompleted BIT NOT NULL CONSTRAINT DF_Projects_WorkOrderChecklistItems_IsCompleted DEFAULT 0,
    CompletedAtUtc DATETIME2(7) NULL,
    CompletedById NVARCHAR(450) NULL,
    Notes NVARCHAR(500) NULL,
    CONSTRAINT FK_Projects_WorkOrderChecklistItems_WorkOrders FOREIGN KEY (WorkOrderId) REFERENCES Projects.WorkOrders (Id) ON DELETE CASCADE,
    CONSTRAINT FK_Projects_WorkOrderChecklistItems_CompletedBy FOREIGN KEY (CompletedById) REFERENCES Projects.AspNetUsers (Id)
);
GO

CREATE NONCLUSTERED INDEX IX_Projects_WorkOrderChecklistItems_WorkOrderId ON Projects.WorkOrderChecklistItems (WorkOrderId);
GO

-- Table 14: SpareParts
CREATE TABLE Projects.SpareParts (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Projects_SpareParts PRIMARY KEY DEFAULT NEWID(),
    PartNumber NVARCHAR(50) NOT NULL,
    Name NVARCHAR(150) NOT NULL,
    Description NVARCHAR(300) NULL,
    UnitPrice DECIMAL(18,2) NOT NULL,
    QuantityOnHand INT NOT NULL CONSTRAINT DF_Projects_SpareParts_QuantityOnHand DEFAULT 0,
    MinimumStockLevel INT NOT NULL CONSTRAINT DF_Projects_SpareParts_MinimumStockLevel DEFAULT 5,
    BinLocation NVARCHAR(50) NOT NULL,
    RowVersion ROWVERSION NOT NULL,
    CreatedAtUtc DATETIME2(7) NOT NULL CONSTRAINT DF_Projects_SpareParts_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
    UpdatedAtUtc DATETIME2(7) NULL,
    CONSTRAINT UQ_Projects_SpareParts_PartNumber UNIQUE (PartNumber),
    CONSTRAINT CK_Projects_SpareParts_QuantityOnHand CHECK (QuantityOnHand >= 0)
);
GO

CREATE NONCLUSTERED INDEX IX_Projects_SpareParts_PartNumber ON Projects.SpareParts (PartNumber);
GO

-- Table 15: WorkOrderPartAllocations
CREATE TABLE Projects.WorkOrderPartAllocations (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Projects_WorkOrderPartAllocations PRIMARY KEY DEFAULT NEWID(),
    WorkOrderId UNIQUEIDENTIFIER NOT NULL,
    SparePartId UNIQUEIDENTIFIER NOT NULL,
    QuantityUsed INT NOT NULL,
    UnitPriceAtUsage DECIMAL(18,2) NOT NULL,
    AllocatedAtUtc DATETIME2(7) NOT NULL CONSTRAINT DF_Projects_WorkOrderPartAllocations_AllocatedAtUtc DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Projects_WorkOrderPartAllocations_WorkOrders FOREIGN KEY (WorkOrderId) REFERENCES Projects.WorkOrders (Id) ON DELETE CASCADE,
    CONSTRAINT FK_Projects_WorkOrderPartAllocations_SpareParts FOREIGN KEY (SparePartId) REFERENCES Projects.SpareParts (Id),
    CONSTRAINT CK_Projects_WorkOrderPartAllocations_QuantityUsed CHECK (QuantityUsed > 0)
);
GO

CREATE NONCLUSTERED INDEX IX_Projects_WorkOrderPartAllocations_WorkOrderId ON Projects.WorkOrderPartAllocations (WorkOrderId);
CREATE NONCLUSTERED INDEX IX_Projects_WorkOrderPartAllocations_SparePartId ON Projects.WorkOrderPartAllocations (SparePartId);
GO

-- Table 16: AuditLogs (Immutable Audit Trail)
CREATE TABLE Projects.AuditLogs (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Projects_AuditLogs PRIMARY KEY DEFAULT NEWID(),
    UserId NVARCHAR(450) NULL,
    UserEmail NVARCHAR(100) NULL,
    Action NVARCHAR(50) NOT NULL, -- CREATE, UPDATE, DELETE, STATUS_CHANGE, LOGIN
    EntityName NVARCHAR(100) NOT NULL,
    EntityId NVARCHAR(100) NOT NULL,
    OldValues NVARCHAR(MAX) NULL, -- JSON formatted
    NewValues NVARCHAR(MAX) NULL, -- JSON formatted
    IpAddress NVARCHAR(50) NULL,
    TimestampUtc DATETIME2(7) NOT NULL CONSTRAINT DF_Projects_AuditLogs_TimestampUtc DEFAULT SYSUTCDATETIME()
);
GO

CREATE NONCLUSTERED INDEX IX_Projects_AuditLogs_Entity ON Projects.AuditLogs (EntityName, EntityId);
CREATE NONCLUSTERED INDEX IX_Projects_AuditLogs_TimestampUtc ON Projects.AuditLogs (TimestampUtc DESC);
CREATE NONCLUSTERED INDEX IX_Projects_AuditLogs_UserId ON Projects.AuditLogs (UserId);
GO

-- ============================================================================
-- 4. STORED PROCEDURES (Projects Schema)
-- ============================================================================

-- Stored Procedure 1: sp_CreateWorkOrder
-- Generates formatted WorkOrderNumber, creates record, and logs audit atomically
CREATE PROCEDURE Projects.sp_CreateWorkOrder
    @Title NVARCHAR(200),
    @Description NVARCHAR(MAX),
    @AssetId UNIQUEIDENTIFIER,
    @Priority INT,
    @CreatedById NVARCHAR(450),
    @EstimatedHours DECIMAL(5,2),
    @ScheduledDate DATETIME2(7) = NULL,
    @NewWorkOrderId UNIQUEIDENTIFIER OUTPUT,
    @GeneratedWorkOrderNumber NVARCHAR(50) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Verify Asset exists & is not decommissioned
        IF NOT EXISTS (SELECT 1 FROM Projects.Assets WHERE Id = @AssetId AND Status <> 3)
        BEGIN
            THROW 50001, 'Asset does not exist or has been decommissioned.', 1;
        END

        -- 2. Generate Next Work Order Number (Format: WO-YEAR-SEQUENCE)
        DECLARE @YearStr NVARCHAR(4) = CAST(YEAR(SYSUTCDATETIME()) AS NVARCHAR(4));
        DECLARE @NextSeq INT;

        SELECT @NextSeq = ISNULL(MAX(CAST(RIGHT(WorkOrderNumber, 5) AS INT)), 1000) + 1
        FROM Projects.WorkOrders
        WHERE WorkOrderNumber LIKE 'WO-' + @YearStr + '-%';

        IF @NextSeq IS NULL SET @NextSeq = 1001;

        SET @GeneratedWorkOrderNumber = 'WO-' + @YearStr + '-' + RIGHT('00000' + CAST(@NextSeq AS NVARCHAR(5)), 5);
        SET @NewWorkOrderId = NEWID();

        -- 3. Insert Work Order
        INSERT INTO Projects.WorkOrders (
            Id, WorkOrderNumber, Title, Description, AssetId, Priority, Status,
            CreatedById, EstimatedHours, ScheduledDate, CreatedAtUtc
        )
        VALUES (
            @NewWorkOrderId, @GeneratedWorkOrderNumber, @Title, @Description, @AssetId, @Priority,
            1, -- Status: 1 = Submitted
            @CreatedById, @EstimatedHours, @ScheduledDate, SYSUTCDATETIME()
        );

        -- 4. Insert Audit Log
        DECLARE @UserEmail NVARCHAR(100);
        SELECT @UserEmail = Email FROM Projects.AspNetUsers WHERE Id = @CreatedById;

        INSERT INTO Projects.AuditLogs (
            Id, UserId, UserEmail, Action, EntityName, EntityId,
            OldValues,
            NewValues,
            TimestampUtc
        )
        VALUES (
            NEWID(), @CreatedById, @UserEmail, 'CREATE', 'WorkOrder', CAST(@NewWorkOrderId AS NVARCHAR(100)),
            NULL,
            CONCAT('{"WorkOrderNumber":"', @GeneratedWorkOrderNumber, '","Priority":', @Priority, ',"Status":1}'),
            SYSUTCDATETIME()
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- Stored Procedure 2: sp_ApproveWorkOrder
-- Approves a submitted work order, assigns technician, changes asset status if emergency
CREATE PROCEDURE Projects.sp_ApproveWorkOrder
    @WorkOrderId UNIQUEIDENTIFIER,
    @ApprovedById NVARCHAR(450),
    @AssignedTechnicianId NVARCHAR(450) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @CurrentStatus INT;
        DECLARE @AssetId UNIQUEIDENTIFIER;
        DECLARE @Priority INT;

        SELECT @CurrentStatus = Status, @AssetId = AssetId, @Priority = Priority
        FROM Projects.WorkOrders
        WHERE Id = @WorkOrderId;

        IF @CurrentStatus IS NULL
        BEGIN
            THROW 50002, 'Work Order does not exist.', 1;
        END

        IF @CurrentStatus <> 1 -- Must be 1 (Submitted) to approve
        BEGIN
            THROW 50003, 'Work Order is not in a submittable state for approval.', 1;
        END

        -- Update Work Order to Approved (2)
        UPDATE Projects.WorkOrders
        SET Status = 2, -- Approved
            ApprovedById = @ApprovedById,
            AssignedTechnicianId = ISNULL(@AssignedTechnicianId, AssignedTechnicianId),
            UpdatedAtUtc = SYSUTCDATETIME()
        WHERE Id = @WorkOrderId;

        -- If priority is High or Emergency, mark asset status as UnderMaintenance (2)
        IF @Priority IN (2, 3)
        BEGIN
            UPDATE Projects.Assets
            SET Status = 2, UpdatedAtUtc = SYSUTCDATETIME()
            WHERE Id = @AssetId AND Status <> 2;
        END

        -- Audit Log
        DECLARE @ManagerEmail NVARCHAR(100);
        SELECT @ManagerEmail = Email FROM Projects.AspNetUsers WHERE Id = @ApprovedById;

        INSERT INTO Projects.AuditLogs (
            Id, UserId, UserEmail, Action, EntityName, EntityId,
            OldValues,
            NewValues,
            TimestampUtc
        )
        VALUES (
            NEWID(), @ApprovedById, @ManagerEmail, 'STATUS_CHANGE', 'WorkOrder', CAST(@WorkOrderId AS NVARCHAR(100)),
            '{"Status":1}',
            '{"Status":2,"Approved":true}',
            SYSUTCDATETIME()
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- Stored Procedure 3: sp_AllocateSparePart
-- Atomically deducts inventory stock and logs usage with concurrency protection
CREATE PROCEDURE Projects.sp_AllocateSparePart
    @WorkOrderId UNIQUEIDENTIFIER,
    @SparePartId UNIQUEIDENTIFIER,
    @QuantityUsed INT,
    @UserId NVARCHAR(450)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @AvailableQty INT;
        DECLARE @UnitPrice DECIMAL(18,2);
        DECLARE @PartNumber NVARCHAR(50);

        -- Lock the row using UPDLOCK to prevent race conditions
        SELECT @AvailableQty = QuantityOnHand, @UnitPrice = UnitPrice, @PartNumber = PartNumber
        FROM Projects.SpareParts WITH (UPDLOCK, ROWLOCK)
        WHERE Id = @SparePartId;

        IF @AvailableQty IS NULL
        BEGIN
            THROW 50004, 'Spare part does not exist.', 1;
        END

        IF @AvailableQty < @QuantityUsed
        BEGIN
            THROW 50005, 'Insufficient inventory stock available for allocation.', 1;
        END

        -- Deduct inventory
        UPDATE Projects.SpareParts
        SET QuantityOnHand = QuantityOnHand - @QuantityUsed,
            UpdatedAtUtc = SYSUTCDATETIME()
        WHERE Id = @SparePartId;

        -- Record allocation
        INSERT INTO Projects.WorkOrderPartAllocations (
            Id, WorkOrderId, SparePartId, QuantityUsed, UnitPriceAtUsage, AllocatedAtUtc
        )
        VALUES (
            NEWID(), @WorkOrderId, @SparePartId, @QuantityUsed, @UnitPrice, SYSUTCDATETIME()
        );

        -- Audit Log
        DECLARE @UserEmail NVARCHAR(100);
        SELECT @UserEmail = Email FROM Projects.AspNetUsers WHERE Id = @UserId;

        INSERT INTO Projects.AuditLogs (
            Id, UserId, UserEmail, Action, EntityName, EntityId,
            OldValues,
            NewValues,
            TimestampUtc
        )
        VALUES (
            NEWID(), @UserId, @UserEmail, 'ALLOCATE_PART', 'SparePart', CAST(@SparePartId AS NVARCHAR(100)),
            CONCAT('{"PartNumber":"', @PartNumber, '","PreviousStock":', @AvailableQty, '}'),
            CONCAT('{"QuantityDeducted":', @QuantityUsed, ',"RemainingStock":', (@AvailableQty - @QuantityUsed), '}'),
            SYSUTCDATETIME()
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- Stored Procedure 4: sp_GetAssetMaintenanceSummary
-- Returns comprehensive KPI metrics and recent maintenance history for an asset
CREATE PROCEDURE Projects.sp_GetAssetMaintenanceSummary
    @AssetId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    -- Asset Details & Operational Health
    SELECT 
        a.Id,
        a.AssetTag,
        a.Name AS AssetName,
        a.SerialNumber,
        c.Name AS CategoryName,
        d.Name AS DepartmentName,
        a.Status,
        a.Criticality,
        a.PurchaseDate,
        a.WarrantyExpiryDate,
        DATEDIFF(DAY, a.PurchaseDate, SYSUTCDATETIME()) AS DaysInService
    FROM Projects.Assets a
    INNER JOIN Projects.AssetCategories c ON a.CategoryId = c.Id
    INNER JOIN Projects.Departments d ON a.DepartmentId = d.Id
    WHERE a.Id = @AssetId;

    -- Work Order Metrics Breakdown
    SELECT 
        COUNT(Id) AS TotalWorkOrders,
        SUM(CASE WHEN Status = 5 THEN 1 ELSE 0 END) AS CompletedOrders,
        SUM(CASE WHEN Status IN (1, 2, 3) THEN 1 ELSE 0 END) AS ActiveOrders,
        ISNULL(SUM(ActualHours), 0.00) AS TotalMaintenanceHoursSpent,
        ISNULL(AVG(ActualHours), 0.00) AS AverageMaintenanceHoursPerOrder
    FROM Projects.WorkOrders
    WHERE AssetId = @AssetId;

    -- Spare Parts Cost Incurred on this Asset
    SELECT 
        ISNULL(SUM(pa.QuantityUsed * pa.UnitPriceAtUsage), 0.00) AS TotalSparePartsCostIncurred
    FROM Projects.WorkOrderPartAllocations pa
    INNER JOIN Projects.WorkOrders wo ON pa.WorkOrderId = wo.Id
    WHERE wo.AssetId = @AssetId;
END;
GO

-- Stored Procedure 5: sp_RotateRefreshToken
-- Atomic JWT token rotation preventing replay attacks
CREATE PROCEDURE Projects.sp_RotateRefreshToken
    @OldToken NVARCHAR(256),
    @NewToken NVARCHAR(256),
    @NewJwtId NVARCHAR(128),
    @UserId NVARCHAR(450),
    @ExpiresAtUtc DATETIME2(7)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @IsUsed BIT, @IsRevoked BIT, @TokenExpiry DATETIME2(7);

        SELECT @IsUsed = IsUsed, @IsRevoked = IsRevoked, @TokenExpiry = ExpiresAtUtc
        FROM Projects.RefreshTokens WITH (UPDLOCK)
        WHERE Token = @OldToken AND UserId = @UserId;

        IF @IsUsed IS NULL
        BEGIN
            THROW 50006, 'Invalid refresh token.', 1;
        END

        IF @IsUsed = 1 OR @IsRevoked = 1 OR @TokenExpiry < SYSUTCDATETIME()
        BEGIN
            -- Suspicious activity: Revoke ALL tokens for this user
            UPDATE Projects.RefreshTokens
            SET IsRevoked = 1
            WHERE UserId = @UserId;

            THROW 50007, 'Token has already been used, revoked, or expired. Token family revoked.', 1;
        END

        -- Mark old token as used and record replacement
        UPDATE Projects.RefreshTokens
        SET IsUsed = 1, ReplacedByToken = @NewToken
        WHERE Token = @OldToken;

        -- Insert new refresh token
        INSERT INTO Projects.RefreshTokens (
            Id, UserId, Token, JwtId, IsUsed, IsRevoked, CreatedAtUtc, ExpiresAtUtc
        )
        VALUES (
            NEWID(), @UserId, @NewToken, @NewJwtId, 0, 0, SYSUTCDATETIME(), @ExpiresAtUtc
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ============================================================================
-- 5. INITIAL SEED DATA (Departments, Roles, Categories, Assets, Parts)
-- ============================================================================

-- Seed Departments
DECLARE @DeptOpsId UNIQUEIDENTIFIER = '11111111-1111-1111-1111-111111111111';
DECLARE @DeptElecId UNIQUEIDENTIFIER = '22222222-2222-2222-2222-222222222222';
DECLARE @DeptMechId UNIQUEIDENTIFIER = '33333333-3333-3333-3333-333333333333';
DECLARE @DeptSafeId UNIQUEIDENTIFIER = '44444444-4444-4444-4444-444444444444';

INSERT INTO Projects.Departments (Id, Code, Name, Location, IsActive)
VALUES 
    (@DeptOpsId, 'DEP-OPS', 'Plant Operations', 'Main Plant - Floor 1', 1),
    (@DeptElecId, 'DEP-ELEC', 'Electrical Maintenance', 'Substation Building A', 1),
    (@DeptMechId, 'DEP-MECH', 'Mechanical & Hydraulics', 'Workshop Bay 3', 1),
    (@DeptSafeId, 'DEP-SAFE', 'Safety & Environmental', 'Safety HQ - Bldg C', 1);
GO

-- Seed Roles
INSERT INTO Projects.AspNetRoles (Id, Name, NormalizedName, ConcurrencyStamp, Description)
VALUES
    ('role-superadmin', 'SuperAdmin', 'SUPERADMIN', NEWID(), 'Complete system control, role assignments, security configuration'),
    ('role-opsmanager', 'OperationsManager', 'OPERATIONSMANAGER', NEWID(), 'Departmental work order approvals, asset management, budget oversight'),
    ('role-technician', 'FieldTechnician', 'FIELDTECHNICIAN', NEWID(), 'Mobile field work execution, inspection checklist completion, parts checkout'),
    ('role-auditor', 'SafetyAuditor', 'SAFETYAUDITOR', NEWID(), 'Read-only audit trail analysis, compliance inspection and verification');
GO

-- Seed Role Claims (Granular RBAC Permissions)
INSERT INTO Projects.AspNetRoleClaims (RoleId, ClaimType, ClaimValue)
VALUES
    ('role-superadmin', 'Permission', 'users.manage'),
    ('role-superadmin', 'Permission', 'departments.manage'),
    ('role-superadmin', 'Permission', 'assets.manage'),
    ('role-superadmin', 'Permission', 'workorders.manage'),
    ('role-superadmin', 'Permission', 'audit.view'),

    ('role-opsmanager', 'Permission', 'assets.manage'),
    ('role-opsmanager', 'Permission', 'workorders.create'),
    ('role-opsmanager', 'Permission', 'workorders.approve'),
    ('role-opsmanager', 'Permission', 'inventory.view'),

    ('role-technician', 'Permission', 'workorders.execute'),
    ('role-technician', 'Permission', 'inventory.checkout'),
    ('role-technician', 'Permission', 'checklist.complete'),

    ('role-auditor', 'Permission', 'audit.view'),
    ('role-auditor', 'Permission', 'compliance.report');
GO

-- Seed Asset Categories
DECLARE @CatTurbineId UNIQUEIDENTIFIER = 'AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA';
DECLARE @CatHvacId UNIQUEIDENTIFIER = 'BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB';
DECLARE @CatHydraulicId UNIQUEIDENTIFIER = 'CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC';
DECLARE @CatSwitchgearId UNIQUEIDENTIFIER = 'DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD';

INSERT INTO Projects.AssetCategories (Id, Name, Description)
VALUES
    (@CatTurbineId, 'Turbines & Generators', 'Heavy power generation turbines and auxiliary motor generators'),
    (@CatHvacId, 'Industrial HVAC', 'Facility climate control, chillers, and industrial air handling units'),
    (@CatHydraulicId, 'Pumps & Hydraulics', 'High-pressure hydraulic pumps, fluid valves, and actuators'),
    (@CatSwitchgearId, 'Electrical Switchgear', 'High-voltage power distribution switchboards and circuit breakers');
GO

-- Seed Assets
DECLARE @Asset1 UNIQUEIDENTIFIER = 'E1111111-1111-1111-1111-111111111111';
DECLARE @Asset2 UNIQUEIDENTIFIER = 'E2222222-2222-2222-2222-222222222222';
DECLARE @Asset3 UNIQUEIDENTIFIER = 'E3333333-3333-3333-3333-333333333333';

INSERT INTO Projects.Assets (Id, AssetTag, Name, Description, SerialNumber, CategoryId, DepartmentId, Status, Criticality, PurchaseDate, WarrantyExpiryDate)
VALUES
    (@Asset1, 'AST-2026-001', 'Gas Turbine Generator Alpha', 'Primary 45MW gas turbine powering Facility Sector 1', 'SN-GT45-98214', 
     'AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA', '11111111-1111-1111-1111-111111111111', 0, 3, '2023-01-15', '2028-01-15'),

    (@Asset2, 'AST-2026-002', 'Centrifugal Chiller 500-Ton', 'Central industrial chiller unit for server halls', 'SN-CH500-1102', 
     'BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB', '22222222-2222-2222-2222-222222222222', 0, 2, '2024-03-10', '2027-03-10'),

    (@Asset3, 'AST-2026-003', 'Hydraulic Press 200-Bar', 'Main stamping hydraulic actuator with dual piston', 'SN-HP200-5590', 
     'CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC', '33333333-3333-3333-3333-333333333333', 1, 2, '2022-06-20', '2025-06-20');
GO

-- Seed Spare Parts
INSERT INTO Projects.SpareParts (Id, PartNumber, Name, Description, UnitPrice, QuantityOnHand, MinimumStockLevel, BinLocation)
VALUES
    (NEWID(), 'SP-BRG-6204', 'Deep Groove Ball Bearing 6204', 'Precision high-speed steel ball bearing', 45.50, 48, 10, 'BIN-A1-04'),
    (NEWID(), 'SP-FLT-HVAC01', 'HEPA Air Filter 24x24x12', 'Commercial grade particulate air filter for chillers', 85.00, 32, 8, 'BIN-B2-12'),
    (NEWID(), 'SP-VLV-HYD02', 'High-Pressure Hydraulic Solenoid Valve', '24V DC rated 350-bar proportional control valve', 320.00, 14, 5, 'BIN-C3-01'),
    (NEWID(), 'SP-FUS-HV100', '100A High Voltage Fuse Link', 'Fast-acting power distribution cartridge fuse', 65.00, 60, 15, 'BIN-D1-09');
GO

PRINT 'ApexCMMS database schema [Projects], 16 tables, 5 stored procedures, and seed data created successfully.';
GO
