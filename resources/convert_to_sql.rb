#!/usr/bin/env ruby -KU

require 'ruby-progressbar'
require 'nokogiri'
require 'sqlite3'
require 'libxml'
require 'yaml'
require 'pry'

filename = "kanjidic2.xml"

# Sample Entry
# <character>
#     <literal>唖</literal>
#     <codepoint>
#         <cp_value cp_type="ucs">5516</cp_value>
#         <cp_value cp_type="jis208">16-2</cp_value>
#     </codepoint>
#     <radical>
#         <rad_value rad_type="classical">30</rad_value>
#     </radical>
#     <misc>
#         <stroke_count>10</stroke_count>
#         <variant var_type="jis212">21-64</variant>
#         <variant var_type="jis212">45-68</variant>
#     </misc>
#     <dic_number>
#         <dic_ref dr_type="nelson_c">939</dic_ref>
#         <dic_ref dr_type="nelson_n">795</dic_ref>
#         <dic_ref dr_type="heisig">2958</dic_ref>
#         <dic_ref dr_type="moro" m_vol="2" m_page="1066">3743</dic_ref>
#     </dic_number>
#     <query_code>
#         <q_code qc_type="skip">1-3-7</q_code>
#         <q_code qc_type="sh_desc">3d8.3</q_code>
#         <q_code qc_type="four_corner">6101.7</q_code>
#     </query_code>
#     <reading_meaning>
#         <rmgroup>
#             <reading r_type="pinyin">ya1</reading>
#             <reading r_type="korean_r">a</reading>
#             <reading r_type="korean_h">아</reading>
#             <reading r_type="ja_on">ア</reading>
#             <reading r_type="ja_on">アク</reading>
#             <reading r_type="ja_kun">おし</reading>
#             <meaning>mute</meaning>
#             <meaning>dumb</meaning>
#         </rmgroup>
#     </reading_meaning>
# </character>

include LibXML

class PostCallbacks
  	include XML::SaxParser::Callbacks

  	attr_accessor :kanjis

	def initialize total = 0
		@kanjis = []
		@character_num = 0
		@progressbar = ProgressBar.create(:title => "Processed", :starting_at => 0, :format => '%a %B %p%% %t', :total => total)
		

		@demand_all_tags = false
		@inside = false
		@all_tags_for = nil
		@cur_tag_name = nil

		@demand_characters = false
		@characters_for = nil

		@attributes = nil

		@dash = false
	end

  	def on_start_element(element, attributes)
		if element.eql? 'character'
			@kanjis[@character_num] = {}
		end

		if element.eql? @all_tags_for.to_s
			@inside = true
		end

		if @demand_all_tags.eql? true and @inside
			request_caracters_for element, attributes, element.to_sym
		end

		request_caracters_for element, attributes, :literal
		request_caracters_for element, attributes, :cp_value
		request_caracters_for element, attributes, :rad_value
		request_caracters_for element, attributes, :dic_ref
		request_caracters_for element, attributes, :q_code
		request_caracters_for element, attributes, :reading
		request_caracters_for element, attributes, :nanori
		request_caracters_for element, attributes, :meaning

		request_all_tags_for :misc
  	end

  	def on_end_element(element)
  		@demand_characters = false

  		if element.eql? @all_tags_for.to_s
			@inside = false
		end

  		if @demand_all_tags.eql? true and not @all_tags_for.nil?
  			if element.eql? @all_tags_for.to_s
  				@all_tags_for = nil
  				@demand_all_tags = false
  			end
  		end

		if element.eql? 'character'
			@progressbar.increment
			@character_num += 1
		end
  	end

  	def on_characters(chars)
  		if chars.eql? '-'
  			@dash = true
  		elsif not chars.eql? "\n"
  			if @dash
  				ch = '-'
  				ch << chars
  				chars = ch
  				@dash = false
  			end

	  		if @demand_characters.eql? true
	  			process @characters_for, @attributes, chars
	  		end
	  	end
  	end

  	def process element, attributes, text

	  	if element.eql? :literal
			@kanjis[@character_num][:literal] = text
			return
		end



		if not text.nil?
			if element.eql? :cp_value
				@kanjis[@character_num][:codepoints] ||= []
				@kanjis[@character_num][:codepoints].push ({
					:codepoint_type => attributes['cp_type'],
					:codepoint 	    => text
				})
				return
			end

			if element.eql? :rad_value
				@kanjis[@character_num][:radicals] ||= []
				@kanjis[@character_num][:radicals].push ({
					:radical_type => attributes['rad_type'],
					:radical 	  => text
				})
				return
			end

			if @demand_all_tags.eql? true and @inside and @all_tags_for.eql? :misc and not element.eql? :misc
			 	@kanjis[@character_num][:miscs] ||= []
				@kanjis[@character_num][:miscs].push ({
					:misc_type     => element.to_s,
					:misc_sub_type => attributes['var_type'],
					:misc 	       => text
				})
				return
			end

			if element.eql? :dic_ref
				@kanjis[@character_num][:dictionary_refs] ||= []
				@kanjis[@character_num][:dictionary_refs].push ({
					:dictionary_ref_type    => attributes['dr_type'],
					:dictionary_ref_m_vol   => attributes['m_vol'],
					:dictionary_ref_m_page  => attributes['m_page'],
					:dictionary_ref 	    => text
				})
				return
			end	

			if element.eql? :q_code
				@kanjis[@character_num][:query_codes] ||= []
				@kanjis[@character_num][:query_codes].push ({
					:query_code_type     => attributes['qc_type'],
					:query_code_misclass => attributes['skip_misclass'],
					:query_code 	     => text
				})
				return
			end	

			if element.eql? :reading
				@kanjis[@character_num][:readings] ||= []
				@kanjis[@character_num][:readings].push ({
					:reading_type => attributes['r_type'],
					:reading      => text
				})
				return
			end	

			if element.eql? :nanori
				@kanjis[@character_num][:readings] ||= []
				@kanjis[@character_num][:readings].push ({
					:reading_type => 'ja_nanori',
					:reading      => text
				})
				return
			end	

			if element.eql? :meaning
				@kanjis[@character_num][:meanings] ||= []
				@kanjis[@character_num][:meanings].push ({
					:meaning_language => (attributes['m_lang'].nil?)? "en" : attributes['m_lang'],
					:meaning          => text
				})
				return
			end
		end
  	end

  	## ---------------------------------
  	private

  	def request_caracters_for element, attributes, tag
  		if element.eql? tag.to_s
			@characters_for = tag
			@demand_characters = true
			@attributes = attributes
		end
  	end

  	def request_all_tags_for element
  		@all_tags_for = element
  		@demand_all_tags = true
  	end
end

KanjiDictFile = File.open( filename)
dictionary = Nokogiri::XML( KanjiDictFile )
total_characters = dictionary.search("//character").size
KanjiDictFile.close

puts "Reading"
parser = XML::SaxParser.file( filename )
aggregator = PostCallbacks.new total_characters
parser.callbacks = aggregator
parser.parse

kanjis = aggregator.kanjis



puts "Tyding up Database File..."

# Shoving everything into SQLite database
database = SQLite3::Database.new "KanjiDic2.db"

# Clearing out all tables
database.transaction do |db|
	db.execute('DROP TABLE IF EXISTS kanji;')
	db.execute('DROP TABLE IF EXISTS kanji_codepoint;')
	db.execute('DROP TABLE IF EXISTS kanji_radical;')
	db.execute('DROP TABLE IF EXISTS kanji_misc;')
	db.execute('DROP TABLE IF EXISTS kanji_dict_ref;')
	db.execute('DROP TABLE IF EXISTS kanji_query_code;')
	db.execute('DROP TABLE IF EXISTS kanji_reading;')
	db.execute('DROP TABLE IF EXISTS kanji_meaning;')
end

# Creating tables
sqlite_create_tables = <<-SQL
PRAGMA foreign_keys = ON;

CREATE TABLE kanji (
	kanji_id INTEGER PRIMARY KEY ,
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

mysql_create_tables = <<-SQL
PRAGMA foreign_keys = ON;

CREATE TABLE kanji (
	kanji_id INTEGER AUTO_INCREMENT PRIMARY KEY ,
	literal VARCHAR(5)
);

CREATE TABLE kanji_codepoint (
	codepoint_id INTEGER AUTO_INCREMENT PRIMARY KEY,
	codepoint_type VARCHAR(20),
	codepoint_value VARCHAR(20),
	fk_kanji_id INTEGER,
	FOREIGN KEY (fk_kanji_id) REFERENCES Kanji(kanji_id)
);

CREATE TABLE kanji_radical (
	radical_id INTEGER AUTO_INCREMENT PRIMARY KEY,
	radical_type VARCHAR(20),
	radical_value VARCHAR(20),
	fk_kanji_id INTEGER,
	FOREIGN KEY (fk_kanji_id) REFERENCES Kanji(kanji_id)
);

CREATE TABLE kanji_misc (
	misc_id INTEGER AUTO_INCREMENT PRIMARY KEY,
	misc_type VARCHAR(20),
	misc_sub_type VARCHAR(20),
	misc_value VARCHAR(20),
	fk_kanji_id INTEGER,
	FOREIGN KEY (fk_kanji_id) REFERENCES Kanji(kanji_id)
);

CREATE TABLE kanji_dict_ref (
	dict_ref_id INTEGER AUTO_INCREMENT PRIMARY KEY,
	dict_ref_type VARCHAR(20),
	dict_ref_m_vol VARCHAR(20),
	dict_ref_m_page VARCHAR(20),
	dict_ref_value VARCHAR(20),
	fk_kanji_id INTEGER,
	FOREIGN KEY (fk_kanji_id) REFERENCES Kanji(kanji_id)
);

CREATE TABLE kanji_query_code (
	query_code_id INTEGER AUTO_INCREMENT PRIMARY KEY,
	query_code_type VARCHAR(20),
	query_code_misclass_type VARCHAR(20),
	query_code_value VARCHAR(20),
	fk_kanji_id INTEGER,
	FOREIGN KEY (fk_kanji_id) REFERENCES Kanji(kanji_id)
);

CREATE TABLE kanji_reading (
	reading_id INTEGER AUTO_INCREMENT PRIMARY KEY,
	reading_type VARCHAR(20),
	reading_value VARCHAR(20),
	fk_kanji_id INTEGER,
	FOREIGN KEY (fk_kanji_id) REFERENCES Kanji(kanji_id)
);

CREATE TABLE kanji_meaning (
	meaning_id INTEGER AUTO_INCREMENT PRIMARY KEY,
	meaning_language VARCHAR(20),
	meaning_value VARCHAR(20),
	fk_kanji_id INTEGER,
	FOREIGN KEY (fk_kanji_id) REFERENCES Kanji(kanji_id)
);
SQL

database.execute_batch sqlite_create_tables

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


puts "Saving yaml file..."
# yamlBackup = File.open( 'kanjidic2.yaml', "w" )
# yamlBackup.write kanjis.to_yaml


puts "Writing"
progressbar = ProgressBar.create(:title => "Processed", :starting_at => 0, :format => '%a %B %p%% %t', :total => total_characters)

# For each character
kanji_id = 0
kanjis.each do |kanji|
	# Fill Kanji Table
	progressbar.increment

	kanji_id += 1

	database.transaction do |db|
		database.execute insert_kanji_query , :kanji=> kanji[:literal]

		if kanji[:codepoints].respond_to? :each
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
		if kanji[:radicals].respond_to? :each
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
		if kanji[:miscs].respond_to? :each
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
		if kanji[:dictionary_refs].respond_to? :each
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
		if kanji[:query_codes].respond_to? :each
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
		if kanji[:readings].respond_to? :each
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
		if kanji[:meanings].respond_to? :each
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
end