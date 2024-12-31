
CREATE TABLE area {
	   id INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
	   name TEXT NOT NULL,

	   description TEXT,
	   illustration_image_path TEXT,
	   plan_image_path TEXT,
}

CREATE TABLE storage {
	   id INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
	   name TEXT NOT NULL,
	   area INTEGER NOT NULL REFERENCES area,

	   description TEXT,
	   illustration_image_path TEXT,
	   plan_image_path TEXT,
}

CREATE TABLE item {
	   id INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
	   name TEXT NOT NULL,

	   count INTEGER NOT NULL DEFAULT 1,
	   description TEXT,
	   value REAL,
	   storage INTEGER NOT NULL REFERENCES storage,
	   illustration_image_path TEXT,
}
