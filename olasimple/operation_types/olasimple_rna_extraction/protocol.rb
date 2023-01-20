# frozen_string_literal: true
# Updated version: January 19, 2023
needs 'OLASimple/OLAConstants'
needs 'OLASimple/OLALib'
needs 'OLASimple/OLAGraphics'
needs 'OLASimple/JobComments'
needs 'OLASimple/OLAKitIDs'
needs 'OLASimple/RNAExtractionResources'

class Protocol
  include OLAConstants
  include OLALib
  include OLAGraphics
  include JobComments
  include OLAKitIDs
  include FunctionalSVG
  include RNAExtractionResources

  ##########################################
  # INPUT/OUTPUT
  ##########################################

  INPUT = 'Plasma'
  OUTPUT = 'Viral RNA'

  ##########################################
  # COMPONENTS
  ##########################################

  AREA = PRE_PCR
  BSC = 'BSC'
  PACK_HASH = EXTRACTION_UNIT

  THIS_UNIT     = PACK_HASH['Unit Name']
  DTT           = THIS_UNIT + PACK_HASH['Components']['dtt']                # E0
  LYSIS_BUFFER  = THIS_UNIT + PACK_HASH['Components']['lysis buffer']       # E1
  WASH1         = THIS_UNIT + PACK_HASH['Components']['wash buffer 1']      # E2
  WASH2         = THIS_UNIT + PACK_HASH['Components']['wash buffer 2']      # E3
  SA_WATER      = THIS_UNIT + PACK_HASH['Components']['sodium azide water'] # E4
  SAMPLE_COLUMN = THIS_UNIT + PACK_HASH['Components']['sample column']      # E5
  RNA_EXTRACT   = THIS_UNIT + PACK_HASH['Components']['rna extract tube']   # E6
  ETHANOL       = 'Molecular Grade Ethanol'
  GuSCN_WASTE = 'GuSCN waste container'


  SHARED_COMPONENTS = [DTT, WASH1, WASH2, SA_WATER, ETHANOL, GuSCN_WASTE].freeze
  PER_SAMPLE_COMPONENTS = [LYSIS_BUFFER, SAMPLE_COLUMN, RNA_EXTRACT].freeze
  OUTPUT_COMPONENT = '6'

  # for debugging
  PREV_COMPONENT = 'S'
  PREV_UNIT = ''

  def main
    this_package = prepare_protocol_operations

    introduction
    record_technician_id

    safety_warning(AREA)
    cynanide_warning
    required_equipment
    simple_clean('OLASimple RNA Extraction')

    retrieve_package(this_package)
    package_validation_with_multiple_tries(this_package)
    open_package(this_package)

    fill_ethanol

    prepare_lysis_buffers
    
    lyse_samples 
    remove_outer_layer
    incubate_lysed_samples(operations)
    prepare_wash_buffers
    add_ethanol

    2.times do
      operations.each { |op| add_sample_to_column(op) }
      centrifuge_columns(flow_instructions: "Discard flow through into #{GuSCN_WASTE}", speed: 8000)
      change_collection_tubes
    end
    
    add_wash_1 # E2
    centrifuge_columns(flow_instructions: "Discard flow through into #{GuSCN_WASTE}", speed: 8000)
    change_collection_tubes

    add_wash_2 # E3
    centrifuge_columns(flow_instructions: "Discard flow through into #{GuSCN_WASTE}", speed: "14000", centrifuge_time: "3 Minutes")

    2.times do
      change_collection_tubes # Added March 22 (55)
      centrifuge_columns(flow_instructions: '<b>DO NOT DISCARD FLOW THROUGH</b>', extra_warning: 'DO NOT DISCARD FLOW THROUGH', speed: 14000)
    end

    transfer_column_to_e6 # 53
    elute # 54

    incubate(sample_labels.map { |s| "#{SAMPLE_COLUMN}-#{s}" }, '1 minute')

    centrifuge_columns(flow_instructions: '<b>DO NOT DISCARD FLOW THROUGH</b>', extra_warning: 'DO NOT DISCARD FLOW THROUGH', speed: "at least 13000")

    finish_up
    disinfect
    store
    cleanup
    wash_self
    accept_comments
    conclusion(operations)
    {}
  end

  # perform initiating steps for operations,
  # and gather kit package from operations
  # that will be used for this protocol.
  # returns kit package if nothing went wrong
  def prepare_protocol_operations
    if operations.length > BATCH_SIZE
      raise "Batch size > #{BATCH_SIZE} is not supported for this protocol. Please rebatch."
    end

    operations.make.retrieve interactive: false

    if debug
      labels = %w[001 002]
      operations.each.with_index do |op, i|
        op.input(INPUT).item.associate(SAMPLE_KEY, labels[i])
        op.input(INPUT).item.associate(COMPONENT_KEY, PREV_COMPONENT)
        op.input(INPUT).item.associate(UNIT_KEY, PREV_UNIT)
        op.input(INPUT).item.associate(KIT_KEY, 'K001')
        op.input(INPUT).item.associate(PATIENT_KEY, 'a patient id')
      end
    end
    save_temporary_input_values(operations, INPUT)
    operations.each do |op|
      op.temporary[:pack_hash] = PACK_HASH
    end
    save_temporary_output_values(operations)

    operations.each do |op|
      op.make_item_and_alias(OUTPUT, 'rna extract tube', INPUT)
    end

    kits = operations.running.group_by { |op| op.temporary[:input_kit] }
    this_package = kits.keys.first + THIS_UNIT
    raise 'More than one kit is not supported by this protocol. Please rebatch.' if kits.length > 1

    this_package
  end

  def sample_labels
    operations.map { |op| op.temporary[:input_sample] }
  end

  def save_user(ops)
    ops.each do |op|
      username = get_technician_name(jid)
      op.associate(:technician, username)
    end
  end

  def introduction
    show do
      title 'Welcome to OLASimple RNA Extraction'
      note 'In this protocol you will lyse viral particles and purify RNA from HIV-infected plasma.'
    end

    show do
      title 'RNase degrades RNA'
      note 'RNA is prone to degradation by RNase present in our eyes, skin, and breath.'
      note 'Avoid opening tubes outside the Biosafety Cabinet (BSC).'
      bullet 'Change gloves whenever you suspect potential RNAse contamination'
    end

    show do
      title 'Required Reagent (not provided)'
      check 'Before starting this protocol, make sure you have access to molecular grade ethanol (5 mL, 200 proof).'
      note 'Do not use other grades of ethanol as this will negatively affect the RNA extraction yield.'
      note 'Soon, using a serological pipette, you will transfer 4ml of the molecular grade ethanol to the provided ethanol container in the kit.'
      note display_ethanol_question_svg
    end
  end

  def cynanide_warning
    show do
      title 'Review the safety warnings'
      warning '<b>TOXIC CYANIDE GAS</b>'
      note "Do not mix #{LYSIS_BUFFER} or #{WASH1} with bleach, as this can generate cyanide gas."
      note "#{LYSIS_BUFFER} AND #{WASH1} waste must be discarded into the GuSCN waste container"
      note display_guscn_waste_svg
    end
  end

  def required_equipment
    show do
      title 'You will need the following supplies in the BSC'
      materials = [
        'P1000 pipette and filter tips',
        'P200 pipette and filter tips',
        'P20 pipette and filter tips',
        'Gloves',
        'Pipette controller and 10mL serological pipette',
        'Vortex mixer',
        'Centrifuge',
        'Cold tube rack',
        '70% v/v Ethanol spray for cleaning',
        '10% v/v Bleach spray for cleaning',
        'Molecular grade ethanol'
      ]
      materials.each do |m|
        check m
      end
    end
  end

  def retrieve_package(this_package)
    show do
      title "Retrieve package"
      check "Take package #{this_package.bold} from the #{FRIDGE_PRE} and place in the #{BSC}"
    end
  end

  def open_package(this_package)
    show_open_package(this_package, '', 0) do
      img = kit_image
      check 'Check that the following are in the pack:'
      note display_svg(img, 0.75)
      note 'Arrange tubes on plastic rack for later use.'
    end
  end

  def kit_image
    grid = SVGGrid.new(PER_SAMPLE_COMPONENTS.size + SHARED_COMPONENTS.size + 1, operations.size, 80, 100)
    initial_kit_components = {
      DTT => :E6_closed, #changed from E0_closed_dry to remove bead
      LYSIS_BUFFER => :E1_closed,
      SA_WATER => :E4_closed,
      WASH1 => :E2_closed,
      WASH2 => :E3_closed,
      SAMPLE_COLUMN => :E5_empty_closed_w_empty_collector,
      RNA_EXTRACT => :E6_closed,
      ETHANOL => :ethanol_container,
      GuSCN_WASTE => :guscn_container
    }

    SHARED_COMPONENTS.each_with_index do |component, i|
      svg_label = component != ETHANOL && component != GuSCN_WASTE ? component : ''
      svg = draw_svg(initial_kit_components[component], svg_label: svg_label)
      grid.add(svg, i, 0)
    end

    operations.each_with_index do |op, i|
      sample_num = op.temporary[:output_sample]
      PER_SAMPLE_COMPONENTS.each_with_index do |component, j|
        svg = draw_svg(initial_kit_components[component], svg_label: "#{component}\n#{sample_num}")
        svg.translate!(30 * (i % 2), 0)
        grid.add(svg, j + SHARED_COMPONENTS.size, i)
      end
    end

    grid.add(many_collection_tubes(6), PER_SAMPLE_COMPONENTS.size + SHARED_COMPONENTS.size, 0)

    grid.align!('center-left')
    SVGElement.new(children: [grid], boundx: 1000, boundy: 300).translate!(30, 50)
  end

  def retrieve_inputs
    input_sample_ids = operations.map do |op|
      op.input_ref(INPUT)
    end

    grid = SVGGrid.new(input_sample_ids.size, 1, 80, 100)
    input_sample_ids.each_with_index do |s, i|
      svg = draw_svg(:sXXX_closed, svg_label: s.split('-').join("\n"), opened: false, contents: 'full')
      grid.add(svg, i, 0)
    end

    img = SVGElement.new(children: [grid], boundx: 1000, boundy: 200).translate!(0, -30)
    show do
      title 'Retrieve Samples'
      note display_svg(img, 0.75)
      check "Take #{input_sample_ids.to_sentence} from #{FRIDGE_PRE}"
    end
  end

  def fill_ethanol
    svg = SVGElement.new(children: [ethanol_container_open], boundx: 400, boundy: 200)
    show do
      title 'Transfer 4mL of Molecular grade ethanol to Provided Container'
      check 'Use a serological pipette to transfer <b>4ml</b> of <b>Molecular Grade Ethanol</b> into provided container.'
      note display_svg(svg)
      check 'Return the Molecular grade ethanol to the flammable cabinet.'
    end
  end

  # helper method for simple transfers in this protocol
  def transfer_and_vortex(title, from, to, volume_ul, warning: nil, to_svg: nil, from_svg: nil, skip_vortex: false, skip_centrifuge: false, extra_check: nil, vortex_note: nil, centrifuge_note: nil, vortex_time: 2)

    pipette, extra_note, setting_instruction = pipette_decision(volume_ul)
   # pipette, extra_note, setting_instruction = "P20", nil, "Set P20 pipette to [0 5 6]"  
    
    if to.is_a?(Array) # MULTI TRANSFER
      img = nil
      if from_svg && to_svg
        from_component, from_sample_num = from.split('-')
        from_label = from_component != ETHANOL && from_component != GuSCN_WASTE ? from.split('-').join("\n") : ''
        from_svg_rendered = draw_svg(from_svg, svg_label: from_label)
        to_labels = to.map { |t| t.split('-').join("\n") }
        to_svgs_rendered = to_labels.map.with_index { |to_label, i| draw_svg(to_svg, svg_label: to_label).translate!(130 * i, 0) }
        to_svg_final = SVGElement.new(children: to_svgs_rendered, boundx: 300, boundy: 220)
        img = make_transfer(from_svg_rendered, to_svg_final, 300, "#{volume_ul}ul", "(#{pipette})")
      end
      show do
        title title
        check setting_instruction
        to.each do |t|
          check "Transfer <b>#{volume_ul}uL</b> of <b>#{from}</b> into <b>#{t}</b> using a #{pipette} pipette."
          note extra_note if extra_note
          check "Discard pipette tip into #{WASTE_PRE}."
          check extra_check if extra_check
        end
        warning warning if warning
        note display_svg(img, 0.75) if img
        check "Ensure tube caps are tightly shut for #{to.to_sentence}."
        check "Vortex <b>#{to.to_sentence}</b> for <b>#{vortex_time} seconds, twice</b>." unless skip_vortex
        check "Centrifuge <b>#{to.to_sentence}</b> for <b>5 seconds</b>." unless skip_centrifuge
        check vortex_note
        check centrifuge_note
      end
    else # SINGLE TRANSFER
      from_component, from_sample_num = from.split('-')
      to_component, to_sample_num = to.split('-')
      if from_svg && to_svg
        from_label = from_component != ETHANOL && from_component != GuSCN_WASTE ? [from_component, from_sample_num].join("\n") : ''
        from_svg = draw_svg(from_svg, svg_label: from_label)
        to_label = to_component != ETHANOL && to_component != GuSCN_WASTE ? [to_component, to_sample_num].join("\n") : ''
        to_svg = draw_svg(to_svg, svg_label: to_label)
        img = make_transfer(from_svg, to_svg, 300, "#{volume_ul}ul", "(#{pipette})")
      end

      show do
        title title
        check setting_instruction
        check "Transfer <b>#{volume_ul}uL</b> of <b>#{from}</b> into <b>#{to}</b> using a #{pipette} pipette."
        note extra_note if extra_note
        warning warning if warning
        note display_svg(img, 0.75) if img
        check "Discard pipette tip into #{WASTE_PRE}."
        check extra_check if extra_check
        check "Ensure tube cap is tightly shut for #{to}."
        check "Vortex <b>#{to}</b> for <b>#{vortex_time} seconds, twice</b>." unless skip_vortex
        check "Centrifuge <b>#{to}</b> for <b>5 seconds</b>." unless skip_centrifuge
        check vortex_note
        check centrifuge_note
      end
    end
  end

  def pipette_decision(volume_ul)
    if volume_ul <= 20
      setting = '[ ' + (volume_ul * 10).round.to_s.rjust(3, '0').split('').join(' ') + ' ]'
      [P20_PRE, nil, "Set P20 pipette to <b>#{volume_ul} uL</b>"]
    elsif volume_ul <= 200
      setting = '[ ' + volume_ul.round.to_s.rjust(3, '0').split('').join(' ') + ' ]'
      [P200_PRE, nil, "Set p200 pipette to <b>#{volume_ul} uL</b>"]
    elsif volume_ul <= 1000
      setting = '[ ' + (volume_ul / 10).round.to_s.rjust(3, '0').split('').join(' ') + ' ]'
      [P1000_PRE, nil, "Set p1000 pipette to <b>#{volume_ul} uL</b>"]
    else
      factor = volume_ul.fdiv(1000).ceil
      split_volume = volume_ul.fdiv(factor)
      setting = '[ ' + (split_volume / 10).round.to_s.rjust(3, '0').split('').join(' ') + ' ]'
      [P1000_PRE, "Transfer <b>#{split_volume.round}uL</b>, <b>#{factor} times</b>.", "Set p1000 pipette to <b>#{setting}</b>"]
    end
  end

  # helper method for simple incubations
  def incubate(samples, time)
    show do
      title 'Incubate E1 Tubes to ensure full RNA recovery.'
      note "Let <b>#{samples.to_sentence}</b> incubate for <b>#{time}</b> at room temperature."
      check "Set a timer for <b>#{time}</b>"
      note 'Do not proceed until time has elapsed.'
    end
  end

  def centrifuge_columns(flow_instructions: nil, extra_warning: nil, speed: nil, centrifuge_time: "1 Minute")
    columns = sample_labels.map { |s| "#{SAMPLE_COLUMN}-#{s}" }

    show do
      title " Centrifuge Columns for #{centrifuge_time}"
      warning extra_warning if extra_warning
      warning 'Ensure both tube caps are tightly closed'
      if speed
        note "Set centrifuge to #{speed} RPM"
      end
      raw centrifuge_proc('Column', columns, centrifuge_time, '', AREA)
      note display_balance_tubes_svg
      check flow_instructions if flow_instructions
    end
  end

  def prepare_lysis_buffers
    show do
      title "Centrifuge the following:" # E0 and E4
      check "Centrifuge <b>#{DTT}</b> and <b>#{WASH1}</b> for <b>5 seconds</b>." # E0 and E2
      check "Centrifuge <b>E1-001</b> and <b>E1-002</b> for 5 seconds"
      check "Centrifuge <b>#{WASH2}</b> and <b>#{SA_WATER}</b> for <b>5 seconds</b>." #E3 and E4
    end

    lysis_buffers = operations.map { |op| "#{LYSIS_BUFFER}-#{op.temporary[:output_sample]}" }
 
    transfer_and_vortex(
      "Prepare Lysis Buffers #{lysis_buffers.to_sentence}",
      DTT, #E0
      lysis_buffers,
      5.6,
      from_svg: :E0_open_wet,
      to_svg: :E1_open,
    #   skip_centrifuge: true
        skip_centrifuge: false
    )
  end # prepare_lysis_buffers

   def prepare_wash_buffers
#   prepare wash buffer 2 with ethanol
      transfer_and_vortex(
        "Prepare Buffers #{WASH1} and #{WASH2}", # E2 and E3
        ETHANOL,
        WASH1, # E2
        680,
        from_svg: :ethanol_container_open,
        to_svg: :E3_open,
        skip_vortex: true,
        skip_centrifuge: true
      )
    
      transfer_and_vortex(
        "Prepare #{WASH2}", # E3
        ETHANOL,
        WASH2,
        840,
        from_svg: :ethanol_container_open,
        to_svg: :E3_open,
        skip_vortex: true,
        skip_centrifuge: true,
        vortex_note: "Vortex <b>#{WASH1}</b> and <b>#{WASH2}</b> for 2 seconds, twice",
        centrifuge_note: "Centrifuge <b>#{WASH1}</b> and <b>#{WASH2}</b> for 5 seconds"
      )
  end

  SAMPLE_VOLUME = 140 
  # transfer plasma Samples into lysis buffer and incubate
  def lyse_samples
    operations.each do |op|
      from_name = op.input_ref(INPUT).to_s
      to_name = "#{LYSIS_BUFFER}-#{op.temporary[:output_sample]}"
      from_svg = draw_svg(:sXXX_closed, svg_label: op.input_ref(INPUT).to_s.sub('-', "\n"))
      to_svg = draw_svg(:E1_closed, svg_label: "#{LYSIS_BUFFER}\n#{op.temporary[:output_sample]}")
      pre_transfer_validation_with_multiple_tries(from_name, to_name, from_svg, to_svg)
      transfer_and_vortex(
        "Lyse Sample #{op.input_ref(INPUT)}",
        op.input_ref(INPUT).to_s,
        "#{LYSIS_BUFFER}-#{op.temporary[:output_sample]}",
        SAMPLE_VOLUME,
        from_svg: :sXXX_open,
        to_svg: :E1_open,
        skip_centrifuge: true,
        vortex_time: 5,
        extra_check: "Close #{from_name} tightly and discard into #{WASTE_PRE}."
      )
    end
  end

  def incubate_lysed_samples(ops)
    lysed_samples = ops.map { |op| "#{LYSIS_BUFFER}-#{op.temporary[:output_sample]}" }
    incubate(lysed_samples, '10 minutes')
  end

  ETHANOL_BUFFER_VOLUME = 560 
  def add_ethanol
    lysis_buffers = operations.map { |op| "#{LYSIS_BUFFER}-#{op.temporary[:output_sample]}" }
    transfer_and_vortex(
      "Add #{ETHANOL} to samples #{lysis_buffers.to_sentence}",
      ETHANOL,
      lysis_buffers,
      ETHANOL_BUFFER_VOLUME,
      from_svg: :ethanol_container_open,
      to_svg: :E1_open,
      skip_centrifuge: false,
      vortex_time: 5
    )
  end

  COLUMN_VOLUME = 630 
  def add_sample_to_column(op)
    from = "#{LYSIS_BUFFER}-#{op.temporary[:output_sample]}"
    to = "#{SAMPLE_COLUMN}-#{op.temporary[:output_sample]}"
    from_svg = draw_svg(:E1_closed, svg_label: from.sub('-', "\n"))
    to_svg = draw_svg(:E5_empty_closed_w_empty_collector, svg_label: to.sub('-', "\n"))
    pre_transfer_validation_with_multiple_tries(from, to, from_svg, to_svg)
    transfer_carefully(from, to, COLUMN_VOLUME, from_type: 'sample', to_type: 'column', from_svg: :E1_open, to_svg: :E5_full_open_w_empty_collector)
  end

  def change_collection_tubes
    sample_columns = operations.map { |op| "#{SAMPLE_COLUMN}-#{op.temporary[:output_sample]}" }
    from_svgs_rendered = sample_columns.map.with_index { |from_label, i| draw_svg(:E5_empty_closed_w_empty_collector, svg_label: from_label.sub('-', "\n")).translate!(80 * i, 0) }
    from_svg_final = SVGElement.new(children: from_svgs_rendered, boundx: 150, boundy: 200)
    img = make_transfer(from_svg_final, many_collection_tubes(sample_columns.size), 300, '', '(Change Tubes)')
    show do
      title 'Change Collection Tubes'
      note display_svg(img, 0.8)
      sample_columns.each do |column|
        check "Transfer <b>#{column}</b> to new collection tubes."
      end
      note 'Discard previous collection tubes.'
    end
  end

  def add_wash_1 #E2
    columns = operations.map { |op| column = "#{SAMPLE_COLUMN}-#{op.temporary[:output_sample]}" }
    transfer_carefully(WASH1, columns, 500, from_type: 'Wash Buffer E2', to_type: 'column', from_svg: :E2_open, to_svg: :E5_full_open_w_empty_collector)
  end

  def add_wash_2 #E3
    columns = operations.map { |op| column = "#{SAMPLE_COLUMN}-#{op.temporary[:output_sample]}" }
    transfer_carefully(WASH2, columns, 500, from_type: 'Wash Buffer E3', to_type: 'column', from_svg: :E3_open, to_svg: :E5_full_open_w_empty_collector)
  end

  def transfer_carefully(from, to, volume_ul, from_type:, to_type:, from_svg: nil, to_svg: nil)
    pipette, extra_note, setting_instruction = pipette_decision(volume_ul)
    if to.is_a?(Array) # MULTI TRANSFER
      img = nil
      if from_svg && to_svg
        from_label = from.split('-').join("\n")
        from_svg_rendered = draw_svg(from_svg, svg_label: from_label)
        to_labels = to.map { |t| t.split('-').join("\n") }
        to_svgs_rendered = to_labels.map.with_index { |to_label, i| draw_svg(to_svg, svg_label: to_label).translate!(80 * i, 0) }
        to_svg_final = SVGElement.new(children: to_svgs_rendered, boundx: 300, boundy: 300)
        img = make_transfer(from_svg_rendered, to_svg_final, 300, "#{volume_ul}ul", "(#{pipette})")
      end
      show do
        title "Add #{from_type || from} to each #{to_type + ' ' + to.to_sentence || to}"
        check setting_instruction
        note "<b>Carefully</b> open #{to_type.pluralize(to)} <b>#{to.to_sentence}</b> lid."
        to.each do |t|
          check "<b>Carefully</b> Add <b>#{volume_ul}uL</b> of #{from_type} <b>#{from}</b> to <b>#{t}</b> using a #{pipette} pipette."
          check 'Discard pipette tip.'
        end
        note extra_note if extra_note
        note display_svg(img, 0.75) if img
        note "<b>Slowly</b> close lid of <b>#{to.to_sentence}</b>"
      end
    else # SINGLE TRANSFER
      img = nil
      if from_svg && to_svg
        from_label = from.split('-').join("\n")
        from_svg_rendered = draw_svg(from_svg, svg_label: from_label)
        to_label = to.split('-').join("\n")
        to_svg_rendered = draw_svg(to_svg, svg_label: to_label)
        img = make_transfer(from_svg_rendered, to_svg_rendered, 300, "#{volume_ul}ul", "(#{pipette})")
      end
      show do
        title "Add #{from_type || from} to #{to_type + ' ' + to || to}"
        check setting_instruction
        note "<b>Carefully</b> open #{to_type} <b>#{to}</b> lid."
        check "<b>Carefully</b> Add <b>#{volume_ul}uL</b> of #{from_type} <b>#{from}</b> to <b>#{to}</b> using a #{pipette} pipette."
        note extra_note if extra_note
        note display_svg(img, 0.75) if img
        check 'Discard pipette tip.'
        note "<b>Slowly</b> close lid of <b>#{to}</b>"
      end
    end
  end

  def transfer_column_to_e6
    show do
      title 'Transfer E5 Columns to E6 Clean Tubes'
      warning 'Make sure the bottom of the E5 columns did not touch any fluid from the previous collection tubes. When in doubt, centrifuge the tube for 1 more minute.'
      note display_pre_elution_warning
      operations.each do |op|
        column = "#{SAMPLE_COLUMN}-#{op.temporary[:output_sample]}"
        extract_tube = "#{RNA_EXTRACT}-#{op.temporary[:output_sample]}"
        check "Transfer column <b>#{column}</b> to <b>#{extract_tube}</b>"
      end
    end
  end

  def elute
    show do
      title 'Add Elution Buffer'
      warning 'Add buffer to center of columns'
      # Need to change this so it says to use E6-001 and E6-002
      columns = operations.map { |op| column = "#{SAMPLE_COLUMN}-#{op.temporary[:output_sample]}" }
      note display_elution_addition
      columns.each do |column|
        check "Add <b>50uL</b> from <b>#{SA_WATER}</b> to column <b>#{column}</b>"
      end
      check 'Close lid on column tightly.'
    end
  end

  def finish_up
    show do
      title 'Prepare Samples for Storage'
      operations.each do |op|
        column = "#{SAMPLE_COLUMN}-#{op.temporary[:output_sample]}"
        extract_tube = "#{RNA_EXTRACT}-#{op.temporary[:output_sample]}"
        check "Remove column <b>#{column}</b> from <b>#{extract_tube}</b>, and discard <b>#{column} in #{WASTE_PRE}</b>"
      end
      extract_tubes = sample_labels.map { |s| "#{RNA_EXTRACT}-#{s}" }
      check "Ensure lids are firmly closed for all of #{extract_tubes.to_sentence}."
      check "Place <b>#{extract_tubes.to_sentence}</b> on cold rack"
    end
  end

  def store
    show do
      title 'Store Items'
      extract_tubes = sample_labels.map { |s| "#{RNA_EXTRACT}-#{s}" }
      note "Store <b>#{extract_tubes.to_sentence}</b> in the fridge on a cold rack if the amplification module will proceed immediately."
      note "Store <b>#{extract_tubes.to_sentence}</b> in -80C freezer if proceeding with the amplification module later."
    end
  end

  def cleanup
    show do
      title 'Clean up Waste'
      warning "DO NOT dispose of liquid waste and bleach into #{GuSCN_WASTE}, this can produce dangerous gas."
      bullet 'Dispose of liquid waste in bleach down the sink with running water.'
      bullet "Dispose of remaining tubes into #{WASTE_PRE}."
      bullet "Dispose of #{GuSCN_WASTE} in the manner that you are trained to."
    end

    show do
      title 'Clean Biosafety Cabinet (BSC)'
      note 'Place items in the BSC off to the side.'
      note 'Spray surface of BSC with 10% bleach. Wipe clean using paper towel.'
      note 'Spray surface of BSC with 70% ethanol. Wipe clean using paper towel.'
      note "After cleaning, dispose of gloves and paper towels in #{WASTE_PRE}."
    end
  end

  def conclusion(_myops)
    show do
      title 'Thank you!'
      note 'Press the OK button in the upper right hand corner to finish this protocol.'
      note 'You may start the next protocol immediately, or you may take a short break and come back.'
    end
  end

  def remove_outer_layer
    show do
      title 'Remove outer Layer of Gloves'
      check "Remove outer layer of gloves and discard them into #{WASTE_PRE}"
    end
  end
end
