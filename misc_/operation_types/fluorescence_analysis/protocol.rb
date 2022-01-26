# frozen_string_literal: true

# This is a default, one-size-fits all protocol that shows how you can
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!
needs 'OLASimple/NetworkRequests'
class Protocol
  include NetworkRequests
  API_URL = 'http://ola_image_processing:5000/api/classifyfluorescence'
  def main
    operations.each do |op|
      image_results = nil
      5.times.each do |_i|
        break if image_results

        upload = accept_file

        image_results = make_calls(upload)
      end

      if image_results.nil?
        op.error(:image_result_failed, 'Image processing has failed. Check that the OLA IP service is running and connected correctly, and that the file is in a normal image format.')
        raise 'Image processing has failed. Check that the OLA IP service is running and connected correctly, and that the file is in a normal image format.'
      end

      result_table = [['tube #', 'viral', 'r', 'g', 'b']]
      tubes = image_results[0].size
      tubes.times do |i|
        rgb = image_results[0][i]
        classification = image_results[1][i]
        result_table << [i.to_s, classification, *rgb]
      end

      show do
        title 'Image analyzed'
        note 'Results:'
        table result_table
      end
    end
    {}
  end

  def make_calls(image_upload)
    res = post_file(API_URL, 'file', image_upload)
    JSON.parse(res.body)['results']
  end

  def accept_file
    result = show do
      title 'Upload file for analysis'
      upload var: :files
    end
    upload_hashes = result[:files] || []
    uhash = upload_hashes.first
    Upload.find(uhash[:id])
  end
end
