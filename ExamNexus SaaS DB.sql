-- ============================================================================
-- ExamNexus: Multi-Tenant Assessment & Real-Time Proctored Exam Platform
-- Target Database: SQL Server / Azure SQL
-- Schema: ExamSaaS
-- Author: Antigravity Engineering
-- Date: 2026-10-29
-- ============================================================================

-- 1. SCHEMA CREATION
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'ExamSaaS')
BEGIN
    EXEC('CREATE SCHEMA ExamSaaS');
END
GO

-- ============================================================================
-- 2. DROP EXISTING OBJECTS IN SAFE ORDER (IF RE-RUNNING)
-- ============================================================================
IF OBJECT_ID('ExamSaaS.sp_GetTenantProctorDashboardSummary', 'P') IS NOT NULL DROP PROCEDURE ExamSaaS.sp_GetTenantProctorDashboardSummary;
IF OBJECT_ID('ExamSaaS.sp_LogProctorEvent', 'P') IS NOT NULL DROP PROCEDURE ExamSaaS.sp_LogProctorEvent;
IF OBJECT_ID('ExamSaaS.sp_SubmitCandidateExamSession', 'P') IS NOT NULL DROP PROCEDURE ExamSaaS.sp_SubmitCandidateExamSession;
IF OBJECT_ID('ExamSaaS.sp_StartCandidateExamSession', 'P') IS NOT NULL DROP PROCEDURE ExamSaaS.sp_StartCandidateExamSession;
GO

IF OBJECT_ID('ExamSaaS.SubscriptionRequests', 'U') IS NOT NULL DROP TABLE ExamSaaS.SubscriptionRequests;
IF OBJECT_ID('ExamSaaS.AuditLogs', 'U') IS NOT NULL DROP TABLE ExamSaaS.AuditLogs;
IF OBJECT_ID('ExamSaaS.ProctorEvents', 'U') IS NOT NULL DROP TABLE ExamSaaS.ProctorEvents;
IF OBJECT_ID('ExamSaaS.CandidateAnswers', 'U') IS NOT NULL DROP TABLE ExamSaaS.CandidateAnswers;
IF OBJECT_ID('ExamSaaS.CandidateExamSessions', 'U') IS NOT NULL DROP TABLE ExamSaaS.CandidateExamSessions;
IF OBJECT_ID('ExamSaaS.ExamQuestions', 'U') IS NOT NULL DROP TABLE ExamSaaS.ExamQuestions;
IF OBJECT_ID('ExamSaaS.Exams', 'U') IS NOT NULL DROP TABLE ExamSaaS.Exams;
IF OBJECT_ID('ExamSaaS.QuestionOptions', 'U') IS NOT NULL DROP TABLE ExamSaaS.QuestionOptions;
IF OBJECT_ID('ExamSaaS.Questions', 'U') IS NOT NULL DROP TABLE ExamSaaS.Questions;
IF OBJECT_ID('ExamSaaS.QuestionBanks', 'U') IS NOT NULL DROP TABLE ExamSaaS.QuestionBanks;
IF OBJECT_ID('ExamSaaS.Courses', 'U') IS NOT NULL DROP TABLE ExamSaaS.Courses;
IF OBJECT_ID('ExamSaaS.RefreshTokens', 'U') IS NOT NULL DROP TABLE ExamSaaS.RefreshTokens;
IF OBJECT_ID('ExamSaaS.AspNetUserTokens', 'U') IS NOT NULL DROP TABLE ExamSaaS.AspNetUserTokens;
IF OBJECT_ID('ExamSaaS.AspNetUserLogins', 'U') IS NOT NULL DROP TABLE ExamSaaS.AspNetUserLogins;
IF OBJECT_ID('ExamSaaS.AspNetUserClaims', 'U') IS NOT NULL DROP TABLE ExamSaaS.AspNetUserClaims;
IF OBJECT_ID('ExamSaaS.AspNetRoleClaims', 'U') IS NOT NULL DROP TABLE ExamSaaS.AspNetRoleClaims;
IF OBJECT_ID('ExamSaaS.AspNetUserRoles', 'U') IS NOT NULL DROP TABLE ExamSaaS.AspNetUserRoles;
IF OBJECT_ID('ExamSaaS.AspNetUsers', 'U') IS NOT NULL DROP TABLE ExamSaaS.AspNetUsers;
IF OBJECT_ID('ExamSaaS.AspNetRoles', 'U') IS NOT NULL DROP TABLE ExamSaaS.AspNetRoles;
IF OBJECT_ID('ExamSaaS.Tenants', 'U') IS NOT NULL DROP TABLE ExamSaaS.Tenants;
GO

-- ============================================================================
-- 3. CORE MULTI-TENANT TABLES DEFINITION (DDL)
-- ============================================================================

-- Table 1: Tenants (Multi-Tenant Master Registry)
CREATE TABLE ExamSaaS.Tenants (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_ExamSaaS_Tenants PRIMARY KEY DEFAULT NEWID(),
    Identifier NVARCHAR(50) NOT NULL, -- Subdomain / Tenant Slug (e.g. "mit", "stanford", "microsoft")
    Name NVARCHAR(150) NOT NULL,
    Plan INT NOT NULL CONSTRAINT DF_ExamSaaS_Tenants_Plan DEFAULT 1, -- 0: Free, 1: Professional, 2: Enterprise
    MaxCandidateSlots INT NOT NULL CONSTRAINT DF_ExamSaaS_Tenants_MaxCandidateSlots DEFAULT 500,
    BrandColorHex NVARCHAR(10) NULL CONSTRAINT DF_ExamSaaS_Tenants_BrandColorHex DEFAULT '#2563eb',
    IsActive BIT NOT NULL CONSTRAINT DF_ExamSaaS_Tenants_IsActive DEFAULT 1,
    CreatedAtUtc DATETIME2(7) NOT NULL CONSTRAINT DF_ExamSaaS_Tenants_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_ExamSaaS_Tenants_Identifier UNIQUE (Identifier)
);
GO

-- Table 2: AspNetRoles
CREATE TABLE ExamSaaS.AspNetRoles (
    Id NVARCHAR(450) NOT NULL CONSTRAINT PK_ExamSaaS_AspNetRoles PRIMARY KEY,
    Name NVARCHAR(256) NULL,
    NormalizedName NVARCHAR(256) NULL,
    ConcurrencyStamp NVARCHAR(MAX) NULL,
    Description NVARCHAR(250) NULL,
    CONSTRAINT UQ_ExamSaaS_AspNetRoles_NormalizedName UNIQUE (NormalizedName)
);
GO

-- Table 3: AspNetUsers (Tenant-Partitioned)
CREATE TABLE ExamSaaS.AspNetUsers (
    Id NVARCHAR(450) NOT NULL CONSTRAINT PK_ExamSaaS_AspNetUsers PRIMARY KEY,
    TenantId UNIQUEIDENTIFIER NULL, -- Nullable for Global SystemAdmin
    UserCode NVARCHAR(30) NOT NULL, -- Student ID / Staff ID (e.g. "STD-2026-104")
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL,
    IsActive BIT NOT NULL CONSTRAINT DF_ExamSaaS_AspNetUsers_IsActive DEFAULT 1,
    CreatedAtUtc DATETIME2(7) NOT NULL CONSTRAINT DF_ExamSaaS_AspNetUsers_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
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
    CONSTRAINT FK_ExamSaaS_AspNetUsers_Tenants FOREIGN KEY (TenantId) REFERENCES ExamSaaS.Tenants(Id) ON DELETE CASCADE
);
GO

CREATE NONCLUSTERED INDEX IX_ExamSaaS_AspNetUsers_TenantId ON ExamSaaS.AspNetUsers (TenantId);
CREATE NONCLUSTERED INDEX IX_ExamSaaS_AspNetUsers_NormalizedEmail ON ExamSaaS.AspNetUsers (NormalizedEmail);
GO

-- Table 4: AspNetUserRoles
CREATE TABLE ExamSaaS.AspNetUserRoles (
    UserId NVARCHAR(450) NOT NULL,
    RoleId NVARCHAR(450) NOT NULL,
    CONSTRAINT PK_ExamSaaS_AspNetUserRoles PRIMARY KEY (UserId, RoleId),
    CONSTRAINT FK_ExamSaaS_AspNetUserRoles_AspNetUsers FOREIGN KEY (UserId) REFERENCES ExamSaaS.AspNetUsers (Id) ON DELETE CASCADE,
    CONSTRAINT FK_ExamSaaS_AspNetUserRoles_AspNetRoles FOREIGN KEY (RoleId) REFERENCES ExamSaaS.AspNetRoles (Id) ON DELETE CASCADE
);
GO

-- Identity Sub-tables
CREATE TABLE ExamSaaS.AspNetRoleClaims (
    Id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ExamSaaS_AspNetRoleClaims PRIMARY KEY,
    RoleId NVARCHAR(450) NOT NULL,
    ClaimType NVARCHAR(MAX) NULL,
    ClaimValue NVARCHAR(MAX) NULL,
    CONSTRAINT FK_ExamSaaS_AspNetRoleClaims_AspNetRoles FOREIGN KEY (RoleId) REFERENCES ExamSaaS.AspNetRoles (Id) ON DELETE CASCADE
);
GO

CREATE TABLE ExamSaaS.AspNetUserClaims (
    Id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ExamSaaS_AspNetUserClaims PRIMARY KEY,
    UserId NVARCHAR(450) NOT NULL,
    ClaimType NVARCHAR(MAX) NULL,
    ClaimValue NVARCHAR(MAX) NULL,
    CONSTRAINT FK_ExamSaaS_AspNetUserClaims_AspNetUsers FOREIGN KEY (UserId) REFERENCES ExamSaaS.AspNetUsers (Id) ON DELETE CASCADE
);
GO

CREATE TABLE ExamSaaS.AspNetUserLogins (
    LoginProvider NVARCHAR(128) NOT NULL,
    ProviderKey NVARCHAR(128) NOT NULL,
    ProviderDisplayName NVARCHAR(MAX) NULL,
    UserId NVARCHAR(450) NOT NULL,
    CONSTRAINT PK_ExamSaaS_AspNetUserLogins PRIMARY KEY (LoginProvider, ProviderKey),
    CONSTRAINT FK_ExamSaaS_AspNetUserLogins_AspNetUsers FOREIGN KEY (UserId) REFERENCES ExamSaaS.AspNetUsers (Id) ON DELETE CASCADE
);
GO

CREATE TABLE ExamSaaS.AspNetUserTokens (
    UserId NVARCHAR(450) NOT NULL,
    LoginProvider NVARCHAR(128) NOT NULL,
    Name NVARCHAR(128) NOT NULL,
    Value NVARCHAR(MAX) NULL,
    CONSTRAINT PK_ExamSaaS_AspNetUserTokens PRIMARY KEY (UserId, LoginProvider, Name),
    CONSTRAINT FK_ExamSaaS_AspNetUserTokens_AspNetUsers FOREIGN KEY (UserId) REFERENCES ExamSaaS.AspNetUsers (Id) ON DELETE CASCADE
);
GO

-- Table 5: RefreshTokens
CREATE TABLE ExamSaaS.RefreshTokens (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_ExamSaaS_RefreshTokens PRIMARY KEY DEFAULT NEWID(),
    TenantId UNIQUEIDENTIFIER NOT NULL,
    UserId NVARCHAR(450) NOT NULL,
    Token NVARCHAR(256) NOT NULL,
    JwtId NVARCHAR(128) NOT NULL,
    IsUsed BIT NOT NULL CONSTRAINT DF_ExamSaaS_RefreshTokens_IsUsed DEFAULT 0,
    IsRevoked BIT NOT NULL CONSTRAINT DF_ExamSaaS_RefreshTokens_IsRevoked DEFAULT 0,
    CreatedAtUtc DATETIME2(7) NOT NULL CONSTRAINT DF_ExamSaaS_RefreshTokens_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
    ExpiresAtUtc DATETIME2(7) NOT NULL,
    ReplacedByToken NVARCHAR(256) NULL,
    CONSTRAINT UQ_ExamSaaS_RefreshTokens_Token UNIQUE (Token),
    CONSTRAINT FK_ExamSaaS_RefreshTokens_AspNetUsers FOREIGN KEY (UserId) REFERENCES ExamSaaS.AspNetUsers (Id) ON DELETE CASCADE,
    CONSTRAINT FK_ExamSaaS_RefreshTokens_Tenants FOREIGN KEY (TenantId) REFERENCES ExamSaaS.Tenants(Id)
);
GO

CREATE NONCLUSTERED INDEX IX_ExamSaaS_RefreshTokens_UserId ON ExamSaaS.RefreshTokens (UserId);
CREATE NONCLUSTERED INDEX IX_ExamSaaS_RefreshTokens_TenantId ON ExamSaaS.RefreshTokens (TenantId);
GO

-- Table 6: Courses (Tenant-Scoped)
CREATE TABLE ExamSaaS.Courses (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_ExamSaaS_Courses PRIMARY KEY DEFAULT NEWID(),
    TenantId UNIQUEIDENTIFIER NOT NULL,
    Code NVARCHAR(30) NOT NULL, -- e.g. "CS-501", "AZ-900"
    Title NVARCHAR(150) NOT NULL,
    Description NVARCHAR(500) NULL,
    CreatedByInstructorId NVARCHAR(450) NOT NULL,
    CreatedAtUtc DATETIME2(7) NOT NULL CONSTRAINT DF_ExamSaaS_Courses_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_ExamSaaS_Courses_Tenants FOREIGN KEY (TenantId) REFERENCES ExamSaaS.Tenants(Id),
    CONSTRAINT FK_ExamSaaS_Courses_Instructor FOREIGN KEY (CreatedByInstructorId) REFERENCES ExamSaaS.AspNetUsers(Id)
);
GO

CREATE NONCLUSTERED INDEX IX_ExamSaaS_Courses_TenantId ON ExamSaaS.Courses (TenantId);
GO

-- Table 7: QuestionBanks
CREATE TABLE ExamSaaS.QuestionBanks (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_ExamSaaS_QuestionBanks PRIMARY KEY DEFAULT NEWID(),
    TenantId UNIQUEIDENTIFIER NOT NULL,
    CourseId UNIQUEIDENTIFIER NOT NULL,
    Title NVARCHAR(150) NOT NULL,
    Description NVARCHAR(300) NULL,
    CreatedAtUtc DATETIME2(7) NOT NULL CONSTRAINT DF_ExamSaaS_QuestionBanks_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_ExamSaaS_QuestionBanks_Tenants FOREIGN KEY (TenantId) REFERENCES ExamSaaS.Tenants(Id),
    CONSTRAINT FK_ExamSaaS_QuestionBanks_Courses FOREIGN KEY (CourseId) REFERENCES ExamSaaS.Courses(Id) ON DELETE CASCADE
);
GO

-- Table 8: Questions
CREATE TABLE ExamSaaS.Questions (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_ExamSaaS_Questions PRIMARY KEY DEFAULT NEWID(),
    TenantId UNIQUEIDENTIFIER NOT NULL,
    BankId UNIQUEIDENTIFIER NOT NULL,
    Text NVARCHAR(MAX) NOT NULL,
    QuestionType INT NOT NULL CONSTRAINT DF_ExamSaaS_Questions_Type DEFAULT 0, -- 0: MultipleChoice, 1: TrueFalse, 2: ShortAnswer
    Points DECIMAL(5,2) NOT NULL CONSTRAINT DF_ExamSaaS_Questions_Points DEFAULT 1.00,
    Explanation NVARCHAR(MAX) NULL,
    CreatedAtUtc DATETIME2(7) NOT NULL CONSTRAINT DF_ExamSaaS_Questions_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_ExamSaaS_Questions_Tenants FOREIGN KEY (TenantId) REFERENCES ExamSaaS.Tenants(Id),
    CONSTRAINT FK_ExamSaaS_Questions_Banks FOREIGN KEY (BankId) REFERENCES ExamSaaS.QuestionBanks(Id) ON DELETE CASCADE
);
GO

-- Table 9: QuestionOptions
CREATE TABLE ExamSaaS.QuestionOptions (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_ExamSaaS_QuestionOptions PRIMARY KEY DEFAULT NEWID(),
    QuestionId UNIQUEIDENTIFIER NOT NULL,
    OptionText NVARCHAR(MAX) NOT NULL,
    IsCorrect BIT NOT NULL CONSTRAINT DF_ExamSaaS_QuestionOptions_IsCorrect DEFAULT 0,
    OrderIndex INT NOT NULL CONSTRAINT DF_ExamSaaS_QuestionOptions_OrderIndex DEFAULT 1,
    CONSTRAINT FK_ExamSaaS_QuestionOptions_Questions FOREIGN KEY (QuestionId) REFERENCES ExamSaaS.Questions(Id) ON DELETE CASCADE
);
GO

-- Table 10: Exams
CREATE TABLE ExamSaaS.Exams (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_ExamSaaS_Exams PRIMARY KEY DEFAULT NEWID(),
    TenantId UNIQUEIDENTIFIER NOT NULL,
    CourseId UNIQUEIDENTIFIER NOT NULL,
    Title NVARCHAR(200) NOT NULL,
    AccessCode NVARCHAR(20) NOT NULL, -- Secure randomized pass-code for candidate entry (e.g. "EXAM-9941")
    DurationMinutes INT NOT NULL CONSTRAINT DF_ExamSaaS_Exams_Duration DEFAULT 60,
    PassingScorePercent DECIMAL(5,2) NOT NULL CONSTRAINT DF_ExamSaaS_Exams_PassingScore DEFAULT 70.00,
    TotalMarks DECIMAL(5,2) NOT NULL CONSTRAINT DF_ExamSaaS_Exams_TotalMarks DEFAULT 100.00,
    MaxTabSwitchesAllowed INT NOT NULL CONSTRAINT DF_ExamSaaS_Exams_MaxTabSwitches DEFAULT 3,
    IsActive BIT NOT NULL CONSTRAINT DF_ExamSaaS_Exams_IsActive DEFAULT 1,
    CreatedById NVARCHAR(450) NOT NULL,
    CreatedAtUtc DATETIME2(7) NOT NULL CONSTRAINT DF_ExamSaaS_Exams_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_ExamSaaS_Exams_Tenants FOREIGN KEY (TenantId) REFERENCES ExamSaaS.Tenants(Id),
    CONSTRAINT FK_ExamSaaS_Exams_Courses FOREIGN KEY (CourseId) REFERENCES ExamSaaS.Courses(Id),
    CONSTRAINT FK_ExamSaaS_Exams_CreatedBy FOREIGN KEY (CreatedById) REFERENCES ExamSaaS.AspNetUsers(Id)
);
GO

CREATE NONCLUSTERED INDEX IX_ExamSaaS_Exams_TenantId ON ExamSaaS.Exams (TenantId);
CREATE NONCLUSTERED INDEX IX_ExamSaaS_Exams_AccessCode ON ExamSaaS.Exams (AccessCode);
GO

-- Table 11: ExamQuestions (Junction Table)
CREATE TABLE ExamSaaS.ExamQuestions (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_ExamSaaS_ExamQuestions PRIMARY KEY DEFAULT NEWID(),
    TenantId UNIQUEIDENTIFIER NOT NULL,
    ExamId UNIQUEIDENTIFIER NOT NULL,
    QuestionId UNIQUEIDENTIFIER NOT NULL,
    OrderIndex INT NOT NULL CONSTRAINT DF_ExamSaaS_ExamQuestions_Order DEFAULT 1,
    CONSTRAINT FK_ExamSaaS_ExamQuestions_Tenants FOREIGN KEY (TenantId) REFERENCES ExamSaaS.Tenants(Id),
    CONSTRAINT FK_ExamSaaS_ExamQuestions_Exams FOREIGN KEY (ExamId) REFERENCES ExamSaaS.Exams(Id) ON DELETE CASCADE,
    CONSTRAINT FK_ExamSaaS_ExamQuestions_Questions FOREIGN KEY (QuestionId) REFERENCES ExamSaaS.Questions(Id)
);
GO

-- Table 12: CandidateExamSessions (Real-Time Proctor State Machine)
CREATE TABLE ExamSaaS.CandidateExamSessions (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_ExamSaaS_CandidateExamSessions PRIMARY KEY DEFAULT NEWID(),
    TenantId UNIQUEIDENTIFIER NOT NULL,
    ExamId UNIQUEIDENTIFIER NOT NULL,
    CandidateId NVARCHAR(450) NOT NULL,
    Status INT NOT NULL CONSTRAINT DF_ExamSaaS_CandidateExamSessions_Status DEFAULT 0, -- 0: NotStarted, 1: InProgress, 2: Submitted, 3: AutoSubmittedTimeout, 4: FlaggedCheating
    StartTimeUtc DATETIME2(7) NULL,
    EndTimeUtc DATETIME2(7) NULL,
    TimeRemainingSeconds INT NOT NULL,
    FinalScore DECIMAL(5,2) NULL,
    Percentage DECIMAL(5,2) NULL,
    HasPassed BIT NULL,
    TabSwitchCount INT NOT NULL CONSTRAINT DF_ExamSaaS_CandidateExamSessions_TabSwitches DEFAULT 0,
    IsFlagged BIT NOT NULL CONSTRAINT DF_ExamSaaS_CandidateExamSessions_IsFlagged DEFAULT 0,
    FlagReason NVARCHAR(250) NULL,
    SessionKey UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_ExamSaaS_CandidateExamSessions_SessionKey DEFAULT NEWID(),
    RowVersion ROWVERSION NOT NULL,
    CreatedAtUtc DATETIME2(7) NOT NULL CONSTRAINT DF_ExamSaaS_CandidateExamSessions_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_ExamSaaS_CandidateExamSessions_Tenants FOREIGN KEY (TenantId) REFERENCES ExamSaaS.Tenants(Id),
    CONSTRAINT FK_ExamSaaS_CandidateExamSessions_Exams FOREIGN KEY (ExamId) REFERENCES ExamSaaS.Exams(Id),
    CONSTRAINT FK_ExamSaaS_CandidateExamSessions_Candidate FOREIGN KEY (CandidateId) REFERENCES ExamSaaS.AspNetUsers(Id)
);
GO

CREATE NONCLUSTERED INDEX IX_ExamSaaS_CandidateExamSessions_TenantId ON ExamSaaS.CandidateExamSessions (TenantId);
CREATE NONCLUSTERED INDEX IX_ExamSaaS_CandidateExamSessions_CandidateId ON ExamSaaS.CandidateExamSessions (CandidateId);
CREATE NONCLUSTERED INDEX IX_ExamSaaS_CandidateExamSessions_Status ON ExamSaaS.CandidateExamSessions (Status);
GO

-- Table 13: CandidateAnswers (Live Progress & Auto-Grading)
CREATE TABLE ExamSaaS.CandidateAnswers (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_ExamSaaS_CandidateAnswers PRIMARY KEY DEFAULT NEWID(),
    TenantId UNIQUEIDENTIFIER NOT NULL,
    SessionId UNIQUEIDENTIFIER NOT NULL,
    QuestionId UNIQUEIDENTIFIER NOT NULL,
    SelectedOptionId UNIQUEIDENTIFIER NULL,
    TextResponse NVARCHAR(MAX) NULL,
    IsEvaluated BIT NOT NULL CONSTRAINT DF_ExamSaaS_CandidateAnswers_IsEvaluated DEFAULT 0,
    AwardedMarks DECIMAL(5,2) NOT NULL CONSTRAINT DF_ExamSaaS_CandidateAnswers_AwardedMarks DEFAULT 0.00,
    AnsweredAtUtc DATETIME2(7) NOT NULL CONSTRAINT DF_ExamSaaS_CandidateAnswers_AnsweredAtUtc DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_ExamSaaS_CandidateAnswers_Tenants FOREIGN KEY (TenantId) REFERENCES ExamSaaS.Tenants(Id),
    CONSTRAINT FK_ExamSaaS_CandidateAnswers_Sessions FOREIGN KEY (SessionId) REFERENCES ExamSaaS.CandidateExamSessions(Id) ON DELETE CASCADE,
    CONSTRAINT FK_ExamSaaS_CandidateAnswers_Questions FOREIGN KEY (QuestionId) REFERENCES ExamSaaS.Questions(Id),
    CONSTRAINT FK_ExamSaaS_CandidateAnswers_Options FOREIGN KEY (SelectedOptionId) REFERENCES ExamSaaS.QuestionOptions(Id)
);
GO

CREATE NONCLUSTERED INDEX IX_ExamSaaS_CandidateAnswers_SessionId ON ExamSaaS.CandidateAnswers (SessionId);
GO

-- Table 14: ProctorEvents (SignalR Real-Time Audit & Anti-Cheat Telemetry)
CREATE TABLE ExamSaaS.ProctorEvents (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_ExamSaaS_ProctorEvents PRIMARY KEY DEFAULT NEWID(),
    TenantId UNIQUEIDENTIFIER NOT NULL,
    SessionId UNIQUEIDENTIFIER NOT NULL,
    EventType NVARCHAR(50) NOT NULL, -- HEARTBEAT, TAB_SWITCH, WINDOW_BLUR, DISCONNECTED, TIME_WARNING, CHEAT_FLAGGED
    Severity INT NOT NULL CONSTRAINT DF_ExamSaaS_ProctorEvents_Severity DEFAULT 0, -- 0: Info, 1: Warning, 2: Critical
    Details NVARCHAR(500) NULL,
    TimestampUtc DATETIME2(7) NOT NULL CONSTRAINT DF_ExamSaaS_ProctorEvents_TimestampUtc DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_ExamSaaS_ProctorEvents_Tenants FOREIGN KEY (TenantId) REFERENCES ExamSaaS.Tenants(Id),
    CONSTRAINT FK_ExamSaaS_ProctorEvents_Sessions FOREIGN KEY (SessionId) REFERENCES ExamSaaS.CandidateExamSessions(Id) ON DELETE CASCADE
);
GO

CREATE NONCLUSTERED INDEX IX_ExamSaaS_ProctorEvents_SessionId ON ExamSaaS.ProctorEvents (SessionId);
CREATE NONCLUSTERED INDEX IX_ExamSaaS_ProctorEvents_TimestampUtc ON ExamSaaS.ProctorEvents (TimestampUtc DESC);
GO

-- Table 15: AuditLogs (Tenant-Partitioned Immutable Auditing)
CREATE TABLE ExamSaaS.AuditLogs (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_ExamSaaS_AuditLogs PRIMARY KEY DEFAULT NEWID(),
    TenantId UNIQUEIDENTIFIER NULL,
    UserId NVARCHAR(450) NULL,
    UserEmail NVARCHAR(100) NULL,
    Action NVARCHAR(50) NOT NULL, -- CREATE, UPDATE, DELETE, PROCTOR_ACTION, EXAM_SUBMIT
    EntityName NVARCHAR(100) NOT NULL,
    EntityId NVARCHAR(100) NOT NULL,
    OldValues NVARCHAR(MAX) NULL,
    NewValues NVARCHAR(MAX) NULL,
    TimestampUtc DATETIME2(7) NOT NULL CONSTRAINT DF_ExamSaaS_AuditLogs_TimestampUtc DEFAULT SYSUTCDATETIME()
);
GO

-- Table 16: SubscriptionRequests (Platform-wide Tenant Inquiries & Plan Purchases)
CREATE TABLE ExamSaaS.SubscriptionRequests (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_ExamSaaS_SubscriptionRequests PRIMARY KEY DEFAULT NEWID(),
    OrganizationName NVARCHAR(150) NOT NULL,
    SuggestedIdentifier NVARCHAR(50) NULL,
    ContactName NVARCHAR(100) NOT NULL,
    ContactEmail NVARCHAR(150) NOT NULL,
    ContactPhone NVARCHAR(30) NULL,
    RequestedPlan INT NOT NULL CONSTRAINT DF_ExamSaaS_SubscriptionRequests_RequestedPlan DEFAULT 1, -- 0: Free, 1: Professional, 2: Enterprise
    EstimatedCandidates INT NOT NULL CONSTRAINT DF_ExamSaaS_SubscriptionRequests_EstimatedCandidates DEFAULT 500,
    AdditionalNotes NVARCHAR(1000) NULL,
    Status INT NOT NULL CONSTRAINT DF_ExamSaaS_SubscriptionRequests_Status DEFAULT 0, -- 0: Pending, 1: Approved, 2: Rejected
    RejectionReason NVARCHAR(500) NULL,
    ProcessedAtUtc DATETIME2(7) NULL,
    ProcessedByUserId NVARCHAR(450) NULL,
    CreatedTenantId UNIQUEIDENTIFIER NULL,
    CreatedAtUtc DATETIME2(7) NOT NULL CONSTRAINT DF_ExamSaaS_SubscriptionRequests_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
    UpdatedAtUtc DATETIME2(7) NULL,
    IsDeleted BIT NOT NULL CONSTRAINT DF_ExamSaaS_SubscriptionRequests_IsDeleted DEFAULT 0,
    CONSTRAINT FK_ExamSaaS_SubscriptionRequests_Tenants FOREIGN KEY (CreatedTenantId) REFERENCES ExamSaaS.Tenants(Id) ON DELETE SET NULL
);
GO

CREATE NONCLUSTERED INDEX IX_ExamSaaS_SubscriptionRequests_Status ON ExamSaaS.SubscriptionRequests (Status);
GO

-- ============================================================================
-- 4. STORED PROCEDURES (ExamSaaS Schema)
-- ============================================================================

-- Stored Procedure 1: sp_StartCandidateExamSession
-- Validates access code, initializes timer, generates atomic candidate session
CREATE PROCEDURE ExamSaaS.sp_StartCandidateExamSession
    @TenantId UNIQUEIDENTIFIER,
    @ExamId UNIQUEIDENTIFIER,
    @CandidateId NVARCHAR(450),
    @NewSessionId UNIQUEIDENTIFIER OUTPUT,
    @DurationMinutes INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Check if exam exists and is active for this tenant
        SELECT @DurationMinutes = DurationMinutes
        FROM ExamSaaS.Exams
        WHERE Id = @ExamId AND TenantId = @TenantId AND IsActive = 1;

        IF @DurationMinutes IS NULL
        BEGIN
            THROW 51001, 'Exam is either inactive or does not belong to your organization.', 1;
        END

        -- 2. Check if candidate already has an active or submitted session
        DECLARE @ExistingStatus INT;
        SELECT @ExistingStatus = Status, @NewSessionId = Id
        FROM ExamSaaS.CandidateExamSessions
        WHERE ExamId = @ExamId AND CandidateId = @CandidateId AND TenantId = @TenantId;

        IF @ExistingStatus = 1 -- Already InProgress
        BEGIN
            COMMIT TRANSACTION;
            RETURN;
        END

        IF @ExistingStatus IN (2, 3, 4) -- Already Submitted or Flagged
        BEGIN
            THROW 51002, 'You have already completed or submitted this assessment.', 1;
        END

        -- 3. Create fresh exam session
        SET @NewSessionId = NEWID();
        DECLARE @TotalSeconds INT = @DurationMinutes * 60;

        INSERT INTO ExamSaaS.CandidateExamSessions (
            Id, TenantId, ExamId, CandidateId, Status, StartTimeUtc,
            TimeRemainingSeconds, TabSwitchCount, IsFlagged, CreatedAtUtc
        )
        VALUES (
            @NewSessionId, @TenantId, @ExamId, @CandidateId, 1, -- InProgress
            SYSUTCDATETIME(), @TotalSeconds, 0, 0, SYSUTCDATETIME()
        );

        -- Log Initial Proctor Event
        INSERT INTO ExamSaaS.ProctorEvents (Id, TenantId, SessionId, EventType, Severity, Details, TimestampUtc)
        VALUES (NEWID(), @TenantId, @NewSessionId, 'EXAM_STARTED', 0, 'Candidate launched exam session.', SYSUTCDATETIME());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- Stored Procedure 2: sp_SubmitCandidateExamSession
-- Computes auto-grading for all multiple choice questions, calculates percentages, updates status
CREATE PROCEDURE ExamSaaS.sp_SubmitCandidateExamSession
    @TenantId UNIQUEIDENTIFIER,
    @SessionId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @ExamId UNIQUEIDENTIFIER;
        DECLARE @CandidateId NVARCHAR(450);
        DECLARE @PassingPercent DECIMAL(5,2);
        DECLARE @TotalExamMarks DECIMAL(5,2);

        SELECT @ExamId = s.ExamId, @CandidateId = s.CandidateId, 
               @PassingPercent = e.PassingScorePercent, @TotalExamMarks = e.TotalMarks
        FROM ExamSaaS.CandidateExamSessions s
        INNER JOIN ExamSaaS.Exams e ON s.ExamId = e.Id
        WHERE s.Id = @SessionId AND s.TenantId = @TenantId;

        IF @ExamId IS NULL
        BEGIN
            THROW 51003, 'Exam session not found.', 1;
        END

        -- Auto-grade multiple-choice answers by comparing SelectedOptionId with IsCorrect option
        UPDATE ca
        SET ca.IsEvaluated = 1,
            ca.AwardedMarks = CASE WHEN qo.IsCorrect = 1 THEN q.Points ELSE 0.00 END
        FROM ExamSaaS.CandidateAnswers ca
        INNER JOIN ExamSaaS.Questions q ON ca.QuestionId = q.Id
        LEFT JOIN ExamSaaS.QuestionOptions qo ON ca.SelectedOptionId = qo.Id
        WHERE ca.SessionId = @SessionId;

        -- Sum total score
        DECLARE @EarnedScore DECIMAL(5,2);
        SELECT @EarnedScore = ISNULL(SUM(AwardedMarks), 0.00)
        FROM ExamSaaS.CandidateAnswers
        WHERE SessionId = @SessionId;

        DECLARE @CalculatedPercent DECIMAL(5,2) = 0.00;
        IF @TotalExamMarks > 0
        BEGIN
            SET @CalculatedPercent = ROUND((@EarnedScore / @TotalExamMarks) * 100.0, 2);
        END

        DECLARE @HasPassed BIT = CASE WHEN @CalculatedPercent >= @PassingPercent THEN 1 ELSE 0 END;

        -- Finalize Session
        UPDATE ExamSaaS.CandidateExamSessions
        SET Status = 2, -- Submitted
            EndTimeUtc = SYSUTCDATETIME(),
            TimeRemainingSeconds = 0,
            FinalScore = @EarnedScore,
            Percentage = @CalculatedPercent,
            HasPassed = @HasPassed
        WHERE Id = @SessionId;

        -- Log Final Proctor Event
        INSERT INTO ExamSaaS.ProctorEvents (Id, TenantId, SessionId, EventType, Severity, Details, TimestampUtc)
        VALUES (
            NEWID(), @TenantId, @SessionId, 'EXAM_SUBMITTED', 0, 
            CONCAT('Score: ', @EarnedScore, '/', @TotalExamMarks, ' (', @CalculatedPercent, '%) - Passed: ', @HasPassed), 
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

-- Stored Procedure 3: sp_LogProctorEvent
-- Logs telemetry (tab-switches, focus loss) and auto-flags cheating when threshold exceeded
CREATE PROCEDURE ExamSaaS.sp_LogProctorEvent
    @TenantId UNIQUEIDENTIFIER,
    @SessionId UNIQUEIDENTIFIER,
    @EventType NVARCHAR(50),
    @Severity INT,
    @Details NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO ExamSaaS.ProctorEvents (Id, TenantId, SessionId, EventType, Severity, Details, TimestampUtc)
        VALUES (NEWID(), @TenantId, @SessionId, @EventType, @Severity, @Details, SYSUTCDATETIME());

        -- If event is a tab switch / window blur, increment counter
        IF @EventType IN ('TAB_SWITCH', 'WINDOW_BLUR')
        BEGIN
            UPDATE ExamSaaS.CandidateExamSessions
            SET TabSwitchCount = TabSwitchCount + 1
            WHERE Id = @SessionId;

            -- Check if threshold exceeded
            DECLARE @CurrentCount INT, @MaxAllowed INT;
            SELECT @CurrentCount = s.TabSwitchCount, @MaxAllowed = e.MaxTabSwitchesAllowed
            FROM ExamSaaS.CandidateExamSessions s
            INNER JOIN ExamSaaS.Exams e ON s.ExamId = e.Id
            WHERE s.Id = @SessionId;

            IF @CurrentCount > @MaxAllowed
            BEGIN
                UPDATE ExamSaaS.CandidateExamSessions
                SET IsFlagged = 1,
                    FlagReason = CONCAT('Exceeded maximum allowable tab switches (', @CurrentCount, '/', @MaxAllowed, ').')
                WHERE Id = @SessionId;

                INSERT INTO ExamSaaS.ProctorEvents (Id, TenantId, SessionId, EventType, Severity, Details, TimestampUtc)
                VALUES (NEWID(), @TenantId, @SessionId, 'CHEAT_FLAGGED', 2, 'Candidate flagged by automated anti-cheat heuristic.', SYSUTCDATETIME());
            END
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- Stored Procedure 4: sp_GetTenantProctorDashboardSummary
-- Real-time analytics for the Instructor & Proctor command console
CREATE PROCEDURE ExamSaaS.sp_GetTenantProctorDashboardSummary
    @TenantId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    -- Session counts by status
    SELECT 
        COUNT(s.Id) AS TotalSessions,
        SUM(CASE WHEN s.Status = 1 THEN 1 ELSE 0 END) AS ActiveLiveSessions,
        SUM(CASE WHEN s.Status IN (2, 3) THEN 1 ELSE 0 END) AS CompletedSessions,
        SUM(CASE WHEN s.IsFlagged = 1 THEN 1 ELSE 0 END) AS FlaggedCheatingSessions,
        ISNULL(AVG(s.Percentage), 0.00) AS AverageCandidateScorePercent
    FROM ExamSaaS.CandidateExamSessions s
    WHERE s.TenantId = @TenantId;

    -- Recent High-Severity Proctor Warnings
    SELECT TOP 10
        pe.Id,
        pe.EventType,
        pe.Severity,
        pe.Details,
        pe.TimestampUtc,
        u.FirstName + ' ' + u.LastName AS CandidateName,
        e.Title AS ExamTitle
    FROM ExamSaaS.ProctorEvents pe
    INNER JOIN ExamSaaS.CandidateExamSessions s ON pe.SessionId = s.Id
    INNER JOIN ExamSaaS.AspNetUsers u ON s.CandidateId = u.Id
    INNER JOIN ExamSaaS.Exams e ON s.ExamId = e.Id
    WHERE pe.TenantId = @TenantId AND pe.Severity >= 1
    ORDER BY pe.TimestampUtc DESC;
END;
GO

-- ============================================================================
-- 5. INITIAL SEED DATA (Tenants, Roles, Courses, Exams, Users)
-- ============================================================================

-- Seed Demo Tenants
DECLARE @TenantAcmeId UNIQUEIDENTIFIER = '11111111-2222-3333-4444-555555555555';
DECLARE @TenantApexUnivId UNIQUEIDENTIFIER = '22222222-3333-4444-5555-666666666666';

INSERT INTO ExamSaaS.Tenants (Id, Identifier, Name, Plan, MaxCandidateSlots, BrandColorHex, IsActive)
VALUES
    (@TenantAcmeId, 'acme-corp', 'Acme Global Corporate Academy', 2, 2000, '#0284c7', 1),
    (@TenantApexUnivId, 'apex-university', 'Apex Institute of Technology', 1, 1000, '#7c3aed', 1);
GO

-- Seed Roles
INSERT INTO ExamSaaS.AspNetRoles (Id, Name, NormalizedName, ConcurrencyStamp, Description)
VALUES
    ('role-sysadmin', 'SystemAdmin', 'SYSTEMADMIN', NEWID(), 'Global SaaS platform administrator'),
    ('role-tenantadmin', 'TenantAdmin', 'TENANTADMIN', NEWID(), 'Organization SuperAdmin managing branding, instructors, and subscriptions'),
    ('role-instructor', 'Instructor', 'INSTRUCTOR', NEWID(), 'Authors courses, question banks, and publishes exams'),
    ('role-proctor', 'Proctor', 'PROCTOR', NEWID(), 'Real-time live session proctor monitoring anti-cheat telemetry'),
    ('role-candidate', 'Candidate', 'CANDIDATE', NEWID(), 'Student / examinee taking timed assessments');
GO

-- Seed Global Platform SuperAdmin (TenantId = NULL)
DECLARE @SysAdminId NVARCHAR(450) = 'user-sysadmin-001';
INSERT INTO ExamSaaS.AspNetUsers (Id, UserName, NormalizedUserName, Email, NormalizedEmail, EmailConfirmed, PasswordHash, SecurityStamp, ConcurrencyStamp, UserCode, FirstName, LastName, TenantId, IsActive, CreatedAtUtc)
VALUES (
    @SysAdminId,
    'superadmin@examnexus.com',
    'SUPERADMIN@EXAMNEXUS.COM',
    'superadmin@examnexus.com',
    'SUPERADMIN@EXAMNEXUS.COM',
    1,
    'AQAAAAIAAYagAAAAEG498qJt8tF0Ld78x6k0rD6yX9hJ2mP1q9+o8lK0m1a2b3c4d5e6f7g8h9i0j1k2l3==', -- P@ssword123!
    NEWID(),
    NEWID(),
    'SYS-001',
    'Global',
    'SuperAdmin',
    NULL,
    1,
    SYSUTCDATETIME()
);

INSERT INTO ExamSaaS.AspNetUserRoles (UserId, RoleId)
VALUES (@SysAdminId, 'role-sysadmin');
GO

-- Seed Sample Prospective Plan Inquiries
INSERT INTO ExamSaaS.SubscriptionRequests (Id, OrganizationName, SuggestedIdentifier, ContactName, ContactEmail, ContactPhone, RequestedPlan, EstimatedCandidates, AdditionalNotes, Status, CreatedAtUtc)
VALUES
    (NEWID(), 'Stanford Online Prep Institute', 'stanford-prep', 'Dr. Eleanor Vance', 'eleanor.vance@stanfordprep.edu', '+1 650 555 0192', 2, 2500, 'Evaluating for spring semester finals with live SignalR tab-switch monitoring.', 0, DATEADD(hour, -18, SYSUTCDATETIME())),
    (NEWID(), 'FinTech Global Academy', 'fintech-global', 'Liam Henderson', 'liam.h@fintech-academy.io', '+44 20 7946 0912', 1, 450, 'Need immediate onboarding for compliance certification tests.', 0, DATEADD(hour, -6, SYSUTCDATETIME()));
GO

PRINT 'ExamNexus Multi-Tenant SaaS database schema [ExamSaaS], 15 tables, 4 stored procedures, and seed data created successfully.';
GO
