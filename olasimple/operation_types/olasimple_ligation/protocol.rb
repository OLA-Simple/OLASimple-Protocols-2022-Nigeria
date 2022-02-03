# frozen_string_literal: true

##########################################
#
#
# OLASimple Ligation
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

class Protocol
  include OLALib
  include OLAGraphics
  include OLAConstants
  include JobComments
  include OLAKitIDs

  ##########################################
  # INPUT/OUTPUT
  ##########################################
  INPUT = 'PCR Product'
  OUTPUT = 'Ligation Product'
  PACK = 'Ligation Pack'
  A = 'Diluent A' #Update to be LO??

  ##########################################
  # TERMINOLOGY
  ##########################################

  ##########################################
  # Protocol Specifics
  ##########################################

  AREA = POST_PCR

  # for debugging
  PREV_COMPONENT = '2'
  PREV_UNIT = 'A'

  CENTRIFUGE_TIME = '5 seconds' # time to pulse centrifuge to pull down dried powder
  VORTEX_TIME = '5 seconds' # time to pulse vortex to mix
  TUBE_CAP_WARNING = 'Check to make sure tube caps are completely closed.'

  PACK_HASH = LIGATION_UNIT

  LIGATION_VOLUME = PACK_HASH['Ligation Mix Rehydration Volume'] # volume to rehydrate ligation mix
  SAMPLE_VOLUME = PACK_HASH['PCR to Ligation Mix Volume'] # volume of pcr product to ligation mix
  MATERIALS = [
    'gloves (wear tight gloves to reduce contamination risk)',
    'P200 pipette and filtered tips',
    'P2 pipette and filtered tips',
    'a spray bottle of 10% v/v bleach',
    'a spray bottle of 70% v/v ethanol',
    'balancing tube (on rack)',
    'centrifuge',
    'vortex mixer'
  ].freeze
  COMPONENTS = PACK_HASH['Components']['sample tubes']

  ##########################################
  # ##
  # Input Restrictions:
  # Input needs a kit, unit, components,
  # and sample data associations to work properly
  ##########################################

  def main
    operations.running.retrieve interactive: false
    save_user operations
    debug_setup(operations) if debug
    save_temporary_input_values(operations, INPUT)
    # save_pack_hash(operations, PACK)
    operations.each do |op|
      op.temporary[:pack_hash] = PACK_HASH
    end
    save_temporary_output_values(operations)
    run_checks operations

    expert_mode = true

    introduction(operations.running)
    record_technician_id
    safety_warning
    area_preparation(POST_PCR, MATERIALS, PRE_PCR)
    simple_clean("OLASimple Ligation")

    get_samples_from_thermocycler(operations.running)
    validate_ligation_inputs(operations.running)

    get_ligation_packages(operations.running)
    validate_ligation_packages(operations.running)
    open_ligation_packages(operations.running)
    # check_for_tube_defects operations.running
    centrifuge_samples(sorted_ops.running)
    rehydrate_ligation_mix(sorted_ops.running, expert_mode)
    vortex_and_centrifuge_samples(sorted_ops.running)
    add_template(sorted_ops.running, expert_mode)
    vortex_and_centrifuge_samples(sorted_ops.running)

    cleanup(sorted_ops)
    start_ligation(sorted_ops.running)
    wash_self
    accept_comments
    conclusion(sorted_ops)
    {}
  end

  def sorted_ops
    operations.sort_by { |op| op.output_ref(OUTPUT) }.extend(OperationList)
  end

  def save_user(ops)
    ops.each do |op|
      username = get_technician_name(jid)
      op.associate(:technician, username)
    end
  end

  def debug_setup(ops)
    # make an alias for the inputs
    if debug
      ops.each_with_index do |op, i|
        kit_num = 'K001'
        sample_num = sample_num_to_id(i + 1)
        make_alias(op.input(INPUT).item, kit_num, PREV_UNIT, PREV_COMPONENT, 'a patient id', sample_num)
      end
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

  def ask_if_expert
    resp = show do
      title 'Expert Mode?'
      note 'Are you an expert at this protocol? If you do not know what this means, then continue without enabling expert mode.'
      select ['Continue in normal mode', 'Enable expert mode'], var: :choice, label: 'Expert Mode?', default: 0
    end
    resp[:choice] == 'Enable expert mode'
  end

  def introduction(_ops)
    show do
      title 'Welcome to OLASimple Ligation'
      note 'You will be running the OLASimple Ligation protocol'
      note 'In this protocol you will be using PCR samples from the PCR protocol' \
      ' and adding small pieces of DNA which will allow you to detect HIV mutations.'
    end
  end

  def get_ligation_packages(myops)
    gops = myops.group_by { |op| op.temporary[:output_kit_and_unit] }
    show do
      title "Take #{LIG_PKG_NAME.pluralize(gops.length)} from the R1 #{FRIDGE_POST} "
      gops.each do |unit, _ops|
        check "Retrieve #{PACKAGE_POST} #{unit.bold}"
      end
      check "Place #{pluralizer(PACKAGE_POST, gops.length)} on the #{BENCH_POST}."
      note "If you touched the refrigerator handle to remove the samples, put on a new outside layer of gloves."
    end
  end

  def validate_ligation_packages(myops)
    group_packages(myops).each { |unit, _ops| package_validation_with_multiple_tries(unit) }
  end

  def open_ligation_packages(_myops)
    grouped_by_unit = operations.running.group_by { |op| op.temporary[:output_kit_and_unit] }
    grouped_by_unit.each do |kit_and_unit, ops|
      ops.each do |op|
        op.make_collection_and_alias(OUTPUT, 'sample tubes', INPUT)
      end

      ops.each do |op|
        op.temporary[:label_string] = "#{op.output_refs(OUTPUT)[0]} through #{op.output_refs(OUTPUT)[-1]}"
      end

      ##################################
      # get output collection references
      #################################

      show_open_package(kit_and_unit, '', ops.first.temporary[:pack_hash][NUM_SUB_PACKAGES_FIELD_VALUE]) do
        tube = make_tube(closedtube, '', ops.first.tube_label('diluent A'), 'medium')
        num_samples = ops.first.temporary[:pack_hash][NUM_SAMPLES_FIELD_VALUE]
        grid = SVGGrid.new(1, num_samples, 0, 100)
        tokens = ops.first.output_tokens(OUTPUT)
        ops.each_with_index do |op, i|
          _tokens = tokens.dup
          _tokens[-1] = op.temporary[:input_sample]
          ligation_tubes = display_ligation_tubes(*_tokens, COLORS)
          stripwell = ligation_tubes.g
          grid.add(stripwell, 0, i)
        end
        grid.align_with(tube, 'center-right')
        grid.align!('center-left')
        img = SVGElement.new(children: [tube, grid], boundx: 1000, boundy: 300).translate!(30, -50)
        note 'Check that the following tubes are in the pack:'
        # check "a 1.5mL tube of #{DILUENT_A} labeled #{ops.first.ref("diluent A")}"
        # ops.each do |op|
        #   check "a strip of colored tubes labeled #{op.temporary[:label_string].bold}"
        # end
        note display_svg(img, 0.75)
      end

      show do
        title 'Place strips of tubes into a rack'
        check "Take #{pluralizer('tube strip', ops.length)} and place them in the plastic racks"
      end
    end
  end

  def centrifuge_samples(ops)
    labels = ops.map { |op| op.temporary[:label_string] }
    diluentALabels = ops.map { |op| op.ref('diluent A') }.uniq
    show do
      title 'Centrifuge Diluent A and Ligation tubes for 5 seconds to pull down reagents'
      note 'Put the tag side of the rack toward the center of the centrifuge'
      check "Centrifuge #{(labels + diluentALabels).to_sentence.bold} for 5 seconds."
    end
    # centrifuge_helper("tube set", labels, CENTRIFUGE_TIME,
    #                   "to pull down dried powder.",
    #                   "There may be dried powder on the inside of the tube #{"lid".pluralize(labels.length)}.")
    # centrifuge_helper("tube", diluentALabels, CENTRIFUGE_TIME,
    #                   "to pull down liquid.")
  end

  def vortex_and_centrifuge_samples(ops)
    labels = ops.map { |op| op.temporary[:label_string] }
    vortex_and_centrifuge_helper('tube set', labels, CENTRIFUGE_TIME, VORTEX_TIME,
                                 'to mix.', 'to pull down the fluid.', AREA)
    show do
      title 'Check your tubes.'
      note 'Dried powder of reagents should be dissolved at this point. '
      check 'Look on the side of the tubes to check if you see any remaining powder. If you notice any powder remains on the side, rotate the tubes while vortexing for 5 seconds and centrifuge for 5 seconds.'
    end
  end

  def get_samples_from_thermocycler(myops)
    show do
      title "Retrieve PCR samples from the #{THERMOCYCLER}"
      check "Take #{PCR_SAMPLE.pluralize(myops.length)} #{myops.map { |op| ref(op.input(INPUT).item).bold }.join(', ')} from the #{THERMOCYCLER}"
      note 'If thermocycler run is complete (infinite hold at 4C), hit cancel followed by yes. '
      check "Position #{PCR_SAMPLE.pluralize(myops.length)} on #{BENCH_POST} in front of you."
      centrifuge_proc(PCR_SAMPLE, myops.map { |op| ref(op.input(INPUT).item) }, '3 seconds', 'to pull down liquid.', AREA, balance = false)
    end
  end

  def validate_ligation_inputs(myops)
    expected_inputs = myops.map { |op| ref(op.input(INPUT).item) }
    sample_validation_with_multiple_tries(expected_inputs)
  end

  def rehydrate_ligation_mix(myops, expert_mode)
    gops = myops.group_by { |op| op.temporary[:input_kit_and_unit] }
    gops.each do |_unit, ops|
      ops.each do |op|
        labels = op.output_refs(OUTPUT)
        if expert_mode
          # All transfers at once...
          from = op.ref('diluent A')
          tubeA = make_tube(opentube, [DILUENT_A, from], op.tube_label('diluent A'), 'medium')
          show do
            title "Add #{DILUENT_A} #{from} to #{LIGATION_SAMPLE}s #{op.temporary[:label_string].bold}"
            labels.map! { |l| "<b>#{l}</b>" }
            note "In this step we will be adding #{LIGATION_VOLUME}uL of #{DILUENT_A} #{from} into #{pluralizer('tube', COMPONENTS.length)} "
            "of the colored strip of tubes labeled <b>#{labels[0]} to #{labels[-1]}</b>"
            note "Set a #{P200_POST} pipette to [2 0 0]."
            note "Using #{P200_POST} add #{LIGATION_VOLUME}uL from #{DILUENT_A} #{from} into each of the #{COMPONENTS.length} tubes."
            warning "Only open one of the ligation tubes at a time and discard. Change your pipette tip after every transfer of #{DILUENT_A}."

            ligation_tubes = display_ligation_tubes(*op.output_tokens(OUTPUT), COLORS).translate!(0, -20)

            transfer_image = make_transfer(tubeA, ligation_tubes, 300, "#{LIGATION_VOLUME}uL", "(#{P200_POST} pipette)")
            note display_svg(transfer_image, 0.6)

            labels.each do |l|
              check "Transfer #{LIGATION_VOLUME}uL from #{from.bold} into #{l}"
            end

            # t = Table.new
            # t.add_column("Tube", labels)
            # t.add_column("Color", COMPONENTS_COLOR_CODE)
            # table t
          end
        else
          # each transfer
          from = op.ref('diluent A')
          ligation_tubes = display_ligation_tubes(*op.output_tokens(OUTPUT), COLORS)
          ligation_tubes.align!('bottom-left')
          ligation_tubes.align_with(tube, 'bottom-right')
          ligation_tubes.translate!(50)
          tubeA = make_tube(closedtube, DILUENT_A, op.tube_label('diluent A'), 'medium')
          image = SVGElement.new(children: [tubeA, ligation_tubes], boundx: 1000, boundy: tube.boundy)
          image.translate!(50, -50)
          show do
            title "Position #{DILUENT_A} #{from.bold} and colored tubes #{op.temporary[:label_string].bold} in front of you."
            note "In the next steps you will dissolve the powder in #{pluralizer('tube', COMPONENTS.length)} using #{DILUENT_A}"
            note display_svg(image, 0.75)
          end
          ligation_tubes_svg = display_ligation_tubes(*op.output_tokens(OUTPUT), COLORS).translate!(0, -20)
          img = display_svg(ligation_tubes_svg, 0.7)
          # centrifuge_helper(LIGATION_SAMPLE, op.temporary[:labels], CENTRIFUGE_TIME, "to pull down dried powder.", img)

          labels.each.with_index do |label, i|
            show do
              raw transfer_title_proc(LIGATION_VOLUME, from, label)
              # title "Add #{LIGATION_VOLUME}uL #{DILUENT_A} #{from.bold} to #{LIGATION_SAMPLE} #{label}
              warning 'Change pipette tip between tubes'
              note "Set a #{P200_POST} pipette to [0 2 4]."
              check "Add #{LIGATION_VOLUME}uL from #{from.bold} into tube #{label.bold}"
              note "Close tube #{label.bold}"
              tubeA = make_tube(opentube, [DILUENT_A, from], '', 'medium')
              transfer_image = transfer_to_ligation_tubes_with_highlight(
                tubeA, i, *op.output_tokens(OUTPUT), COLORS, LIGATION_VOLUME, "(#{P200_POST} pipette)"
              )
              note display_svg(transfer_image, 0.6)
            end
          end
        end
        # vortex_and_centrifuge_helper(LIGATION_SAMPLE,
        #                              op.temporary[:labels],
        #                              VORTEX_TIME,
        #                              CENTRIFUGE_TIME,
        #                              "to mix well.",
        #                              "to pull down liquid.",
        #                              img)

        # show do
        #   title "Mix ligation tubes #{op.temporary[:labels][0]} through #{op.temporary[:labels][-1]}"
        #   note display_svg(display_ligation_tubes(op.temporary[:input_kit], THIS_UNIT, COMPONENTS, op.temporary[:input_sample]), 0.5)
        #   warning "Make sure tubes are firmly closed before proceeding."
        #   check "Vortex #{pluralizer("tube", COMPONENTS.length)} for 5 seconds to mix well."
        #   warning "Make sure all powder is dissolved. Vortex for 10 more seconds to dissolve powder."
        #   check "Centrifuge #{pluralizer("tube", COMPONENTS.length)} for 5 seconds to pull down liquid."
        #   check "Place tubes back into the rack."
        # end
      end
    end

    # vortex_and_centrifuge_helper("tube set",
    #                              myops.map { |op| op.temporary[:label_string] },
    #                              VORTEX_TIME,
    #                              CENTRIFUGE_TIME,
    #                              "to mix well.",
    #                              "to pull down liquid.")
  end

  def add_template(myops, expert_mode)
    gops = myops.group_by { |op| op.temporary[:input_kit_and_unit] }
    gops.each do |_unit, ops|
      ops.each do |op|
        from = op.input_ref(INPUT)
        labels = op.output_refs(OUTPUT)
        to_strip_name = "#{op.temporary[:output_unit]}-#{op.temporary[:output_sample]}"
        tubeP = make_tube(opentube, ['PCR Sample'], op.input_tube_label(INPUT), 'small').scale(0.75)
        ligation_tubes = display_ligation_tubes(*op.output_tokens(OUTPUT), COLORS).translate!(0, -20)
        pre_transfer_validation_with_multiple_tries(from, to_strip_name, tubeP, ligation_tubes)
        if expert_mode
          # All transfers at once...
          show do
            raw transfer_title_proc(SAMPLE_VOLUME, from, op.temporary[:label_string])
            warning 'Change pipette tip between tubes'
            check "Using a P20 pipette set to [0 4 0]."
            note "Add #{SAMPLE_VOLUME}uL from #{from.bold} into each of #{op.temporary[:label_string].bold}. Only open one ligation tube at a time."
            note "Discard pipette tip between each tube."

            transfer_image = make_transfer(tubeP, ligation_tubes, 300, "#{SAMPLE_VOLUME}uL", "(Post-PCR P2 pipette)")
            note display_svg(transfer_image, 0.6)
            labels.each do |l|
              check "Transfer #{SAMPLE_VOLUME}uL from #{from.bold} into #{l}"
            end
          end
        else
          show do
            title "Position #{PCR_SAMPLE} #{from.bold} and #{LIGATION_SAMPLE.pluralize(COMPONENTS.length)} #{op.temporary[:label_string].bold} in front of you."
            note "In the next steps you will add #{PCR_SAMPLE} to #{pluralizer('tube', COMPONENTS.length)}"
            tube = make_tube(closedtube, [PCR_SAMPLE, from], '', 'small')
            ligation_tubes = display_ligation_tubes(*op.output_tokens(OUTPUT), COLORS)
            ligation_tubes.align!('bottom-left')
            ligation_tubes.align_with(tube, 'bottom-right')
            ligation_tubes.translate!(50)
            image = SVGElement.new(children: [tube, ligation_tubes], boundx: 1000, boundy: tube.boundy)
            image.translate!(50, -30)
            note display_svg(image, 0.75)
          end
          labels.each.with_index do |label, i|
            show do
              raw transfer_title_proc(SAMPLE_VOLUME, from, label)
              # title "Add #{PCR_SAMPLE} #{from.bold} to #{LIGATION_SAMPLE} #{label}"
              warning 'Change of pipette tip between tubes'
              check "Using a P2 pipette set to [1 2 0], add #{SAMPLE_VOLUME}uL from #{from.bold} into tube #{label.bold}"
              note "Close tube #{label.bold}"
              tube = make_tube(opentube, ['PCR Sample'], op.input_tube_label(INPUT), 'small').scale(0.75)
              img = transfer_to_ligation_tubes_with_highlight(tube, i, *op.output_tokens(OUTPUT), COLORS, SAMPLE_VOLUME, "(Post-PCR P2 pipette)")
              note display_svg(img, 0.6)
            end
          end
        end

        # ligation_tubes_svg = display_ligation_tubes(*op.output_tokens(OUTPUT), COLORS)
        # img = display_svg(ligation_tubes_svg, 0.7)
        # vortex_and_centrifuge_helper(LIGATION_SAMPLE,
        #                              op.output_refs(OUTPUT),
        #                              VORTEX_TIME,
        #                              CENTRIFUGE_TIME,
        #                              "to mix well.",
        #                              "to pull down liquid.",
        #                              img)
      end
    end
  end

  def start_ligation(myops)
    gops = myops.group_by { |op| op.temporary[:input_kit_and_unit] }
    ops = gops.map { |_unit, ops| ops }.flatten # organize by unit
    # show do
    #   title "Place #{LIGATION_SAMPLE.pluralize(COMPONENTS.length)} into #{THERMOCYCLER}"
    #   check "Place #{pluralizer(LIGATION_SAMPLE, ops.length * COMPONENTS.length)} (#{ops.length} #{"set".pluralize(ops.length)} of #{COMPONENTS.length})" \
    #     " in the #{THERMOCYCLER}"
    #   check "Close and tighten the lid."
    #   ops.each do |op|
    #     note display_svg(display_ligation_tubes(*op.output_tokens(OUTPUT), COLORS), 0.5)
    #   end
    # end

    add_to_thermocycler('sample', ops.length * COMPONENTS.length, LIG_CYCLE, ligation_cycle_table, 'Ligation')

    show do
      title 'Set a timer for 35 minutes'
      #   check "Return to the #{PRE_PCR}."
      check 'Find a timer and set it for 35 minutes. Continue to next step.'
    end
  end

  def ligation_cycle_table
    t = Table.new
    cycles_temp = "<table style=\"width:100%\">
                        <tr><td>94</td></tr>
                        <tr><td>37C</td></tr>
          </table>"
    cycles_time = "<table style=\"width:100%\">
                        <tr><td>30 sec</td></tr>
                        <tr><td>4 min</td></tr>
          </table>"
    # t.add_column("STEP", ["Initial Melt", "10 cycles of", "Hold"])
    t.add_column('TEMP', ['95C', cycles_temp, '4C'])
    t.add_column('TIME', ['4 min', cycles_time, 'forever'])
    t
  end

  def cleanup(myops)
    items = [INPUT].map { |x| myops.map { |op| op.input(x) } }.flatten.uniq
    item_refs = [INPUT].map { |x| myops.map { |op| op.input_ref(x) } }.flatten.uniq
    item_refs = [] if KIT_NAME == 'uw kit'
    temp_items = ['diluent A'].map { |x| myops.map { |op| op.ref(x) } }.flatten.uniq

    all_refs = temp_items + item_refs

    show do
      title "Discard items into the #{WASTE_POST}"

      note "Discard the following items into the #{WASTE_POST} in the #{AREA}"
      all_refs.each { |r| bullet r }
    end
    # clean_area AREA
  end

  def conclusion(myops)
    if KIT_NAME == 'uw kit'
      show do
        title 'Please return PCR products'
        check "Place #{'sample'.pluralize(myops.length)} #{myops.map { |op| op.input_ref(INPUT) }.join(', ')} in the -20."
        image 'Actions/OLA/map_Klavins.svg '
      end
    end
    show do
      title 'Thank you!'
      note "The #{THERMOCYCLER} will be done in 50 minutes."
    end
  end
end
