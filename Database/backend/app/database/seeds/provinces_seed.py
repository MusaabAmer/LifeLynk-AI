from sqlalchemy.orm import Session

from app.database.models.province import Province


PROVINCES = [
    {
        "name": "Punjab",
        "code": "PK-PB",
    },
    {
        "name": "Sindh",
        "code": "PK-SD",
    },
    {
        "name": "Khyber Pakhtunkhwa",
        "code": "PK-KP",
    },
    {
        "name": "Balochistan",
        "code": "PK-BA",
    },
    {
        "name": "Islamabad Capital Territory",
        "code": "PK-IS",
    },
    {
        "name": "Gilgit Baltistan",
        "code": "PK-GB",
    },
    {
        "name": "Azad Jammu & Kashmir",
        "code": "PK-JK",
    },
]


def seed_provinces(db: Session):
    """
    Insert Pakistan provinces.
    """

    for province in PROVINCES:

        exists = (
            db.query(Province)
            .filter(Province.code == province["code"])
            .first()
        )

        if not exists:
            db.add(Province(**province))

    db.commit()

    print("✓ Provinces seeded successfully.")