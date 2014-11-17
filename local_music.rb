require "sinatra"
require "data_mapper"
require "builder"
require "sinatra/flash"
require 'sinatra/redirect_with_flash'

enable :sessions

SITE_TITLE = "Discover Local Music"
SITE_DESCRIPTION = "Be a locovore for your music"

DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/local_music.db")

class Show
  include DataMapper::Resource
  property :id, Serial
  property :band, Text, :required => true
  property :description, Text, :required => true
  property :venue, Text, :required => true
  property :zipcode, Text, :required => true
  #property :time, DateTime
end

DataMapper.finalize.auto_upgrade!

helpers do
  include Rack::Utils
  alias_method :h, :escape_html
end

get "/" do
  @shows = Show.all #:order => :zipcode
  @title = "All shows"
  if @shows.empty?
    flash[:error] = "No shows found."
  end
  erb :home
end

post "/" do
  show = Show.new
  show.band = params[:band]
  show.description = params[:description]
  show.venue = params[:venue]
  show.zipcode = params[:zipcode]
  if show.save
    redirect "/", flash[:notice] = "Show created successfully"
  else
    redirect "/", flash[:error] = "Failed to create show"
  end
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


