CREATE TABLE shows (
  id serial,
  band varchar(255) NOT NULL,
  band_id integer NOT NULL,
  description varchar(255) NOT NULL,
  venue varchar(255) NOT NULL,
  venue_id integer NOT NULL,
  zipcode integer NOT NULL,
  show_date date NOT NULL,
);

CREATE TABLE bands (
  id serial,
  band_name varchar(255) NOT NULL,
  band_description varchar(255)
);

CREATE TABLE venues (
  id serial,
  venue_name varchar(255) NOT NULL,
  venue_zip_code integer,
  venue_description varchar(255)
);

# db is called 'local_music'
