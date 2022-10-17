##########################################
#
#
# OLASimple Visual Call
# author: Justin Vrana
# date: March 2018
#
#
##########################################

needs "OLASimple/OLAConstants"
needs "OLASimple/OLALib"
needs "OLASimple/OLAGraphics"

class Protocol
  include OLAConstants
  include OLALib
  include OLAGraphics

  ##########################################
  # INPUT/OUTPUT
  ##########################################

  INPUT = "Detection Strip"

  ##########################################
  # TERMINOLOGY
  ##########################################

  AREA = POST_PCR

  ##########################################
  # Protocol Specifics
  ##########################################

  PACK_HASH = ANALYSIS_UNIT
  MUTATIONS_LABEL = PACK_HASH["Mutation Labels"]
  PREV_COMPONENTS = PACK_HASH["Components"]["strips"]
  PREV_UNIT = "D"

  ##########################################
  # ##
  # Input Restrictions:
  # Input needs a kit, unit, components,
  # and sample data associations to work properly
  ##########################################

  POSITIVE = "positive"
  NEGATIVE = "negative"
  DEBUG_UPLOAD_ID = 21840
  def main
    save_user operations

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
    operations.running.retrieve interactive: false
    debug_setup(operations)

    if debug
      operations.each do |op|
        op.input(INPUT).item.associate(SCANNED_IMAGE_UPLOAD_ID_KEY, DEBUG_UPLOAD_ID)
      end
    end

    operations.running.each do |op|
      image_upload_id = op.input(INPUT).item.get(SCANNED_IMAGE_UPLOAD_ID_KEY)
      if image_upload_id.nil?
        op.error(:no_image_attached, "No image was found for item #{op.input(INPUT).item.id} (#{op.input_refs(INPUT)})")
      end
    end

    if operations.errored.any?
      show do
        title "Some images were not found."
        note "Images were not found for the following:"
        operations.errored.each do |op|
          bullet "Strips #{op.input(INPUT).item} (#{op.input_refs(INPUT)})"
        end
        note "Contact #{SUPERVISOR}."
      end
    end

    if operations.running.empty?
      show do
        title "There are no operations left running"
        note "Contact #{SUPERVISOR}."
      end
      return {}
    end

    save_temporary_input_values(operations, INPUT)
    introduction operations.running
    make_calls operations.running, band_choices, categories
    show_calls operations.running, band_choices
    show_summary operations.running
    cleanup operations.running, AREA
    return {}
  end # MAIN

  def save_user ops
    ops.each do |op|
      username = get_technician_name(self.jid)
      op.associate(:technician, username)
    end
  end

  def debug_setup ops
    if debug
      ops.each do |op|
        kit_num = rand(1..60)
        INPUT
        PREV_UNIT
        PREV_COMPONENTS
        make_alias(op.input(INPUT).item, kit_num, PREV_UNIT, PREV_COMPONENTS, 1)
        # op.input(PACK).item.associate(KIT_KEY, kit_num)
      end

      if ops.length >= 2
        i = ops[-1].input(INPUT).item
        make_alias(i, i.get(KIT_KEY), i.get(UNIT_KEY), PREV_COMPONENTS, i.get(SAMPLE_KEY))

        # kit_num = ops[-1].input(PACK).item.get(KIT_KEY)
        # ops[0].input(PACK).item.associate(KIT_KEY, kit_num)
      end
    end
  end


  def introduction myops
    username = get_technician_name(self.jid).color("darkblue")
    show do
      title "Welcome #{username} to the OLASimple Visual Call protocol"

      note "In this protocol, you will be ask to look at and evaluate images of detection strips."
      note "Each strip may have three bands:"
      bullet "Top band  corresponds to a flow control (C)"
      bullet "Middle band corresponds to the wild-type genotype at that codon (W)"
      bullet "Bottom band corresponds to the mutant genotype at that codon (M)"
      note "You will be asked to compare your detection trips to some images on the screen"
      note "Click \"OK\" in the upper right to continue."
    end

    show do
      title "You will be making visual calls on these #{"scanned images".quote.bold}"
      warning "Do not make calls based on your actual strips. This is because:"
      note "1) Assay is time-sensitive; false signal can develop over time on the actual strips after you scan the strips."
      note "2) Doctors will confirm your visual calls based on the scanned images, not the actual strips."
      # note "You may have noticed that we are not using notebooks for any of the procedures. This is because " \
      #       " #{AQUARIUM.bold} tracks every step in the protocol providing a detailed record for all of the protocols " \
      #        " allowing researchers to go back and look at the information."

    end
  end

    
  def make_calls(myops, band_choices, category_hash)
    myops.each.with_index do |op|

      this_kit = op.temporary[:input_kit]
      this_unit = op.temporary[:input_unit]
      this_sample = op.temporary[:input_sample]
      #   show do
      #     refs = op.input_refs(INPUT)
      #     from = refs[0]
      #     to = refs[-1]
      #     title "Place the #{STRIP} panel in front of you"
      #     note "Labels should read #{from.bold} to #{to.bold}."
      #     note display_svg(display_strip_panel(*op.input_tokens(INPUT), COLORS))
      #   end

      PREV_COMPONENTS.each.with_index do |this_component, i|
        alias_label = op.input_refs(INPUT)[i]
        colorclass = COLORS[i] + "strip"
        strip_label = self.tube_label(this_kit, this_unit, this_component, this_sample)
        strip = make_strip(strip_label, colorclass).scale!(0.5)
        question_mark = label("?", "font-size".to_sym => 100)
        question_mark.align('center-center')
        question_mark.align_with(strip, 'center-top')
        question_mark.translate!(0, 75)

        index = 0
        grid = SVGGrid.new(band_choices.length, 1, 100, 10)
        band_choices.each do |choice, band_hash|
          this_strip = strip.inst.scale(1.0)
          
          reading_window = SVGElement.new(boundy: 50)
          
          # add strip
          reading_window.add_child(this_strip)
          
          # add the bands
          band_hash[:bands].each do |band|
            reading_window.add_child(band)
          end
          
          # crop label and bottom part of strip
          c = reading_window.group_children
          c.translate!(0, -40)
          whitebox = SVGElement.new(boundx: 110, boundy: 400)
          whitebox.add_child("<rect x=\"-1\" y=\"95\" width=\"102\" height=\"400\" fill=\"white\" />")
          reading_window.add_child(whitebox)
          
          # add label
          strip_choice = label(choice, "font-size".to_sym => 40)
          strip_choice.align!('center-top')
          strip_choice.align_with(whitebox, 'center-top')
          strip_choice.translate!(-10, 110)
          reading_window.add_child(strip_choice)
          
          grid.add(reading_window, index, 0)
          index += 1
        end
        grid.scale!(0.75)
        img = SVGElement.new(children: [grid], boundx: 500, boundy: 250).scale(0.8)

        upload = Upload.find(op.input(INPUT).item.get(SCANNED_IMAGE_UPLOAD_ID_KEY).to_i)
        choice = show do
          title "Compare #{STRIP} #{alias_label} with the images below."
          note "There are three possible pink/red #{BANDS} for the #{STRIP}."
          note "Select the choice below that most resembles #{STRIP} #{alias_label}"
          warning "<h2>Do not make calls based on the actual strips but based on the scanned images.</h2>"
          warning "<h2>After you click OK, you cannot change your call."
          note "Signal of all the lines does not have to be equally strong. Flow control signal is always the strongest."
          select band_choices.keys.map {|k| k.to_s}, var: :choice, label: "Choose:", default: 0
          raw display_strip_section(upload, i, PREV_COMPONENTS.length, "25%")
          note display_svg(img)
        end

        if debug
          choice[:choice] = band_choices.keys.sample.to_s
        end

        the_choice = choice[:choice]
        op.input(INPUT).item.associate(make_call_key(alias_label), the_choice)
        # op.input(INPUT).item.associate(make_call_description_key(alias_label), band_choices[the_choice.to_sym][:description])
        op.input(INPUT).item.associate(make_call_category_key(alias_label), category_hash[the_choice.to_sym])
        op.associate(make_call_key(alias_label), the_choice)
        # op.associate(make_call_description_key(alias_label), band_choices[the_choice.to_sym][:description])
        op.associate(make_call_category_key(alias_label), category_hash[the_choice.to_sym])
      end
    end
  end

  def make_call_key alias_label
    "#{alias_label}_call".to_sym
  end

  def make_call_description_key alias_label
    "#{alias_label}_call_description".to_sym
  end

  def make_call_category_key alias_label
    "#{alias_label}_call_category".to_sym
  end


  def show_calls myops, band_choices
    myops.each do |op|
      kit_summary = {}

      this_kit = op.temporary[:input_kit]
      this_item = op.input(INPUT).item
      this_unit = op.temporary[:input_unit]
      this_sample = op.temporary[:input_sample]

      grid = SVGGrid.new(MUTATIONS_LABEL.length, 1, 90, 10)
      categories = []
      PREV_COMPONENTS.each.with_index do |this_component, i|
        alias_label = op.input_refs(INPUT)[i]
        strip_label = self.tube_label(this_kit, this_unit, this_component, this_sample)
        strip = make_strip(strip_label, COLORS[i] + "strip")
        band_choice = this_item.get(make_call_key(alias_label))
        codon_label = label(MUTATIONS_LABEL[i], "font-size".to_sym => 25)
        codon_label.align_with(strip, 'center-bottom')
        codon_label.align!('center-top').translate!(0, 30)
        category = this_item.get(make_call_category_key(alias_label))
        kit_summary[MUTATIONS_LABEL[i]] = {:alias => alias_label, :category => category.to_s, :call => band_choice.to_s}
        tokens = category.split(' ')
        tokens.push("") if tokens.length == 1
        category_label = two_labels(*tokens)
        category_label.scale!(0.75)
        category_label.align!('center-top')
        category_label.align_with(codon_label, 'center-bottom')
        category_label.translate!(0, 10)
        bands = band_choices[band_choice.to_sym][:bands]
        grid.add(strip, i, 0)
        grid.add(codon_label, i, 0)
        grid.add(category_label, i, 0)
        bands.each do |band|
          grid.add(band, i, 0)
        end
      end

      op.associate(:results, kit_summary)
      op.input(INPUT).item.associate(:results, kit_summary)
      op.temporary[:results] = kit_summary

      img = SVGElement.new(children: [grid], boundx: 600, boundy: 350)
      img.translate!(15)
      show do
        refs = op.input_refs(INPUT)
        title "Here is the summary of your results for <b>#{refs[0]}-#{refs[-1]}</b>"
        note display_svg(img)
      end
    end
  end

  def show_summary ops
    ops.each do |op|
      hits = op.temporary[:results].select {|k, v| v == POSITIVE}
    end
    show do
      title "Sample summary"
      note "You analyzed #{ops.length} #{"kit".pluralize(ops.length)}. Below is the summarized data."

      results_hash = {}
      kits = ops.map {|op| op.input(INPUT).item.get(KIT_KEY)}
      samples = ops.map {|op| op.input(INPUT).item.get(SAMPLE_KEY)}
      t = Table.new
      t.add_column("Kit", kits)
      t.add_column("Sample", samples)
      MUTATIONS_LABEL.each do |label|
        col = ops.map {|op| op.temporary[:results][label][:category]}
        t.add_column(label, col)
        results_hash[label] = col
      end
      results_hash["kits"] = kits
      results_hash["samples"] = samples
      table t


      if KIT_NAME == "uw kit"
        user = User.find_by_name("Nuttada Panpradist")
        tech = get_technician_name(self.jid)
        tech = User.find(66) unless tech.is_a?(User)
        kits = ops.map {|op| op.temporary[:input_kit]}
        samples = ops.map {|op| op.temporary[:input_sample]}
        subject = "Visual call result for #{tech.name}"
        
              message = "<p>Tech: #{tech.name} (#{tech.id})</p> " \
                "<p>Operations: #{ops.map { |op| op.id } }</p> " \
                "<p>Job: #{self.jid}</p>" \
                "<p>Kits: #{kits}</p> " \
                "<p>Samples: #{samples}</p> " \
                "<p>Results: #{results_hash}</p>"
        user.send_email(subject, message) unless debug
      end
    end
  end


  def cleanup myops, area
    show do
      title "Cleanup"
      if KIT_NAME == "uw kit"
        check "Return to post-PCR space."
        image "Actions/OLA/map_Klavins.svg" if KIT_NAME == "uw kit"
      else
        check "You may now discard strips and tubes into the trash."
      end
    end

    show do
      disinfectant = "10% bleach"
      title "Wipe down #{AREA.bold} with #{disinfectant.bold}."
      note "Now you will wipe down your #{BENCH} and equipment with #{disinfectant.bold}."
      check "Spray #{disinfectant.bold} onto a #{WIPE} and clean off pipettes and pipette tip boxes."
      check "Spray a small amount of #{disinfectant.bold} on the bench surface. Clean bench with #{WIPE}."
      # check "Spray some #{disinfectant.bold} on a #{WIPE}, gently wipe down keyboard and mouse of this computer/tablet."
      warning "Do not spray #{disinfectant.bold} onto tablet or computer!"
      check "Finally, spray outside of gloves with #{disinfectant.bold}."
    end

    show do
      disinfectant = "70% ethanol"
      title "Wipe down #{AREA.bold} with #{disinfectant.bold}."
      note "Now you will wipe down your #{BENCH} and equipment with #{disinfectant.bold}."
      check "Spray #{disinfectant.bold} onto a #{WIPE} and clean off pipettes and pipette tip boxes."
      check "Spray a small amount of #{disinfectant.bold} on the bench surface. Clean bench with #{WIPE}."
    #   check "Spray a #{"small".bold} amount of #{disinfectant.bold} on a #{WIPE}. Gently wipe down keyboard and mouse of this computer/tablet."
      warning "Do not spray #{disinfectant.bold} onto tablet or computer!"
      check "Finally, dispose of gloves in garbage bin."
    end
  end
  
  def apply_clipping(section, num_sections)
      x = 100.0/num_sections
      x1 = 100 - (x * section).to_i
      x2 = (x*(section-1)).to_i
      clipping_style = ".clipimg { clip-path: inset(0% #{x1}% 0% #{x2}%); }"
      "<style>#{clipping_style}</style>"
  end

  def conclusion myops
    show do
      title "Thank you!"
      warning "<h2>You must click #{"OK".quote.bold} to complete the protocol</h2>"
      note "Thanks for your hard work!"
      note "All of your selections and steps in this protocol were tracked and saved using #{AQUARIUM.bold}. " \
            " #{AQUARIUM} uses the information from the computer/tablet and stores all of the steps and information " \
            " elsewhere on a server. We have a detailed record of each and every step for all protocols. "
      # note "You may have noticed that we are not using notebooks for any of the procedures. This is because " \
      #       " #{AQUARIUM.bold} tracks every step in the protocol providing a detailed record for all of the protocols " \
      #        " allowing researchers to go back and look at the information."

    end
  end

end
