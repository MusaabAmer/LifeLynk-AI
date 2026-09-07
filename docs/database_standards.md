# Database Standards

## Primary Keys

- UUID
- Never Integer IDs

---

## Foreign Keys

Suffix:

_id

Example:

user_id

hospital_id

reservation_id

---

## Naming

snake_case

Correct

blood_inventory

Wrong

BloodInventory

---

## Time

UTC

TIMESTAMPTZ

---

## Delete

Soft Delete

deleted_at

---

## Enums

Always PostgreSQL ENUM

Never plain VARCHAR

---

## Boolean

Prefix

is_

Examples

is_active

is_verified

is_read

---

## Audit

Every business table

created_at

updated_at

deleted_at

---

## Relationships

Always use Foreign Keys

Never store duplicate data.
