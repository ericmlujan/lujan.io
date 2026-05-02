#!/usr/bin/env ruby
# frozen_string_literal: true

require 'aws-sdk-s3'
require 'dotenv'
require 'google/cloud/firestore'
require 'mini_exiftool'
require 'mini_magick'
require 'optparse'
require 'tempfile'
require 'time'

Dotenv.load('.env') if File.exist?('.env')

STATIC_BASE_URL = 'https://static.lujan.io'
THUMBNAIL_WIDTH = 800
FIRESTORE_ALBUMS_COL = 'albums'

def parse_args
  options = { hidden: false, dry_run: false, current_time: false }

  OptionParser.new do |opts|
    opts.banner = 'Usage: upload_album [options]'

    opts.on('--album-slug SLUG',        'Album slug (URL-safe, e.g. iceland-2024)') { |v| options[:album_slug] = v }
    opts.on('--album-name NAME',        'Album display name')                        { |v| options[:album_name] = v }
    opts.on('--album-description DESC', 'Album description')                         { |v| options[:album_description] = v }
    opts.on('--export-dir DIR',         'Path to Lightroom JPEG export directory')   { |v| options[:export_dir] = File.expand_path(v) }
    opts.on('--hidden',                 'Mark album hidden in Firestore')            { options[:hidden] = true }
    opts.on('--current-time',           'Use current time as album time instead of earliest EXIF date') { options[:current_time] = true }
    opts.on('--dry-run',                'Print actions without uploading or writing') { options[:dry_run] = true }
  end.parse!

  %i[album_slug album_name export_dir].each do |key|
    abort "Missing required option: --#{key.to_s.tr('_', '-')}" unless options[key]
  end

  abort "Export directory not found: #{options[:export_dir]}" unless Dir.exist?(options[:export_dir])

  options
end

def check_env!
  missing = %w[FIRESTORE_PROJECT R2_ACCOUNT_ID R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY R2_BUCKET].reject { |v| ENV[v] }
  abort "Missing environment variables: #{missing.join(', ')}" unless missing.empty?
end

def connect_r2
  Aws::S3::Client.new(
    endpoint: "https://#{ENV.fetch('R2_ACCOUNT_ID')}.r2.cloudflarestorage.com",
    region: 'auto',
    access_key_id: ENV.fetch('R2_ACCESS_KEY_ID'),
    secret_access_key: ENV.fetch('R2_SECRET_ACCESS_KEY')
  )
end

def connect_firestore
  Google::Cloud::Firestore.new(project_id: ENV.fetch('FIRESTORE_PROJECT'))
end

def max_display_index(firestore)
  max = 0
  firestore.col(FIRESTORE_ALBUMS_COL).get.each do |album|
    photos = album[:photos]
    next unless photos.is_a?(Hash)

    photos.each_value do |photo|
      idx = photo[:display_index].to_i
      max = idx if idx > max
    end
  end
  max
end

def slugify(str)
  str.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/^-|-$/, '')
end

def r2_key(album_slug, photo_slug, variant)
  "photography/#{album_slug}/#{photo_slug}/#{variant}.jpg"
end

def static_url(album_slug, photo_slug, variant)
  "#{STATIC_BASE_URL}/photography/#{album_slug}/#{photo_slug}/#{variant}.jpg"
end

def upload_file(r2, key, path, label)
  File.open(path, 'rb') do |f|
    r2.put_object(bucket: ENV.fetch('R2_BUCKET'), key: key, body: f, content_type: 'image/jpeg')
  end
  puts "  uploaded #{label} → #{key}"
end

def process_photo(file, album_slug, position, max_idx)
  exif = MiniExiftool.new(file)

  name    = exif.title.to_s.strip
  caption = (exif.description || exif.caption || '').to_s.strip
  time    = exif.date_time_original&.iso8601

  if name.empty?
    warn "  WARNING: no Title set for #{File.basename(file)} — falling back to filename for slug and name"
    name = File.basename(file, '.*')
  end

  slug = slugify(name)

  image        = MiniMagick::Image.open(file)
  aspect_ratio = image.width.to_f / image.height

  {
    slug: slug,
    name: name,
    caption: caption,
    alt: name,
    aspect_ratio: aspect_ratio.round(4),
    display_index: max_idx + position,
    time: time,
    hidden: false,
    path: static_url(album_slug, slug, 'original'),
    thumbnail_path: static_url(album_slug, slug, 'thumbnail')
  }
end

def build_thumbnail(file)
  tmp = Tempfile.new([File.basename(file, '.*'), '.jpg'])
  tmp.close

  image = MiniMagick::Image.open(file)
  image.resize "#{THUMBNAIL_WIDTH}x#{THUMBNAIL_WIDTH}"
  image.write(tmp.path)

  tmp
end

def main
  opts    = parse_args
  dry_run = opts[:dry_run]

  check_env! unless dry_run

  puts dry_run ? '=== DRY RUN ===' : '=== upload_album ==='
  puts "Album: #{opts[:album_slug]} / \"#{opts[:album_name]}\""
  puts "Dir:   #{opts[:export_dir]}"
  puts

  jpegs = Dir.glob("#{opts[:export_dir]}/*.{jpg,jpeg,JPG,JPEG}").sort
  abort 'No JPEG files found in export directory.' if jpegs.empty?
  puts "Found #{jpegs.length} JPEG(s)"
  puts

  r2        = dry_run ? nil : connect_r2
  firestore = dry_run ? nil : connect_firestore
  base_idx  = dry_run ? 0   : max_display_index(firestore)

  puts "Current max display_index: #{base_idx}" unless dry_run
  puts

  photos_map = {}
  start_time = Time.now

  jpegs.each_with_index do |file, i|
    position = i + 1
    puts "#{position}/#{jpegs.length} #{File.basename(file)}"

    photo = process_photo(file, opts[:album_slug], position, base_idx)
    puts "  slug:          #{photo[:slug]}"
    puts "  name:          #{photo[:name]}"
    puts "  caption:       #{photo[:caption].empty? ? '(none)' : photo[:caption]}"
    puts "  time:          #{photo[:time] || '(none)'}"
    puts "  aspect_ratio:  #{photo[:aspect_ratio]}"
    puts "  display_index: #{photo[:display_index]}"
    puts "  path:          #{photo[:path]}"
    puts "  thumbnail:     #{photo[:thumbnail_path]}"

    unless dry_run
      original_key  = r2_key(opts[:album_slug], photo[:slug], 'original')
      thumbnail_key = r2_key(opts[:album_slug], photo[:slug], 'thumbnail')

      thumb = build_thumbnail(file)
      begin
        upload_file(r2, original_key,  file,       'original')
        upload_file(r2, thumbnail_key, thumb.path, 'thumbnail')
      ensure
        thumb.unlink
      end
    end

    photos_map[photo[:slug]] = photo
    puts
  end

  unless dry_run
    album_time = if opts[:current_time]
                   Time.now.iso8601
                 else
                   photos_map.values
                             .filter_map { |p| p[:time] && Time.parse(p[:time]) }
                             .min
                             &.iso8601 || Time.now.iso8601
                 end

    album_data = {
      slug:        opts[:album_slug],
      name:        opts[:album_name],
      description: opts[:album_description] || '',
      hidden:      opts[:hidden],
      time:        album_time,
      photos:      photos_map
    }

    puts 'Writing to Firestore...'
    firestore.col(FIRESTORE_ALBUMS_COL).doc(opts[:album_slug]).set(album_data, merge: true)
    puts "  albums/#{opts[:album_slug]} updated"
  end

  elapsed = (Time.now - start_time).round(1)
  puts
  puts "Done. #{jpegs.length} photo(s) in #{elapsed}s#{dry_run ? ' (dry run — nothing written)' : ''}."
end

main
