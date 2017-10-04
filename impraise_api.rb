require 'rack'
require 'rack/test'
require 'grape'
require 'active_record'
require 'otr-activerecord'
require 'sqlite3'
require_relative 'models/shortcode_data'
require 'introspective_grape'
OTR::ActiveRecord.configure_from_file!('config/database.yml')

module Impraise
  class API < Grape::API
    format :json
    formatter :json, IntrospectiveGrape::Formatter::CamelJson
    get '/' do
      ShortcodeData.limit(1000)
    end

    post '/shorten' do
      if params[:url].blank?
        status 400
        return "Missing url"
      elsif params.has_key?(:shortcode)
        if !(/\A[0-9a-zA-Z_]{4,}\Z/.match(params[:shortcode]))
          status 422
          return "The shortcode fails to meet the following regexp: ^[0-9a-zA-Z_]{4,}$"
        elsif ShortcodeData.where(shortcode: params[:shortcode]).present?
           status 409
           return "The desired shortcode is already present."
        else
          ShortcodeData.create(url: params[:url], shortcode: params[:shortcode])
          return {shortcode: params[:shortcode]}
        end
      else
        shortcode = ShortcodeData.new(url: params[:url])
        while (!shortcode.valid?)
          shortcode = ShortcodeData.new(url: params[:url])
        end
        shortcode.save!
        return {shortcode: shortcode.shortcode}
      end
    end

    get '/:shortcode' do
      code = ShortcodeData.where(shortcode: params[:shortcode])
      if code.present?
        code = code.first
        code.last_seen_date = DateTime.now
        code.redirect_count = code.redirect_count + 1
        code.save!
        redirect code.url
      else
        status 404
        "The shortcode cannot be found in the system"
      end
    end

    get '/:shortcode/stats' do
      shortcode = ShortcodeData.find_by_shortcode(params[:shortcode])
      if shortcode.nil?
        status 404
        "Not found"
      else
        shortcode
      end
    end
  end
end