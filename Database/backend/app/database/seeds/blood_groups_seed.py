from sqlalchemy.orm import Session

from app.database.models.blood_group import BloodGroup


BLOOD_GROUPS = [
    {"code": "A+", "name": "A Positive"},
    {"code": "A-", "name": "A Negative"},
    {"code": "B+", "name": "B Positive"},
    {"code": "B-", "name": "B Negative"},
    {"code": "AB+", "name": "AB Positive"},
    {"code": "AB-", "name": "AB Negative"},
    {"code": "O+", "name": "O Positive"},
    {"code": "O-", "name": "O Negative"},
]


def seed_blood_groups(db: Session):
    """
    Insert all blood groups.
    """

    for blood_group in BLOOD_GROUPS:

        exists = (
            db.query(BloodGroup)
            .filter(BloodGroup.code == blood_group["code"])
            .first()
        )

        if not exists:
            db.add(BloodGroup(**blood_group))

    db.commit()

    print("✓ Blood groups seeded successfully.")