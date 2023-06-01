# frozen_string_literal: true

##########################################
#
# OLASimple Analysis
# author: Justin Vrana
# update in progress: May 31, 2023
# former visual call plus some stuff from detection
##########################################

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

    PACK_HASH = ANALYSIS_UNIT
    MUTATION_LABELS = PACK_HASH['Mutation Labels']
    MUTATION_COLORS = PACK_HASH['Mutation Colors']    

    PREV_PACK = DETECTION_UNIT
    PREV_COMPONENTS = PREV_PACK["Components"]["strips"]
    PREV_UNIT = "D"

    POSITIVE = "positive"
    NEGATIVE = "negative"
    
    INPUT = "Detection Strip"
    
    DEBUG_UPLOAD_ID = [4, 32] # make upload, get id for deployed version
    
    def main
    
        band_choices = {
            "M": {bands: [mut_band], description: "-CTRL -WT +MUT"},
            "N": {bands: [control_band, wt_band, mut_band], description: "+CTRL +WT +MUT"},
            "O": {bands: [control_band, mut_band], description: "+CTRL -WT +MUT"},
            "P": {bands: [control_band, wt_band], description: "+CTRL +WT -MUT"},
            "Q": {bands: [control_band], description: "+CTRL -WT -MUT"},
            "R": {bands: [], description: "-CTRL -WT -MUT"}
        }

        categories = {
            "M": POSITIVE,
            "N": POSITIVE,
            "O": POSITIVE,
            "P": NEGATIVE,
            "Q": "ligation failure",
            "R": "detection failure"
        }
    
        save_user(operations)
        operations.running.retrieve interactive: false
        # add back in error checks
        debug_setup(operations) # has to happen before temp hash is made
        
        if debug
            operations.each_with_index do |op, idx|
                op.input(INPUT).item.associate(SCANNED_IMAGE_UPLOAD_ID_KEY, DEBUG_UPLOAD_ID[idx])
            end # each do
        end # if debug
        
        save_temporary_input_values(operations, INPUT)
        
        # operations.running.each do |op|
        #     image_upload_id = op.input(INPUT).item.get(SCANNED_IMAGE_UPLOAD_ID_KEY)
        # #     if image_upload_id.nil?
        # #         op.error(:no_image_attached, "No image was found for item #{op.input(INPUT).item.id} (#{op.input_refs(INPUT)})")
        # #     end # if image nil
        # end # ops each do
        
        introduction
        
        # my_temp_test_function(operations.running)
    
        call_instructions
        make_visual_call(operations.running, band_choices, categories)
        show_results_table(operations.running)
        conclusion

    end #main

    def debug_setup(ops)
        # make an alias for the inputs, add setup for image to use in testing
        if debug
            ops.each_with_index do |op, i|
                kit_num = 'K001'
                sample_num = sample_num_to_id(i + 1)
                make_alias(op.input(INPUT).item, kit_num, PREV_UNIT, PREV_COMPONENTS, 'a patient id', sample_num)
                op.input(INPUT).item.associate(SCANNED_IMAGE_UPLOAD_ID_KEY, DEBUG_UPLOAD_ID) # make data association for input if testing
            end #each with index
        end # if debug
    end #debug set up

    def save_user ops
        ops.each do |op|
            username = get_technician_name(self.jid)
        op.associate(:technician, username)
        end
    end

    def my_temp_test_function(ops)
        ops.each_with_index do |op, idx|
            image_upload_id = op.input(INPUT).item.get(SCANNED_IMAGE_UPLOAD_ID_KEY)
            upload = Upload.find(image_upload_id)
            show do
                note "This is my test function"
                note "op.temporary is #{op.temporary}"
                note "input is #{op.input(INPUT).item}"
                note "upload id is #{image_upload_id}"
                note "file name is #{upload.upload_file_name}"
            end
        end
    end
    
    def introduction
        show do
         title 'Welcome to OLASimple Analysis procotol'
         note 'In this protocol you will look at and evaluate images of the detction strips'
        end
    end
    
    
    def call_instructions
        show do
          note "Now you will look at and evaluate images of the detection strips."
          note "Each strip may have three bands:"
          bullet "Top band corresponds to a flow control (C)"
          bullet "Middle band corresponds to the wild-type genotype at that codon (W)"
          bullet "Bottom band corresponds to the mutant genotype at that codon (M)"
          note "You will be asked to compare your detection trips to some images on the screen"
          note "Click \"OK\" in the upper right to continue."
        end
        show do
          title "You will be making visual calls on these #{"scanned images".quote.bold}"
          warning "Do not make calls based on your actual strips because:"
          note "1) The assay is time-sensitive; a false signal can develop over time on the actual strips after you scan the strips."
          note "2) Doctors will confirm your visual calls based on the scanned images, not the actual strips."
        end
    end # end call_instructions
    
    def make_visual_call(ops, band_choices, category_hash)
        
        # for each op, display that image and one tenth of the strip upload and get choices 
        ops.each do |op|
            this_kit = op.temporary[:input_kit]
            this_unit = op.temporary[:input_unit]
            this_sample = op.temporary[:input_sample]
            
            band_keys = band_choices.keys
            test_colors = ["red", "green","yellow", "blue", "purple", "gray"]
            
            # work around for image display issue
            # Find upload 
            # Since we can't show the images, use this to get the name of the file instead
            # either the real one or the one we set up in debug step
            image_upload_id = op.input(INPUT).item.get(SCANNED_IMAGE_UPLOAD_ID_KEY)
            upload = Upload.find(image_upload_id)
            file_name = upload.upload_file_name
            
            
            # if image_upload_id.nil?
        #   op.error(:no_image_attached, "No image was found for item #{op.input(INPUT).item.id} (#{op.input_refs(INPUT)})")
        #     end # if image nil
        
            
            
            # show do
            #     note "image upload id is upload is #{image_upload_id}"
            #     note "upload name is #{file_name}"
            # end
            
            # confirm they have the right file
            image_confirmed = false
            5.times do
                next if image_confirmed
                confirmed = show do
                    title "Confirm that you are looking at file #{file_name.bold}"
                    select %w[yes no], var: 'confirmed', label: 'Are you looking at the correct image file?', default: 0
                end # confirmed
                
                image_confirmed = confirmed[:confirmed] == 'yes'
                show do
                    note "image confirmed == #{image_confirmed}"
                end

                next if image_confirmed

                show do
                    title "You did not confirm the file name."
                    note "If you don't see the file name, ask for assistance and try again."
                end
            end # 5 times
            
        
            # make the reference image with the codon labels
            # grid = SVGGrid.new(6, 1, 90, 10)
            grid = SVGGrid.new(6, 1, 90, 0)
        
            #self.two_labels("#{unit}#{component}", "#{sample}")
        
            band_keys.each_with_index do |band_key, idx|
                # strip_label = tube_label("", band_key, "", "") # because labels needs an object of class label
                strip_label = tube_label(this_kit, this_unit, band_key, this_sample)
                make_strip(strip_label, test_colors[idx] + 'strip') # could really be any color since this is for reference
                grid.add(strip, idx, 0)
                
                # labels for bottom, with results
                choice_label = label(band_keys[idx], 'font-size'.to_sym => 25)
                choice_label.align_with(strip, 'center-bottom')
                choice_label.align!('center-top').translate!(0, 30)
                
                # {"M": {bands: [mut_band], description: "-CTRL -WT +MUT"},}
                # This will give you [mut_band] or [control_band, wt_band, mut_band] or nothing depending on result
                bands = band_choices[band_key.to_sym][:bands]
				
                grid.add(choice_label, idx, 0)
                # grid.add(category_label, i, 0)

                bands.each do |band|
                    grid.add(band, idx, 0) # then this is just adding the lines or no adding them, as the result went 
                end # add bands
            end # band keys do
            
            reference_img = SVGElement.new(children: [grid], boundx: PREV_COMPONENTS.size * 100, boundy: 350)
            reference_img.translate!(15)
        
            op.temporary[:results] = {"choice_letter": [], "choice_category": []}
            
            PREV_COMPONENTS.each_with_index do |this_component, idx|
                alias_label = op.input_refs(INPUT)[idx] # e.g. D1-001
                # note display_svg(reference_img)
                tech_choice = show do
                    title "Compare #{STRIP} #{alias_label} with the images below."
                    warning "Make sure you are looking at the correct strip."
                    note "There are three possible pink/red #{BANDS} for the #{STRIP}."
                    note "Select the choice below that most resembles #{STRIP} #{alias_label}"
                    warning "<h2>After you click OK, you cannot change your call."
                    note "Signal of all the lines does not have to be equally strong. Flow control signal is always the strongest."
                    select band_choices.keys.map {|k| k.to_s}, var: :strip_choice, label: "Choose:", default: 0
                    # raw display_strip_section(upload, idx, PREV_COMPONENTS.length, "25%")
                    note display_svg(reference_img)
                end # tech choice show do
                
            if debug
                tech_choice[:strip_choice] = band_choices.keys[idx % 5].to_s
            end # debug 

            # op.temporary[:results].append(tech_choice[:strip_choice])
            op.temporary[:results][:choice_letter].append(tech_choice[:strip_choice])
            op.temporary[:results][:choice_category].append(category_hash[tech_choice[:strip_choice].to_sym])
            
            # show do
            #     note "Tech Chose #{tech_choice}"
            #     note "Results are #{op.temporary[:results]}"
            #     # tech_choice {:strip_choice=>"M", :timestamp=>1671042324000}
            # end # display tech choice show do
            
            current_choice = tech_choice[:strip_choice]
            
            # # create data associations for item
            op.input(INPUT).item.associate(make_call_key(alias_label), current_choice)
            
            # # create data associations for operation -- maybe not needed here 
            # op.associate(make_call_key(alias_label), current_choice)
            
            # # op.associate(make_call_category_key(alias_label), category_hash[current_choice.to_sym])
            op.input(INPUT).item.associate(make_call_category_key(alias_label), category_hash[current_choice.to_sym])
            
            # show do
            #     title "TESTING"
            #     note "item associations are now #{op.input(INPUT).item.associations}"
            # end
            
            end # prev components 
            
        end # ops each do
    end # make call test
    
    # make key for data association, :D1-001_tech_call
    def make_call_key alias_label
        "#{alias_label}_tech_call".to_sym
    end

    # make key for data assocation, :D1-001_tech_call_category
    def make_call_category_key alias_label
        "#{alias_label}_tech_call_category".to_sym
    end
    
    def show_results_table(ops)
        results_hash = {}
        kits = ops.map { |op| op.input(INPUT).item.get(KIT_KEY) }
        samples = ops.map { |op| op.input(INPUT).item.get(SAMPLE_KEY) }
        patients = ops.map { |op| op.input(INPUT).item.get(PATIENT_KEY) }
        
        t = Table.new
        t.add_column('Kit', kits)
        t.add_column('Samples', samples)
        t.add_column('Patients', patients)
        
        MUTATION_LABELS.each_with_index do |label, idx|
            col = ops.map { |op| op.temporary[:results][:choice_category][idx]}
            # col = ops.map { |op| op.temporary[:results][label][:category] }
            t.add_column(label, col)
            # results_hash[label] = col
        end
        
        show do
            table t
        end
        
        
        # ops.each do |op|
        #     show do
        #         title "RESULTS TEST"
        #         note "op.temporary is #{op.temporary}"
        #     end
        # end 
    end
    
    def conclusion
        show do
            title 'Thank you for all your hard work!'
            note 'Click OK in the upper right corner to complete the protocol'
        end # end show do
    end # end conclusion

end #protocol

