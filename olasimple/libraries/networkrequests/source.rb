# This library allows complex network requests to be made from protocols
# so that external APIs can be consulted during protocol execution

require 'net/https'
module NetworkRequests
  
  # make post request to a URL, sending a Upload object as a file
  # returns the http response
  def post_file(post_url, key, aq_upload)
    file_url = aq_upload.url
    file_name = aq_upload.name
    file_obj = URI.open(file_url)
    
    uri = URI(post_url)
    req = Net::HTTP::Post.new(uri)
    req.set_form([[key, file_obj, {'filename': file_name}]], 'multipart/form-data')
    
    res = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end
    return res
  end
  
end