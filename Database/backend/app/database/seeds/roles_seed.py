from sqlalchemy.orm import Session

from app.database.models.role import Role


ROLES = [
    {
        "name": "SUPER_ADMIN",
        "description": "System Super Administrator",
    },
    {
        "name": "GOVERNMENT_ADMIN",
        "description": "Government Health Authority",
    },
    {
        "name": "HOSPITAL_ADMIN",
        "description": "Hospital Administrator",
    },
    {
        "name": "BLOOD_BANK_ADMIN",
        "description": "Blood Bank Administrator",
    },
    {
        "name": "STAFF",
        "description": "Organization Staff Member",
    },
    {
        "name": "DONOR",
        "description": "Registered Blood Donor",
    },
    {
        "name": "PATIENT",
        "description": "Patient",
    },
]


def seed_roles(db: Session):
    """
    Insert default roles.
    """

    for role in ROLES:

        exists = (
            db.query(Role)
            .filter(Role.name == role["name"])
            .first()
        )

        if not exists:
            db.add(Role(**role))

    db.commit()

    print("✓ Roles seeded successfully.")