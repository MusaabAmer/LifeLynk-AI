# Database Design Document

<!-- markdownlint-disable MD024 MD060 MD047 -->

## Project

LifeLynk AI – Pakistan's National Digital Blood Infrastructure

## Purpose

This document defines the complete PostgreSQL database architecture for the LifeLynk AI platform.

It serves as the single source of truth for database development and integration across backend services, frontend applications, AI services, analytics, and government dashboards.

The document specifies database entities, relationships, constraints, indexing strategies, naming conventions, and security considerations.

All database implementation, SQLAlchemy models, Alembic migrations, and API contracts must follow this specification.

## Design Principles

The database has been designed according to the following principles:

- Third Normal Form (3NF)
- Data Integrity
- High Availability
- Scalability
- Security by Design
- Auditability
- Maintainability
- Extensibility
- Performance Optimization

## Database Standards

Database Engine:
PostgreSQL 17+

ORM:
SQLAlchemy 2.x

Migration Tool:
Alembic

Primary Keys:
UUID

Time Zone:
UTC

Timestamp Type:
TIMESTAMPTZ

Naming Convention:
snake_case

Soft Delete:
deleted_at

Relationship Enforcement:
Foreign Keys

Schema Versioning:
Alembic

Database Platform:
Supabase PostgreSQL

## Modules Overview

| Module          | Purpose                           |
| --------------- | --------------------------------- |
| Authentication  | User accounts, roles, permissions |
| Geography       | Provinces and cities              |
| Organizations   | Hospitals, blood banks, staff     |
| Patients        | Patient profiles                  |
| Blood Inventory | Blood stock management            |
| Reservations    | Blood reservation workflow        |
| Emergency       | SOS requests                      |
| Notifications   | User notifications                |
| AI              | AI chat and feedback              |
| Audit           | System audit logs                 |

## Entity Relationship Overview

The LifeLynk AI database is organized into ten logical modules.

Each module represents a specific business domain while maintaining referential integrity through foreign key relationships.

## High-Level Relationships

Authentication
    │
    ▼
Users
    │
    ├──────────────┐
    ▼              ▼
Patients     Organization Staff
                    │
                    ▼
             Organizations
              ├────────────┐
              ▼            ▼
        Hospitals     Blood Banks
              │            │
              └──────┬─────┘
                     ▼
              Blood Inventory
                     │
                     ▼
              Reservations
                     │
                     ▼
           Reservation History

Organizations
       │
       ▼
Cities
       │
       ▼
Provinces

Users
 ├───────────────┐
 ▼               ▼
Notifications   AI Chat

Users
     │
     ▼
Emergency Requests

Users
     │
     ▼
Login Logs

Users
     │
     ▼
Refresh Tokens

Users
     │
     ▼
User Sessions

## Table Specifications

## Table: roles

### Purpose

The `roles` table defines the user roles used throughout the LifeLynk AI platform.

Each user account is assigned exactly one role.

The role determines the user's access level through the Role-Based Access Control (RBAC) system.

---

### Business Rules

- Every user must have one role.
- Role names must be unique.
- Roles cannot be deleted if they are assigned to users.
- Roles are managed only by System Administrators.

---

### Columns

| Column | Type | Nullable | Default | Description |
|---------|------|----------|---------|-------------|
| id | UUID | No | uuid_generate_v4() | Primary Key |
| name | VARCHAR(50) | No | — | Unique role name |
| description | TEXT | Yes | NULL | Role description |
| created_at | TIMESTAMPTZ | No | NOW() | Creation timestamp |
| updated_at | TIMESTAMPTZ | No | NOW() | Last update timestamp |

---

### Constraints

PRIMARY KEY (id)

UNIQUE (name)

---

### Relationships

One Role

↓

Many Users

One Role

↓

Many Role Permissions

---

### Indexes

Primary Key

Unique Index on name

---

### Initial Seed Data

ADMIN

PATIENT

HOSPITAL_STAFF

BLOOD_BANK_STAFF

GOVERNMENT

---

### Design Decision

Roles are stored as data rather than an ENUM to allow future expansion without schema changes.

## Table: permissions

### Purpose

The permissions table defines every action that can be performed within the LifeLynk AI platform.

Permissions are assigned to roles through the `role_permissions` table.

---

### Business Rules

- Permission names must be unique.
- Permissions cannot be duplicated.
- Permissions are grouped by functional module.
- Permissions are managed by administrators only.

---

### Columns

| Column | Type | Nullable | Default | Description |
|---------|------|----------|---------|-------------|
| id | UUID | No | uuid_generate_v4() | Primary Key |
| name | VARCHAR(100) | No | — | Permission name |
| module | VARCHAR(100) | No | — | Functional module |
| description | TEXT | Yes | NULL | Permission description |
| created_at | TIMESTAMPTZ | No | NOW() | Creation timestamp |
| updated_at | TIMESTAMPTZ | No | NOW() | Last update timestamp |

---

### Constraints

PRIMARY KEY (id)

UNIQUE (name)

---

### Relationships

One Permission

↓

Many Role Permissions

---

### Indexes

Primary Key

Unique Index on name

Index on module

---

### Example Permissions

users.view

users.create

users.update

users.delete

inventory.view

inventory.update

inventory.create

reservation.approve

reservation.reject

analytics.view

notifications.send

ai.chat

---

### Design Decision

Permissions follow the naming convention:

module.action

Examples

inventory.update

users.create

analytics.view

## Table: role_permissions

### Purpose

The `role_permissions` table establishes a many-to-many relationship between roles and permissions.

It defines which permissions are granted to each role.

This design enables a flexible Role-Based Access Control (RBAC) system where permissions can be added or removed without modifying application code.

---

### Business Rules

- A role can have multiple permissions.
- A permission can belong to multiple roles.
- The same role-permission combination cannot exist more than once.
- Permission assignments are managed only by System Administrators.

---

### Columns

| Column | Type | Nullable | Default | Description |
|---------|------|----------|---------|-------------|
| role_id | UUID | No | — | References roles.id |
| permission_id | UUID | No | — | References permissions.id |
| created_at | TIMESTAMPTZ | No | NOW() | Assignment timestamp |

---

### Primary Key

(role_id, permission_id)

---

### Foreign Keys

role_id → roles(id)

permission_id → permissions(id)

---

### Relationships

Many Roles

⇄

Many Permissions

---

### Constraints

PRIMARY KEY(role_id, permission_id)

FOREIGN KEY(role_id)

FOREIGN KEY(permission_id)

ON DELETE RESTRICT

---

### Indexes

Composite Primary Key

Index(role_id)

Index(permission_id)

---

### Design Decision

A composite primary key is used because each role-permission pair must be unique.

No surrogate UUID key is required for this junction table.

## Table: users

### Purpose

The `users` table stores authentication and identity information for every platform user.

This includes patients, hospital staff, blood bank staff, government officers, and system administrators.

Business-specific information is stored in separate profile tables.

---

### Business Rules

- Every user has exactly one role.
- Email must be unique.
- Username must be unique.
- Phone number must be unique.
- Passwords are stored only as secure hashes.
- Accounts can be activated or deactivated.
- Soft delete is used.

---

### Columns

| Column | Type | Nullable | Description |
|---------|------|----------|-------------|
| id | UUID | No | Primary Key |
| role_id | UUID | No | FK → roles.id |
| first_name | VARCHAR(100) | No | Given name |
| last_name | VARCHAR(100) | No | Family name |
| username | VARCHAR(50) | No | Unique username |
| email | VARCHAR(255) | No | Unique email |
| phone_number | VARCHAR(20) | No | Unique phone |
| password_hash | TEXT | No | Argon2 hashed password |
| profile_image_url | TEXT | Yes | Avatar URL |
| is_active | BOOLEAN | No | Account active |
| is_verified | BOOLEAN | No | Email/phone verified |
| last_login_at | TIMESTAMPTZ | Yes | Last login |
| created_at | TIMESTAMPTZ | No | Created |
| updated_at | TIMESTAMPTZ | No | Updated |
| deleted_at | TIMESTAMPTZ | Yes | Soft delete |

---

### Constraints

PRIMARY KEY(id)

FOREIGN KEY(role_id)

UNIQUE(email)

UNIQUE(username)

UNIQUE(phone_number)

CHECK(length(username)>=3)

---

### Relationships

One Role

↓

Many Users

One User

↓

One Patient

↓

OR

↓

One Organization Staff

↓

Many Sessions

↓

Many Refresh Tokens

↓

Many Notifications

↓

Many AI Chats

↓

Many Login Logs

---

### Indexes

PK(id)

UNIQUE(email)

UNIQUE(username)

UNIQUE(phone_number)

INDEX(role_id)

INDEX(is_active)

INDEX(last_login_at)

---

### Security Notes

Passwords are never stored.

Only Argon2 password hashes are stored.

JWT tokens are never stored inside this table.

## Table: refresh_tokens

### Purpose

The `refresh_tokens` table stores hashed refresh tokens issued to authenticated users.

Refresh tokens are used to generate new access tokens without requiring the user to log in again.

Only hashed refresh tokens are stored.

---

### Business Rules

- One user can have multiple active refresh tokens.
- Each refresh token belongs to exactly one user.
- Plain-text refresh tokens are never stored.
- Tokens can be individually revoked.
- Expired tokens should be periodically removed.

---

### Columns

| Column | Type | Nullable | Description |
|---------|------|----------|-------------|
| id | UUID | No | Primary Key |
| user_id | UUID | No | FK → users.id |
| token_hash | TEXT | No | Hashed refresh token |
| expires_at | TIMESTAMPTZ | No | Expiration timestamp |
| revoked_at | TIMESTAMPTZ | Yes | Revocation timestamp |
| created_at | TIMESTAMPTZ | No | Creation timestamp |

---

### Constraints

PRIMARY KEY(id)

FOREIGN KEY(user_id)

---

### Relationships

One User

↓

Many Refresh Tokens

---

### Indexes

PK(id)

INDEX(user_id)

INDEX(expires_at)

INDEX(revoked_at)

---

### Security Notes

Refresh tokens must be hashed before storage.

Expired or revoked tokens must never be accepted.

## Table: user_sessions

### Purpose

The `user_sessions` table records authenticated sessions for every device used by a user.

This enables secure session management, logout from specific devices, and future support for multi-device authentication.

---

### Business Rules

- A user can have multiple active sessions.
- Sessions expire automatically.
- Individual sessions can be revoked without affecting others.

---

### Columns

| Column | Type | Nullable | Description |
|---------|------|----------|-------------|
| id | UUID | No | Primary Key |
| user_id | UUID | No | FK → users.id |
| device_name | VARCHAR(150) | Yes | Device description |
| device_type | VARCHAR(50) | Yes | Mobile, Desktop, Tablet |
| operating_system | VARCHAR(100) | Yes | Android, iOS, Windows |
| browser | VARCHAR(100) | Yes | Chrome, Firefox, Safari |
| ip_address | INET | Yes | Client IP |
| user_agent | TEXT | Yes | Browser/User-Agent string |
| started_at | TIMESTAMPTZ | No | Session start |
| last_activity_at | TIMESTAMPTZ | No | Last request |
| expires_at | TIMESTAMPTZ | No | Session expiration |
| revoked_at | TIMESTAMPTZ | Yes | Logout/revocation time |

---

### Constraints

PRIMARY KEY(id)

FOREIGN KEY(user_id)

---

### Relationships

One User

↓

Many Sessions

---

### Indexes

PK(id)

INDEX(user_id)

INDEX(last_activity_at)

INDEX(expires_at)

INDEX(revoked_at)

## Table: login_logs

### Purpose

The `login_logs` table records every authentication attempt.

It supports security monitoring, suspicious activity detection, and compliance auditing.

---

### Business Rules

- Every login attempt is recorded.
- Both successful and failed attempts are logged.
- Logs are immutable.
- Records are never updated after creation.

---

### Columns

| Column | Type | Nullable | Description |
|---------|------|----------|-------------|
| id | UUID | No | Primary Key |
| user_id | UUID | Yes | FK → users.id (nullable if user not found) |
| email | VARCHAR(255) | No | Email used during login |
| status | VARCHAR(20) | No | SUCCESS / FAILED |
| failure_reason | VARCHAR(255) | Yes | Reason for failure |
| ip_address | INET | Yes | Client IP |
| user_agent | TEXT | Yes | Browser/User-Agent |
| attempted_at | TIMESTAMPTZ | No | Attempt timestamp |

---

### Constraints

PRIMARY KEY(id)

FOREIGN KEY(user_id)

CHECK(status IN ('SUCCESS','FAILED'))

---

### Relationships

One User

↓

Many Login Logs

---

### Indexes

PK(id)

INDEX(user_id)

INDEX(email)

INDEX(status)

INDEX(attempted_at)

## Table: provinces

### Purpose

The `provinces` table stores the administrative provinces and territories of Pakistan.

It acts as a master reference table for geographical data and supports national reporting, analytics, and location-based searches.

---

### Business Rules

- Province names must be unique.
- Provinces are managed by System Administrators.
- Provinces are considered master data.
- Provinces cannot be deleted if cities exist.

---

### Columns

| Column | Type | Nullable | Description |
|---------|------|----------|-------------|
| id | UUID | No | Primary Key |
| name | VARCHAR(100) | No | Province name |
| code | VARCHAR(10) | No | Short code (e.g. PB, SD) |
| created_at | TIMESTAMPTZ | No | Creation timestamp |
| updated_at | TIMESTAMPTZ | No | Last update timestamp |

---

### Constraints

PRIMARY KEY(id)

UNIQUE(name)

UNIQUE(code)

---

### Relationships

One Province

↓

Many Cities

---

### Indexes

PK(id)

UNIQUE(name)

UNIQUE(code)

---

### Initial Seed Data

Punjab

Sindh

Khyber Pakhtunkhwa

Balochistan

Islamabad Capital Territory

Gilgit-Baltistan

Azad Jammu & Kashmir

---

### Design Decision

Province names are stored only once and referenced by foreign keys from the `cities` table.

## Table: cities

### Purpose

The `cities` table stores all supported cities in Pakistan.

Each city belongs to exactly one province.

Cities are referenced throughout the platform for hospitals, blood banks, patients, reservations, emergency requests, and analytics.

---

### Business Rules

- Every city belongs to one province.
- City names may repeat across provinces.
- Duplicate city names within the same province are not allowed.
- Cities are master reference data.

---

### Columns

| Column | Type | Nullable | Description |
|---------|------|----------|-------------|
| id | UUID | No | Primary Key |
| province_id | UUID | No | FK → provinces.id |
| name | VARCHAR(150) | No | City name |
| latitude | NUMERIC(9,6) | Yes | City center latitude |
| longitude | NUMERIC(9,6) | Yes | City center longitude |
| created_at | TIMESTAMPTZ | No | Creation timestamp |
| updated_at | TIMESTAMPTZ | No | Last update timestamp |

---

### Constraints

PRIMARY KEY(id)

FOREIGN KEY(province_id)

UNIQUE(province_id, name)

---

### Relationships

One Province

↓

Many Cities

One City

↓

Many Hospitals

↓

Many Blood Banks

↓

Many Patients

---

### Indexes

PK(id)

INDEX(province_id)

INDEX(name)

---

### Design Decision

Latitude and longitude represent the city's approximate center.

These coordinates support:

- Nearby hospital search
- Google Maps integration
- AI demand prediction
- Distance calculations

## Table: organizations

### Purpose

The `organizations` table stores common information for all healthcare organizations registered in the LifeLynk AI platform.

Each organization is classified by its type and can have a specialized record in the corresponding subtype table.

---

### Business Rules

- Every organization has one type.
- Every organization belongs to one city.
- Organization names should be unique within the same city.
- Only verified organizations can publish blood inventory.
- Soft delete is supported.

---

### Columns

| Column | Type | Nullable | Description |
|---------|------|----------|-------------|
| id | UUID | No | Primary Key |
| organization_type | organization_type_enum | No | HOSPITAL / BLOOD_BANK |
| city_id | UUID | No | FK → cities.id |
| name | VARCHAR(255) | No | Official organization name |
| address_line | TEXT | No | Street address |
| postal_code | VARCHAR(20) | Yes | Postal code |
| phone_number | VARCHAR(20) | No | Primary contact |
| email | VARCHAR(255) | Yes | Official email |
| website | VARCHAR(255) | Yes | Website URL |
| latitude | NUMERIC(9,6) | No | Exact latitude |
| longitude | NUMERIC(9,6) | No | Exact longitude |
| is_verified | BOOLEAN | No | Government verification |
| verified_at | TIMESTAMPTZ | Yes | Verification date |
| created_at | TIMESTAMPTZ | No | Creation timestamp |
| updated_at | TIMESTAMPTZ | No | Last update |
| deleted_at | TIMESTAMPTZ | Yes | Soft delete |

---

### Constraints

PRIMARY KEY(id)

FOREIGN KEY(city_id)

UNIQUE(city_id, name)

---

### Relationships

One City

↓

Many Organizations

One Organization

↓

One Hospital OR One Blood Bank

One Organization

↓

Many Staff Members

One Organization

↓

Many Blood Inventory Records

---

### Indexes

PK(id)

INDEX(city_id)

INDEX(organization_type)

INDEX(is_verified)

INDEX(latitude, longitude)

## Table: hospitals

### Purpose

The `hospitals` table stores information specific to hospitals.

Each hospital record extends exactly one organization.

---

### Business Rules

- Every hospital must reference one organization.
- One organization can have only one hospital record.

---

### Columns

| Column | Type | Nullable | Description |
|---------|------|----------|-------------|
| organization_id | UUID | No | PK & FK → organizations.id |
| hospital_license_number | VARCHAR(100) | No | Government registration |
| hospital_category | hospital_category_enum | No | Public / Private / Military / Teaching |
| emergency_services | BOOLEAN | No | Emergency department available |
| trauma_center | BOOLEAN | No | Trauma center availability |
| created_at | TIMESTAMPTZ | No | Creation timestamp |
| updated_at | TIMESTAMPTZ | No | Last update |

---

### Constraints

PRIMARY KEY(organization_id)

FOREIGN KEY(organization_id)

UNIQUE(hospital_license_number)

---

### Relationships

One Organization

↓

One Hospital

## Table: blood_banks

### Purpose

The `blood_banks` table stores information specific to licensed blood banks.

Each blood bank extends one organization.

---

### Business Rules

- Every blood bank references one organization.
- License numbers are unique.
- Only licensed blood banks may maintain blood inventory.

---

### Columns

| Column | Type | Nullable | Description |
|---------|------|----------|-------------|
| organization_id | UUID | No | PK & FK → organizations.id |
| license_number | VARCHAR(100) | No | Government license |
| component_separation_available | BOOLEAN | No | Blood component processing |
| twenty_four_hours | BOOLEAN | No | 24/7 availability |
| created_at | TIMESTAMPTZ | No | Creation timestamp |
| updated_at | TIMESTAMPTZ | No | Last update |

---

### Constraints

PRIMARY KEY(organization_id)

FOREIGN KEY(organization_id)

UNIQUE(license_number)

---

### Relationships

One Organization

↓

One Blood Bank

## Table: organization_staff

### Purpose

The `organization_staff` table stores employment information for hospital and blood bank staff.

Authentication remains in the `users` table, while employment details are stored here.

---

### Business Rules

- Every staff member references one user.
- Every staff member belongs to one organization.
- A user may only be employed by one organization in the MVP.
- Employment can be activated or deactivated.

---

### Columns

| Column | Type | Nullable | Description |
|---------|------|----------|-------------|
| id | UUID | No | Primary Key |
| user_id | UUID | No | FK → users.id |
| organization_id | UUID | No | FK → organizations.id |
| employee_id | VARCHAR(100) | Yes | Internal employee identifier |
| job_title | VARCHAR(100) | No | Staff designation |
| is_active | BOOLEAN | No | Employment status |
| joined_at | DATE | No | Employment start date |
| created_at | TIMESTAMPTZ | No | Creation timestamp |
| updated_at | TIMESTAMPTZ | No | Last update |

---

### Constraints

PRIMARY KEY(id)

FOREIGN KEY(user_id)

FOREIGN KEY(organization_id)

UNIQUE(user_id)

---

### Relationships

One Organization

↓

Many Staff Members

One User

↓

One Organization Staff Profile

## Table: patients

### Purpose

The `patients` table stores patient-specific profile information.

Authentication data remains in the `users` table.

Each patient profile belongs to exactly one authenticated user.

---

### Business Rules

- Every patient must have one user account.
- A user can have only one patient profile.
- Blood group is required.
- Soft delete is supported.
- Patient data must be protected according to healthcare privacy standards.

---

### Columns

| Column | Type | Nullable | Description |
|---------|------|----------|-------------|
| id | UUID | No | Primary Key |
| user_id | UUID | No | FK → users.id |
| city_id | UUID | No | FK → cities.id |
| blood_group | blood_group_enum | No | Patient blood group |
| date_of_birth | DATE | No | Date of birth |
| gender | gender_enum | No | Patient gender |
| national_id | VARCHAR(20) | Yes | Government-issued ID (optional for MVP) |
| address_line | TEXT | Yes | Residential address |
| emergency_contact_name | VARCHAR(150) | Yes | Emergency contact |
| emergency_contact_phone | VARCHAR(20) | Yes | Emergency contact number |
| created_at | TIMESTAMPTZ | No | Creation timestamp |
| updated_at | TIMESTAMPTZ | No | Last update timestamp |
| deleted_at | TIMESTAMPTZ | Yes | Soft delete timestamp |

---

### Constraints

PRIMARY KEY(id)

FOREIGN KEY(user_id)

FOREIGN KEY(city_id)

UNIQUE(user_id)

CHECK(date_of_birth <= CURRENT_DATE)

---

### Relationships

One User

↓

One Patient

One City

↓

Many Patients

One Patient

↓

Many Reservations

One Patient

↓

Many Emergency Requests

---

### Indexes

PK(id)

UNIQUE(user_id)

INDEX(city_id)

INDEX(blood_group)

INDEX(date_of_birth)

## Table: blood_inventory

### Purpose

Stores the current available blood inventory for each organization.

Each record represents the available units of one blood group at one organization.

---

### Business Rules

- One organization can have one record per blood group.
- Available units cannot be negative.
- Reserved units cannot exceed available units.
- Inventory is updated through inventory movements.

---

### Columns

| Column | Type | Nullable | Description |
|---------|------|----------|-------------|
| id | UUID | No | Primary Key |
| organization_id | UUID | No | FK → organizations.id |
| blood_group | blood_group_enum | No | Blood group |
| available_units | INTEGER | No | Available blood units |
| reserved_units | INTEGER | No | Reserved units |
| minimum_threshold | INTEGER | No | Low-stock alert threshold |
| last_updated_at | TIMESTAMPTZ | No | Last inventory update |
| created_at | TIMESTAMPTZ | No | Created |
| updated_at | TIMESTAMPTZ | No | Updated |

---

### Constraints

PRIMARY KEY(id)

FOREIGN KEY(organization_id)

UNIQUE(organization_id, blood_group)

CHECK(available_units >= 0)

CHECK(reserved_units >= 0)

CHECK(minimum_threshold >= 0)

CHECK(reserved_units <= available_units)

---

### Relationships

One Organization

↓

Many Blood Inventory Records

One Blood Group

↓

One Inventory Record per Organization

---

### Indexes

PK(id)

INDEX(organization_id)

INDEX(blood_group)

INDEX(available_units)

## Table: blood_inventory_batches

Purpose

Stores individual blood batches.

Each batch has its own expiry date.

This enables FIFO inventory management and expiry tracking.

Columns

id

inventory_id

batch_number

blood_group

units

collection_date

expiry_date

status

created_at

## Table: blood_inventory_history

Purpose

Stores every inventory transaction.

Examples

Donation

Reservation

Expiry

Transfer

Manual Adjustment

Columns

id

inventory_id

batch_id

movement_type

quantity

reference_type

reference_id

performed_by

remarks

created_at

## Table: reservations

### Purpose

Stores blood reservation requests submitted by patients.

Each reservation belongs to one patient and one organization.

---

### Business Rules

- A patient may have multiple reservations.
- A reservation belongs to one organization.
- A reservation requests only one blood group.
- Quantity must be greater than zero.
- Status changes are tracked separately.
- Soft delete is supported.

---

### Columns

| Column | Type | Nullable | Description |
|---------|------|----------|-------------|
| id | UUID | No | Primary Key |
| reservation_number | VARCHAR(30) | No | Human-readable unique reservation number |
| patient_id | UUID | No | FK → patients.id |
| organization_id | UUID | No | FK → organizations.id |
| blood_group | blood_group_enum | No | Requested blood group |
| requested_units | INTEGER | No | Number of units requested |
| status | reservation_status_enum | No | Current reservation status |
| required_before | TIMESTAMPTZ | Yes | Required before date/time |
| notes | TEXT | Yes | Additional information |
| approved_by | UUID | Yes | FK → organization_staff.id |
| approved_at | TIMESTAMPTZ | Yes | Approval timestamp |
| fulfilled_at | TIMESTAMPTZ | Yes | Blood handed over |
| completed_at | TIMESTAMPTZ | Yes | Reservation completed |
| cancelled_at | TIMESTAMPTZ | Yes | Cancellation timestamp |
| cancellation_reason | TEXT | Yes | Reason for cancellation |
| created_at | TIMESTAMPTZ | No | Creation timestamp |
| updated_at | TIMESTAMPTZ | No | Last update timestamp |
| deleted_at | TIMESTAMPTZ | Yes | Soft delete timestamp |

---

### Constraints

PRIMARY KEY(id)

UNIQUE(reservation_number)

FOREIGN KEY(patient_id)

FOREIGN KEY(organization_id)

FOREIGN KEY(approved_by)

CHECK(requested_units > 0)

---

### Relationships

One Patient

↓

Many Reservations

One Organization

↓

Many Reservations

One Staff Member

↓

Many Approved Reservations

---

### Indexes

PK(id)

UNIQUE(reservation_number)

INDEX(patient_id)

INDEX(organization_id)

INDEX(status)

INDEX(blood_group)

INDEX(created_at)

## Table: reservation_status_history

### Purpose

Stores the complete history of reservation status changes.

---

### Columns

| Column | Type |
|---------|------|
| id | UUID |
| reservation_id | UUID |
| previous_status | reservation_status_enum |
| new_status | reservation_status_enum |
| changed_by | UUID |
| remarks | TEXT |
| created_at | TIMESTAMPTZ |

---

### Relationships

One Reservation

↓

Many Status History Records

One Staff Member

↓

Many Status Changes

## Table: emergency_requests

### Purpose

Stores high-priority emergency blood requests.

---

### Business Rules

- Every emergency request belongs to one patient.
- A request may optionally target one organization.
- Multiple organizations may view the same request.
- Emergency requests do not directly reduce inventory.
- Once accepted, an emergency request may create a reservation.

---

### Columns

| Column | Type | Nullable | Description |
|---------|------|----------|-------------|
| id | UUID | No | Primary Key |
| emergency_number | VARCHAR(30) | No | Human-readable emergency ID |
| patient_id | UUID | No | FK → patients.id |
| organization_id | UUID | Yes | FK → organizations.id |
| blood_group | blood_group_enum | No | Requested blood group |
| required_units | INTEGER | No | Requested units |
| priority | emergency_priority_enum | No | Priority level |
| status | emergency_status_enum | No | Current status |
| hospital_name | VARCHAR(255) | Yes | Treating hospital (optional) |
| hospital_address | TEXT | Yes | Hospital location |
| latitude | DECIMAL(9,6) | Yes | Latitude |
| longitude | DECIMAL(9,6) | Yes | Longitude |
| contact_name | VARCHAR(150) | No | Emergency contact person |
| contact_phone | VARCHAR(20) | No | Emergency contact number |
| notes | TEXT | Yes | Additional information |
| expires_at | TIMESTAMPTZ | Yes | Request expiry |
| accepted_by | UUID | Yes | FK → organization_staff.id |
| accepted_at | TIMESTAMPTZ | Yes | Acceptance timestamp |
| created_at | TIMESTAMPTZ | No | Creation timestamp |
| updated_at | TIMESTAMPTZ | No | Last update |
| deleted_at | TIMESTAMPTZ | Yes | Soft delete |

---

### Constraints

PRIMARY KEY(id)

UNIQUE(emergency_number)

FOREIGN KEY(patient_id)

FOREIGN KEY(organization_id)

FOREIGN KEY(accepted_by)

CHECK(required_units > 0)

---

### Indexes

PK(id)

UNIQUE(emergency_number)

INDEX(patient_id)

INDEX(organization_id)

INDEX(status)

INDEX(priority)

INDEX(blood_group)

INDEX(created_at)

## Table: notifications

### Purpose

Stores all notifications generated by the system.

Supports:

- Push notifications
- In-app notifications
- Notification history
- Delivery tracking

---

### Business Rules

- Every notification belongs to one user.
- Notifications are never physically deleted.
- Read status is tracked.
- Delivery status is tracked.
- Notifications may reference another entity.

---

### Columns

| Column | Type | Nullable | Description |
|---------|------|----------|-------------|
| id | UUID | No | Primary Key |
| user_id | UUID | No | FK → users.id |
| type | notification_type_enum | No | Notification type |
| status | notification_status_enum | No | Delivery status |
| title | VARCHAR(150) | No | Notification title |
| message | TEXT | No | Notification body |
| reference_type | VARCHAR(50) | Yes | reservations, emergency_requests, etc. |
| reference_id | UUID | Yes | Related entity ID |
| is_read | BOOLEAN | No | Read flag |
| read_at | TIMESTAMPTZ | Yes | Read timestamp |
| sent_at | TIMESTAMPTZ | Yes | Sent timestamp |
| delivered_at | TIMESTAMPTZ | Yes | Delivery timestamp |
| created_at | TIMESTAMPTZ | No | Creation timestamp |
| updated_at | TIMESTAMPTZ | No | Last update |
| deleted_at | TIMESTAMPTZ | Yes | Soft delete |

---

### Constraints

PRIMARY KEY(id)

FOREIGN KEY(user_id)

CHECK(
    (is_read = FALSE AND read_at IS NULL)
    OR
    (is_read = TRUE AND read_at IS NOT NULL)
)

---

### Relationships

One User

↓

Many Notifications

---

### Indexes

PK(id)

INDEX(user_id)

INDEX(type)

INDEX(status)

INDEX(is_read)

INDEX(created_at)

## Table: ai_chat_history

### Purpose

Stores conversations between authenticated users and the AI assistant.

Used for:

- Conversation history
- Context preservation
- Analytics
- Prompt improvement
- User support

---

### Business Rules

- Every chat belongs to one user.
- Messages are immutable after creation.
- AI responses are stored exactly as generated.
- Conversations can be soft deleted.

---

### Columns

| Column | Type | Nullable | Description |
|---------|------|----------|-------------|
| id | UUID | No | Primary Key |
| user_id | UUID | No | FK → users.id |
| session_id | UUID | No | Conversation session identifier |
| user_message | TEXT | No | User input |
| ai_response | TEXT | No | AI response |
| model_name | VARCHAR(100) | No | AI model used |
| response_time_ms | INTEGER | Yes | Processing time |
| tokens_used | INTEGER | Yes | Total tokens consumed |
| created_at | TIMESTAMPTZ | No | Creation timestamp |
| deleted_at | TIMESTAMPTZ | Yes | Soft delete |

---

### Constraints

PRIMARY KEY(id)

FOREIGN KEY(user_id)

CHECK(response_time_ms >= 0)

CHECK(tokens_used >= 0)

---

### Relationships

One User

↓

Many AI Conversations

One Session

↓

Many Messages

---

### Indexes

PK(id)

INDEX(user_id)

INDEX(session_id)

INDEX(created_at)

## Table: ai_feedback

### Purpose

Stores user feedback about AI responses.

Used to improve prompts and monitor AI quality.

---

### Columns

| Column | Type | Nullable |
|---------|------|----------|
| id | UUID | No |
| chat_id | UUID | No |
| user_id | UUID | No |
| rating | SMALLINT | No |
| feedback | TEXT | Yes |
| created_at | TIMESTAMPTZ | No |

---

### Constraints

PRIMARY KEY(id)

FOREIGN KEY(chat_id)

FOREIGN KEY(user_id)

CHECK(rating BETWEEN 1 AND 5)

---

### Relationships

One Chat

↓

Many Feedback Records

One User

↓

Many Feedback Records

---

### Indexes

PK(id)

INDEX(chat_id)

INDEX(user_id)

## Table: audit_logs

### Purpose

Stores an immutable record of important business actions.

Used for:

- Security investigations
- Compliance
- Operational monitoring
- Administrative reports

---

### Business Rules

- Audit records are append-only.
- Existing audit records are never updated.
- Audit records are never hard deleted.
- Every record identifies who performed the action.

---

### Columns

| Column | Type | Nullable | Description |
|---------|------|----------|-------------|
| id | UUID | No | Primary Key |
| user_id | UUID | Yes | FK → users.id (nullable for system actions) |
| action | audit_action_enum | No | Action performed |
| entity_type | VARCHAR(50) | No | reservations, blood_inventory, organizations, etc. |
| entity_id | UUID | Yes | ID of the affected entity |
| description | TEXT | Yes | Human-readable description |
| ip_address | INET | Yes | Client IP address |
| user_agent | TEXT | Yes | Browser/device information |
| created_at | TIMESTAMPTZ | No | Timestamp |

---

### Constraints

PRIMARY KEY(id)

FOREIGN KEY(user_id)

---

### Relationships

One User

↓

Many Audit Logs

---

### Indexes

PK(id)

INDEX(user_id)

INDEX(action)

INDEX(entity_type)

INDEX(entity_id)

INDEX(created_at)

## Table: login_logs

### Purpose

Stores user authentication attempts.

Used for:

- Security monitoring
- Detecting suspicious activity
- Failed login reporting

---

### Columns

| Column | Type | Nullable |
|---------|------|----------|
| id | UUID | No |
| user_id | UUID | Yes |
| email | VARCHAR(255) | Yes |
| success | BOOLEAN | No |
| failure_reason | VARCHAR(255) | Yes |
| ip_address | INET | Yes |
| user_agent | TEXT | Yes |
| logged_in_at | TIMESTAMPTZ | No |

---

### Constraints

PRIMARY KEY(id)

FOREIGN KEY(user_id)

---

### Relationships

One User

↓

Many Login Logs

---

### Indexes

PK(id)

INDEX(user_id)

INDEX(email)

INDEX(success)

INDEX(logged_in_at)