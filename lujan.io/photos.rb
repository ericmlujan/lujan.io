# frozen_string_literal: true

require 'json'
require 'logger'
require 'time'
require 'google/cloud/firestore'

FIRESTORE_ALBUMS_COL = 'albums'

class PhotosCache
  attr_reader :albums, :photos

  CACHE_TTL = 1800 # s

  def initialize(firestore)
    @firestore = firestore
    @albums = {}
    @photos = []
    @last_refreshed = Time.new(0)
  end

  def should_refresh?
    return true if Time.now - @last_refreshed > CACHE_TTL

    albums_ref = @firestore.col(FIRESTORE_ALBUMS_COL)
    firestore_albums_count = 0
    albums_count_query = albums_ref.aggregate_query.add_count

    albums_count_query.get do |snapshot|
      firestore_albums_count = snapshot.get
    end

    @albums.count != firestore_albums_count
  end

  def refresh
    return unless should_refresh?

    @last_refreshed = Time.now

    albums_ref = @firestore.col(FIRESTORE_ALBUMS_COL)
    albums = albums_ref.get

    albums.each do |album|
      @albums[album[:slug]] = album

      album[:photos].each_value do |photo|
        # TODO: Annotating in the album dynamically to the hash like this isn't
        # terribly optimal. We should revisit the data abstractions here.
        photo[:album] = album[:slug]
        photo[:album_name] = album[:name]
        @photos << photo
      end
    end

    @photos.sort! { |a, b| a[:display_index] <=> b[:display_index] }
  end
end

class Photos
  PHOTOS_PER_PAGE = 10

  def initialize
    @logger = Logger.new($stderr)
    unless ENV.include?('FIRESTORE_PROJECT')
      raise ArgumentError, "The environment variable FIRESTORE_PROJECT isn't set, but is required"
    end

    @logger.info "Firestore project set to #{ENV.fetch('FIRESTORE_PROJECT', nil)}"
    @firestore = Google::Cloud::Firestore.new(project_id: ENV.fetch('FIRESTORE_PROJECT', nil))
    @cache = PhotosCache.new(@firestore)
  end

  def all_photos
    @cache.refresh
    @cache.photos
  end

  def photos_for_page(page_number)
    photos = all_photos
    lower = page_number * PHOTOS_PER_PAGE
    upper = lower + PHOTOS_PER_PAGE

    if lower >= photos.count
      []
    else
      photos[lower...upper]
    end
  end

  def get_photo(album_slug, photo_slug)
    @cache.refresh

    return nil unless @cache.albums.include?(album_slug)

    album = @cache.albums[album_slug]
    photos = album[:photos]

    # TODO: We're storing raw data from Firestore in the cache, which symbolizes hash keys.
    # Make it consistent so we don't have to shim this in.
    photo_slug = photo_slug.to_sym
    photos[photo_slug]
  end

  def total_count_photos
    @cache.refresh
    @cache.photos.count
  end

  def total_count_pages
    (total_count_photos / PHOTOS_PER_PAGE).ceil
  end

  def columnarize(elems, n_columns)
    columns = []
    n_columns.times do
      columns << []
    end

    elems.each_with_index do |value, index|
      columns[index % n_columns].push(value)
    end

    columns
  end
end
