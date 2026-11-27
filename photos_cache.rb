# frozen_string_literal: true

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

      album[:photos].values.sort_by { |p| p[:display_index].to_i }.each do |photo|
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
