require 'sinatra/base'
require 'digest/sha1'
require 'aws/s3'

AWS::S3::Base.establish_connection!(
  :access_key_id     => ENV["AMAZON_ACCESS_KEY_ID"],
  :secret_access_key => ENV["AMAZON_SECRET_ACCESS_KEY"]
)

class Justpics < Sinatra::Base
  BUCKET_NAME = ENV['AMAZON_S3_BUCKET']
  MAX_SIZE = (ENV['JUSTPICS_MAX_SIZE'] || 2 * 1024 * 1024).to_i
  POST_PATH = "/#{ENV["JUSTPICS_POST_PATH"]}".gsub(%r{//+}, "/")
  MINIMUM_KEY_LENGTH = (ENV['JUSTPICS_MINIMUM_KEY_LENGTH'] || 40).to_i
  MINIMUM_KEY_LENGTH > 0 or raise ArgumentError, "JUSTPICS_MINIMUM_KEY_LENGTH must be above 0, otherwise where would the home page go?!?"
  MINIMUM_KEY_LENGTH <= 40 or raise ArgumentError, "JUSTPICS_MINIMUM_KEY_LENGTH cannot be bigger then the full key length (40)"

  NotFound = Class.new(RuntimeError)

  enable :static, :methodoverride

  get POST_PATH do
    File.read(File.expand_path("../../public/index.html", __FILE__))
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

    id = Digest::SHA1.file(tmpfile.path).hexdigest

    unless AWS::S3::S3Object.exists?(id, BUCKET_NAME)
      AWS::S3::S3Object.store(id, tmpfile, BUCKET_NAME, :content_type => file[:type])
    end

    short_key = find_short_key_for(id)
    resource_url = url("/#{short_key}")

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
    file = AWS::S3::S3Object.find(sha, BUCKET_NAME)
    content_type file.content_type
    Enumerable::Enumerator.new(file, :value)
  rescue AWS::S3::NoSuchKey => e
    raise NotFound, e.message
  end

  def render_default
    send_file File.expand_path('../../assets/default.png', __FILE__)
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
    AWS::S3::Bucket.objects(BUCKET_NAME, :prefix => key).sort_by{|o| Date.parse(o.about["last-modified"]) }.map(&:key)
  end

  def expand_sha(small)
    small = small.to_s[/^[a-fA-F0-9]*/]
    get_keys_starting_with(small).first unless small.length < MINIMUM_KEY_LENGTH
  end

  class AlwaysFresh
    def initialize(app)
      @app = app
    end

    def call(env)
      if (env["HTTP_IF_MODIFIED_SINCE"] or env["HTTP_IF_NONE_MATCH"]) and env["REQUEST_METHOD"] == "GET" and env["REQUEST_PATH"].length > MINIMUM_KEY_LENGTH
        [304, {}, []]
      else
        @app.call(env)
      end
    end
  end
end
