#!/usr/bin/env ruby -KU

require 'ruby-progressbar'
require 'nokogiri'
require 'sqlite3'
require 'pry'

## Parsing file :
KanjiDictFile = File.open( 'kanjidic2.xml' )
dictionary = Nokogiri::XML( KanjiDictFile )

binding.pry

total = dictionary.search("//character").size
progressbar = ProgressBar.create(:title => "Processed", :starting_at => 0, :total => total)

kanjis = []
dictionary.search("//character").each do |character|
	puts 'start'

	cur_kanji = {}
	cur_kanji[:literal] = character.search("//literal")[0].text

	puts 'start1'
	cur_kanji_codepoints = []
 	codepoints = character.search("//codepoint/cp_value")
 	codepoints.each do |codepoint|
		cur_kanji_codepoints.push ({
			:codepoint_type => codepoint['cp_type'],
			:codepoint 	    => codepoint.text
		})
 	end
 	cur_kanji[:codepoints] = cur_kanji_codepoints

	puts 'start2'
	cur_kanji_radicals = []
 	character.search("//radical/rad_value").each do |radical|
		cur_kanji_radicals.push ({
			:radical_type => radical['rad_type'],
			:radical 	    => radical.text
		})
 	end
 	cur_kanji[:radicals] = cur_kanji_radicals


	puts 'start3'
 	cur_kanji_miscs = []
 	character.search("//misc/*").each do |misc|
		cur_kanji_miscs.push ({
			:misc_type     => misc.name,
			:misc_sub_type => misc['var_type'],
			:misc 	       => misc.text
		})
 	end
 	cur_kanji[:miscs] = cur_kanji_miscs

	puts 'start4'
	cur_kanji_dictionary_refs = []
 	character.search("//dic_number/dic_ref").each do |dictionary_ref|
		cur_kanji_dictionary_refs.push ({
			:dictionary_ref_type    => dictionary_ref['dr_type'],
			:dictionary_ref_m_vol   => dictionary_ref['m_vol'],
			:dictionary_ref_m_page  => dictionary_ref['m_page'],
			:dictionary_ref 	    => dictionary_ref.text
		})
 	end
 	cur_kanji[:dictionary_refs] = cur_kanji_dictionary_refs
	
	puts 'start5'
	cur_kanji_query_codes = []
 	character.search("//query_code/q_code").each do |query_code|
		cur_kanji_query_codes.push ({
			:query_code_type => query_code['qc_type'],
			:query_code_misclass => query_code['skip_misclass'],
			:query_code 	    => query_code.text
		})
 	end
 	cur_kanji[:query_codes] = cur_kanji_query_codes

	puts 'start6'
	cur_kanji_readings = []
 	character.search("//reading_meaning/rmgroup/reading").each do |reading|
		cur_kanji_readings.push ({
			:reading_type => reading['r_type'],
			:reading 	  => reading.text
		})
 	end
 	cur_kanji[:readings] = cur_kanji_readings

	puts 'start7'
	cur_kanji_meanings = []
 	character.search("//reading_meaning/rmgroup/meaning").each do |meaning|
		cur_kanji_meanings.push ({
			:meaning_language => meaning['m_lang'],
			:meaning => meaning.text
		})
 	end
 	cur_kanji[:meanings] = cur_kanji_meanings

	kanjis.push cur_kanji

	# progressbar.increment

	puts 'end' 
end


db = SQLite3::Database.new "KanjiDic2.db"

# Clearing out all tables
db.execute('DROP TABLE IF EXISTS kanji;')
db.execute('DROP TABLE IF EXISTS kanji_codepoint;')
db.execute('DROP TABLE IF EXISTS kanji_radical;')
db.execute('DROP TABLE IF EXISTS kanji_misc;')
db.execute('DROP TABLE IF EXISTS kanji_dict_ref;')
db.execute('DROP TABLE IF EXISTS kanji_query_code;')
db.execute('DROP TABLE IF EXISTS kanji_reading;')
db.execute('DROP TABLE IF EXISTS kanji_meaning;')

# Creating tables
db.execute_batch <<-SQL
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
	meaning_language VARCHAR(20),
	meaning_value VARCHAR(20),
	fk_kanji_id INTEGER,
	FOREIGN KEY (fk_kanji_id) REFERENCES Kanji(kanji_id)
);
SQL

# Parameter [:kanji] -> literal
get_kanji_id_query = <<-SQL
	SELECT CASE EXISTS(
		SELECT * FROM kanji WHERE literal = :kanji
	)
	WHEN 1 THEN(
		SELECT kanji_id FROM kanji WHERE literal = :kanji
	)
	ELSE 0
	END
SQL

# Parameter [:kanji] -> literal
insert_kanji_query = <<-SQL
	INSERT INTO kanji VALUES (null, :kanji)
SQL

insert_kanji_codepoint = <<-SQL
	INSERT INTO kanji_codepoint VALUES (null, :type, :value, :kanji_id)
SQL

insert_kanji_radical = <<-SQL
	INSERT INTO kanji_radical VALUES (null, :type, :value, :kanji_id)
SQL

insert_kanji_misc = <<-SQL
	INSERT INTO kanji_misc VALUES (null, :type, :sub_type, :value, :kanji_id)
SQL

insert_kanji_dict_ref = <<-SQL
	INSERT INTO kanji_dict_ref VALUES (null, :type, :m_vol, :m_page, :value, :kanji_id)
SQL

insert_kanji_query_code = <<-SQL
	INSERT INTO kanji_query_code VALUES (null, :type, :misclass_type, :value, :kanji_id)
SQL

insert_kanji_reading = <<-SQL
	INSERT INTO kanji_reading VALUES (null, :type, :value, :kanji_id)
SQL

insert_kanji_meaning = <<-SQL
	INSERT INTO kanji_meaning VALUES (null, :language, :value, :kanji_id)
SQL


building.pry
progressbar = ProgressBar.create(:title => "Processed", :starting_at => 0, :total => 100)

# For each character
kanjis.each do |kanji|
	# Fill Kanji Table

	db.execute insert_kanji_query , :kanji=> kanji[:literal]
	kanji_id = db.get_first_value get_kanji_id_query, :kanji=> kanji[:literal]

	# Fill codepoints table
	if kanji[:codepoints].a.respond_to? :each
		kanji[:codepoints].each do |codepoint|
			db.execute(
				insert_kanji_codepoint, {
					:type     => codepoint[:codepoint_type],
					:value    => codepoint[:codepoint],
					:kanji_id => kanji_id
				}
			)
		end
	end

	# Fill radical table
	if kanji[:radicals].a.respond_to? :each
		kanji[:radicals].each do |radical|
			db.execute(
				insert_kanji_radical, {
					:type     => radical[:radical_type],
					:value    => radical[:radical],
					:kanji_id => kanji_id
				}
			)
		end
	end

	# Fill misc table
	if kanji[:miscs].a.respond_to? :each
		kanji[:miscs].each do |misc|
			db.execute(
				insert_kanji_misc, {
					:type     => misc[:misc_type],
					:sub_type => misc[:misc_sub_type],
					:value    => misc[:misc],
					:kanji_id => kanji_id
				}
			)
		end
	end

	# Fill dict ref
	if kanji[:dictionary_refs].a.respond_to? :each
		kanji[:dictionary_refs].each do |dictionary_ref|
			db.execute(
				insert_kanji_dict_ref, {
					:type     => dictionary_ref[:dictionary_ref_type],
					:m_vol    => dictionary_ref[:dictionary_ref_m_vol],
					:m_page   => dictionary_ref[:dictionary_ref_m_page],
					:value    => dictionary_ref[:dictionary_ref],
					:kanji_id => kanji_id
				}
			)
		end 
	end

	# Fill query code table
	if kanji[:query_codes].a.respond_to? :each
		kanji[:query_codes].each do |query_code|
			db.execute(
				insert_kanji_query_code, {
					:type          => query_code[:query_code_type],
					:misclass_type => query_code[:query_code_misclass],
					:value         => query_code[:query_code],
					:kanji_id      => kanji_id
				}
			)
		end
	end

	# Fill reading table
	if kanji[:readings].a.respond_to? :each
		kanji[:readings].each do |reading|
			db.execute(
				insert_kanji_reading, {
					:type     => reading[:reading_type],
					:value    => reading[:reading],
					:kanji_id => kanji_id
				}
			)
		end
	end

	# Fill meaning table
	if kanji[:meanings].a.respond_to? :each
		kanji[:meanings].each do |meaning|
			db.execute(
				insert_kanji_meaning, {
					:value    => meaning[:meaning],
					:language => meaning[:meaning_language],
					:kanji_id => kanji_id
				}
			)
		end
	end
end




KanjiDictFile.close

