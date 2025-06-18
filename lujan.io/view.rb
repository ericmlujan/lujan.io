# frozen_string_literal: true

require 'erb'

class View
  VIEW_EXTENSION = '.html.erb'
  FRAGMENT_EXTENSION = '.html'
  TEMPLATE_DIR = 'templates'
  FRAGMENT_DIR = 'fragments'

  class TemplateError < RuntimeError
  end

  def initialize(view_path)
    @view_path = File.absolute_path(view_path.gsub(%r{^/}, ''))
    @view_path << '/' unless @view_path.end_with?('/')

    @views = {}
    @templates = {}
    @fragments = {}

    # Load views
    Dir
      .children(@view_path)
      .each do |child|
        if child.end_with? VIEW_EXTENSION
          name = File.basename(child, VIEW_EXTENSION)
          view(name)
        end
      end

    # Load templates
    template_path = File.join(@view_path, TEMPLATE_DIR)
    Dir
      .children(template_path)
      .each do |child|
        if child.end_with? VIEW_EXTENSION
          name = File.basename(child, VIEW_EXTENSION)
          template(name)
        end
      end

    # Load fragments
    fragment_path = File.join(@view_path, FRAGMENT_DIR)
    Dir
      .children(fragment_path)
      .each do |child|
        if child.end_with? FRAGMENT_EXTENSION
          name = File.basename(child, FRAGMENT_EXTENSION)
          fragment(name)
        end
      end
  end

  def render(name, options = {})
    if options.include? :template
      template_render(name, options[:template], options)
    else
      page_render(name, options)
    end
  end

  private

  def view(name)
    filepath = File.join(@view_path, name + VIEW_EXTENSION)
    File.open(filepath, 'r') { |file| @views[name.to_sym] = file.read }
  end

  def template(name)
    filepath = File.join(@view_path, TEMPLATE_DIR, name + VIEW_EXTENSION)
    File.open(filepath, 'r') { |file| @templates[name.to_sym] = file.read }
  end

  def fragment(name)
    filepath = File.join(@view_path, FRAGMENT_DIR, name + FRAGMENT_EXTENSION)
    File.open(filepath, 'r') { |file| @fragments[name.to_sym] = file.read }
  end

  def page_render(name, options)
    renderer = ERB.new(@views[name])

    locals = if options.include? :locals
               options[:locals]
             else
               {}
             end

    renderer.result_with_hash(locals)
  end

  def template_render(name, template, options)
    page_content = page_render(name, options)
    template_renderer = ERB.new(@templates[template])

    locals = { page_content: }
    locals = locals.merge(options[:locals]) if options.include? :locals
    locals = locals.merge(@fragments)

    template_renderer.result_with_hash(locals)
  end
end
