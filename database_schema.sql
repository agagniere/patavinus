CREATE TABLE area (
	   id INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
	   name TEXT NOT NULL,
	   plan_image_path TEXT NOT NULL,

	   description TEXT,
	   illustration_image_path TEXT
);

CREATE TABLE storage (
	   id INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
	   name TEXT NOT NULL,
	   area INTEGER NOT NULL REFERENCES area ON DELETE RESTRICT,
	   position_in_area POINT NOT NULL,
	   plan_image_path TEXT NOT NULL,

	   description TEXT,
	   illustration_image_path TEXT
);

CREATE TABLE item (
	   id INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
	   name TEXT NOT NULL,
	   storage INTEGER NOT NULL REFERENCES storage ON DELETE RESTRICT,
	   count INTEGER NOT NULL DEFAULT 1,
	   illustration_image_path TEXT NOT NULL,

	   description TEXT,
	   value REAL
);
