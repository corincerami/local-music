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

def all_shows
  select_query = "SELECT * FROM shows"
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

def add_venue(venue_name)
  insert_query = "INSERT INTO venues (venue_name)
                  VALUES ('#{venue_name}');"
  find_venue_id = "SELECT id FROM venues WHERE venue_name = '#{venue_name}'"
  venue_id = nil
  db_connection do |conn|
    if conn.exec(find_venue_id).to_a.empty?
      conn.exec(insert_query)
    end
    venue_id = conn.exec(find_venue_id)
  end
  venue_id.to_a[0]["id"].to_i
end

def add_show(band, description, venue, zipcode, date)
  band_id = add_band(band)
  venue_id = add_venue(venue)
  add_venue(venue)
  insert_query = "INSERT INTO shows (band, band_id, description, venue, venue_id, zipcode, show_date)
                  VALUES ('#{band}', '#{band_id}', '#{description}', '#{venue}', '#{venue_id}', '#{zipcode}', CAST('#{date}' AS date));"
  db_connection do |conn|
    conn.exec(insert_query)
  end
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
  erb :home
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
                WHERE shows.id = #{show_id}"
  show = db_connection { |conn| conn.exec(show_query) }
  show = show.to_a
  @show = show[0]
  binding.pry
  if @show
    @title = "#{@show['band']} at #{@show['venue']}"
    erb :edit
  else
    redirect "/", flash[:error] = "Can't find that show"
  end
end

# put "/:id" do
#   show = Show.get params[:id]
#   unless show
#     redirect "/", flash[:error] = "Can't find that show"
#   end
#   show.band = params[:band]
#   show.description = params[:description]
#   show.venue = params[:venue]
#   show.zipcode = params[:zipcode]
#   show.date = params[:date]
#   if show.save
#     redirect "/", flash[:notice] = "Show updated successfully"
#   else
#     redirect "/", flash[:error] = "Error updating show"
#   end
# end

# get "/:id/delete" do
#   @show = Show.get params[:id]
#   @title = "Are you sure you want to delete this show?"
#   if @show
#     erb :delete
#   else
#     redirect "/", flash[:error] = "Can't find that show"
#   end
# end

# delete "/:id" do
#   show = Show.get params[:id]
#   if show.destroy
#     redirect "/", flash[:notice] = "Show successfully deleted"
#   else
#     redirect "/", flash[:error] = "Error deleting show"
#   end
# end


