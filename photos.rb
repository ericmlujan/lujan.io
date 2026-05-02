# frozen_string_literal: true

require 'json'
require 'logger'
require 'time'
require 'google/cloud/firestore'

FIRESTORE_ALBUMS_COL = 'albums'

class PhotosCache
  attr_reader :albums, :photos, :page_boundaries

  CACHE_TTL = 1800 # s
  GALLERY_COLUMNS = 3
  GALLERY_PAGE_POOL = 20 # max photos offered to the balance algorithm per page

  def initialize(firestore)
    @firestore = firestore
    @albums = {}
    @photos = []
    @page_boundaries = [0]
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

    # Clear cache
    @albums = {}
    @photos = []

    albums_ref = @firestore.col(FIRESTORE_ALBUMS_COL)
    sorted_albums = albums_ref.get.sort_by { |album| album[:time] || Time.new(0) }.reverse

    sorted_albums.each do |album|
      @albums[album[:slug]] = album

      album[:photos].values.sort_by { |p| p[:display_index]&.to_i || 0 }.each do |photo|
        # TODO: Annotating in the album dynamically to the hash like this isn't
        # terribly optimal. We should revisit the data abstractions here.
        photo[:album] = album[:slug]
        photo[:album_name] = album[:name]
        @photos << photo
      end
    end

    @page_boundaries = compute_page_boundaries
  end

  private

  # Greedily assigns each photo to the shortest column and returns the count
  # of photos at the point where column heights are most evenly balanced.
  def best_column_balance(pool)
    col_heights = Array.new(GALLERY_COLUMNS, 0.0)
    min_spread = Float::INFINITY
    best_count = pool.length
    min_photos = GALLERY_COLUMNS * 2

    pool.each_with_index do |photo, i|
      ar = photo[:aspect_ratio]&.to_f || 1.5
      col = col_heights.each_with_index.min_by { |h, _| h }[1]
      col_heights[col] += 1.0 / ar

      next if i + 1 < min_photos

      max_h = col_heights.max
      min_h = col_heights.min
      spread = (max_h - min_h) / max_h

      if spread < min_spread
        min_spread = spread
        best_count = i + 1
      end
    end

    best_count
  end

  def compute_page_boundaries
    boundaries = [0]

    while (start = boundaries.last) < @photos.length
      pool = @photos[start, GALLERY_PAGE_POOL]
      break if pool.nil? || pool.empty?

      count = best_column_balance(pool)
      boundaries << (start + count)
    end

    boundaries
  end
end

class Photos
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
    @cache.refresh
    boundaries = @cache.page_boundaries
    start = boundaries[page_number]
    return [] if start.nil?

    finish = boundaries[page_number + 1] || @cache.photos.length
    @cache.photos[start...finish]
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
    @cache.refresh
    @cache.page_boundaries.length - 1
  end
end
