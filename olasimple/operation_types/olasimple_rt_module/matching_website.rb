# frozen_string_literal: true
# protocol that matches the version I have deployed locally
# Add to this as you add things to that


needs 'OLASimple/OLAConstants'
needs 'OLASimple/OLALib'
needs 'OLASimple/OLAGraphics'
needs 'OLASimple/JobComments'
needs 'OLASimple/OLAKitIDs'


class Protocol

    include OLAConstants
    include OLALib
    include OLAGraphics
    include JobComments
    include OLAKitIDs

    INPUT = 'Patient Sample'
    OUTPUT = 'cDNA'
    PACK = 'RT Pack'
    
    PACK_HASH = RT_UNIT
    AREA = PRE_PCR
    SAMPLE_VOLUME = 20 # volume of sample to add to PCR mix
     CENTRIFUGE_TIME = '5 seconds' # time to pulse centrifuge to pull down dried powder
    VORTEX_TIME = '5 seconds' # time to pulse vortex to mix

    TUBE_CAP_WARNING = 'Check to make sure tube caps are completely closed.'
    MATERIALS = [
        'P20 pipette and filtered tips',
        'Gloves (wear tight gloves to reduce contamination risk)',
        'Centrifuge',
        '70% v/v Ethanol spray for cleaning',
        '10% v/v Bleach spray for cleaning',
        'Molecular grade ethanol'
    ].freeze

    SAMPLE_ALIAS = 'RT cDNA'


  
    def main
        
        operations.running.retrieve interactive: false
        operations.running.make
        save_user operations

# Debug info goes here

        show do
            operations.each do |op|
            note "input is #{op.input(INPUT)}"
            end # iteration
        end # show block
        
        save_temporary_input_values(operations, INPUT)
 
        
        operations.each do |op|
            op.temporary[:pack_hash] = PACK_HASH
        end # operations each do for PACK_HASH

        run_checks(operations)
        kit_introduction(operations.running)
        record_technician_id
        safety_warning
    
        area_preparation('pre-PCR', MATERIALS, POST_PCR)
        simple_clean("OLASimple RT Module")


    end #main
    
    #######################################
    # Instructions
    #######################################

  def kit_introduction(ops)
    show do
      title "Welcome to OLASimple RT (Reverse Transcription)"
      note 'In this protocol you will be converting the RNA generated from the E module into cDNA'
    end # welcome block

    show do
      title 'RNase degrades RNA'
      note 'RNA is prone to degradation by RNase present in our eyes, skin, and breath.'
      note 'Avoid opening tubes outside the Biosafety Cabinet (BSC).'
      bullet 'Change gloves whenever you suspect potential RNAse contamination'
    end # RNase warning block
  end # kit_introduction


    
    
    
    
    
    
    
    
    
    
  #######################################
  # Utilities
  #######################################
  def save_user(ops)
    ops.each do |op|
      username = get_technician_name(jid)
      op.associate(:technician, username)
    end
  end #save_user
  
    def run_checks(_myops)
        if operations.running.empty?
            show do
                title 'All operations have errored'
                note "Contact #{SUPERVISOR}"
        operations.each do |op|
          note (op.errors.map { |k, v| [k, v] }).to_s
        end
      end
      {}
    end
  end #run_checks



end #class


