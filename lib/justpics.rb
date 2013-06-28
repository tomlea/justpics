require 'sinatra/base'
require 'enumerator'
require 'digest/sha1'
require 'aws/s3'



class Justpics < Sinatra::Base
end

class Justpics::AlwaysFresh
  def initialize(app)
    @app = app
  end

  def call(env)
    if (env["HTTP_IF_MODIFIED_SINCE"] or env["HTTP_IF_NONE_MATCH"]) and env["REQUEST_METHOD"] == "GET" and env["PATH_INFO"].try(:length) > Justpics::MINIMUM_KEY_LENGTH
      puts "Quick 304"
      [304, {}, []]
    else
      @app.call(env)
    end
  end
end


class Justpics < Sinatra::Base
  BUCKET_NAME = ENV['AMAZON_S3_BUCKET']
  MAX_SIZE = (ENV['JUSTPICS_MAX_SIZE'] || 2 * 1024 * 1024).to_i
  POST_PATH = "/#{ENV["JUSTPICS_POST_PATH"]}".gsub(%r{//+}, "/")
  MINIMUM_KEY_LENGTH = (ENV['JUSTPICS_MINIMUM_KEY_LENGTH'] || 40).to_i
  MINIMUM_KEY_LENGTH > 0 or raise ArgumentError, "JUSTPICS_MINIMUM_KEY_LENGTH must be above 0, otherwise where would the home page go?!?"
  MINIMUM_KEY_LENGTH <= 40 or raise ArgumentError, "JUSTPICS_MINIMUM_KEY_LENGTH cannot be bigger then the full key length (40)"

  NotFound = Class.new(RuntimeError)
  S3 = AWS::S3.new

  enable :static, :methodoverride

  use Justpics::AlwaysFresh

  get '/favicon.ico' do
    cache_forever
    send_file File.expand_path("../../assets/favicon.ico", __FILE__)
  end

  get "/" do
    status 404
    render_default
  end

  get POST_PATH do
    File.read(File.expand_path("../../assets/index.html", __FILE__))
  end

  post POST_PATH do
    file = params[:file] || params[:media]

    unless file and tmpfile = file[:tempfile]
      status 510
      return "No file selected"
    end

    if tmpfile.size > MAX_SIZE
      status 510
      return "File too large. Keep it under #{MAX_SIZE} bytes."
    end

    resource_url = url upload_image(tmpfile.path, file[:type])

    if params[:media]
      "<mediaurl>#{resource_url}</mediaurl>"
    else
      redirect resource_url
    end
  end

  get "/:id*" do
    id = params[:id].to_s[/^[a-zA-Z0-9]*/]
    begin
      cache_forever
      render_image(id)
    rescue NotFound
      status 404
      render_default
    end
  end

  def cache_forever
    response['Cache-Control'] = "public, max-age=#{60*60*24*356*3}"
    response['ETag'] = "the-same-thing-every-time"
    response['Last-Modified'] = Time.at(1337).httpdate
  end

  def render_image(id)
    raise NotFound unless sha = expand_sha(id)
    file = bucket.objects[sha]
    content_type file.content_type
    Enumerator.new(file, :read)
  rescue AWS::S3::Errors::NoSuchKey => e
    raise NotFound, e.message
  end

  def render_default
    send_file File.expand_path('../../assets/default.png', __FILE__)
  end

  def expand_sha(small)
    small = small.to_s[/^[a-fA-F0-9]*/]
    get_keys_starting_with(small).first unless small.length < MINIMUM_KEY_LENGTH
  end

  module UploadMethods
    def bucket
      @bucket ||= S3.buckets[BUCKET_NAME]
    end

    def upload_image(path, type = "application/octet-stream")
      id = Digest::SHA1.file(path).hexdigest

      unless bucket.objects[id].exists?
        bucket.objects[id].write(
          Pathname.new(path),
          content_type: type,
          cache_control: "public,max-age=999999999",
          acl: :public_read,
          content_disposition: :attachment
        )
      end

      short_key = find_short_key_for(id)
      "/#{short_key}"
    end

    def find_short_key_for(key)
      keys = get_keys_starting_with(key[0...MINIMUM_KEY_LENGTH]) - [key]
      MINIMUM_KEY_LENGTH.upto(key.length) do |length|
        candidate = key[0...length]
        keys = keys.grep(/^#{candidate}/)
        return candidate if keys.empty?
      end
      key
    end

    def get_keys_starting_with(key)
      bucket.objects.with_prefix(key).sort_by(&:last_modified).map(&:key)
    end
  end

  extend UploadMethods
  include UploadMethods

end
