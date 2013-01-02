PRAGMA foreign_keys = ON;

CREATE TABLE kanji (
	kanji_id INTEGER PRIMARY KEY,
	literal VARCHAR(5)
);

CREATE TABLE kanji_codepoint (
	codepoint_id INTEGER PRIMARY KEY,
	codepoint_type VARCHAR(20),
	codepoint_value VARCHAR(20),
	fk_kanji_id INTEGER,
	FOREIGN KEY (fk_kanji_id) REFERENCES Kanji(kanji_id)
);

CREATE TABLE kanji_radical (
	radical_id INTEGER PRIMARY KEY,
	radical_type VARCHAR(20),
	radical_value VARCHAR(20),
	fk_kanji_id INTEGER,
	FOREIGN KEY (fk_kanji_id) REFERENCES Kanji(kanji_id)
);

CREATE TABLE kanji_misc (
	misc_id INTEGER PRIMARY KEY,
	misc_type VARCHAR(20),
	misc_sub_type VARCHAR(20),
	misc_value VARCHAR(20),
	fk_kanji_id INTEGER,
	FOREIGN KEY (fk_kanji_id) REFERENCES Kanji(kanji_id)
);

CREATE TABLE kanji_dict_ref (
	dict_ref_id INTEGER PRIMARY KEY,
	dict_ref_type VARCHAR(20),
	dict_ref_m_vol VARCHAR(20),
	dict_ref_m_page VARCHAR(20),
	dict_ref_value VARCHAR(20),
	fk_kanji_id INTEGER,
	FOREIGN KEY (fk_kanji_id) REFERENCES Kanji(kanji_id)
);

CREATE TABLE kanji_query_code (
	query_code_id INTEGER PRIMARY KEY,
	query_code_type VARCHAR(20),
	query_code_misclass_type VARCHAR(20),
	query_code_value VARCHAR(20),
	fk_kanji_id INTEGER,
	FOREIGN KEY (fk_kanji_id) REFERENCES Kanji(kanji_id)
);

CREATE TABLE kanji_reading (
	reading_id INTEGER PRIMARY KEY,
	reading_type VARCHAR(20),
	reading_value VARCHAR(20),
	fk_kanji_id INTEGER,
	FOREIGN KEY (fk_kanji_id) REFERENCES Kanji(kanji_id)
);

CREATE TABLE kanji_meaning (
	meaning_id INTEGER PRIMARY KEY,
	meaning_value VARCHAR(20),
	fk_kanji_id INTEGER,
	FOREIGN KEY (fk_kanji_id) REFERENCES Kanji(kanji_id)
);