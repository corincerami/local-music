require "sinatra"
require "json"
require "data_mapper"
require "sinatra/flash"
require 'sinatra/redirect_with_flash'
require "net/http"
require "pry"

if !ENV.has_key?("ZIP_CODE_API_KEY")
 puts "You need to set the ZIP_CODE_API_KEY"
 exit 1
end

enable :sessions

SITE_TITLE = "Scene Hub"
SITE_DESCRIPTION = "Listen Locally"

DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/local_music.db")

class Show
  include DataMapper::Resource
  property :id, Serial
  property :band, Text, :required => true
  property :description, Text, :required => true
  property :venue, Text, :required => true
  property :zipcode, Text, :required => true
  property :date, Date, :required => true
end

DataMapper.finalize.auto_upgrade!

helpers do
  include Rack::Utils
  alias_method :h, :escape_html
end

get "/" do
  redirect "/shows"
end

get "/shows" do
  @shows = Show.all
  @title = "All shows"
  if @shows.empty?
    flash[:error] = "No shows found."
  end
  erb :home
end

post "/shows" do
  show = Show.new
  show.band = params[:band]
  show.description = params[:description]
  show.venue = params[:venue]
  show.zipcode = params[:zipcode]
  show.date = params[:date]
  if show.save
    redirect "/", flash[:notice] = "Show created successfully"
  else
    redirect "/", flash[:error] = "Failed to create show"
  end
end

get "/find/:user_zip" do
  @title = "Find shows"
  @shows = Show.all
  @user_zip = params[:user_zip]
  @nearby_shows = []
  @shows.each do |show|
    api_key = ENV["ZIP_CODE_API_KEY"]
    zip_api_response = URI("https://www.zipcodeapi.com/rest/#{api_key}/distance.json/#{@user_zip}/#{show.zipcode}/mile")
    response = Net::HTTP.get(zip_api_response)
    distance = JSON.parse(response)
    if distance["distance"] < 25
      @nearby_shows << show
    end
  end

  erb :find
end

post "/find" do
  redirect "/find/#{params[:user_zip]}"
end

get "/:id" do
  @show = Show.get params[:id]
  @title = "#{params[:band]} at #{params[:venue]}"
  if @show
    erb :edit
  else
    redirect "/", flash[:error] = "Can't find that show"
  end
end

put "/:id" do
  show = Show.get params[:id]
  unless show
    redirect "/", flash[:error] = "Can't find that show"
  end
  show.band = params[:band]
  show.description = params[:description]
  show.venue = params[:venue]
  show.zipcode = params[:zipcode]
  show.date = params[:date]
  if show.save
    redirect "/", flash[:notice] = "Show updated successfully"
  else
    redirect "/", flash[:error] = "Error updating show"
  end
end

get "/:id/delete" do
  @show = Show.get params[:id]
  @title = "Are you sure you want to delete this show?"
  if @show
    erb :delete
  else
    redirect "/", flash[:error] = "Can't find that show"
  end
end

delete "/:id" do
  show = Show.get params[:id]
  if show.destroy
    redirect "/", flash[:notice] = "Show successfully deleted"
  else
    redirect "/", flash[:error] = "Error deleting show"
  end
end


