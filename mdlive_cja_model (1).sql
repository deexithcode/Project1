-- ============================================================
-- MDLIVE Customer Journey Analytics (CJA) – Dimensional Model
-- Source: Adobe CJA Web + Mobile App event exports (XDM)
-- Target: Databricks / Delta Lake (Gold/Semantic layer)
-- Grain of fact  : ONE ROW PER EVENT (_id)
-- ============================================================

-- ------------------------------------------------------------
-- FACT: fct_digital_events
-- One row per _id (a single web/app interaction event)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fct_digital_events (
    event_id                STRING       COMMENT 'Natural key (_id from source). Grain = 1 row per event.',
    event_ts                TIMESTAMP    COMMENT 'Event timestamp (from `timestamp`).',
    date_key                INT          COMMENT 'FK -> dim_date (yyyymmdd).',
    channel                 STRING       COMMENT 'Web | App (derived from source dataset).',
    event_type              STRING       COMMENT 'pageLoad, pageAction, web.webpagedetails.pageViews, web.webinteraction.linkClicks, application.launch/close, errorInfo.',
    -- Dimension foreign keys
    user_key                STRING       COMMENT 'FK -> dim_user (experienceCloudID / ECID).',
    device_key              STRING       COMMENT 'FK -> dim_device.',
    geo_key                 STRING       COMMENT 'FK -> dim_geo.',
    page_key                STRING       COMMENT 'FK -> dim_page.',
    insurance_key           STRING       COMMENT 'FK -> dim_insurance.',
    -- Degenerate / measure attributes
    login_status            STRING       COMMENT 'LOGGED_IN | NOT_LOGGED_IN.',
    page_views              INT          COMMENT 'Additive measure: 1 when the event is a page view.',
    link_clicks             INT          COMMENT 'Additive measure: 1 when the event is a link/control click.',
    control_name            STRING       COMMENT 'UI control clicked (e.g. login_signIn_attempt, timeSlot).',
    interaction_name        STRING       COMMENT 'Friendly name of the interaction.',
    session_length_sec      INT          COMMENT 'App session length (from application.close events).',
    error_ind               INT          COMMENT '1 if event_type = errorInfo.',
    -- Lineage / ops
    source_file_name        STRING       COMMENT 'S3 parquet source path (lineage).',
    export_time             STRING       COMMENT 'CJA export batch id.',
    ingestion_ts            TIMESTAMP    COMMENT 'Pipeline load timestamp.'
)
USING DELTA
PARTITIONED BY (channel, date_key)
COMMENT 'Event-grain fact for MDLIVE web & mobile digital analytics.';

-- ------------------------------------------------------------
-- DIM: dim_user  (grain = 1 row per ECID)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim_user (
    user_key                STRING       COMMENT 'PK = experienceCloudID (ECID).',
    account_id              STRING       COMMENT 'MDLIVE accountID (nullable for anonymous).',
    user_type               STRING       COMMENT 'Internal / External.',
    login_type              STRING       COMMENT 'Direct / SSO etc.',
    age                     INT          COMMENT 'Reported member age.',
    gender                  STRING       COMMENT 'Normalise casing (Male/Female/Non-binary).',
    lifecycle_segment       STRING       COMMENT 'new | returning.',
    service_history         STRING       COMMENT 'e.g. hasVisits.',
    patient_type            STRING,
    member_relationship     STRING,
    scd_start_ts            TIMESTAMP,
    scd_end_ts              TIMESTAMP,
    is_current              BOOLEAN
)
USING DELTA
COMMENT 'Member/visitor dimension keyed on ECID. SCD Type 2 recommended.';

-- ------------------------------------------------------------
-- DIM: dim_device
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim_device (
    device_key              STRING       COMMENT 'PK = hash(type, manufacturer, model, os, browser).',
    device_type             STRING       COMMENT 'Desktop | Mobile Phone.',
    manufacturer            STRING       COMMENT 'Samsung, Google, Apple...',
    model                   STRING       COMMENT 'Galaxy S24, Pixel 9, iPhone...',
    operating_system        STRING       COMMENT 'Android, iOS, Windows 10, macOS, Linux.',
    browser_name            STRING       COMMENT 'Chrome, Samsung Browser, Safari...',
    screen_height           INT,
    screen_width            INT
)
USING DELTA
COMMENT 'Device & browser dimension.';

-- ------------------------------------------------------------
-- DIM: dim_geo
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim_geo (
    geo_key                 STRING       COMMENT 'PK = hash(country, state, city, postal).',
    country_code            STRING,
    state_province          STRING       COMMENT 'e.g. US-CA, IN-TS.',
    city                    STRING,
    postal_code             STRING,
    iana_timezone           STRING
)
USING DELTA
COMMENT 'Geography dimension derived from placeContext.geo.';

-- ------------------------------------------------------------
-- DIM: dim_page
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim_page (
    page_key                STRING       COMMENT 'PK = hash(page_name, page_type, site_section).',
    page_name               STRING       COMMENT 'e.g. Mdlive:BookVisit.',
    page_type               STRING       COMMENT 'Dashboard, Login, Urgent Care, Primary Care, Behavioral...',
    site                    STRING       COMMENT 'Mdlive | MDLive Mobile App.',
    site_section            STRING       COMMENT 'Dashboard, Access...',
    auth_type               STRING       COMMENT 'Pre-/Post-Authentication.',
    funnel_stage            STRING       COMMENT 'Derived: SelectProvider->BookVisit->ConfirmPatient->PaymentInfo->AppointmentConfirmed.'
)
USING DELTA
COMMENT 'Page/screen dimension.';

-- ------------------------------------------------------------
-- DIM: dim_insurance
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim_insurance (
    insurance_key           STRING       COMMENT 'PK = insuranceProvider code.',
    insurance_provider_code STRING       COMMENT 'e.g. 18880, 96, dtc, bcbsil.',
    insurance_provider_name STRING       COMMENT 'Enrich via reference/lookup table.'
)
USING DELTA
COMMENT 'Insurance / client-org dimension from clientOrgDetails.insuranceProvider.';

-- ------------------------------------------------------------
-- DIM: dim_date  (standard calendar)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim_date (
    date_key                INT          COMMENT 'PK yyyymmdd.',
    full_date               DATE,
    day_of_week             STRING,
    week_of_year            INT,
    month                   INT,
    month_name              STRING,
    quarter                 INT,
    year                    INT,
    is_weekend              BOOLEAN
)
USING DELTA
COMMENT 'Standard calendar dimension.';
