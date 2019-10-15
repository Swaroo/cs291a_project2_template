require 'sinatra'
require 'digest'
require 'yaml'
require 'google/cloud/storage'

storage = Google::Cloud::Storage.new(project_id: 'cs291-f19')
bucket = storage.bucket 'cs291_project2', skip_lookup: true

def validHex(str)

  if !(str.length == 64)
    return false
  end

  str.downcase!
  if (str =~ /[g-z]/).nil?
    return true
  else
    return false
  end
end

get '/' do
  redirect '/files/'
end

post '/files/' do
  status = 201
  hexFileName = ""
  headers = {}
  body = ""
  begin
    if !params[:file].nil? && !params[:file][:tempfile].nil? && !params[:file][:filename].nil? && !(params[:file][:filename] == "")
      file = params[:file][:tempfile]
      reqHeaders = YAML.load(params[:file][:head])
      content = file.sysread(1048577)
      if content.length > 1048576
        return [422]
      end
      hexFileName = Digest::SHA256.hexdigest(content)

      found_file = false
      fileList = bucket.files
      fileList.each do |gcfile|
        checkName = gcfile.name
        checkName.gsub!('/','')
        checkName.downcase!
        if checkName == hexFileName
          status = 409
          headers = {}
          body = ""
          found_file = true
          break
        end
      end

      if !found_file
        hexFileName.downcase!
        hexFileName.insert 2, "/"
        hexFileName.insert 5, "/"
        bucket.create_file file, hexFileName, content_type: reqHeaders["Content-Type"]
        status = 201
        headers = {"content-type" => "application/json"}
        body = {"uploaded" => hexFileName.gsub!('/','')}.to_json
      end

    else
      status = 422
      headers = {}
      body = ""
    end
  rescue TypeError
    status = 422
    headers = {}
    body = ""
    [status,headers,body]
  end
  [status,headers,body]
end


get '/files/' do
  files = bucket.files
  hexFileName = ""
  fileList = []
  files.each do |file|
    hexFileName = file.name
    if hexFileName[2] == "/" && hexFileName[5] == "/"
      hexFileName.gsub!('/','')
      if validHex(hexFileName)
        fileList.append(hexFileName)
      end
    end
  end
  fileList.sort()
  200
  content_type :json
  fileList.to_json
end

get '/files/:hexId' do
  status = 200
  headers = {}
  body = ""
  hexId = (params[:hexId])
  hexId.downcase!

  if !validHex(hexId)
    status = 422
    headers = {}
    body = ''
  else
    hexId.insert 2, "/"
    hexId.insert 5, "/"
    file = bucket.file hexId
    if file
      status = 200
      headers = {"content-disposition" => "attachment","content-type" => file.content_type}

      downloaded = file.download
      downloaded.rewind
      body = downloaded.read
      return [status,headers,body]
      body = file
    else
      status = 404
      headers = {}
      body = ''
    end
  end
  [status,headers,body]
end

delete '/files/:hexId' do
  status = 200
  headers = {}
  body = ""
  hexId = (params[:hexId])
  hexId.downcase!

  if !validHex(hexId)
    status = 422
    headers = {}
    body = ''
  else
    hexId.insert 2, "/"
    hexId.insert 5, "/"
    file = bucket.file hexId
    if file.nil?
      status = 200
      headers = {}
      body = ''
    else
      file.delete # raises Google::Cloud::PermissionDeniedError
      status = 200
      headers = {}
      body = ''
    end
  end
  [status,headers,body]
end

