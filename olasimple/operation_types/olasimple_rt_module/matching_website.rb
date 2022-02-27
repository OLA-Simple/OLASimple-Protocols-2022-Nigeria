# frozen_string_literal: true

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


  ##########################################
  # INPUT/OUTPUT
  ##########################################
    INPUT = 'Patient Sample'
    OUTPUT = 'cDNA'
    PACK = 'RT Pack'
    
    
  ##########################################
  # TERMINOLOGY
  ##########################################

  ##########################################
  # Protocol Specifics
  ##########################################
    
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
    
      # for debugging and tests
      PREV_COMPONENT = '6'
      PREV_UNIT = 'E'

  
    def main
        
        operations.running.retrieve interactive: false
        operations.running.make
        save_user operations

        # Debug info goes here #
        # these are the values used when running tests 
        if debug
          labels = %w[001 002]
          kit_num = 'K001'
          operations.each.with_index do |op, i|
            op.input(INPUT).item.associate(SAMPLE_KEY, labels[i])
            op.input(INPUT).item.associate(COMPONENT_KEY, PREV_COMPONENT)
            op.input(INPUT).item.associate(KIT_KEY, kit_num)
            op.input(INPUT).item.associate(UNIT_KEY, PREV_UNIT)
            op.input(INPUT).item.associate(PATIENT_KEY, "A PATIENT ID")        
          end #each with index
        end #if debug


        show do
            operations.each do |op|
            note "input is #{op.input(INPUT)}"
            end # iteration
        end # show block
        
        show do
            note "PACK_HASH is #{PACK_HASH}"
        end
        


        
        save_temporary_input_values(operations, INPUT)
 
        
        operations.each do |op|
            op.temporary[:pack_hash] = PACK_HASH
            show do 
                note "op.temporary[:pack_hash] is #{op.temporary[:pack_hash]}"
            end 
        end # operations each do for PACK_HASH

        run_checks(operations)
        kit_introduction(operations.running)
        
        
        
        
        # record_technician_id
        # safety_warning
        # area_preparation('pre-PCR', MATERIALS, POST_PCR)
        # simple_clean("OLASimple RT Module")


        get_samples_from_previous_op(operations.running)
        
        #get_rt_packages(operations.running)

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
    
    
    def get_samples_from_previous_op(myops)
        # get the results of the extraction
        gops = group_packages(myops)
        show do
            title "Place #{SAMPLE_ALIAS.bold} samples in #{AREA.bold} area."
            note "In #{AREA.bold} area, retrieve RT tubes from thermocycler and place into a rack."
            
            tubes = []
            gops.each do |unit, ops|

                ops.each_with_index do |op, i|
                    tubes << make_tube(closedtube, '', ref(op.input(INPUT).item).split('-'), 'medium', true).translate!(100 * i)
                end # each with index, create tube images and add to array

                img = SVGElement.new(children: tubes, boundy: 300, boundx: 300).translate!(20) # create image

                note display_svg(img) # display image -- method from image library
            end # gops each do

        end # show block
        
    end #method



    def get_rt_packages(myops)
        gops = group_packages(myops)
        show do
            note "gops is #{gops}"
        end
        show do
        title "Take #{RT_PKG_NAME.pluralize(gops.length)} from the #{FRIDGE_PRE} with a Paper Towel and place on the #{BENCH_POST}"
            gops.each do |unit, _ops|
                check "unit is #{unit}"
                check "Take package #{unit.bold} from fridge."
                check "Place package #{unit.bold} on the bench."
            end # take and place block
        end # show block
    end #get_rt_packages method   

    
    
    
    
    
    
    
    
    
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


