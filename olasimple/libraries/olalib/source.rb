# frozen_string_literal: true

# Library code here
# category = "Tissue Culture Libs"
# needs "#{category}/TissueCulture"
needs 'OLASimple/OLAConstants'
needs 'OLASimple/OLAGraphics'
needs 'OLASimple/NetworkRequests'

module TextExtension
  include ActionView::Helpers::TagHelper

  def bold
    content_tag(:b, to_s)
  end

  def ital
    content_tag(:i, to_s)
  end

  def strong
    content_tag(:strong, to_s)
  end

  def color(which_color)
    content_tag(:font, to_s, color: which_color)
  end

  def cap
    remaining = ''
    remaining = self[1..-1] if length > 1
    self[0].capitalize + remaining
  end

  def quote
    "\"#{self}\""
  end
end

module RefExtension
  include OLAConstants
  # this requires :output_kit, :output_unit, :output_sample, and :pack_hash temporary values
  # references require :kit, :unit, :component, and :sample keys

  def sort_by(&block)
    super(&block).extend(OperationList)
  end

  def component(name)
    temporary[:pack_hash][COMPONENTS_FIELD_VALUE][name]
  end

  def input_component(name)
    get_input_item_helper(name).get(COMPONENT_KEY)
  end

  def output_component(name)
    get_output_item_helper(name).get(COMPONENT_KEY)
  end

  def ref(name, with_sample = false)
    # returns the label for a temporary item by name
    t = temporary
    c = component(name)
    kit = t[:output_kit]
    unit = t[:output_unit]
    # samp = t[:output_sample]
    samp = ''
    samp = t[:output_sample] if with_sample
    alias_helper(kit, unit, c, samp)
  end

  def tube_label(name, with_sample = false)
    label_helper(*ref_tokens(name, with_sample))
  end

  def label_helper(_k, u, c, s)
    ["#{u}#{c}", s.to_s]
  end

  def input_tube_label(name)
    label_helper(*input_tokens(name))
  end

  def output_tube_label(name)
    label_helper(*output_tokens(name))
  end

  # TOKENS
  def ref_tokens(name, with_sample = false)
    # return array for kit-unit and component-sample, usually for labeling purposes
    t = temporary
    c = component(name)
    kit = t[:output_kit]
    unit = t[:output_unit]
    samp = '' # t[:output_sample]
    samp = t[:output_sample] if with_sample
    [kit, unit, c, samp]
  end

  def ref_tokens_helper(item)
    [item.get(KIT_KEY), item.get(UNIT_KEY), item.get(COMPONENT_KEY), item.get(SAMPLE_KEY)]
  end

  def input_tokens(name)
    ref_tokens_helper(get_input_item_helper(name))
  end

  def output_tokens(name)
    ref_tokens_helper(get_output_item_helper(name))
  end

  def alias_helper(_kit, unit, component, sample)
    # returns the label given kit, unit, comp and sample
    if !sample.blank?
      "#{unit}#{component}-#{sample}"
    else
      "#{unit}#{component}"
    end
  end

  def ref_helper(item)
    # returns the label for an item
    alias_helper(*ref_tokens_helper(item))
  end

  def refs_helper(item)
    # returns an array of labels for a collection
    components = item.get(COMPONENT_KEY)
    raise 'Components must be an array to use refs_helper' unless components.is_a?(Array)

    components.map do |c|
      alias_helper(item.get(KIT_KEY), item.get(UNIT_KEY), c, item.get(SAMPLE_KEY))
    end
  end

  def get_input_item_helper(name)
    input = self.input(name)
    raise "Could not find input field_value #{name}" if input.nil?

    item = input(name).item
    raise "Input #{name} has no item" if item.nil?

    item
  end

  def get_output_item_helper(name)
    output = self.output(name)
    raise "Could not find output field_value \"#{name}\"" if output.nil?

    item = output(name).item
    raise "Output \"#{name}\" has no item" if item.nil?

    item
  end

  def input_ref(name)
    # return the label for an input
    ref_helper(get_input_item_helper(name))
  end

  def input_ref_tokens(name)
    # return the label for an input
    ref_tokens_helper(get_input_item_helper(name))
  end

  def output_ref(name)
    # return the label for an output
    ref_helper(get_output_item_helper(name))
  end

  def output_ref_tokens(name)
    # return the label for an input
    ref_tokens_helper(get_output_item_helper(name))
  end

  def input_refs(name)
    # return the array of labels for an input
    refs_helper(get_input_item_helper(name))
  end

  def output_refs(name)
    # return the array of labels for an output
    refs_helper(get_output_item_helper(name))
  end

  def make_alias_from_pack_hash(output_item, package_name, from_item)
    kit = temporary[:output_kit]
    unit = temporary[:output_unit]
    component = self.component(package_name)
    sample = temporary[:output_sample]
    patient = temporary[:patient]

    raise 'Kit is nil' if kit.nil?
    raise 'Unit is nil' if unit.nil?
    raise 'Component is nil' if component.nil?
    raise 'Sample is nil' if sample.nil?
    raise 'Patient ID is nil' if patient.nil?

    output_item.associate(KIT_KEY, kit)
    output_item.associate(UNIT_KEY, unit)
    output_item.associate(COMPONENT_KEY, component)
    output_item.associate(SAMPLE_KEY, sample)
    output_item.associate(PATIENT_KEY, patient)
    output_item.associate(ALIAS_KEY, ref_helper(output_item))

    # from associations
    output_item.associate(:from, input(from_item).item.id)
    output_item.associate(:fromref, input_ref(from_item))
    output_item.associate(:from_pack, "#{temporary[:input_unit]}#{temporary[:input_kit]}")
    output_item
  end

  def make_item_and_alias(name, package_name, from_item)
    output(name).make
    output_item = output(name).item
    make_alias_from_pack_hash(output_item, package_name, from_item)
  end

  def make_collection_and_alias(name, package_name, from_item)
    output_collection = output(name).make_collection
    components = component(package_name)
    components.each do |_c|
      output_collection.add_one(output(name).sample)
    end
    output_item = output(name).item
    make_alias_from_pack_hash(output_item, package_name, from_item)
  end
end

module OLALib
  include OLAConstants
  include NetworkRequests
  include OLAGraphics
  include FunctionalSVG

  String.prepend TextExtension
  Integer.prepend TextExtension
  Float.prepend TextExtension
  Operation.prepend RefExtension
  #   include TissueCulture

  #######################################
  # OLA image processing API
  #######################################

  # TODO: add error handling to this function, since function could fail if api service disconnected
  def make_calls_from_image(image_upload)
    response = post_file(OLA_IP_API_URL, 'file', image_upload)
    results = JSON.parse(response.body)['results']
    if results.blank?
      raise 'Automatic Visual Call failed. Missing or unprocessible image.'
    else
      return results
    end
  end

  #######################################
  # Utilities
  #######################################

  def pluralizer(noun, num)
    if num == 1
      "the #{noun.pluralize(num)}"
    elsif num == 2
      "both #{noun.pluralize(num)}"
    else
      "all #{num} #{noun.pluralize(num)}"
    end
  end

  def group_by_unit(ops)
    ops.running.group_by { |op| op.temporary[:unit] }
  end

  def get_technician_name(job_id)
    job = Job.find(job_id)
    user_id = job.user_id
    username = '"unknown user"'
    username = User.find(job.user_id).name unless user_id.nil?
    username
  end

  ####################################
  # Item Alias
  ####################################

  def alias_helper(_kit, unit, component, sample)
    # returns the label given kit, unit, comp and sample
    if !sample.blank?
      "#{unit}#{component}-#{sample}"
    else
      "#{unit}#{component}"
    end
  end

  def make_alias(item, kit, unit, component, patient, sample = nil)
    sample ||= ''
    label = alias_helper(kit, unit, component, sample)
    item.associate(ALIAS_KEY, label)
    item.associate(KIT_KEY, kit)
    item.associate(UNIT_KEY, unit)
    item.associate(COMPONENT_KEY, component)
    item.associate(SAMPLE_KEY, sample)
    item.associate(PATIENT_KEY, patient)
  end

  def get_alias_array(item)
    [item.get(KIT_KEY), item.get(UNIT_KEY), item.get(COMPONENT_KEY), item.get(SAMPLE_KEY), item.get(PATIENT_KEY)]
  end

  def ref(item)
    "#{item.get(UNIT_KEY)}#{item.get(COMPONENT_KEY)}-#{item.get(SAMPLE_KEY)}"
  end

  def save_temporary_input_values(ops, input)
    # get the aliases from the inputs
    ops.each do |op|
      kit, unit, component, sample, patient = get_alias_array(op.input(input).item)
      op.temporary[:patient] = patient
      op.temporary[:input_kit] = kit
      op.temporary[:input_unit] = unit
      op.temporary[:input_component] = component
      op.temporary[:input_sample] = sample
      op.temporary[:input_kit_and_unit] = [kit, unit].join('')
    end
  end

  def save_pack_hash(ops, pack)
    ops.running.each do |op|
      op.temporary[:pack_hash] = get_pack_hash(op.input(pack).sample)
    end
  end

  def save_temporary_output_values(myops)
    myops.each do |op|
      op.temporary[:output_kit] = op.temporary[:input_kit]
      op.temporary[:output_unit] = op.temporary[:pack_hash][UNIT_NAME_FIELD_VALUE]
      op.temporary[:output_sample] = op.temporary[:input_sample]
      op.temporary[:output_kit_and_unit] = [op.temporary[:output_kit], op.temporary[:output_unit]].join('')
      op.temporary[:output_number_of_samples] = op.temporary[:pack_hash][NUM_SAMPLES_FIELD_VALUE]
    end
  end

  def group_packages(myops)
    myops.group_by { |op| "#{op.temporary[:output_kit]}#{op.temporary[:output_unit]}" }
  end

  ####################################
  # Collection Alias
  ####################################

  def make_array_association(item, label, data)
    raise 'must be an item not a collection for array associations' unless item.is_a?(Item)

    data.each.with_index do |d, i|
      item.associate("#{label}#{i}".to_sym, d)
    end
  end

  def get_array_association(item, label, i)
    item.get("#{label}#{i}".to_sym)
  end

  ####################################
  # Kit and Package Parser
  ####################################

  def parse_component(component_string)
    # parses the component value for a OLASimple Package sample
    # values are formatted as "key: value" or "key: [val1, val2, val3]"
    val = nil
    tokens = component_string.split(/\s*\:\s*/)
    m = /\[(.+)\]/.match(tokens[1])
    if !m.nil?
      arr_str = m[1]
      val = arr_str.split(/\s*,\s*/).map(&:strip)
    else
      val = tokens[1]
    end
    [tokens[0], val]
  end

  def get_component_dictionary(package_sample)
    # parses all of the components in a OLASimple Package
    components = package_sample.properties[COMPONENTS_FIELD_VALUE]
    components.map { |v| [*parse_component(v)] }.to_h
  end

  def get_pack_hash(sample)
    pack_hash = {}
    # get the properties for the output pack sample
    pack_hash = sample.properties

    # parse the component values, formatted as "key: value" or "key: [val1, val2, val3]"
    pack_hash[COMPONENTS_FIELD_VALUE] = get_component_dictionary(sample)
    pack_hash
  end

  def get_kit_hash(op)
    kit_hash = {}
    # validates that input and output kits sample definitions are formatted correctly
    [SAMPLE_PREP_FIELD_VALUE, PCR_FIELD_VALUE, LIGATION_FIELD_VALUE, DETECTION_FIELD_VALUE].each do |x|
      # validate that the input kit is the same as the expected output kits
      output_sample = op.output(x).sample
      kit_hash[x] = get_pack_hash(output_sample)
    end

    kit_hash
  end

  def kit_hash_to_json(kit_hash)
    h = kit_hash.map { |k, v| [k, v.reject { |key, _val| key == KIT_FIELD_VALUE }] }.to_h
    JSON.pretty_generate(h)
  end

  def validate_kit_hash(op, kit_hash)
    # validates the kit hash
    errors = []

    kit_hash.each do |pack_name, pack_properties|
      if pack_properties.empty?
        errors.push(["components_empty_for_#{pack_name}".to_sym, 'Package components are empty!'])
      end

      if pack_properties[KIT_FIELD_VALUE] != op.input(KIT_FIELD_VALUE).sample
        errors.push(["kit_not_found_in_input_for_#{pack_name}".to_sym, 'Input kit does not match output package definition.'])
      end
    end

    kit_sample = op.input(KIT_FIELD_VALUE).sample
    kit_sample_props = kit_sample.properties
    num_codons = kit_sample_props[CODONS_FIELD_VALUE].length
    num_codon_colors = kit_sample_props[CODON_COLORS_FIELD_VALUE].length
    num_ligation_tubes = kit_hash[LIGATION_FIELD_VALUE][COMPONENTS_FIELD_VALUE]['sample tubes'].length
    num_strips = kit_hash[DETECTION_FIELD_VALUE][COMPONENTS_FIELD_VALUE]['strips'].length

    if debug
      show do
        title 'DEBUG: Kit Hash Errors'
        errors.each do |k, v|
          note "#{k}: #{v}"
        end
      end
    end

    errors.each do |k, v|
      op.error(k, v)
    end

    if debug
      show do
        title 'DEBUG: Kit Hash'
        note kit_hash_to_json(kit_hash).to_s
        # note "#{kit_hash}"
      end
    end
  end

  ####################################
  # Step Utilities
  ####################################

  def ask_if_expert
    resp = show do
      title 'Expert Mode?'
      note 'Are you an expert at this protocol? If you do not know what this means, then continue without enabling expert mode.'
      select ['Continue in normal mode', 'Enable expert mode'], var: :choice, label: 'Expert Mode?', default: 0
    end
    resp[:choice] == 'Enable expert mode'
  end

  def wash_self
    show do
      title 'Discard gloves and wash hands'
      check "After clicking #{'OK'.quote.bold}, discard your gloves and wash your hands with soap."
    end
  end

  def check_for_tube_defects(_myops)
    # show do
    defects = show do
      title 'Check for cracked or damaged tubes.'
      select %w[No Yes], var: 'cracked', label: 'If there are cracks or defects in the tube, select "Yes" from the dropdown menu below.', default: 0
      note "If yes, #{SUPERVISOR} will replace the samples or tubes for you."
    end

    if defects['cracked'] == 'Yes'
      show do
        title "Contact #{SUPERVISOR} about missing or damaged tubes."

        note 'You said there are some problems with the samples.'
        check "Contact #{SUPERVISOR} about this issue."
        note 'We will simply replace these samples for you.'
      end
    end
  end

  def area_preparation(which_area, materials, other_area)
    show do
      title "#{which_area.cap} preparation"

      note "You will be doing the protocol in the #{which_area.bold} area"
      warning "Keep all materials in the #{which_area.bold} area separate from the #{other_area.bold} area"
      note "Before continuing, make sure you have the following items in the #{which_area.bold} area:"
      materials.each do |i|
        check i
      end
    end
  end

  def put_on_ppe(which_area)
    show do
      title 'Put on Lab Coat and Gloves'

      check 'Put on a lab coat'
      warning "make sure lab coat is from the #{which_area.bold}"
      check 'Put on a pair of latex gloves.'
    end
  end

  def transfer_title_proc(vol, from, to)
    p = proc do
      title "Add #{vol}uL from #{from.bold} to #{to.bold}"
    end
    ShowBlock.new(self).run(&p)
  end

  def show_open_package(kit, unit, num_sub_packages)
    show do
      title "Tear open #{kit.bold}#{unit.bold}"
      note 'Tear open all smaller packages.' if num_sub_packages > 0
      run(&Proc.new) if block_given?
      check 'Discard the packaging material.'
    end
  end

  def disinfect
    show do
      title 'Disinfect Items'
      check 'Spray and wipe down all reagent and sample tubes with 10% bleach.'
      check 'Spray and wipe down all reagent and sample tubes with 70% ethanol.'
    end
  end

  def centrifuge_proc(sample_identifier, sample_labels, time, reason, area, balance = false)
    if area == PRE_PCR
      centrifuge = CENTRIFUGE_PRE
    elsif area == POST_PCR
      centrifuge = CENTRIFUGE_POST
    else
      raise 'Invalid Area'
    end
    p = proc do
      check "Place #{sample_identifier.pluralize(sample_labels.length)} #{sample_labels.join(', ').bold} in the #{centrifuge}"
      check "#{CENTRIFUGE_VERB.cap} #{pluralizer(sample_identifier, sample_labels.length)} for #{time} #{reason}"
      if balance
        if num.even?
          warning "Balance tubes in the #{centrifuge} by placing #{num / 2} #{sample_identifier.pluralize(num / 2)} on each side."
        else
          warning "Use a spare tube to balance #{sample_identifier.pluralize(num)}."
        end
      end
    end
    ShowBlock.new(self).run(&p)
  end

  def vortex_proc(sample_identifier, sample_labels, time, reason)
    p = proc do
      # check "Vortex #{pluralizer(sample_identifier, num)} for #{time} #{reason}"
      check "Vortex #{sample_identifier.pluralize(sample_labels.length)} #{sample_labels.join(', ').bold} for #{time} #{reason}"
      # check "Vortex #{sample_identifier.pluralize(sample_labels.length)} #{sample_labels.map { |label| label.bold })}
    end
    ShowBlock.new(self).run(&p)
  end

  def centrifuge_helper(sample_identifier, sample_labels, time, reason, area, mynote = nil)
    sample_labels = sample_labels.uniq
    show do
      title "#{CENTRIFUGE_VERB.cap} #{sample_identifier.pluralize(sample_labels.length)} for #{time}"
      note mynote unless mynote.nil?
      warning "Ensure #{pluralizer('tube cap', sample_labels.length)} are closed before centrifuging."
      raw centrifuge_proc(sample_identifier, sample_labels, time, reason, area)
    end
  end

  def vortex_helper(sample_identifier,
                    sample_labels,
                    vortex_time,
                    vortex_reason, mynote = nil)
    num = sample_labels.length
    show do
      title "Vortex #{sample_identifier.pluralize(num)}"
      note mynote unless mynote.nil?
      warning "Close #{pluralizer('tube cap', sample_labels.length)}."
      raw vortex_proc(sample_identifier, sample_labels, vortex_time, vortex_reason)
    end
  end

  def vortex_and_centrifuge_helper(sample_identifier,
                                   sample_labels,
                                   vortex_time, spin_time,
                                   vortex_reason, spin_reason, area, mynote = nil)
    num = sample_labels.length
    show do
      title "Vortex and #{CENTRIFUGE_VERB} #{sample_identifier.pluralize(num)}"
      note mynote unless mynote.nil?
      warning "Close tube caps."
      # note "Using #{sample_identifier.pluralize(num)} #{sample_labels.join(', ').bold}:"
      raw vortex_proc(sample_identifier, sample_labels, vortex_time, vortex_reason)
      raw centrifuge_proc(sample_identifier, sample_labels, spin_time, spin_reason, area)
      check 'Place the tubes back on rack'
    end
  end

  def add_to_thermocycler(sample_identifier, sample_labels, program_name, program_table, name)
    len = if sample_labels.is_a?(Array)
            sample_labels.length
          else
            sample_labels
          end

    show do
      title "Run #{name}"
      check "Add #{pluralizer(sample_identifier, len)} to #{THERMOCYCLER}"
      check 'Close and tighten the lid.'
      check "Select the program named #{program_name.bold} under the <b>OS</b>"
      check 'Hit <b>"Run"</b> and click <b>"OK"</b>'
      table program_table
    end
  end

  def clean_area(area)
    show do
      disinfectant = '10% bleach'
      title "Wipe down #{area} with #{disinfectant.bold}."
      note "Now you will wipe down your #{area} space and equipment with #{disinfectant.bold}."
      check "Spray #{disinfectant.bold} onto a #{WIPE} and clean off pipettes and pipette tip boxes."
      check "Spray #{disinfectant.bold} onto a #{WIPE} and wipe down the bench surface."
      # check "Spray some #{disinfectant.bold} on a #{WIPE}, gently wipe down keyboard and mouse of this computer/tablet."
      warning "Do not spray 10% bleach directly onto tablet, computer, barcode scanner or centrifuge!"
      # check "Finally, spray outside of gloves with #{disinfectant.bold}."
    end

    show do
      disinfectant = '70% ethanol'
      title "Wipe down #{area} with #{disinfectant.bold}."
      note "Now you will wipe down your #{area} space and equipment with #{disinfectant.bold}."
      check "Spray #{disinfectant.bold} onto a #{WIPE} and clean off pipettes and pipette tip boxes."
      check "Spray #{disinfectant.bold} onto a #{WIPE} and wipe down the bench surface."
      note "Bleach residues can inhibit the assay. Make sure to completely wipe all surface with 70% ethanol spray"
      warning "Do not spray #{disinfectant.bold} onto tablet or computer!"
      # check "Finally, spray outside of gloves with #{disinfectant.bold}."
    end
  end

  def simple_clean(protocol)
    show do
      title 'Ensure Workspace is Clean'
      note "#{protocol} is prone to contamination. False positives can occur when the area is not clean."
      check "If area is not clean, or you aren't sure, wipe down space with 10% bleach and 70% ethanol."
      note 'Spray disinfectants onto wipes, not directly onto surfaces.'
      warning 'Only spray bleach and ethanol when all tubes are closed. Bleach can inhibit the reactions.'
    end
  end

  def area_setup(area, materials, other_area = nil)
    area_preparation area, materials, other_area
    put_on_ppe area
    clean_area area
  end

  def safety_warning(area = nil)
    grid = SVGGrid.new(3, 1, 200, 100)
    grid.add(gloves_svg, 0, 0)
    grid.add(coat_svg, 1, 0)
    img2 = SVGElement.new(children: [grid], boundx: 1000, boundy: 200)
    show do
      title 'Review Safety Warnings'
      note '<b>Always</b> pay attention to orange warning blocks throughout the protocol.'
      if area && area == PRE_PCR
        img1 = SVGElement.new(children: [bsc_svg], boundx: 200, boundy: 200)
        warning '<b>INFECTIOUS MATERIALS</b>'
        note 'You will be working with infectious materials.'
        note 'Do <b>ALL</b> work in a biosafety cabinet (BSC).'
        note display_svg(img1, 0.2)
      end
      note '<b>PPE is required</b>'
      note display_svg(img2, 0.2)
      check 'Put on lab coat.'
      check "Put on #{(area && area == PRE_PCR) ? 'layers of ' : ''}gloves."
      bullet 'Make sure to use tight gloves. Tight gloves reduce the chance of the gloves getting caught on the tubes when closing their lids.'
      if area && area == PRE_PCR
        bullet 'Change outer layer of gloves after handling infectious sample and before touching surfaces outside of the BSC (such as a refrigerator door handle).'
      end
    end
  end

  def gloves_svg
    icon_from_html(
      '<svg><title>3_gloveson</title><path d="M413,353c0-2.8-1.1-12.4-4-17.3s-10.8-22.1-10-27.2,1.2-16.4-.4-21.7-3.2-14-3.2-14-2.5-6.4,1.1-6.6,10.5,3.9,12.1,10.5,2.6,16.2,4.8,20.6c0,0,14-18.4,14.8-22.7s9.7-26.5,9.8-28,7.1-20.2,11-22.6,5.9-3.4,7.2-1.7a13.26,13.26,0,0,1,1.6,5.3s4-11.7,6.2-11.7c0,0,5.5-3.9,7.2,1.6a20.58,20.58,0,0,1-.2,11.2l-2.3,11.9c1.9-5.5,4.5-12.7,6-12.7,2.2,0,8.6-4,6.5,5.7-1.8,8.7-5.3,22.8-6,25.6h0c2.1-5.7,4.4-6.8,8.3-8.7s1.6,12.5,1.6,14.6-5.4,20.3-5.7,30.5-7.2,29.6-10.5,34.5-14.4,31.2-16.3,36.2,1.8,21.2-1.6,27.2-39.9-12.9-39.9-12.9S413,355.8,413,353Z" transform="translate(-305.22 -213.96)" fill="#b4b9de"/><path d="M420.9,306.2s-4.7-4.5-6.9-8.9-3.2-14-4.8-20.6-8.5-10.7-12.1-10.5-1.1,6.6-1.1,6.6,1.7,8.7,3.2,14,1.1,16.6.4,21.7,7.1,22.2,10,27.2,4,14.5,4,17.3-2,27.8-2,27.8,36.4,18.9,39.9,12.9-.3-22.2,1.6-27.2,13-31.3,16.3-36.2,10.2-24.3,10.5-34.5,5.7-28.5,5.7-30.5,2.3-16.5-1.6-14.6-6.4,3-8.5,9.2-3.2,18.2-4.6,21.7-1.2,8.5-1.2,8.5" transform="translate(-305.22 -213.96)" fill="none" stroke="#2e3192" stroke-miterlimit="10"/><path d="M414,297.3s14-18.4,14.8-22.7,9.7-26.5,9.8-28,7.1-20.2,11-22.6,5.9-3.4,7.2-1.7a13.26,13.26,0,0,1,1.6,5.3,14.65,14.65,0,0,1-1.1,8c-2.4,4.7-10.6,26.7-11.5,32s-1.5,8.6-1.5,8.6" transform="translate(-305.22 -213.96)" fill="none" stroke="#2e3192" stroke-miterlimit="10"/><path d="M456.8,278.9s9.2-30.5,10.5-32.8,5.9-18.4,8.1-18.4,8.6-4,6.5,5.7-6.2,26.2-6.2,26.2" transform="translate(-305.22 -213.96)" fill="none" stroke="#2e3192" stroke-miterlimit="10"/><path d="M458.4,227.5s4-11.7,6.2-11.7c0,0,5.5-3.9,7.2,1.6a20.58,20.58,0,0,1-.2,11.2l-2.3,11.9" transform="translate(-305.22 -213.96)" fill="none" stroke="#2e3192" stroke-miterlimit="10"/><path d="M384.9,353.1c0-2.6,1.1-11.6,4.3-16s11.5-20,10.7-24.8-1.4-15.5.3-20.3a129.68,129.68,0,0,0,3.4-12.9s2.6-5.9-1.2-6.2-11.3,2.9-13,9-2.7,15.1-5.1,19c0,0-15.2-18.2-16-22.3s-10.6-25.5-10.6-27-7.7-19.5-11.9-22-6.3-3.6-7.7-2.1a10.09,10.09,0,0,0-1.7,4.8s-4.3-11.3-6.7-11.4c0,0-5.9-4-7.7,1s.3,10.5.3,10.5l2.5,11.3c-2.1-5.3-4.9-12.3-6.5-12.4-2.4-.2-9.2-4.4-7,4.9,2,8.3,5.8,21.8,6.6,24.5h0c-2.2-5.5-4.8-6.7-8.9-8.7-4.3-2.1-1.7,11.6-1.7,13.6s5.9,19.5,6.2,29.1,7.9,28.3,11.4,33.2,15.6,30.3,17.6,35.2-1.9,19.8,1.8,25.7,42.9-9.3,42.9-9.3S384.9,355.7,384.9,353.1Z" transform="translate(-305.22 -213.96)" fill="#b4b9de"/><path d="M376.2,308.6s5-3.9,7.4-7.9,3.5-12.9,5.1-19,9.1-9.4,13-9,1.2,6.2,1.2,6.2-1.8,8.1-3.4,12.9-1.1,15.5-.3,20.3-7.6,20.4-10.7,24.8-4.2,13.4-4.3,16,2.2,26.3,2.2,26.3-39.2,15.2-42.9,9.3.3-20.8-1.8-25.7-14.1-30.4-17.6-35.2-11.1-23.5-11.4-33.2-6.3-27.1-6.2-29.1-2.6-15.7,1.7-13.6,6.9,3.3,9.1,9.2,3.5,17.4,5,20.7,1.3,8.1,1.3,8.1" transform="translate(-305.22 -213.96)" fill="none" stroke="#2e3192" stroke-miterlimit="10"/><path d="M383.6,300.7s-15.2-18.2-16-22.3-10.6-25.5-10.6-27-7.7-19.5-11.9-22-6.3-3.6-7.7-2.1a10.09,10.09,0,0,0-1.7,4.8,12.13,12.13,0,0,0,1.3,7.6c2.6,4.6,11.5,25.8,12.5,30.9s1.7,8.2,1.7,8.2" transform="translate(-305.22 -213.96)" fill="none" stroke="#2e3192" stroke-miterlimit="10"/><path d="M337.5,280.5s-10-29.3-11.4-31.6-6.4-17.7-8.8-17.8-9.2-4.4-7,4.9,6.7,25,6.7,25" transform="translate(-305.22 -213.96)" fill="none" stroke="#2e3192" stroke-miterlimit="10"/><path d="M335.6,232.1s-4.3-11.3-6.7-11.4c0,0-5.9-4-7.7,1s.3,10.5.3,10.5l2.5,11.3" transform="translate(-305.22 -213.96)" fill="none" stroke="#2e3192" stroke-miterlimit="10"/></svg>'
    )
  end

  def coat_svg
    icon_from_html(
      '<svg><title>3_labcoaton</title><path d="M365.7,206.7l-33.6,12.8s-10.5,4.2-10.5,12.6V349h27.9l.6,52.7H440V349.6l28.8-.7V235.1s-5.4-17.4-20.4-19.2L425,206.7H365.7Z" transform="translate(-320.6 -205.7)" fill="#abb2da" stroke="#2e3191" stroke-miterlimit="10" stroke-width="2"/><path d="M458.5,246.8a94.68,94.68,0,0,0-5-30.2,20.07,20.07,0,0,0-5.1-1.3L425,206.1H365.7l-33.6,12.8s-10.5,4.2-10.5,12.6V335.6a102.22,102.22,0,0,0,37.3,7C413.9,342.5,458.5,299.6,458.5,246.8Z" transform="translate(-320.6 -205.7)" fill="#d8def0"/><polyline points="45.1 1 74.6 45.5 104.4 1" fill="#919195" stroke="#2e3191" stroke-miterlimit="10" stroke-width="2"/><polyline points="34.4 5.1 36.4 28.5 53.1 31.4 53.1 43.2 74.7 71.1 94.8 45.5 94.8 31.4 110.5 25.5 112.5 5.1" fill="none" stroke="#2e3191" stroke-miterlimit="10" stroke-width="2"/><line x1="28.9" y1="143.2" x2="28.9" y2="51.9" fill="none" stroke="#2e3191" stroke-miterlimit="10" stroke-width="2"/><line x1="119.4" y1="143.8" x2="119.4" y2="51.9" fill="none" stroke="#2e3191" stroke-miterlimit="10" stroke-width="2"/><path d="M365.7,206.7l-33.6,12.8s-10.5,4.2-10.5,12.6V349h27.9l.6,52.7H440V349.6l28.8-.7V235.1s-5.4-17.4-20.4-19.2L425,206.7H365.7Z" transform="translate(-320.6 -205.7)" fill="none" stroke="#2e3191" stroke-miterlimit="10" stroke-width="2"/><line x1="74.6" y1="45.5" x2="74.6" y2="197.6" fill="none" stroke="#2e3191" stroke-miterlimit="10" stroke-width="2"/><line x1="40.3" y1="125.9" x2="60.3" y2="125.9" fill="none" stroke="#2e3191" stroke-miterlimit="10" stroke-width="2"/><line x1="88.8" y1="125.9" x2="109.4" y2="125.9" fill="none" stroke="#2e3191" stroke-miterlimit="10" stroke-width="2"/><line x1="40.3" y1="71.4" x2="60.3" y2="71.4" fill="none" stroke="#2e3191" stroke-miterlimit="10" stroke-width="2"/><path d="M376.8,223.4" transform="translate(-320.6 -205.7)" fill="none" stroke="#2e3191" stroke-miterlimit="10" stroke-width="2"/><polygon points="93.2 17.7 74.6 45.5 56.2 17.7 93.2 17.7" fill="#abb2da" stroke="#2e3191" stroke-miterlimit="10" stroke-width="2"/></svg>'
    )
  end

  def bsc_svg
    icon_from_html(
      '<svg><title>3_bsccabinet</title><path d="M481.7,319.3H309.3a7.17,7.17,0,0,1-7.2-7.2V222.6a7.17,7.17,0,0,1,7.2-7.2H481.7a7.17,7.17,0,0,1,7.2,7.2v89.5A7.3,7.3,0,0,1,481.7,319.3Z" transform="translate(-302.1 -215.4)" fill="#d8def0"/><path d="M462.7,233.3H331a7.17,7.17,0,0,1-7.2-7.2v-2.2a7.17,7.17,0,0,1,7.2-7.2H462.8a7.17,7.17,0,0,1,7.2,7.2v2.2A7.32,7.32,0,0,1,462.7,233.3Z" transform="translate(-302.1 -215.4)" fill="#262261" stroke="#2e3191" stroke-miterlimit="10"/><path d="M481.6,216.9H463.2c8,7.6,12.7,16.7,12.7,26.4,0,26.9-35.5,48.7-79.3,48.7s-79.3-21.8-79.3-48.7c0-9.7,4.7-18.8,12.7-26.4H309.3a7.17,7.17,0,0,0-7.2,7.2v89.5a7.17,7.17,0,0,0,7.2,7.2H481.7a7.17,7.17,0,0,0,7.2-7.2V224.1A7.39,7.39,0,0,0,481.6,216.9Z" transform="translate(-302.1 -215.4)" fill="#abb2da"/><rect x="10.2" y="103.9" width="7.5" height="76.1" fill="#abb2da"/><rect x="167.8" y="103.9" width="7.5" height="76.1" fill="#abb2da"/><polyline points="7.1 1.5 7.1 79.9 179.3 80.8 179.5 1.5" fill="none" stroke="#2e3191" stroke-miterlimit="10" stroke-width="2"/><line x1="40.4" y1="20.4" x2="27.8" y2="34.2" fill="none" stroke="#2e3191" stroke-miterlimit="10" stroke-width="2"/><line x1="69.8" y1="20.4" x2="64.4" y2="34.2" fill="none" stroke="#2e3191" stroke-miterlimit="10" stroke-width="2"/><line x1="117.9" y1="20.4" x2="122.1" y2="34.2" fill="none" stroke="#2e3191" stroke-miterlimit="10" stroke-width="2"/><line x1="160.4" y1="20.4" x2="171.6" y2="30.9" fill="none" stroke="#2e3191" stroke-miterlimit="10" stroke-width="2"/></svg>'
    )
  end

  ####################################
  # Displaying Images
  ######################################
  def extract_basename(filename)
    ext = File.extname(filename)
    basename = File.basename(filename, ext)
    basename
  end

  def show_with_expected_uploads(op, filename, save_key = nil, num_tries = 5)
    upload_hashes = []
    warning_msg = nil
    num_tries.times.each do |i|
      next unless upload_hashes.empty?

      # ask for uploads
      result = show do
        warning warning_msg unless warning_msg.nil?
        run(&Proc.new) if block_given?
        upload var: :files
      end
      upload_hashes = result[:files] || []

      if debug && (i >= 1)
        n = 'default_filename.txt'
        n = filename if i >= 2
        upload_hashes.push({ id: 12_345, name: n })
      end

      # try again if not files were uploaded
      warning_msg = 'You did not upload any files! Please try again.' if upload_hashes.empty?

      next if upload_hashes.empty?

      # get name to id hash
      name_to_id_hash = upload_hashes.map { |u| [extract_basename(u[:name]), u[:id]] }.to_h

      # get the file even if technician uploaded multiple files
      if name_to_id_hash.keys.include?(extract_basename(filename))
        upload_hashes = [{ name: filename, id: name_to_id_hash[filename] }]
      else
        warning_msg = "File #{filename} not uploaded. Please find file <b>\"#{filename}\"</b>. You uploaded files #{name_to_id_hash.keys.join(', ')}"
        upload_hashes = []
      end
    end
    raise 'Expected file uploads, but there were none!' if upload_hashes.empty?

    upload_ids = upload_hashes.map { |uhash| uhash[:id] }
    uploads = []
    if debug
      random_uploads = Upload.includes(:job)
      uploads = upload_ids.map { |_u| random_uploads.sample }
    else
      uploads = upload_ids.map { |u_id| Upload.find(u_id) }
    end
    upload = uploads.first
    raise 'Expected file uploads, but there were none!' if upload.nil?
    op.temporary[save_key] = upload unless save_key.nil?
    op.temporary["#{save_key}_id".to_sym] = upload.id unless save_key.nil?
    upload
  end

  def display_upload(upload, size = '100%')
    p = proc do
      note "<img src=\"#{upload.expiring_url}\" width=\"#{size}\"></img>"
    end
    ShowBlock.new(self).run(&p)
  end

  def display_strip_section(upload, display_section, num_sections, size)
    p = proc do
      x = 100.0 / num_sections
      styles = []
      num_sections.times.each do |section|
        x1 = 100 - (x * (section + 1)).to_i
        x2 = (x * section).to_i
        styles.push(".clipimg#{section} { clip-path: inset(0% #{x1}% 0% #{x2}%); }")
      end
      style = "<head><style>#{styles.join(' ')}</style></head>"
      note style
      note "<img class=\"clipimg#{display_section}\" src=\"#{upload.expiring_url}\" width=\"#{size}\"></img>"
    end
    ShowBlock.new(self).run(&p)
end
end
