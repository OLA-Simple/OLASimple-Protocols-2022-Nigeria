# frozen_string_literal: true

#
#
# OLASimple PCR
# author: Justin Vrana
# date: March 2018
# 
#
##########################################

needs 'OLASimple/OLAConstants'
needs 'OLASimple/OLALib'
needs 'OLASimple/OLAGraphics'
needs 'OLASimple/JobComments'
needs 'OLASimple/OLAKitIDs'

# TODO: There should be NO calculations in the show blocks

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
  OUTPUT = 'PCR Product'
  PACK = 'PCR Pack'
  A = 'Diluent A'

  ##########################################
  # TERMINOLOGY
  ##########################################

  ##########################################
  # Protocol Specifics
  ##########################################

  this_package = prepare_protocol_operations
  PACK_HASH = PCR_UNIT
  AREA = PRE_PCR
  SAMPLE_VOLUME = 10 # volume of sample to add to PCR mix
  PCR_MIX_VOLUME = PACK_HASH['PCR Rehydration Volume'] # volume of water to rehydrate PCR mix in
  CENTRIFUGE_TIME = '5 seconds' # time to pulse centrifuge to pull down dried powder
  VORTEX_TIME = '5 seconds' # time to pulse vortex to mix

  # for debugging
  PREV_COMPONENT = '6'
  PREV_UNIT = 'E'

  TUBE_CAP_WARNING = 'Check to make sure tube caps are completely closed.'

  component_to_name_hash = {
    'diluent A' => 'Diluent A',
    'sample tube' => 'PCR tube'
  }

  MATERIALS = [
    'P20 pipette and filter tips',
    'Gloves (wear tight gloves to reduce contamination risk)',
    'Centrifuge',
    '70% v/v Ethanol Spray for cleaning',
    '10% v/v Bleach Spray for cleaning',
    'Molecular Grade Ethanol'
  ].freeze

  SAMPLE_ALIAS = 'RNA Extract'

  ##########################################
  # ##
  # Input Restrictions:
  # Input needs a kit, unit, components,
  # and sample data associations to work properly
  ##########################################

  def main
    operations.running.retrieve interactive: false
    operations.running.make
    save_user operations

    if debug
      labels = %w[001 002]
      kit_num = 'K001'
      operations.each.with_index do |op, i|
        op.input(INPUT).item.associate(SAMPLE_KEY, labels[i])
        op.input(INPUT).item.associate(COMPONENT_KEY, PREV_COMPONENT)
        op.input(INPUT).item.associate(KIT_KEY, kit_num)
        op.input(INPUT).item.associate(UNIT_KEY, PREV_UNIT)
        op.input(INPUT).item.associate(PATIENT_KEY, "A PATIENT ID")        
      end
    end

    save_temporary_input_values(operations, INPUT)
    operations.each do |op|
      op.temporary[:pack_hash] = PACK_HASH
    end
    save_temporary_output_values(operations)

    run_checks(operations)
    kit_introduction(operations.running)
    record_technician_id
    safety_warning
    area_preparation('pre-PCR', MATERIALS, PRE_PCR)
    simple_clean("OLASimple RT Module")
    retrieve_package(this_package)
    
    get_inputs(operations.running)
    validate_pcr_inputs(operations.running)
    get_pcr_packages(operations.running)
    validate_pcr_packages(operations.running)
    open_pcr_packages(operations.running)
    # debug_table(operations.running)
    # check_for_tube_defects sorted_ops.running
    # nuttada thaw
    # nuttada needs vortex + centrigure
    centrifuge_samples(sorted_ops.running)
    resuspend_pcr_mix(sorted_ops.running)
    add_template_to_master_mix(sorted_ops.running)
  
    #cleanup(sorted_ops) Removed per Jordan's edits
    start_thermocycler(sorted_ops.running)
    wash_self
    accept_comments
    conclusion(sorted_ops)
    {}
  end # main

  # end of main

  #######################################
  # Utilities
  #######################################
  def save_user(ops)
    ops.each do |op|
      username = get_technician_name(jid)
      op.associate(:technician, username)
    end
  end

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
  end

  def sorted_ops
    operations.sort_by { |op| op.output_ref(OUTPUT) }.extend(OperationList)
  end

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

  #######################################
  # Instructions
  #######################################

  def kit_introduction(ops)
    show do
      title "Welcome to OLASimple RT Module (Reverse Transcription)"
      note 'In this protocol you will be converting the RNA generated in the E module into cDNA.'
    end
  end

  def get_inputs(myops)
    gops = group_packages(myops)

    show do
      title "Place #{SAMPLE_ALIAS.bold} samples in #{AREA.bold}."
      note "Retrieve from cold rack and place the following #{SAMPLE_ALIAS.bold} samples into a rack in the #{AREA.bold} area."
      note 'Samples may also be in the -20 freezer if this protocol has been delayed.'
      tubes = []
      gops.each do |unit, ops|
        ops.each_with_index do |op, i|
          tubes << make_tube(closedtube, '', ref(op.input(INPUT).item).split('-'), 'medium', true).translate!(100 * i)
        end
        img = SVGElement.new(children: tubes, boundy: 300, boundx: 300).translate!(20)
        note display_svg(img)
      end
    end
  end

  def validate_pcr_inputs(myops)
    expected_inputs = myops.map { |op| ref(op.input(INPUT).item) }
    sample_validation_with_multiple_tries(expected_inputs)
  end

  def get_pcr_packages(myops)
    # TODO: remove all references to 4C fridge and replace with refridgerator
    gops = group_packages(myops)
    show do
      title "Take #{PCR_PKG_NAME.pluralize(gops.length)} from the #{FRIDGE_PRE} with a Paper Towel and place on the #{BENCH_POST}"
      # check "Take the following from the #{FRIDGE} and place #{pluralizer(PACKAGE, gops.length)} on the #{BENCH}"
      gops.each do |unit, _ops|
        check 'Take package ' "#{unit.bold}" ' from fridge.'
        check 'Place package ' "#{unit.bold}" ' on the bench.'
      end
    end
  end

  def validate_pcr_packages(myops)
    group_packages(myops).each { |unit, _ops| package_validation_with_multiple_tries(unit) }
  end

  def open_pcr_packages(myops)
    grouped_by_unit = myops.group_by { |op| op.temporary[:output_kit_and_unit] }
    grouped_by_unit.each do |kit_and_unit, ops|
      ops.each do |op|
        op.make_item_and_alias(OUTPUT, 'sample tube', INPUT)
      end

      show_open_package(kit_and_unit, '', ops.first.temporary[:pack_hash][NUM_SUB_PACKAGES_FIELD_VALUE]) do
        # img
        pcr_tube_labels = ops.map { |op| op.output_tube_label(OUTPUT) }

        num_samples = ops.first.temporary[:pack_hash][NUM_SAMPLES_FIELD_VALUE]
        kit, unit, component, sample = ops.first.output_tokens(OUTPUT)
        # diluentATube = label_tube(closedtube, tube_label(kit, unit, diluentAcomponent, ""))
        diluentATube = make_tube(closedtube, 'Diluent A', ops.first.tube_label('diluent A'), 'medium', true)

        grid = SVGGrid.new(num_samples, 1, 75, 10)
        pcr_tube_labels.each_with_index do |tube_label, i|
          pcrtube = make_tube(closedtube, '', tube_label, 'powder', true).scale(0.75)
          grid.add(pcrtube, i, 0)
        end
        grid.boundy = closedtube.boundy * 0.75
        grid.align_with(diluentATube, 'center-right')
        grid.align!('center-left')
        grid.translate!(25, 25)
        img = SVGElement.new(children: [diluentATube, grid], boundy: diluentATube.boundy + 50, boundx: 300).translate!(20)

        check "Look for #{num_samples + 1} #{'tube'.pluralize(num_samples)}"
        check 'Place tubes on a rack'
        note display_svg(img, 0.75)
      end
    end
  end

  def debug_table(myops)
    if debug
      show do
        title 'DEBUG: I/O Table'

        table myops.running.start_table
                   .custom_column(heading: 'Input Kit') { |op| op.temporary[:input_kit] }
                   .custom_column(heading: 'Output Kit') { |op| op.temporary[:output_kit] }
                   .custom_column(heading: 'Input Unit') { |op| op.temporary[:input_unit] }
                   .custom_column(heading: 'Output Unit') { |op| op.temporary[:output_unit] }
                   .custom_column(heading: 'Diluent A') { |op| op.ref('diluent A') }
                   .custom_column(heading: 'Input Ref') { |op| op.input_ref(INPUT) }
                   .custom_column(heading: 'Output Ref') { |op| op.output_ref(OUTPUT) }
                   .end_table
      end
    end
  end

  def centrifuge_samples(ops)
    labels = ops.map { |op| ref(op.output(OUTPUT).item) }
    diluentALabels = ops.map { |op| op.ref('diluent A') }
    show do
      title 'Centrifuge all samples for 5 seconds'
      check 'Place all tubes and samples in the centrifuge, along with a balancing tube. It is important to balance the tubes.'
      check 'Centrifuge the tubes for 5 seconds to pull down liquid and dried reagents'
    end
    # centrifuge_helper("sample", labels, CENTRIFUGE_TIME,
    #                   "to pull down dried powder.",
    #                   "There may be dried powder on the inside of the tube #{"lid".pluralize(labels.length)}.")
    # centrifuge_helper("tube", diluentALabels, CENTRIFUGE_TIME,
    #                   "to pull down liquid.")
  end

  def resuspend_pcr_mix(myops)
    gops = group_packages(myops)
    gops.each do |_unit, ops|
      from = ops.first.ref('diluent A')
      tos = ops.map { |op| ref(op.output(OUTPUT).item) }
      to_tubes = ops.map.with_index do |op, i|
        to_item = op.output(OUTPUT).item
        to = ref(to_item)
        tubeP = make_tube(opentube, [PCR_SAMPLE, to], '', fluid = 'powder').scale!(0.75)
        tubeP.translate!(120 * i, 0)
      end
      tubeA = make_tube(opentube, [DILUENT_A, from], '', fluid = 'medium')
      tubes_P = SVGElement.new(children: to_tubes, boundx: 200, boundy: 200)
      img = make_transfer(tubeA, tubes_P, 300, "#{PCR_MIX_VOLUME}uL", "(#{P200_PRE} pipette)")
      img.translate!(25)
      show do
        raw transfer_title_proc(PCR_MIX_VOLUME, from, tos.to_sentence)
        # title "Add #{PCR_MIX_VOLUME}uL from #{DILUENT_A} #{from.bold} to #{PCR_SAMPLE} #{to.bold}"
        note "#{DILUENT_A} will be used to dissolve the PCR mix in the #{PCR_SAMPLE}s."
        note "Use a #{P200_POST} pipette and set it to <b>[0 4 0]</b>."
        note 'Avoid touching the inside of the lid, as this could cause contamination. '
        tos.each do |to|
          check "Transfer #{PCR_MIX_VOLUME}uL from #{from.bold} into #{to.bold}"
          note 'Discard pipette tip.'
        end
        note display_svg(img, 0.75)
      end
      # TODO: add "make sure tube caps are completely closed" for any centrifugation or vortexing step.
      #
    end

    labels = myops.map { |op| ref(op.output(OUTPUT).item) }
    vortex_and_centrifuge_helper('tubes',
                                 labels,
                                 VORTEX_TIME, CENTRIFUGE_TIME,
                                 'to mix.', 'to pull down liquid', AREA, mynote = nil)
  end

  def add_template_to_master_mix(myops)
    gops = group_packages(myops)

    gops.each do |_unit, ops|
      samples = ops.map { |op| op.input(INPUT).item }
      sample_refs = samples.map { |sample| ref(sample) }
      ops.each do |op|
        from = ref(op.input(INPUT).item)
        to = ref(op.output(OUTPUT).item)
        tubeS = make_tube(opentube, [SAMPLE_ALIAS, from], '', fluid = 'medium')
        tubeP = make_tube(opentube, [PCR_SAMPLE, to], '', fluid = 'medium').scale!(0.75)
        tubeS_closed = make_tube(closedtube, [SAMPLE_ALIAS, from], '', fluid = 'medium')
        tubeP_closed = make_tube(closedtube, [PCR_SAMPLE, to], '', fluid = 'medium').translate!(0,40).scale!(0.75)
        pre_transfer_validation_with_multiple_tries(from, to, tubeS_closed, tubeP_closed)
        show do
          raw transfer_title_proc(SAMPLE_VOLUME, "#{SAMPLE_ALIAS} #{from}", "#{PCR_SAMPLE} #{to}")
          note "Carefully open tube #{from.bold} and tube #{to.bold}"
          note "Use a #{P20_POST} pipette and set it to <b>[1 0 0]</b>."
          check "Transfer #{SAMPLE_VOLUME}uL from #{from.bold} into #{to.bold}"
          img = make_transfer(tubeS, tubeP, 300, "#{SAMPLE_VOLUME}uL", "(#{P20_POST} pipette)")
          img.translate!(25)
          note display_svg(img, 0.75)
          check 'Close tubes and discard pipette tip'
        end
      end
    end
  end

  def start_thermocycler(ops)
    # Adds the PCR tubes to the PCR machine.
    # Instructions for PCR cycles.
    #
    samples = ops.map { |op| op.output(OUTPUT).item }
    sample_refs = samples.map { |sample| ref(sample) }

    # END OF PRE_PCR PROTOCOL

    vortex_and_centrifuge_helper(PCR_SAMPLE,
                                 sample_refs,
                                 VORTEX_TIME, CENTRIFUGE_TIME,
                                 'to mix.', 'to pull down liquid', AREA, mynote = nil)

    t = Table.new
    cycles_temp = "<table style=\"width:100%\">
                    <tr><td>95C</td></tr>
                    <tr><td>57C</td></tr>
                    <tr><td>72C</td></tr>
      </table>"
    cycles_time = "<table style=\"width:100%\">
                    <tr><td>30 sec</td></tr>
                    <tr><td>30 sec</td></tr>
                    <tr><td>30 sec</td></tr>
      </table>"
    t.add_column('STEP', ['Initial Melt', '45 cycles of', 'Extension', 'Hold'])
    t.add_column('TEMP', ['95C', cycles_temp, '72C', '4C'])
    t.add_column('TIME', ['4 min', cycles_time, '7 min', 'forever'])

    show do
      title 'Run PCR'
      check 'Close all the lids of the pipette tip boxes and pre-PCR rack'
      check "Take only the PCR tubes (#{sample_refs.to_sentence}) with you"
      check 'Place the PCR tubes in the assigned thermocycler, close, and tighten the lid'
      check "Select the program named #{PCR_CYCLE} under OS"
      check "Hit #{'Run'.quote} and #{'OK to 50uL'.quote}"
      table t
    end

    operations.each do |op|
      op.output(OUTPUT).item.move THERMOCYCLER
    end

    # END OF POST_PCR PCR REACTION...
  end

  def cleanup(myops)
    items = [INPUT].map { |x| myops.map { |op| op.input(x) } }.flatten.uniq
    item_refs = [INPUT].map { |x| myops.map { |op| op.input_ref(x) } }.flatten.uniq
    temp_items = ['diluent A'].map { |x| myops.map { |op| op.ref(x) } }.flatten.uniq

    all_refs = temp_items + item_refs

    show do
      title "Discard items into the trash"

      note "Discard the following items into the #{WASTE_POST}"
      all_refs.each { |r| bullet r }
    end
    # clean_area AREA
  end

  def conclusion(_myops)
    show do
      title 'Thank you!'
      note 'You may start the next protocol in 2 hours.'
    end
  end
end # Class

