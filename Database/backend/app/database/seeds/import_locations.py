import json
from decimal import Decimal
from pathlib import Path

from sqlalchemy.orm import Session

from app.database.models.city import City
from app.database.models.province import Province


DATA_FILE = (
    Path(__file__).parent
    / "data"
    / "pakistan_locations.json"
)


PROVINCE_MAPPING = {
    "Punjab": "Punjab",
    "Sindh": "Sindh",
    "Khyber Pakhtunkhwa": "Khyber Pakhtunkhwa",
    "Balochistan": "Balochistan",
    "Islamabad": "Islamabad Capital Territory",
    "Islamabad Capital Territory": "Islamabad Capital Territory",
    "Gilgit-Baltistan": "Gilgit Baltistan",
    "Gilgit Baltistan": "Gilgit Baltistan",
    "Azad Kashmir": "Azad Jammu & Kashmir",
    "Azad Jammu and Kashmir": "Azad Jammu & Kashmir",
}


def load_dataset():
    with open(
        DATA_FILE,
        "r",
        encoding="utf-8",
    ) as file:
        return json.load(file)


def seed_cities(db: Session):

    dataset = load_dataset()

    if dataset["name"] != "Pakistan":
        raise Exception("Pakistan dataset not found.")

    inserted = 0
    skipped = 0

    for state in dataset["states"]:

        db_name = PROVINCE_MAPPING.get(state["name"])

        if not db_name:
            print(f"Skipping province: {state['name']}")
            continue

        province = (
            db.query(Province)
            .filter(
                Province.name == db_name
            )
            .first()
        )

        if not province:
            print(f"Province missing in database: {db_name}")
            continue

        for city in state["cities"]:

            city_name = city["name"].strip()

            exists = (
                db.query(City)
                .filter(
                    City.province_id == province.id,
                    City.name == city_name,
                )
                .first()
            )

            if exists:
                skipped += 1
                continue

            db.add(
                City(
                    province_id=province.id,
                    name=city_name,
                    code=f"PK-{city['id']}",
                    latitude=Decimal(city["latitude"]),
                    longitude=Decimal(city["longitude"]),
                    is_active=True,
                )
            )

            inserted += 1

    db.commit()

    print(f"\n✓ Imported {inserted} cities")
    print(f"✓ Skipped {skipped} existing cities")