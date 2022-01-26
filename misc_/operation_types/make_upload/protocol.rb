needs "OLASimple/OLALib"

# TODO: There should be NO calculations in the show blocks

class Protocol
  include OLALib

  def main

    operations.retrieve.make
    
    result = show do
        title "Upload a picture or a video"
        
        upload var: :files
    end
    
    upload_hashes = result[:files]
    
    show do
        upload_hashes.each do |uhash|
            note "#{uhash[:name]} #{uhash[:id]}"
            raw display_upload(Upload.find(uhash[:id]))
        end
    end
    
    operations.store
    
    return {}
    
  end

end
