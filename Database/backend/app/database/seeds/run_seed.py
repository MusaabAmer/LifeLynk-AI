from app.database.session import SessionLocal

from app.database.seeds.roles_seed import seed_roles
from app.database.seeds.blood_groups_seed import seed_blood_groups
from app.database.seeds.provinces_seed import seed_provinces
from app.database.seeds.import_locations import seed_cities



def run_seeds():

    db = SessionLocal()

    try:

        print("Starting database seeding...")

        # Phase 1: Roles
        seed_roles(db)

        # Phase 2: Blood Groups
        seed_blood_groups(db)

        # Phase 3: Provinces
        seed_provinces(db)

        # Phase 4: Cities
        seed_cities(db)


        print("✓ All seed data inserted successfully.")


    except Exception as e:

        db.rollback()

        print("❌ Seed failed:")
        print(e)

        raise


    finally:

        db.close()



if __name__ == "__main__":
    run_seeds()