# frozen_string_literal: true

# Sample Preparation Updated January 19, 2023
#
needs 'OLASimple/OLAConstants'
needs 'OLASimple/OLAKitIDs'
needs 'OLASimple/OLAGraphics'
needs 'OLASimple/SVGGraphics'
needs 'OLASimple/OLALib'
needs 'OLASimple/JobComments'

class Protocol
  include OLALib
  include OLAGraphics
  include FunctionalSVG
  include OLAKitIDs
  include OLAConstants
  include JobComments

  AREA = PRE_PCR

  OUTPUT = 'Patient Sample'
  PATIENT_ID_INPUT = 'Patient Sample Identifier'
  KIT_ID_INPUT = 'Kit Identifier'

  UNIT = 'S'
  OUTPUT_COMPONENT = ''
  PLASMA_LOCATION = '-80 freezer'
  SAMPLE_VOLUME = 140 

  def main
    operations.make
    operations.each_with_index do |op, i|
      if debug
        op.temporary[OLAConstants::PATIENT_KEY] = "patientid#{i}"
        op.temporary[OLAConstants::KIT_KEY] = 'K001'
      else
        op.temporary[OLAConstants::PATIENT_KEY] = op.input(PATIENT_ID_INPUT).value
        op.temporary[OLAConstants::KIT_KEY] = op.input(KIT_ID_INPUT).value
      end
    end

    kit_groups = operations.group_by { |op| op.temporary[OLAConstants::KIT_KEY] }

    introduction
    record_technician_id
    safety_warning(AREA)
    required_equipment
    clean_area(AREA)

    kit_groups.each do |kit_num, ops|
      next unless check_batch_size(ops)

      first_module_setup(ops, kit_num)
      set_output_components_and_units(ops, OUTPUT, OUTPUT_COMPONENT, UNIT)

      this_package = "#{kit_num}#{UNIT}"
      retrieve_package(this_package)
      package_validation_with_multiple_tries(this_package)
      open_package(this_package, ops)
      retrieve_plasma(ops)
      _, expected_plasma_samples = plasma_tubes(ops)
      sample_validation_with_multiple_tries(expected_plasma_samples)
      wait_for_thaw
      transfer_plasma(ops)
      remove_outer_layer
      disinfect
      store(ops)
    end
    accept_comments
    conclusion(operations)
    {}
  end

  # Since this is the first protocol in the workflow, we
  # pause here to link the incoming patient ids to the kit sample numbers
  # in a coherent and deterministic way.
  #
  # Makes the assumptions that all operations here are from the same kit
  # with output items made, and have a suitable batch size
  def first_module_setup(ops, kit_num)
    check_batch_size(ops)
    assign_sample_aliases_from_kit_id(ops, kit_num)

    data_associations = []
    ops.each do |op|
      output_item = op.output(OUTPUT).item
      data_associations << output_item.associate(OLAConstants::KIT_KEY, op.temporary[OLAConstants::KIT_KEY])
      data_associations << output_item.associate(OLAConstants::SAMPLE_KEY, op.temporary[OLAConstants::SAMPLE_KEY])
      data_associations << output_item.associate(OLAConstants::PATIENT_KEY, op.temporary[OLAConstants::PATIENT_KEY])
    end

    DataAssociation.import data_associations, on_duplicate_key_update: [:object]
  end

  # Assigns sample aliases in order of patient id. each operation must have op.temporary[:patient] set.
  # Sample alias assignment is placed in op.temporary[:sample_num] for each op.
  #
  # requires that "operations" input only contains operations from a single kit
  def assign_sample_aliases_from_kit_id(operations, kit_id)
    operations = operations.sort_by { |op| op.temporary[OLAConstants::PATIENT_KEY] }
    sample_nums = sample_nums_from_kit_num(extract_kit_number(kit_id))
    operations.each_with_index do |op, i|
      op.temporary[OLAConstants::SAMPLE_KEY] = sample_num_to_id(sample_nums[i])
    end
  end

  def check_batch_size(ops)
    if ops.size > OLAConstants::BATCH_SIZE
      ops.each do |op|
        op.error(:batch_size_too_big, "operations.size operations batched with #{kit_num}, but max batch size is #{BATCH_SIZE}.")
      end
      false
    else
      true
    end
  end

  def introduction
    show do
      title 'Welcome to OLASimple Sample Preparation'
      note 'In this protocol you will transfer a specific volume of patient plasma into barcoded sample tubes.'
    end
  end

  def required_equipment
    show do
      title 'You will need the following supplies in the BSC'
      materials = [
        'P200 pipette and filter tips',
        'P20 pipette and filter tips',
        'Pipette controller and 10mL serological pipette',
        'gloves',
        'Vortex mixer',
        'Centrifuge',
        'Cold tube rack',
        '70% v/v Ethanol spray for cleaning',
        '10% v/v Bleach spray for cleaning',
        'Molecular grade ethanol',
        'Biohazard Waste Container'
      ]
      materials.each do |m|
        check m
      end
    end
  end

  def retrieve_package(this_package)
    show do
      title "Retrieve Package #{this_package.bold}"
      check "Take #{this_package} from the #{FRIDGE_PRE} and place inside the BSC with a Paper Towel"
    end
  end

  def open_package(this_package, ops)
    show_open_package(this_package, '', 0) do
      img = kit_image(ops)
      check 'Check that the following are in the pack:'
      note display_svg(img, 0.75)
      check 'Discard the packaging material.'
    end
  end

  def kit_image(ops)
    tubes, = kit_tubes(ops)
    grid = SVGGrid.new(tubes.size, 1, 80, 100)
    tubes.each_with_index do |svg, i|
      grid.add(svg, i, 0)
    end
    SVGElement.new(children: [grid], boundx: 1000, boundy: 300)
  end

  def retrieve_plasma(ops)
    tubes, plasma_ids = plasma_tubes(ops)
    grid = SVGGrid.new(tubes.size, 1, 250, 100)
    tubes.each_with_index do |svg, i|
      grid.add(svg, i, 0)
    end
    img = SVGElement.new(children: [grid], boundx: 1000, boundy: 300).translate(100, 0)
    show do
      title 'Retrieve Plasma samples'
      note "Retrieve plasma samples labeled #{plasma_ids.to_sentence.bold}."
      note "Patient samples are located in the #{PLASMA_LOCATION.bold}."
      note display_svg(img, 0.75)
    end
  end

  def wait_for_thaw
    show do
      title 'Wait for Plasma to thaw'
      note 'Let plasma sit at room temperature to thaw for 5 minutes.'
      check 'Set a timer.'
      note 'Built in timer is available in the top left.'
      note 'Plasma should be completely thawed and mixed before pipetting to ensure concentration of virus is homogeneous.'
    end
  end

  def transfer_plasma(ops)
    from_tubes_open, from_names = plasma_tubes_opened(ops)
    to_tubes_open, to_names = kit_tubes_opened(ops)
    from_tubes, from_names = plasma_tubes(ops)
    to_tubes, to_names = kit_tubes(ops)
    ops.each_with_index do |_op, i|
      pre_transfer_validation_with_multiple_tries(from_names[i], to_names[i], from_tubes[i], to_tubes[i])
      transfer_img = make_transfer(from_tubes_open[i], to_tubes_open[i], 250, "#{SAMPLE_VOLUME}ul", "(#{P200_PRE})").translate(100, 0)
      show do
        title "Transfer #{from_names[i]} to #{to_names[i]}"
        note "Use a #{P200_PRE} pipette and set it to <b>[1 4 0]</b>."
        check "Transfer <b>#{SAMPLE_VOLUME}uL</b> from <b>#{from_names[i]}</b> to <b>#{to_names[i]}</b> using a #{P200_PRE} pipette."
        note display_svg(transfer_img, 0.75)
        check "Discard pipette tip into #{WASTE_PRE} to reduce chance of contamination."
        check "Close both tubes."
      end
    end
  end
  
  def remove_outer_layer
    show do
      title 'Remove outer Layer of Gloves'
      check "Remove outer layer of gloves and discard them into #{WASTE_PRE}"
    end
  end

  def store(ops)
    show do
      title 'Store Items'
      sample_tubes = sample_labels.map { |s| "#{UNIT}-#{s}" }
      _, plasma_tube_names = plasma_tubes(ops)
      check "If you won't be moving to the next step until tomorrow, return #{plasma_tube_names.to_sentence} to #{PLASMA_LOCATION}."
      note "Leave <b>#{sample_tubes.to_sentence}</b> in the BSC for immediate continuation."
    end
  end

  def cleanup
    show do
      title 'Clean Biosafety Cabinet (BSC)'
      note 'Place items in the BSC off to the side.'
      note 'Spray surface of BSC with 10% bleach. Wipe clean using paper towel.'
      note 'Spray surface of BSC with 70% ethanol. Wipe clean using paper towel.'
    end
  end

  def conclusion(_myops)
    show do
      title 'Thank you!'
      note 'Press the OK button in the Upper Right Corner to finish this Protocol.'
      note 'You will start the next protocol immediately.'
    end
  end

  def kit_tubes(ops)
    tube_names = ops.map { |op| "#{UNIT}-#{op.temporary[OLAConstants::SAMPLE_KEY]}" }
    tubes = []
    tube_names.each_with_index do |s, _i|
      tubes << draw_svg(:empty_sxx, svg_label: s.split('-').join("\n"), svg_label_initial_offset: -25)
    end
    [tubes, tube_names]
  end

  def plasma_tubes(ops)
    plasma_ids = ops.map { |op| op.temporary[OLAConstants::PATIENT_KEY] }
    tubes = []
    plasma_ids.each_with_index do |s, _i|
      tubes << draw_svg(:plasma_sample_closed, svg_label: "\n\n\n\n\n" + s)
    end
    [tubes, plasma_ids]
  end

  def kit_tubes_opened(ops)
    tube_names = ops.map { |op| "#{UNIT}-#{op.temporary[OLAConstants::SAMPLE_KEY]}" }
    tubes = []
    tube_names.each_with_index do |s, _i|
      tubes << draw_svg(:empty_sxx_opened, svg_label: s.split('-').join("\n"))
    end
    [tubes, tube_names]
  end

  def plasma_tubes_opened(ops)
    plasma_ids = ops.map { |op| op.temporary[OLAConstants::PATIENT_KEY] }
    tubes = []
    plasma_ids.each_with_index do |s, _i|
      tubes << draw_svg(:plasma_sample_opened, svg_label: "\n\n\n\n" + s)
    end
    [tubes, plasma_ids]
  end

  def sample_labels
    operations.map { |op| op.temporary[OLAConstants::SAMPLE_KEY] }
  end

  def empty_sxx
    tube(opened: false)
  end

  def empty_sxx_opened
    tube(opened: true)
  end

  def plasma_sample_closed
    svg_from_html(
      '<svg><defs><style>.cls-1{fill:#efe7a3;}.cls-2,.cls-3{fill:none;}.cls-3,.cls-4{stroke:#231f20;stroke-miterlimit:10;stroke-width:0.5px;}.cls-4{fill:#fff;}</style></defs><title>Plasma_tube_closed_lid</title><path class="cls-1" d="M386.8,334.93a13.86,13.86,0,0,1-13.24-2v45a12,12,0,0,0,12,12h19.85a12,12,0,0,0,12-12V309.32C405.29,313.67,397.2,331.15,386.8,334.93Z" transform="translate(-373.31 -222.24)"/><path class="cls-2" d="M376.55,250.87" transform="translate(-373.31 -222.24)"/><path class="cls-3" d="M8.85,35.78H35.5a8.6,8.6,0,0,1,8.6,8.6v111a12,12,0,0,1-12,12H12.25a12,12,0,0,1-12-12v-111a8.6,8.6,0,0,1,8.6-8.6Z"/><path class="cls-4" d="M395.48,222.49c-12.11,0-21.93,3-21.93,6.74v28.22c0,3.72,9.82,6.74,21.93,6.74s21.93-3,21.93-6.74V229.23C417.41,225.51,407.59,222.49,395.48,222.49Z" transform="translate(-373.31 -222.24)"/><ellipse class="cls-4" cx="22.18" cy="6.87" rx="16.97" ry="4.01"/><line class="cls-3" x1="4.12" y1="12.2" x2="4.12" y2="35.31"/><line class="cls-3" x1="22.97" y1="16" x2="22.97" y2="39.11"/><line class="cls-3" x1="41.55" y1="10.88" x2="41.55" y2="33.99"/><line class="cls-3" x1="32.79" y1="14.89" x2="32.79" y2="38"/><line class="cls-3" x1="13.15" y1="14.89" x2="13.15" y2="38"/></svg>'
    ).translate!(0,70)
  end

  def plasma_sample_opened
    svg_from_html(
      '<svg><defs><style>.cls-1{fill:#efe7a3;}.cls-2,.cls-3{fill:none;}.cls-2,.cls-4{stroke:#010101;stroke-miterlimit:10;stroke-width:0.5px;}.cls-4{fill:#fff;}</style></defs><title>Plasma_tube_open_lid</title><path class="cls-1" d="M359.1,326.3a13.89,13.89,0,0,1-13.2-2v45a12,12,0,0,0,12,12h19.9a12,12,0,0,0,12-12V300.7C377.6,305.1,369.5,322.5,359.1,326.3Z" transform="translate(-345.45 -230.85)"/><path class="cls-2" d="M384,249.9V237c0-3.3-7.3-5.9-16.3-5.9s-16.3,2.7-16.3,5.9v12.9a8.68,8.68,0,0,0-5.7,8.1V369a12,12,0,0,0,12,12h19.9a12,12,0,0,0,12-12V258A8.55,8.55,0,0,0,384,249.9Z" transform="translate(-345.45 -230.85)"/><path class="cls-3" d="M348.8,242.2" transform="translate(-345.45 -230.85)"/><path class="cls-4" d="M423.4,340.1c-12.1,0-21.9,3-21.9,6.7V375c0,3.7,9.8,6.7,21.9,6.7s21.9-3,21.9-6.7V346.8C445.3,343.1,435.5,340.1,423.4,340.1Z" transform="translate(-345.45 -230.85)"/><ellipse class="cls-4" cx="77.95" cy="115.85" rx="17" ry="4"/><line class="cls-2" x1="59.95" y1="121.15" x2="59.95" y2="144.25"/><line class="cls-2" x1="78.75" y1="124.95" x2="78.75" y2="148.05"/><line class="cls-2" x1="97.35" y1="119.85" x2="97.35" y2="142.95"/><line class="cls-2" x1="88.55" y1="123.85" x2="88.55" y2="146.95"/><line class="cls-2" x1="68.95" y1="123.85" x2="68.95" y2="146.95"/><ellipse class="cls-4" cx="22.35" cy="6.05" rx="12.6" ry="3.5"/></svg>',
      100
    ).translate!(0,70)
  end

  def tube(opened: false, contents: 'empty')
    tube = SVGElement.new(boundx: 46.92, boundy: 140)
    
    if contents == 'empty' && !opened
      tube.add_child(
        '<svg><defs><style>.cls-1_tube{fill:#fff;}.cls-1_tube,.cls-2_tube{stroke:#231f20;stroke-miterlimit:10;stroke-width:0.5px;}.cls-2_tube{fill:none;}</style></defs><rect class="cls-1_tube" x="5.5" y="2.53" width="33.11" height="9.82" rx="2.36" ry="2.36"/><rect class="cls-1_tube" x="0.25" y="0.25" width="42.88" height="7.39" rx="2.36" ry="2.36"/><path class="cls-2_tube" d="M411.36,243.86" transform="translate(-371.69 -233.08)"/><path class="cls-2_tube" d="M412,245.43a3.88,3.88,0,0,0,3.29-2.79,4.85,4.85,0,0,0-.42-4.28" transform="translate(-371.69 -233.08)"/><path class="cls-2_tube" d="M412,247.27a6,6,0,0,0,6.16-4.86,5.79,5.79,0,0,0-3.17-7" transform="translate(-371.69 -233.08)"/><rect class="cls-1_tube" x="0.53" y="11.4" width="42.32" height="4.79" rx="2.4" ry="2.4"/><path class="cls-2_tube" d="M374.62,249.27V304.5l11.32,68c.8,4.79,4.61,5.75,7.86,5.09s4.39-5.33,4.39-5.33l13.16-67.79V249.27Z" transform="translate(-371.69 -233.08)"/></svg>'
        )
    elsif contents == 'empty' && opened
      tube.add_child(
        '<svg><defs><style>.cls-1_tube{fill:none;}.cls-1_tube,.cls-2_tube{stroke:#231f20;stroke-miterlimit:10;stroke-width:0.5px;}.cls-2_tube{fill:#fff;}</style></defs><title>Untitled-1</title><path class="cls-1_tube" d="M410.51,263.07" transform="translate(-371.13 -215.85)"/><path class="cls-1_tube" d="M411.12,264.64a3.88,3.88,0,0,0,3.29-2.79,4.85,4.85,0,0,0-.42-4.28" transform="translate(-371.13 -215.85)"/><path class="cls-1_tube" d="M411.12,266.47a6,6,0,0,0,6.16-4.86,5.79,5.79,0,0,0-3.17-7" transform="translate(-371.13 -215.85)"/><rect class="cls-2_tube" x="0.25" y="47.83" width="42.32" height="4.79" rx="2.4" ry="2.4"/><path class="cls-1_tube" d="M373.78,268.47V323.7l11.32,68c.8,4.79,4.61,5.75,7.86,5.09s4.39-5.33,4.39-5.33l13.16-67.79V268.47Z" transform="translate(-371.13 -215.85)"/><rect class="cls-2_tube" x="394.99" y="233.39" width="33.11" height="9.82" rx="2.36" ry="2.36" transform="translate(236.03 -411.02) rotate(84.22)"/><rect class="cls-2_tube" x="393.55" y="233.89" width="42.88" height="7.39" rx="2.36" ry="2.36" transform="translate(238.41 -415.09) rotate(84.22)"/></svg>'
        )
    end
    tube.translate!(0,70)
  end
end
