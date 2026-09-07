import json
from pathlib import Path


SOURCE_FILE = (
    Path(__file__).parent
    / "data"
    / "world_locations.json"
)

OUTPUT_FILE = (
    Path(__file__).parent
    / "data"
    / "pakistan_locations.json"
)


def generate_pakistan_dataset():

    with open(
        SOURCE_FILE,
        "r",
        encoding="utf-8",
    ) as file:

        countries = json.load(file)

    pakistan = next(
        (
            country
            for country in countries
            if country["name"] == "Pakistan"
        ),
        None,
    )

    if pakistan is None:
        raise Exception("Pakistan not found in dataset.")

    with open(
        OUTPUT_FILE,
        "w",
        encoding="utf-8",
    ) as file:

        json.dump(
            pakistan,
            file,
            indent=4,
            ensure_ascii=False,
        )

    print("✓ pakistan_locations.json generated successfully.")


if __name__ == "__main__":
    generate_pakistan_dataset()