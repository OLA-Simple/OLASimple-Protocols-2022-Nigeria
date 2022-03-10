# frozen_string_literal: true

##########################################
#
#
# OLASimple Detection
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
  include OLAConstants
  include OLALib
  include OLAGraphics
  include JobComments
  include OLAKitIDs

  ###########################################
  ## INPUT/OUTPUT
  ###########################################
  # F
  INPUT = 'Ligation Product'
  OUTPUT = 'Detection Strip'
  PACK = 'Detection Pack'
  A = 'Diluent A'
  G = 'Gold Mix'
  S = 'Stop Mix'

  ###########################################
  ## TERMINOLOGY
  ###########################################

  ###########################################
  ## Protocol Specifics
  ###########################################
  AREA = POST_PCR
  NUM_SUB_PACKAGES = 4

  CENTRIFUGE_TIME = '5 seconds' # time to pulse centrifuge to pull down dried powder
  VORTEX_TIME = '5 seconds' # time to pulse vortex to mix
  TUBE_CAP_WARNING = 'Check to make sure tube caps are completely closed.'
  PACK_HASH = DETECTION_UNIT
  THIS_UNIT = PACK_HASH['Unit Name']
  STOP_VOLUME = PACK_HASH['Stop Rehydration Volume']
  GOLD_VOLUME = PACK_HASH['Gold Rehydration Volume']
  STOP_TO_SAMPLE_VOLUME = PACK_HASH['Stop to Sample Volume'] # volume of competitive oligos to add to sample
  SAMPLE_TO_STRIP_VOLUME = PACK_HASH['Sample to Strip Volume'] # volume of sample to add to the strips
  GOLD_TO_STRIP_VOLUME = PACK_HASH['Gold to Strip Volume']
  PREV_COMPONENTS = PACK_HASH['Components']['strips']
  MUTATION_LABELS = PACK_HASH['Mutation Labels']

  PREV_UNIT = 'L'
  MATERIALS = [
    'P1000 pipette and filtered tips',
    'P200 pipette and filtered tips',
    'P20 pipette and filtered tips',
    'a spray bottle of 10% v/v bleach',
    'a spray bottle of 70% v/v ethanol',
    'a timer',
    'gloves'
  ].freeze

  POSITIVE = 'positive'
  NEGATIVE = 'negative'
  DEBUG_UPLOAD_ID = 1

  ##########################################
  # ##
  # Input Restrictions:
  # Input needs a kit, unit, components,
  # and sample data associations to work properly
  ##########################################

  def main
    operations.each do |op|
      op.temporary[:pack_hash] = PACK_HASH
    end
    save_user operations
    operations.running.retrieve interactive: false
    debug_setup operations
    save_temporary_input_values(operations, INPUT)
    save_temporary_output_values(operations)
    expert_mode = true
    introduction operations.running
    record_technician_id
    safety_warning
    area_preparation POST_PCR, MATERIALS, PRE_PCR
    simple_clean('OLASimple Paper Detection')

    get_detection_packages operations.running
    validate_detection_packages operations.running
    open_detection_packages operations.running
    rehydrate_stop_solution(sorted_ops.running)
    wait_for_pcr sorted_ops.running
    retrieve_inputs(sorted_ops.running)
    validate_detection_inputs(sorted_ops.running)

    stop_ligation_product(sorted_ops.running, expert_mode)
    # short_timer
    rehydrate_gold_solution(sorted_ops.running)
    display_detection_strip_diagram
    add_ligation_product_to_strips(sorted_ops.running)
    add_gold_solution(sorted_ops.running)
    read_from_scanner(sorted_ops.running)
    analysis operations.running

    discard_things(sorted_ops.running)
    clean_area(AREA)
    wash_self
    conclusion sorted_ops
    accept_comments
    { 'Ok' => 1 }
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
        make_alias(op.input(INPUT).item, kit_num, PREV_UNIT, PREV_COMPONENTS, 'a patient id', sample_num)
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

  def introduction(_myops)
    show do
      title 'Welcome to OLASimple Paper Detection procotol'
      note 'In this protocol you will be adding samples from the ligation protocol onto paper detection strips. ' \
            'You will then scan an image of the strips and upload the image. The strips will detect whether the sample has drug resistance mutations.'
    end
  end

  def get_detection_packages(myops)
    gops = group_packages(myops)
    show do
      title "Get #{DET_PKG_NAME.pluralize(gops.length)} from the #{FRIDGE_POST}"
      gops.each do |unit, _ops|
        check "Retrieve package #{unit.bold}"
      end
      check "Place #{pluralizer('package', gops.length)} on the bench in the #{AREA.bold} area."
      note "Remove the outside layer of gloves (since you just touched the door knob)"
      note "Put on a new outside layer of gloves."
    end
  end

  def validate_detection_packages(myops)
    group_packages(myops).each { |unit, _ops| package_validation_with_multiple_tries(unit) }
  end

  def open_detection_packages(myops)
    kit_ops = myops.running.group_by { |op| op.temporary[:output_kit] }
    kit_ops.each do |kit, ops|
      ops.each do |op|
        op.make_collection_and_alias(OUTPUT, 'strips', INPUT)
      end

      ops.each do |op|
        op.temporary[:label_string] = "#{op.output_refs(OUTPUT)[0]} through #{op.output_refs(OUTPUT)[-1]}"
      end

      tokens = ops.first.output_tokens(OUTPUT)
      num_samples = ops.first.temporary[:pack_hash][NUM_SAMPLES_FIELD_VALUE]

      grid = SVGGrid.new(num_samples, num_samples, 50, 50)
      ops.each_with_index do |op, i|
        tokens = op.output_tokens(OUTPUT)
        grid.add(display_strip_panel(*tokens, COLORS).scale!(0.5), i, i)
      end

      diluentATube = make_tube(closedtube, 'Diluent A', ops.first.tube_label('diluent A'), 'medium', true).scale!(0.75)
      stopTube = make_tube(closedtube, 'Stop mix', ops.first.tube_label('stop'), 'powder', true).scale!(0.75)
      goldTube = make_tube(closedtube, 'Gold mix', ops.first.tube_label('gold'), 'powder', true, fluidclass: 'pinkfluid').scale!(0.75)
      diluentATube.translate!(50, 75)
      goldTube.align_with(diluentATube, 'top-right').translate!(50)
      stopTube.align_with(goldTube, 'top-right').translate!(50)
      img = SVGElement.new(children: [grid, diluentATube, goldTube, stopTube], boundx: 500, boundy: 220)

      show_open_package(kit, THIS_UNIT, NUM_SUB_PACKAGES) do
        note "Check that there are the following tubes and #{STRIPS}:"
        note display_svg(img, 1.0)
      end
    end
  end

  def rehydrate_stop_solution(myops)
    gops = group_packages(myops)
    gops.each do |_unit, ops|
      from = ops.first.ref('diluent A')
      to = ops.first.ref('stop')
      show do
        raw transfer_title_proc(STOP_VOLUME, from, to)
        #check "Centrifuge tubes #{to} and #{from} for 5 seconds to pull reagents."
        check "Centrifuge tube #{from} for 5 seconds to ensure all liquid is brought down."
        check "Centrifuge tube #{to} for 5 seconds to pull down powder"
        check "Set a #{P200_POST} pipette to <b>[0 6 7]</b>. Add #{STOP_VOLUME}uL from #{from.bold} into tube #{to.bold}"
        tubeA = make_tube(opentube, DILUENT_A, ops.first.tube_label('diluent A'), 'medium')
        tubeS = make_tube(opentube, STOP_MIX, ops.first.tube_label('stop'), 'powder')
        img = make_transfer(tubeA, tubeS, 300, "#{STOP_VOLUME}uL", "(#{P200_POST} pipette)")
        img.translate!(20)
        note display_svg(img, 0.75)
      end

      vortex_and_centrifuge_helper('tube',
                                   [to],
                                   VORTEX_TIME, CENTRIFUGE_TIME,
                                   'to mix.', 'to pull down liquid', AREA, mynote = nil)
    end
  end

  def wait_for_pcr(myops)
    show do
      title 'Wait for thermocycler to finish'

      note "The thermocycler containing the #{LIGATION_SAMPLE.pluralize(5)} needs to complete before continuing"
      check "Check the #{THERMOCYCLER} to see if the samples are done."
      note 'If the cycle is at "hold at 4C" then it is done. If it is done, hit CANCEL followed by YES. If not, continue waiting.'
      note 'Else, if your ligation sample has been stored, retrieve from freezer.'
      note "You need the following samples: "
      myops.each do |op|
        bullet "#{op.input_refs(INPUT)[0].bold} to #{op.input_refs(INPUT)[-1].bold}"
      end
      warning "Do not proceed until the #{THERMOCYCLER} is finished."
    end
  end

  def retrieve_inputs(myops)
    gops = myops.group_by { |op| op.temporary[:output_kit_and_unit] }
    num_tubes = myops.inject(0) { |sum, op| sum + op.output_refs(OUTPUT).length }
    # ordered_ops = gops.map {|unit, ops| ops}.flatten.extend(OperationList) # organize by unit
    show do
      title "Take #{pluralizer('sample', num_tubes)} from the #{THERMOCYCLER} and place on rack in #{AREA.bold} area"
      check 'Centrifuge for 5 seconds to pull down liquid'
      check 'Place on rack in post-PCR area'

      gops.each do |_unit, ops|
        ops.each do |op|
          note display_svg(display_ligation_tubes(*op.input_tokens(INPUT), COLORS), 0.75)
        end
      end
    end
  end

  def validate_detection_inputs(myops)
    expected_inputs = myops.map { |op| "#{op.temporary[:input_unit]}-#{op.temporary[:input_sample]}" }
    sample_validation_with_multiple_tries(expected_inputs)
  end

  def stop_ligation_product(myops, expert_mode)
    gops = myops.group_by { |op| op.temporary[:output_kit_and_unit] }

    gops.each do |_unit, ops|
      from = ops.first.ref('stop')
      ops.each do |op|
        to_labels = op.input_refs(INPUT)
        show do
          # title "Get ready to add #{STOP_MIX} to #{LIGATION_SAMPLE.pluralize(MUTATIONS.length)} for #{unit}"
          title "Position #{STOP_MIX} #{from.bold} and colored tubes #{op.input_refs(INPUT)[0].bold} to #{op.input_refs(INPUT)[-1].bold} in front of you."
          note "In the next steps you will add #{STOP_MIX} to #{pluralizer('tube', PREV_COMPONENTS.length)}"
          tube = closedtube.scale(0.75)
          tube.translate!(0, -50)
          tube = tube.g
          tube.g.boundx = 0
          labeled_tube = make_tube(closedtube, STOP_MIX, op.tube_label('stop'), 'medium', true)
          ligation_tubes = display_ligation_tubes(*op.input_tokens(INPUT), COLORS)
          ligation_tubes.align!('bottom-left')
          ligation_tubes.align_with(tube, 'bottom-right')
          ligation_tubes.translate!(50)
          image = SVGElement.new(children: [labeled_tube, ligation_tubes], boundx: 600, boundy: tube.boundy)
          image.translate!(50)
          image.boundy = image.boundy + 50
          note display_svg(image, 0.75)
        end
        if expert_mode
          show do
            # title "Get ready to add #{STOP_MIX} to #{LIGATION_SAMPLE.pluralize(MUTATIONS.length)} for #{unit}"
            title "Add #{STOP_MIX} #{from.bold} to each of #{op.input_refs(INPUT)[0].bold} to #{op.input_refs(INPUT)[-1].bold} in front of you."
            tube = closedtube.scale(0.75)
            tube.translate!(0, -50)
            tube = tube.g
            tube.g.boundx = 0
            labeled_tube = make_tube(closedtube, STOP_MIX, op.tube_label('stop'), 'medium', true)
            ligation_tubes = display_ligation_tubes(*op.input_tokens(INPUT), COLORS)
            ligation_tubes.align!('bottom-left')
            ligation_tubes.align_with(tube, 'bottom-right')
            ligation_tubes.translate!(50)
            transfer_image = make_transfer(labeled_tube, ligation_tubes, 300, "#{STOP_TO_SAMPLE_VOLUME}uL", "(#{P20_POST} pipette)")
            note display_svg(transfer_image, 0.75)
            to_labels.each do |l|
              check "Transfer #{STOP_TO_SAMPLE_VOLUME}uL from #{STOP_MIX.bold} into #{l.bold}. Discard tip, close cap."
            end
          end
        else
          to_labels.each.with_index do |label, i|
            show do
              raw transfer_title_proc(STOP_TO_SAMPLE_VOLUME, from, label)
              # title "Add #{STOP_TO_SAMPLE_VOLUME}uL #{STOP_MIX} #{from.bold} to #{LIGATION_SAMPLE} #{label}"
              note "Set a #{P20_POST} pipette to [0 4 0]. Add #{STOP_TO_SAMPLE_VOLUME}uL from #{from.bold} into tube #{label.bold}"
              note "Close tube #{label}."
              note 'Discard pipette tip.'
              tubeS = make_tube(opentube, STOP_MIX, op.tube_label('stop'), 'medium')
              transfer_image = transfer_to_ligation_tubes_with_highlight(
                tubeS, i, *op.input_tokens(INPUT), COLORS, STOP_TO_SAMPLE_VOLUME, "(#{P20_POST} pipette)"
              )
              note display_svg(transfer_image, 0.75)
            end
          end
        end
      end
    end

    show do
      title "Vortex and centrifuge all #{operations.size * PREV_COMPONENTS.size} tubes for 5 seconds."
      check 'Vortex for 5 seconds.'
      check 'Centrifuge for 5 seconds.'
      warning 'This step is important to avoid FALSE POSITIVES.'
    end

    t = Table.new
    t.add_column('STEP', ['Initial Melt', 'Annealing'])
    t.add_column('TEMP', %w[95C 37C])
    t.add_column('TIME', ['30s', '4 min'])
    add_to_thermocycler('tube', myops.length * PREV_COMPONENTS.length, STOP_CYCLE, t, 'Stop Cycle')
  end

  def short_timer
    show do
      title 'Set timer for 6 minutes'
      check 'Set a timer for 6 minutes. This will notify you when the thermocycler is done.'
      timer initialize: { minute: 6 }
      check 'Click the "<b>play</b>" button on the left. Proceed to next step now.'
    end
  end

  def display_detection_strip_diagram
    show do
      title "Review #{STRIP} diagram"
      note 'In the next steps you will be adding ligation mixtures followed by the gold solutions to the detection strips.'
      note 'You will pipette into the <b>Port</b>. After pipetting, you should see the <b>Reading Window</b> become wet after a few minutes.'
      warning 'Do not add liquid directly to the <b>Reading Window</b>'
      note display_svg(detection_strip_diagram, 0.75)
    end
  end

  def add_ligation_product_to_strips(myops)
    gops = group_packages(myops)

    show do
      title 'Wait for stop cycle to finish (5 minutes).'
      note "Wait for the #{THERMOCYCLER} containing your samples to finish. "
      bullet "If the #{THERMOCYCLER} beeps, it is done. If not, continue waiting."
      warning "Once the #{THERMOCYCLER} finishes, <b>IMMEDIATELY</b> continue to the next step."
      check "Take #{pluralizer('sample', myops.length * PREV_COMPONENTS.length)} from the #{THERMOCYCLER}."
      check "Vortex #{'sample'.pluralize(PREV_COMPONENTS.length)} for 5 seconds to mix."
      check "Centrifuge #{'sample'.pluralize(PREV_COMPONENTS.length)} for 5 seconds to pull down liquid"
      check "Place on rack in the #{POST_PCR.bold} area."
    end

    timer_set = false
    gops.each do |_unit, ops|
      ops.each do |op|
        kit = op.temporary[:output_kit]
        sample = op.temporary[:output_sample]
        panel_unit = op.temporary[:output_unit]
        tube_unit = op.temporary[:input_unit]
        # show do
        #   title "Arrange #{STRIPS} and tubes" # for sample 1?
        #   note "Place the detection #{STRIPS} and #{LIGATION_SAMPLE.pluralize(PREV_COMPONENTS.length)} as shown in the picture:"
        #   note display_svg(display_panel_and_tubes(kit, panel_unit, tube_unit, PREV_COMPONENTS, sample, COLORS).translate!(50), 0.6)
        # end

        # Validate samples
        from_name = "#{op.temporary[:input_unit]}-#{op.temporary[:input_sample]}"
        to_name = "#{op.temporary[:output_unit]}-#{op.temporary[:output_sample]}"
        svg_both = display_panel_and_tubes(kit, panel_unit, tube_unit, PREV_COMPONENTS, sample, COLORS).translate!(50).scale!(0.8)
        p = proc do
          # CONFIRM THIS WITH JORDAN
          title "Arrange #{STRIPS} and tubes for sample #{op.temporary[:input_sample]}" # for sample 1?
          note "Place the #{STRIPS} #{to_name} and #{LIGATION_SAMPLE.pluralize(PREV_COMPONENTS.length)} #{from_name} as shown in the picture:"
          note 'Scan in IDS of objects for confirmation.'
        end
        content = ShowBlock.new(self).run(&p)
        pre_transfer_validation_with_multiple_tries(from_name, to_name, svg_both, content_override: content)

        show do
          title "From each corresponding tube (as seen above), add #{SAMPLE_TO_STRIP_VOLUME}uL of #{LIGATION_SAMPLE} to the corresponding sample port of each #{STRIP}."
          unless timer_set
            note '<h2>Complicated Step! Take note of all instructions before beginning transfers.</h2>'
            note 'Set a 5 minute timer after adding the ligation sample to the <b>FIRST</b> strip at the SAMPLE PORT.'
            note '<b>Immediately</b> click OK when finished adding the ligation sample to the <b>LAST</b> strip at the sample port.' 
          end
          note '<hr>'
          timer_set = true
          #   check "Set a 5 minute timer" unless set_timer
          check "Set a #{P200_POST} pipette to [0 2 4]. Add #{SAMPLE_TO_STRIP_VOLUME}uL of <b>each</b> #{LIGATION_SAMPLE} to the corresponding #{STRIP}."
          note "Match the sample tube color with the #{STRIP} color. For example, match #{op.input_refs(INPUT)[0].bold} to #{op.output_refs(OUTPUT)[0].bold}"
          #   note "After adding the first sample, set the timer for 5 minutes"
          warning 'Dispose of pipette tip and close tube after each strip.'
          tubes = display_ligation_tubes(*op.input_tokens(INPUT), COLORS, (0..PREV_COMPONENTS.length - 1).to_a, [], 90)
          panel = display_strip_panel(*op.output_tokens(OUTPUT), COLORS)
          tubes.align_with(panel, 'center-bottom')
          tubes.align!('center-top')
          tubes.translate!(50, -50)
          img = SVGElement.new(children: [panel, tubes], boundy: 330, boundx: panel.boundx)
          note display_svg(img, 0.6)
        end
      end
    end
  end

  def rehydrate_gold_solution(myops)
    gops = group_packages(myops)
    gops.each do |_unit, ops|
      from = ops.first.ref('diluent A')
      to = ops.first.ref('gold')

      show do
        raw transfer_title_proc(GOLD_VOLUME, from, to)
        # title "Add #{GOLD_VOLUME}uL of #{DILUENT_A} #{from.bold} to #{GOLD_MIX} #{to.bold}"
        raw centrifuge_proc(GOLD_MIX, [to], CENTRIFUGE_TIME, 'to pull down dried powder.', AREA)
        note "Set a #{P1000_POST} pipette to <b>[ 0 6 7 ]</b>. Add #{GOLD_VOLUME}uL from #{from.bold} into tube #{to.bold}."
        raw vortex_proc(GOLD_MIX, [to], '10 seconds', 'to mix well.')
        warning "Make sure #{GOLD_MIX} is fully dissolved."
        warning "Do not centrifuge #{to.bold} after vortexing."
        tubeA = make_tube(opentube, DILUENT_A, ops.first.tube_label('diluent A'), 'medium')
        tubeG = make_tube(opentube, GOLD_MIX, ops.first.tube_label('gold'), 'powder', fluidclass: 'pinkfluid')
        img = make_transfer(tubeA, tubeG, 300, "#{GOLD_VOLUME}uL", "(#{P1000_POST} pipette)")
        img.translate!(20)
        note display_svg(img, 0.75)
      end
    end
  end

  def add_gold_solution(myops)
    gops = group_packages(myops)
    set_timer = false

    show do
      title 'Wait until 5 minute timer ends'
      warning 'Do not proceed before 5 minute timer is up.'
      note 'The strips need a chance to become fully wet.'
    end

    gops.each do |_unit, ops|
      show do
        title "Add gold solution to #{pluralizer(STRIP, PREV_COMPONENTS.length * ops.length)}"
        note 'Set a 10 minute timer after adding gold to <b>FIRST</b> strip at the SAMPLE PORT.'
        note 'Add gold to the rest of strips at the SAMPLE PORT and then <b>immediately</b> click OK.'
        warning 'DO NOT add gold solution onto the reading window.'
        note '<hr>'
        check "Set a #{P200_POST} pipette to <b>[0 4 0]</b>. Transfer #{GOLD_TO_STRIP_VOLUME}uL of #{GOLD_MIX} #{ops.first.ref('gold').bold} to #{pluralizer(STRIP, PREV_COMPONENTS.length * ops.length)} at the SAMPLE PORT."
        grid = SVGGrid.new(ops.length, ops.length, 50, 50)
        ops.each.with_index do |op, i|
          _tokens = op.output_tokens(OUTPUT)
          grid.add(display_strip_panel(*_tokens, COLORS).scale!(0.5).translate!(0, -50), i, i)
        end
        tubeG = make_tube(opentube, GOLD_MIX, ops.first.tube_label('gold'), 'medium', fluidclass: 'pinkfluid')
        img = make_transfer(tubeG, grid, 300, "#{GOLD_TO_STRIP_VOLUME}uL", '(each strip)')
        img.boundx = 900
        img.boundy = 400
        img.translate!(40)
        note display_svg(img, 0.6)
      end
    end
  end

  def read_from_scanner(myops)
    gops = group_packages(myops)
    show do
      title "Bring #{pluralizer(STRIP, myops.length * PREV_COMPONENTS.length)} to the #{PHOTOCOPIER}."
    end

    show do
      title 'Wait until 10 minute timer is up'
      note "#{STRIPS.capitalize} need to rest for 10 minutes before taking an image."
      check "In the meantime, make sure you have access to the #{PHOTOCOPIER}."
      note 'Signal can develop more slowly if the room is humid. After the 10-min timer ends, you should see at least two lines on each strip.'
      note 'If your signal is hard to see by eye, give it another 5 minutes before clicking OK.'
      note 'Do not continue to the next step until signal is visible.'
    end

    # show do
    #   title "IMPORTANT NOTE TO JUSTIN"
    #   warning "This protocol should be broken into two since technician will be moving from one computer to the next."
    #   note "This really depends on whether we want to use the laptop ONLY for detection purposes (I think we should)"
    # end

    myops.each do |op|
      op.temporary[:filename] = "#{op.output(OUTPUT).item.id}_#{op.temporary[:output_kit]}#{op.temporary[:output_sample]}"
    end

    gops.each do |_unit, ops|
      ops.each do |op|
        labels = op.output_refs(OUTPUT)
        show do
          title "Scan #{STRIPS} <b>#{labels[0]} to #{labels[-1]}</b>"
          check "Open #{PHOTOCOPIER}"
          check "Place #{STRIPS} face down in the #{PHOTOCOPIER}"
          check "Align colored part of #{STRIPS} with the colored tape on the #{PHOTOCOPIER}"
          check "Close the #{PHOTOCOPIER}"
        end

        image_confirmed = false

        5.times.each do |_this_try|
          next if image_confirmed

          show do
            title 'Scan the image'
            check "Press the <b>\"AUTO SCAN\"</b> button firmly on the side of the #{PHOTOCOPIER} and hold for a few seconds. A new window should pop up, with a green bar indicating scanning in progress."
            check "Wait for #{PHOTOCOPIER} to complete. This takes about 1 minute."
          end

          rename = '<md-button ng-disabled="true" class="md-raised">rename</md-button>'
          copy = '<md-button ng-disabled="true" class="md-raised">copy</md-button>'
          paste = '<md-button ng-disabled="true" class="md-raised">paste</md-button>'

          show do
            title "Copy image file name #{op.temporary[:filename].bold}"
            note "1. highlight the file name: #{op.temporary[:filename].bold}"
            note "2. then click #{copy}"
            title "Then rename the new image file to #{op.temporary[:filename].bold}"
            note '1. a new file should appear on the desktop. Minimize this browser and find the new file.'
            note "2. right-click and then click #{rename}"
            note "3. right-click and click #{paste} to rename file."
          end

          show_with_expected_uploads(op, op.temporary[:filename], SCANNED_IMAGE_UPLOAD_KEY) do
            title "Upload file <b>#{op.temporary[:filename]}</b>"
            note "Click the button below to upload file <b>#{op.temporary[:filename]}</b>"
            note "Navigate to the desktop. Click on file <b>#{op.temporary[:filename]}</b>"
          end

          op.temporary[SCANNED_IMAGE_UPLOAD_KEY] = Upload.find(DEBUG_UPLOAD_ID) if debug # false upload if debug

          confirmed = show do
            title "Confirm image labels say #{op.temporary[:label_string].bold}"
            select %w[yes no], var: 'confirmed', label: 'Do the image labels and your image match?', default: 0
            img = display_strip_panel(*op.output_tokens(OUTPUT), COLORS).g
            img.boundy = 50
            note display_svg(img, 0.75)
            raw display_upload(op.temporary[SCANNED_IMAGE_UPLOAD_KEY])
          end

          image_confirmed = confirmed[:confirmed] == 'yes'

          next if image_confirmed

          show do
            title "You selected that the images don't match!"
            note 'You will now be asked to scan and upload the strip again.'
          end
        end

        op.associate(SCANNED_IMAGE_UPLOAD_ID_KEY, op.temporary[SCANNED_IMAGE_UPLOAD_KEY].id)
        op.output(OUTPUT).item.associate(SCANNED_IMAGE_UPLOAD_ID_KEY, op.temporary[SCANNED_IMAGE_UPLOAD_KEY].id)
      end
    end
  end

  def discard_things(myops)
    def discard_refs_from_op(op)
      refs = []
      refs.push('Diluent A ' + op.ref('diluent A').bold)
      refs.push('Gold Mix ' + op.ref('gold').bold)
      refs.push('Stop Mix ' + op.ref('stop').bold)
      refs.push("Samples #{op.input_refs(INPUT).join(', ').bold}")
      refs.push("Strips #{op.output_refs(OUTPUT).join(', ').bold}")
      refs
    end

    all_refs = myops.map { |op| discard_refs_from_op(op) }.flatten.uniq

    show do
      title "Throw items into the #{WASTE_POST}"

      note "Throw the following items into the #{WASTE_POST} in the #{AREA.bold} area:"
      t = Table.new
      t.add_column('Item to throw away', all_refs)
      table t
    end
  end

  def filename(op)
    item_id = op.output(OUTPUT).item.id
    labels = op.output_refs(OUTPUT)
    "#{labels[0]}_#{labels[-1]}_#{item_id}"
  end

  def conclusion(_myops)
    show do
      title 'Thank you!'
      note 'Thank you for your hard work.'
    end
  end

  def analysis(ops)
    band_choices = {
      "M": { bands: [mut_band], description: '-CTRL -WT +MUT' },
      "N": { bands: [control_band, wt_band, mut_band], description: '+CTRL +WT +MUT' },
      "O": { bands: [control_band, mut_band], description: '+CTRL -WT +MUT' },
      "P": { bands: [control_band, wt_band], description: '+CTRL +WT -MUT' },
      "Q": { bands: [control_band], description: '+CTRL -WT -MUT' },
      "R": { bands: [], description: '-CTRL -WT -MUT' }
    }

    categories = {
      "M": POSITIVE,
      "N": POSITIVE,
      "O": POSITIVE,
      "P": NEGATIVE,
      "Q": 'ligation failure',
      "R": 'detection failure'
    }

    run_image_analysis ops.running, band_choices, categories
    show_calls ops.running, band_choices
    show_summary ops.running
  end

  def run_image_analysis(ops, _band_choices, category_hash)
    ops.each do |op|
      image_result = nil
      5.times.each do |_i|
        break if image_result

        upload = op.temporary[SCANNED_IMAGE_UPLOAD_KEY]
        image_result = make_calls_from_image(upload)
      end

      if image_result.nil?
        op.error(:image_result_failed, 'Image processing has failed. Check that the OLA IP service is running and connected correctly, and that the file is in a normal image format.')
        next
      end

      this_kit = op.temporary[:output_kit]
      this_unit = op.temporary[:output_unit]
      this_sample = op.temporary[:output_sample]

      raise 'scanned image had less strips than expected!' if PREV_COMPONENTS.size > image_result.size && !debug
      raise 'scanned image had more strips than expected!' if PREV_COMPONENTS.size < image_result.size && !debug

      PREV_COMPONENTS.each.with_index do |_this_component, i|
        alias_label = op.output_refs(OUTPUT)[i]
        the_choice = image_result[i]
        op.output(OUTPUT).item.associate(make_call_key(alias_label), the_choice)
        op.output(OUTPUT).item.associate(make_call_category_key(alias_label), category_hash[the_choice.to_sym])
        op.associate(make_call_key(alias_label), the_choice)
        op.associate(make_call_category_key(alias_label), category_hash[the_choice.to_sym])
      end
    end
  end

  def make_call_key(alias_label)
    "#{alias_label}_call".to_sym
  end

  def make_call_description_key(alias_label)
    "#{alias_label}_call_description".to_sym
  end

  def make_call_category_key(alias_label)
    "#{alias_label}_call_category".to_sym
  end

  def show_calls(myops, band_choices)
    myops.each do |op|
      kit_summary = {}

      this_kit = op.temporary[:input_kit]
      this_item = op.output(OUTPUT).item
      this_unit = op.temporary[:output_unit]
      this_sample = op.temporary[:output_sample]

      grid = SVGGrid.new(MUTATION_LABELS.length, 1, 90, 10)
      categories = []

      PREV_COMPONENTS.each.with_index do |this_component, i|
        alias_label = op.output_refs(OUTPUT)[i]
        strip_label = tube_label(this_kit, this_unit, this_component, this_sample)
        strip = make_strip(strip_label, COLORS[i] + 'strip')
        band_choice = this_item.get(make_call_key(alias_label))
        codon_label = label(MUTATION_LABELS[i], 'font-size'.to_sym => 25)
        codon_label.align_with(strip, 'center-bottom')
        codon_label.align!('center-top').translate!(0, 30)
        category = this_item.get(make_call_category_key(alias_label))
        kit_summary[MUTATION_LABELS[i]] = { alias: alias_label, category: category.to_s, call: band_choice.to_s }
        tokens = category.split(' ')
        tokens.push('') if tokens.length == 1
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
      op.output(OUTPUT).item.associate(:results, kit_summary)
      op.temporary[:results] = kit_summary

      img = SVGElement.new(children: [grid], boundx: PREV_COMPONENTS.size * 100, boundy: 350)
      img.translate!(15)
      show do
        refs = op.output_refs(OUTPUT)
        title "Here is the summary of your results for <b>#{refs[0]} to #{refs[-1]}</b>"
        note display_svg(img)
      end
    end
  end

  def show_summary(ops)
    ops.each do |op|
      hits = op.temporary[:results].select { |_k, v| v == POSITIVE }
    end
    show do
      title 'Sample summary'
      note "You analyzed #{ops.length} #{'kit'.pluralize(ops.length)}. Below is the exportable summarized data if you need it."

      results_hash = {}
      kits = ops.map { |op| op.output(OUTPUT).item.get(KIT_KEY) }
      samples = ops.map { |op| op.output(OUTPUT).item.get(SAMPLE_KEY) }
      patients = ops.map { |op| op.output(OUTPUT).item.get(PATIENT_KEY) }
      t = Table.new
      t.add_column('Kit', kits)
      t.add_column('Sample', samples)
      t.add_column('Patient ID', patients)
      MUTATION_LABELS.each do |label|
        col = ops.map { |op| op.temporary[:results][label][:category] }
        t.add_column(label, col)
        results_hash[label] = col
      end
      results_hash['kits'] = kits
      results_hash['samples'] = samples
      table t
    end
  end
end
