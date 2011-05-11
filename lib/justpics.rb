require 'sinatra/base'
require 'digest/sha1'
require 'aws/s3'

AWS::S3::Base.establish_connection!(
  :access_key_id     => ENV["AMAZON_ACCESS_KEY_ID"],
  :secret_access_key => ENV["AMAZON_SECRET_ACCESS_KEY"]
)

class Justpics < Sinatra::Base
  enable :static, :methodoverride

  get "/" do
    File.read(File.expand_path("../../public/index.html", __FILE__))
  end

  post "/" do
    unless params[:file] && (tmpfile = params[:file][:tempfile]) && (name = params[:file][:filename])
      status 510
      return "No file selected"
    end
    id = Digest::SHA1.file(tmpfile.path).hexdigest

    AWS::S3::S3Object.store(id, tmpfile, ENV["AMAZON_S3_BUCKET"], :content_type => params[:file][:type])
    redirect "/#{id}"
  end

  get "/:id" do
    id = params[:id].to_s[0...40]
    begin
      file = AWS::S3::S3Object.find(id, ENV["AMAZON_S3_BUCKET"])
      content_type file.content_type

      response['Cache-Control'] = "public, max-age=#{60*60*24*356*3}"
      response['ETag'] = "the-same-thing-every-time"
      response['Last-Modified'] = Time.at(1337).httpdate

      file.value
    rescue AWS::S3::NoSuchKey
      status 404
      "Not here"
    end
  end

  class AlwaysFresh
    def initialize(app)
      @app = app
    end

    def call(env)
      if (env["HTTP_IF_MODIFIED_SINCE"] or env["HTTP_IF_NONE_MATCH"]) and env["REQUEST_METHOD"] == "GET" and env["REQUEST_PATH"].length > 40
        [304, {}, []]
      else
        @app.call(env)
      end
    end
  end
end
