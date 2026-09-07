
# roles

| Column      | Data Type   | Nullable | Description                |
| ----------- | ----------- | -------- | -------------------------- |
| id          | UUID        | No       | Primary key                |
| name        | VARCHAR(50) | No       | Unique role name           |
| description | TEXT        | Yes      | Human-readable description |
| created_at  | TIMESTAMPTZ | No       | Record creation            |
| updated_at  | TIMESTAMPTZ | No       | Last update                |
