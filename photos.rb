# frozen_string_literal: true

require 'json'
require 'logger'
require 'google/cloud/firestore'

require_relative 'photos_cache'

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
