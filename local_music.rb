require "sinatra"
require "json"
require "sinatra/flash"
require 'sinatra/redirect_with_flash'
require "net/http"
require "dotenv"
require "pry"
require "pg"

Dotenv.load

enable :sessions

SITE_TITLE = "Scene Hub"
SITE_DESCRIPTION = "Listen Locally"

def db_connection
  begin
    connection = PG.connect(dbname: 'local_music')
    yield(connection)
  ensure
    connection.close
  end
end

def add_show(band, description, venue, zipcode, date)
  band_id = add_band(band)
  venue_id = add_venue(venue)
  # verifies that the zip code is valid
  api_key = ENV["ZIP_CODE_API_KEY"]
  zip_api_response = URI("https://www.zipcodeapi.com/rest/#{api_key}/info.json/#{zipcode}/degrees")
  response = Net::HTTP.get(zip_api_response)
  city = JSON.parse(response)["city"]

  add_venue(venue)
  insert_query = "INSERT INTO shows (band, band_id, description, venue, venue_id, zipcode, show_date)
                  VALUES ($1, $2, $3, $4, $5, $6, CAST('#{date}' AS date));"
  if city.nil?
    redirect "/", flash[:error] = "Please enter a valid zip code."
  else
    db_connection do |conn|
      conn.exec(insert_query, [band, band_id, description, venue, venue_id, zipcode])
    end
  end
end

def all_shows
  select_query = "SELECT * FROM shows
                  ORDER BY shows.show_date;"
  result = db_connection do |conn|
    conn.exec(select_query)
  end
  result.to_a
end

def add_band(band_name)
  insert_query = "INSERT INTO bands (band_name)
                  VALUES ('#{band_name}');"
  find_band_id = "SELECT id FROM bands WHERE band_name = '#{band_name}';"
  band_id = nil
  db_connection do |conn|
    if conn.exec(find_band_id).to_a.empty?
      conn.exec(insert_query)
    end
    band_id = conn.exec(find_band_id)
  end
  band_id.to_a[0]["id"].to_i
end

def all_bands
  select_query = "SELECT * FROM bands;"
  result = db_connection do |conn|
    conn.exec(select_query)
  end
  result.to_a
end

def add_venue(venue_name)
  insert_query = "INSERT INTO venues (venue_name)
                  VALUES ('#{venue_name}');"
  find_venue_id = "SELECT id FROM venues WHERE venue_name = '#{venue_name}';"
  venue_id = nil
  db_connection do |conn|
    if conn.exec(find_venue_id).to_a.empty?
      conn.exec(insert_query)
    end
    venue_id = conn.exec(find_venue_id)
  end
  venue_id.to_a[0]["id"].to_i
end

def all_venues
  select_query = "SELECT * FROM venues;"
  result = db_connection do |conn|
    conn.exec(select_query)
  end
  result.to_a
end

helpers do
  include Rack::Utils
  alias_method :h, :escape_html
end

get "/" do
  redirect "/shows"
end

get "/shows" do
  @shows = all_shows
  @title = "All shows"
  @user_zip = params[:user_zip]
  if !@user_zip.nil? && !@user_zip.empty?
    @nearby_shows = []
    @shows.each do |show|
      api_key = ENV["ZIP_CODE_API_KEY"]
      zip_api_response = URI("https://www.zipcodeapi.com/rest/#{api_key}/distance.json/#{@user_zip}/#{show['zipcode']}/mile")
      response = Net::HTTP.get(zip_api_response)
      distance = JSON.parse(response)
      if distance["distance"] < 25
        @nearby_shows << show
      end
    end
  end
  erb :"shows/index"
end

post "/shows" do
  band = params[:band]
  description = params[:description]
  venue = params[:venue]
  zipcode = params[:zipcode]
  date = params[:date]
  add_show(band, description, venue, zipcode, date)

  redirect "/shows"
end

get "/shows/:id" do
  show_id = params[:id].to_i
  show_query = "SELECT * FROM shows
                WHERE shows.id = #{show_id};"
  show = db_connection { |conn| conn.exec(show_query) }
  show = show.to_a
  @show = show[0]
  if @show
    @title = "#{@show['band']} at #{@show['venue']}"
    erb :"shows/edit"
  else
    redirect "/", flash[:error] = "Can't find that show"
  end
end

put "/shows/:id" do
  show_id = params[:id].to_i
  band = params[:band]
  description = params[:description]
  venue = params[:venue]
  zipcode = params[:zipcode]
  show_date = params[:date]
  insert_query = "UPDATE shows SET band = $1, description = $2, venue = $3,
                  zipcode = $4, show_date = $5 WHERE id = #{show_id};"
  db_connection { |conn| conn.exec(insert_query, [band, description, venue, zipcode, show_date]) }
  redirect "/shows"
end

get "/shows/:id/delete" do
  show_id = params[:id].to_i
  show_query = "SELECT shows.band, shows.venue, shows.id
                FROM shows WHERE id = #{show_id};"
  show = db_connection { |conn| conn.exec(show_query) }
  show = show.to_a
  @show = show[0]
  @title = "Are you sure you want to delete this show?"
  if @show
    erb :"shows/delete"
  else
    redirect "/", flash[:error] = "Can't find that show"
  end
end

delete "/shows/:id" do
  show_id = params[:id].to_i
  delete_query = "DELETE FROM shows WHERE id = #{show_id};"
  db_connection { |conn| conn.exec(delete_query) }
  redirect "/"
end

get "/bands" do
  @bands = all_bands
  @title = "All bands"
  erb :"bands/index"
end

get "/bands/:id" do
  band_id = params[:id]
  band_query = "SELECT band_name, band_description, shows.description,
                shows.venue, shows.zipcode, shows.show_date, shows.id, shows.venue_id
                FROM bands
                JOIN shows ON shows.band_id = bands.id
                WHERE bands.id = $1
                ORDER BY shows.show_date;"
  band = db_connection do |conn|
    conn.exec(band_query, [band_id])
  end
  @band = band.to_a
  erb :"bands/show"
end

get "/venues" do
  @venues = all_venues
  @title = "All venues"
  erb :"venues/index"
end

get "/venues/:id" do
  venue_id = params[:id].to_i
  venue_query = "SELECT venue_name, venue_zip_code, venue_description,
                 bands.id AS band_id, band_name, shows.show_date, shows.id AS show_id
                 FROM venues
                 LEFT OUTER JOIN shows ON shows.venue_id = venues.id
                 LEFT OUTER JOIN bands on shows.band_id = bands.id
                 WHERE venues.id = $1
                 ORDER BY shows.show_date;"
  venue = db_connection do |conn|
    conn.exec(venue_query, [venue_id])
  end
  @venue = venue.to_a
  erb :"venues/show"
end
