# frozen_string_literal: true

require 'sinatra'

require_relative 'redirects'
require_relative 'view'
require_relative 'photos'

class LujanIoApp < Sinatra::Base
  view = View.new('./views')
  photos = Photos.new

  set :public_folder, "#{__dir__}/public"

  get '/' do
    view.render :index, { template: :main }
  end

  get '/photography' do
    page = params[:page] ? params[:page].to_i : 0
    next_page = page < photos.total_count_pages ? page + 1 : nil
    prev_page = page.positive? ? page - 1 : nil

    page_photos = photos.photos_for_page(page)

    not_found if page_photos.empty?

    photo_columns = photos.columnarize(page_photos, 3)

    view.render :photo_gallery,
                { template: :photography,
                  locals: { photo_columns: photo_columns, prev_page: prev_page, next_page: next_page } }
  end

  get '/photography/:album_slug' do
    params['album_slug']
    # TODO: Stub fetching photos for the album

    view.render :album, { template: :photography }
  end

  get '/photography/:album_slug/:photo_slug' do
    album_slug = params['album_slug']
    photo_slug = params['photo_slug']

    photo = photos.get_photo(album_slug, photo_slug)

    not_found if photo.nil?

    view.render :single_photo, { template: :photography, locals: { photo: photo } }
  end

  Redirects::REDIRECTS.each do |path, target|
    get path do
      redirect to(target)
    end
  end
end
