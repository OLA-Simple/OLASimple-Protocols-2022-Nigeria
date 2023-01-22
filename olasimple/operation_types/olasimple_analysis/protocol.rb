# frozen_string_literal: true

##########################################
#
# OLASimple Analysis
# author: Justin Vrana
# update in progress: January 21, 2023
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
    
    COLORS = ["red", "green","yellow", "blue", "purple", "white", "gray", "red", "yellow", "green"]
    PREV_COMPONENTS = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
    POSITIVE = "positive"
    NEGATIVE = "negative"
    
    INPUT = "Detection Strip"
#   AREA = POST_PCR
#   PACK_HASH = ANALYSIS_UNIT
    # MUTATIONS_LABEL = PACK_HASH["Mutation Labels"]
#   PREV_COMPONENTS = PACK_HASH["Components"]["strips"]
    PREV_UNIT = "D"
    DEBUG_UPLOAD_ID = 4 # make upload, get id for deployed version
    
    # incoming Item has Data Association for scanned image upload key 
    # get that image using the key 
    # output item -- can be same as input item or can be new item
    # either way, make data assocations for the calls made by the tech
    
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
            operations.each do |op|
                op.input(INPUT).item.associate(SCANNED_IMAGE_UPLOAD_ID_KEY, DEBUG_UPLOAD_ID)
            end # each do
        end # if debug
        
        # operations.running.each do |op|
        #     image_upload_id = op.input(INPUT).item.get(SCANNED_IMAGE_UPLOAD_ID_KEY)
        #     if image_upload_id.nil?
        #         op.error(:no_image_attached, "No image was found for item #{op.input(INPUT).item.id} (#{op.input_refs(INPUT)})")
        #     end # if image nil
        # end # ops each do

        
        
        
        save_temporary_input_values(operations, INPUT)
        introduction
        
        my_temp_test_function(operations.running)
    
        call_instructions
        # make_visual_call(operations.running, band_choices)
        make_visual_call_test(operations.running, band_choices, categories)
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
            show do
                note "This is my test function"
                note "op.temporary is #{op.temporary}"
                note "input is #{op.input(INPUT).item}"
                note "upload id is #{image_upload_id}"
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
    
    def make_visual_call_test(ops, band_choices, category_hash)
        
        # for each op, display that image and one tenth of the strip upload and get choices 
        ops.each do |op|
            this_kit = op.temporary[:input_kit]
            this_unit = op.temporary[:input_unit]
            this_sample = op.temporary[:input_sample]
            
            band_keys = ["M", "N", "O", "P", "Q", "R"]
            test_colors = ["red", "green","yellow", "blue", "purple", "gray"]
        
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
                bands = band_choices[band_key.to_sym][:bands]
				# so this will give you [mut_band] or [control_band, wt_band, mut_band] or nothing depending on result

                grid.add(choice_label, idx, 0)
                # grid.add(category_label, i, 0)

                bands.each do |band|
                    grid.add(band, idx, 0) # then this is just adding the lines or no adding them, as the result went 
                end # add bands
            end # band keys do
            
            reference_img = SVGElement.new(children: [grid], boundx: PREV_COMPONENTS.size * 100, boundy: 350)
            reference_img.translate!(15)
        
            op.temporary[:results] = []
            
            # upload = Upload.find(4)
            image_upload_id = op.input(INPUT).item.get(SCANNED_IMAGE_UPLOAD_ID_KEY)
            
            # if image_upload_id.nil?
        #   op.error(:no_image_attached, "No image was found for item #{op.input(INPUT).item.id} (#{op.input_refs(INPUT)})")
        #     end # if image nil
            upload = Upload.find(image_upload_id)
            
            PREV_COMPONENTS.each_with_index do |this_component, idx|
                alias_label = op.input_refs(INPUT)[idx] # e.g. D1-001
                # note display_svg(reference_img)
                tech_choice = show do
                    title "Compare #{STRIP} #{alias_label} with the images below."
                    note "There are three possible pink/red #{BANDS} for the #{STRIP}."
                    note "Select the choice below that most resembles #{STRIP} #{alias_label}"
                    # warning "<h2>After you click OK, you cannot change your call."
                    note "Signal of all the lines does not have to be equally strong. Flow control signal is always the strongest."
                    select band_choices.keys.map {|k| k.to_s}, var: :strip_choice, label: "Choose:", default: 0
                    raw display_strip_section(upload, idx, PREV_COMPONENTS.length, "25%")
                    note display_svg(reference_img)
                end # tech choice show do
                
            if debug
                tech_choice[:strip_choice] = band_choices.keys[idx % 5]
            end # debug 

            op.temporary[:results].append(tech_choice[:strip_choice])
            
            show do
                note "Tech Chose #{tech_choice}"
                note "Results are #{op.temporary[:results]}"
                # tech_choice {:strip_choice=>"M", :timestamp=>1671042324000}
            end # display tech choice show do
            
            current_choice = tech_choice[:strip_choice]
            
            # # create data associations for item
            op.input(INPUT).item.associate(make_call_key(alias_label), current_choice)
            
            # # create data associations for operation -- maybe not needed here 
            # op.associate(make_call_key(alias_label), current_choice)
            
            # # op.associate(make_call_category_key(alias_label), category_hash[current_choice.to_sym])
            op.input(INPUT).item.associate(make_call_category_key(alias_label), category_hash[current_choice.to_sym])
            
            show do
                title "TESTING"
                note "item associations are now #{op.input(INPUT).item.associations}"
            end
            
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
    
    def conclusion
        show do
            title 'Thank you for all your hard work!'
            note 'Click OK in the upper right corner to complete the protocol'
        end # end show do
    end # end conclusion

end #protocol


# def make_visual_call(ops, band_choices)
#       ops.each do |op|
#         this_kit = op.temporary[:input_kit]
#         this_unit = op.temporary[:input_unit]
#         this_sample = op.temporary[:input_sample]
        
#         op.temporary[:results] = []
          
#         PREV_COMPONENTS.each_with_index do |this_component, i|
#             alias_label = op.input_refs(INPUT)[i]
#             colorclass = COLORS[i] + "strip"
#             strip_label = tube_label(this_kit, this_unit, this_component, this_sample)
#             strip = make_strip(strip_label, colorclass).scale!(0.5)
#             question_mark = label("?", "font-size".to_sym => 100)
#             question_mark.align('center-center')
#             question_mark.align_with(strip, 'center-top')
#             question_mark.translate!(0, 75)
            
#             index = 0
#             grid = SVGGrid.new(band_choices.length, 1, 100, 10)
            
#             band_choices.each do |choice, band_hash|
#                 this_strip = strip.inst.scale(1.0)
#                 reading_window = SVGElement.new(boundy: 50)
                          
#                 # add strip
#                 reading_window.add_child(this_strip)
          
#                 # add the bands
#                 band_hash[:bands].each do |band|
#                     reading_window.add_child(band)
#                 end # band_hash add bands
                
#                 # crop label and bottom part of strip
#                 c = reading_window.group_children
#                 c.translate!(0, -40)
#                 whitebox = SVGElement.new(boundx: 110, boundy: 400)
#                 whitebox.add_child("<rect x=\"-1\" y=\"95\" width=\"102\" height=\"400\" fill=\"white\" />")
#                 reading_window.add_child(whitebox)
          
#                 # add label
#                 strip_choice = label(choice, "font-size".to_sym => 40)
#                 strip_choice.align!('center-top')
#                 strip_choice.align_with(whitebox, 'center-top')
#                 strip_choice.translate!(-10, 110)
#                 reading_window.add_child(strip_choice)
          
#                 grid.add(reading_window, index, 0)
#                 index += 1
#             end # band choices each do
            
#             grid.scale!(0.75)
#             img = SVGElement.new(children: [grid], boundx: 500, boundy: 250).scale(0.8)
            
#             #needs error handling
#             # upload = Upload.find(op.input(INPUT).item.get(SCANNED_IMAGE_UPLOAD_ID_KEY).to_i)
#             upload = Upload.find(4)

#             # this is will run once per strip -- based on prev components being 10
#             tech_choice = show do
#                 title "Compare #{STRIP} #{alias_label} with the images below."
#                 note "There are three possible pink/red #{BANDS} for the #{STRIP}."
#                 note "Select the choice below that most resembles #{STRIP} #{alias_label}"
#                 # warning "<h2>Do not make calls based on the actual strips but based on the scanned images.</h2>"
#                 # warning "<h2>After you click OK, you cannot change your call."
#                 note "Signal of all the lines does not have to be equally strong. Flow control signal is always the strongest."
#                 select band_choices.keys.map {|k| k.to_s}, var: :strip_choice, label: "Choose:", default: 0
#                 note ""
#                 note display_svg(img)
#                 note "_______________"
#                 raw display_strip_section(upload, i, PREV_COMPONENTS.length, "25%")
#                 note ""
                
#             end # choice show block
            
#             # if debug
#             #     # "M": {bands: [mut_band], description: "-CTRL -WT +MUT"},
#             #     tech_choice[:strip_choice] = band_choices.keys[i % 5]
#             # end # debug 

#             # op.temporary[:results].append(tech_choice[:strip_choice])
            
#             # show do
#             #     note "Tech Chose #{tech_choice}"
#             #     note "Results are #{op.temporary[:results]}"
#             #     # tech_choice {:strip_choice=>"M", :timestamp=>1671042324000}
#             # end
            
#             # current_choice = tech_choice[:strip_choice]
            
#             # # create data associations for item
#             # op.input(INPUT).item.associate(make_call_key(alias_label), current_choice)
            
#             # # create data associations for operation -- maybe not needed here 
#             # op.associate(make_call_key(alias_label), current_choice)
            
#             # # op.associate(make_call_category_key(alias_label), category_hash[current_choice.to_sym])
#             # # op.input(INPUT).item.associate(make_call_category_key(alias_label), category_hash[current_choice.to_sym])

#         end #PREV_COMPONENTS
#       end # ops each with index
#   end # make visual call method

