# 🗄️ LifeLynk AI Database

> Database module for **LifeLynk AI – Pakistan's National Digital Blood Infrastructure for Blood Availability & Emergency Response**.

---

## Overview

The database is built using:

- PostgreSQL
- SQLAlchemy 2.0
- Alembic
- Supabase
- UUID Primary Keys
- Soft Delete
- Automatic Timestamps

The architecture is fully normalized and designed for scalability, security, and future AI integration.

---

## Technology Stack

| Technology | Purpose |

|------------|---------|
| PostgreSQL | Primary Relational Database |
| SQLAlchemy 2.0 | ORM |
| Alembic | Database Migrations |
| Supabase | Managed PostgreSQL |
| UUID | Primary Keys |
| Pydantic | Data Validation |

---

## Database Architecture

The database is divided into multiple modules.

## 1. Authentication

Responsible for authentication and authorization.

Tables

- roles
- users
- refresh_tokens

---

## 2. Location

Stores Pakistan administrative locations.

Tables

- provinces
- cities

---

## 3. Organizations

Stores hospitals and blood banks.

Tables

- organizations
- hospitals
- blood_banks
- organization_staff

---

## 4. Patients

Stores patient information.

Tables

- patients

---

## 5. Blood Management

Responsible for blood inventory.

Tables

- blood_groups
- blood_inventory
- blood_requests
- blood_reservations

---

## 6. Donor Management

Tables

- donors
- donor_availability
- donation_history
- donor_matches

---

## 7. Emergency

Tables

- emergency_sos

---

## 8. AI

Tables

- ai_chat_history

---

## 9. Notifications

Tables

- notifications

---

## 10. Government Analytics

Tables

- government_analytics

---

## 11. Auditing

Tables

- audit_logs

---

## Database Models

Current SQLAlchemy models

```text
roles
users
refresh_tokens

provinces
cities

organizations
hospitals
blood_banks
organization_staff

patients

blood_groups
blood_inventory
blood_requests
blood_reservations

donors
donor_availability
donation_history
donor_matches

emergency_sos

notifications

audit_logs

ai_chat_history

government_analytics
```

Total Models

```text
23
```

---

## Mixins

The project uses reusable mixins.

## UUIDPrimaryKeyMixin

Provides

```python
id UUID PRIMARY KEY
```

---

## TimestampMixin

Automatically manages

```text
created_at

updated_at
```

---

## SoftDeleteMixin

Provides

```text
deleted_at
```

for soft delete functionality.

---

## BaseModelMixin

Combines

- UUIDPrimaryKeyMixin
- TimestampMixin
- SoftDeleteMixin

Every business model inherits from this mixin.

---

## Database Features

- UUID Primary Keys
- Soft Delete
- Automatic Timestamps
- Foreign Keys
- Constraints
- Indexes
- Normalized Tables
- Alembic Migrations
- Seed Scripts

---

## Migrations

Alembic is used for schema versioning.

Create migration

```bash
alembic revision --autogenerate -m "message"
```

Apply migrations

```bash
alembic upgrade head
```

Rollback

```bash
alembic downgrade -1
```

Current migration

```bash
alembic current
```

History

```bash
alembic history
```

---

## Seed Data

Seed scripts are located in

```text
app/database/seeds/
```

Current seed files

```text
roles_seed.py

blood_groups_seed.py

provinces_seed.py

cities_seed.py

run_seed.py
```

Run all seeds

```bash
python -m app.database.seeds.run_seed
```

---

## Database Relationships

Examples

```text
Role
 │
 └──────< User

Province
 │
 └──────< City

Organization
 │
 ├──────< Hospital

 ├──────< Blood Bank

 ├──────< Blood Inventory

 └──────< Organization Staff

User
 │
 ├──────< Patient

 ├──────< Donor

 └──────< Refresh Token

Blood Inventory
 │
 └──────< Blood Reservation

Blood Request
 │
 └──────< Blood Reservation
```

---

## ER Diagram

The editable ER diagram is available in

```text
docs/ER_Diagram.dbml
```

Image version

```text
docs/ER_Diagram.png
```

PDF version

```text
docs/ER_Diagram.pdf
```

---

## Folder Structure

```text
database/

├── base.py
├── metadata.py
├── config.py

├── enums/

├── mixins/

├── models/

├── seeds/

├── utils/

└── README.md
```

---

## Current Database Status

| Module | Status |

|---------|--------|

| PostgreSQL | ✅ |
| SQLAlchemy Models | ✅ |
| Alembic | ✅ |
| Seed Data | ✅ |
| ER Diagram | ✅ |
| UUID Keys | ✅ |
| Soft Delete | ✅ |
| Constraints | ✅ |
| Indexes | ✅ |

---

## Future Enhancements

The following tables are planned for future releases if required:

- permissions
- role_permissions
- blood_inventory_batches
- blood_inventory_movements
- reservation_status_history
- login_logs
- ai_feedback

These are documented in the ER Diagram for future scalability but are not part of the current implementation.

---

## Development Guidelines

When creating a new model:

1. Inherit from `Base`
2. Inherit from `BaseModelMixin`
3. Add relationships
4. Add indexes where necessary
5. Add constraints
6. Generate Alembic migration
7. Test migration
8. Update ER Diagram if schema changes

---

## Contributors

| Member | Responsibility |

|---------|----------------|

| Musaab Amer | Database Architect & Project Lead |
| Arslan | Backend Development |
| Mueeza | Flutter Frontend |
| Muqaddas | AI Development |
| Urza | Testing & Documentation |

---

## Database Version

**Version:** 1.0

**Status:** Production Ready Database Foundation ✅
