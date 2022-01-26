# frozen_string_literal: true

needs 'OLASimple/OLAConstants'
needs 'OLASimple/OLAGraphics'

module OLAKitIDs
  include OLAGraphics

  KIT_NUM_DIGITS = 3
  SAMPLE_NUM_DIGITS = 3
  BATCH_SIZE = OLAConstants::BATCH_SIZE
  PROPOGATION_KEYS = [OLAConstants::KIT_KEY, OLAConstants::SAMPLE_KEY, OLAConstants::PATIENT_KEY].freeze # which associations to propogate forward during an operation
  ALL_KIT_KEYS = PROPOGATION_KEYS + [OLAConstants::COMPONENT_KEY, OLAConstants::UNIT_KEY].freeze # all keys for important kit item associations

  def extract_kit_number(id)
    id.chars[-KIT_NUM_DIGITS, KIT_NUM_DIGITS].join.to_i if id.chars[-KIT_NUM_DIGITS, KIT_NUM_DIGITS]
  end

  def extract_sample_number(id)
    id.chars[-SAMPLE_NUM_DIGITS, SAMPLE_NUM_DIGITS].join.to_i if id.chars[-SAMPLE_NUM_DIGITS, SAMPLE_NUM_DIGITS]
  end

  def sample_num_to_id(num)
    num.to_s.rjust(SAMPLE_NUM_DIGITS, '0')
  end

  def kit_num_to_id(num)
    num.to_s.rjust(KIT_NUM_DIGITS, '0')
  end

  # requires and returns integer ids
  def kit_num_from_sample_num(sample_num)
    ((sample_num - 1) / BATCH_SIZE).floor + 1
  end

  # requires and returns integer ids
  def sample_nums_from_kit_num(kit_num)
    sample_nums = []
    BATCH_SIZE.times do |i|
      sample_nums << kit_num * BATCH_SIZE - i
    end
    sample_nums.reverse
  end

  AUTOFILL = false # for debugging purposes when you don't have a barcode scanner

  def validate_package(this_package)
    resp = show do
      title 'Validate kit package'
      note "Scan in the ID of package #{this_package} which you've retrieved."
      default = AUTOFILL ? this_package : ''
      get 'text', var: :package, label: "Package ID", default: default
    end
    return false if resp[:package] != this_package

    return true
  end

  def package_validation_with_multiple_tries(this_package)
    5.times do
      result = validate_package(this_package)
      return true if result || debug

      show do
        title 'Wrong Package'
        note 'Ensure that you have the correct package before continuing.'
        note "The package should be labeled <b>#{this_package}</b>."
        note 'On the next step you will retry scanning in the package.'
      end
    end
    operations.each do |op|
      op.error(:package_problem, 'Package id is wrong and could not be resolved')
    end
    raise 'Package id is wrong and could not be resolved. Speak to a Lab manager.'
  end

  def validate_samples(expected_object_ids, svgs, ids_override: nil)
    show_ids = expected_object_ids
    expected_object_ids = ids_override if ids_override
    resp = show do
      title 'Validate Incoming Samples'

      note "To ensure we are working with the right samples, scan in the IDs of the retrieved inputs #{show_ids.to_sentence}."
      expected_object_ids.size.times do |i|
        default = AUTOFILL ? expected_object_ids[i] : ''
        get 'text', var: i.to_s.to_sym, label: '', default: default
      end
    end

    expected_object_ids.size.times do |i|
      if resp[i.to_s.to_sym]
        found = expected_object_ids.delete(resp[i.to_s.to_sym])
      end
      return false unless found
    end
    true
  end

  def pre_transfer_validate(expected_object_ids, svgs, ids_override: nil, content_override: nil)
    show_ids = expected_object_ids
    expected_object_ids = ids_override if ids_override
    grid = SVGGrid.new(svgs.size, 1, 150, 100)
    svgs.each_with_index do |svg, i|
      grid.add(svg, i, 0)
    end
    img = SVGElement.new(children: [grid], boundx: 1000, boundy: 300).translate(100, 0)

    resp = show do
      if content_override
        raw content_override
      else
        title 'Prepare Samples for transfer'

        check "In preparation for liquid transfer, set aside tubes #{show_ids.to_sentence}."
        note 'Scan in tube IDs for confirmation.'
      end
      note display_svg(img, 0.75)
      expected_object_ids.size.times do |i|
        default = AUTOFILL ? expected_object_ids[i] : ''
        get 'text', var: i.to_s.to_sym, label: '', default: default 
      end
    end

    expected_object_ids.size.times do |i|
      if resp[i.to_s.to_sym]
        found = expected_object_ids.delete(resp[i.to_s.to_sym])
      end
      return false unless found
    end
    true
  end

  def pre_transfer_validation_with_multiple_tries(from_name, to_name, from_svg=nil, to_svg=nil, content_override: nil)
    from_id = from_name.dup.sub("-", "")
    to_id = to_name.dup.sub("-", "")
    5.times do
      result = pre_transfer_validate([from_name, to_name], [from_svg, to_svg], ids_override: [from_id, to_id], content_override: content_override)
      return true if result || debug

      show do
        title 'Wrong tubes'
        note 'Ensure that you have the correct tubes before continuing.'
        note 'On the next step you will retry scanning in the samples.'
      end
    end
    operations.each do |op|
      op.error(:wrong_items, 'Objects for transfer are wrong and could not be resolved')
    end
    raise 'Objects for transfer are wrong and could not be resolved. Speak to a lab manager.'
  end

  def sample_validation_with_multiple_tries(expected_object_ids, expected_svgs=nil)
    expected_object_ids = expected_object_ids.map { |id| id.dup.sub("-", "") }
    5.times do
      result = validate_samples(expected_object_ids, expected_svgs, ids_override: expected_object_ids)
      return true if result || debug

      show do
        title 'Wrong Samples'
        note 'Ensure that you have the correct samples before continuing.'
        note 'On the next step you will retry scanning in the samples.'
      end
    end
    operations.each do |op|
      op.error(:sample_problem, 'Incoming samples are wrong and could not be resolved')
    end
    raise 'Incoming samples are wrong and could not be resolved. Speak to a Lab manager.'
  end

  def record_technician_id
    resp = show do
      title 'Scan your technician ID'
      note 'Scan the technician ID barcode on your badge.'
      note display_svg(technician_id_svg, 0.5)
      default = AUTOFILL ? 'TECH634' : ''
      get 'text', var: :id, label: 'ID', default: default
    end
    operations.each do |op|
      op.associate(OLAConstants::TECH_KEY, resp[:id])
    end
  end

  ################################################################################
  ####  ID PROPOGATION
  ################################################################################

  def populate_temporary_kit_info_from_input_associations(ops, input_name)
    if debug
      ops.each_with_index do |op, i|
        op.temporary["input_#{OLAConstants::KIT_KEY}"] = kit_num_to_id(1)
        op.temporary["input_#{OLAConstants::SAMPLE_KEY}"] = sample_num_to_id(i + 1)
        op.temporary["input_#{OLAConstants::PATIENT_KEY}"] = rand(1..30).to_s
        op.temporary["output_#{OLAConstants::KIT_KEY}"] = op.temporary["input_#{OLAConstants::KIT_KEY}"]
        op.temporary["output_#{OLAConstants::SAMPLE_KEY}"] = op.temporary["input_#{OLAConstants::SAMPLE_KEY}"]
        op.temporary["output_#{OLAConstants::PATIENT_KEY}"] = op.temporary["input_#{OLAConstants::PATIENT_KEY}"]
      end
    else
      # grab all data associations from inputs and place into temporary
      populate_temporary_values_from_input_associations(ops, input_name, ALL_KIT_KEYS, PROPOGATION_KEYS)
    end
  end

  def populate_temporary_values_from_input_associations(ops, input_name, keys, propogated_keys)
    ops.each do |op|
      from = op.input(input_name).item
      from_das = DataAssociation.where(parent_id: from.id, parent_class: from.class.to_s, key: keys)
      from_das.each do |da|
        op.temporary["input_#{da.key}".to_sym] = da.value
        op.temporary["output_#{da.key}".to_sym] = da.value if PROPOGATION_KEYS.include?(da.key)
      end
    end
  end

  # Sends forward kit num, sample num, and patient id from the input item to the output item
  # for all operations
  def propogate_kit_info_forward(ops, input_name, output_name)
    das = []
    ops.each do |op|
      new_das = propogate_information_lazy(
        op.input(input_name).item,
        op.output(output_name).item,
        PROPOGATION_KEYS
      )
      das.concat(new_das)
    end
    DataAssociation.import das, on_duplicate_key_update: [:object]
  end

  # helper for propogate_kit_information_forward
  def propogate_information_lazy(from, to, keys = [])
    from_das = DataAssociation.where(parent_id: from.id, parent_class: from.class.to_s, key: keys)
    from_das.map { |da| to.lazy_associate(da.key, da.value) }
  end

  # Assumes only one output item
  # Sets the output items (and operation temporay values) to the given component and unit
  def set_output_components_and_units(ops, output_name, component, unit)
    data_associations = []
    ops.each do |op|
      it = op.output(output_name).item
      data_associations << it.lazy_associate(OLAConstants::COMPONENT_KEY, component)
      data_associations << it.lazy_associate(OLAConstants::UNIT_KEY, unit)
      op.temporary[OLAConstants::COMPONENT_KEY] = component
      op.temporary[OLAConstants::UNIT_KEY] = unit
    end
    DataAssociation.import data_associations, on_duplicate_key_update: [:object]
  end

  def technician_id_svg
    child = icon_from_html(
      '<svg><defs><clipPath id="clip-path" transform="translate(-117.03 -68.5)"><polygon points="190.6 172.5 205.9 144.6 167.7 121.4 91.1 232.7 131.2 285.2 194 237.4 278.2 229.1 279.1 196.4 190.6 196.4 190.6 172.5" fill="none"/></clipPath></defs><title>2_TechnicianIDcard</title><rect x="73.57" y="0.5" width="197.8" height="127.4" fill="#fff" stroke="#000" stroke-miterlimit="10"/><g clip-path="url(#clip-path)"><path d="M139.2,210.9c2.1-1.9,8.4-9.2,10.1-14.6s9.1-22.9,13.4-25.7,12.9-10.2,15.8-14.9a143.5,143.5,0,0,1,8.2-11.8s3-6.2,5.6-3.6,4.2,10.4.4,16-10.2,12.8-12,17.4c0,0,23-2,26.7-4.3s26.1-10.7,27.3-11.6,19.7-8.4,24.1-7.1,6.5,2.1,6.1,4.2a14.94,14.94,0,0,1-2.8,4.8s11.3-4.9,12.8-3.3c0,0,6.6,1.4,3.7,6.4a20.15,20.15,0,0,1-8.4,7.4l-10.3,6.3c5.3-2.3,12.4-5.2,13.4-4.1,1.5,1.6,8.7,3.7.2,8.6-7.6,4.5-20.4,11.4-23,12.8h0c5.6-2.3,8-1.3,12,.3s-8.2,9.6-9.7,11-18.6,9.7-26.4,16.3-26.7,14.6-32.6,15.5-32.8,10.4-37.7,12.3-14.5,15.6-21.2,17.1-17.3-38.2-17.3-38.2S137.2,212.8,139.2,210.9Z" transform="translate(-117.03 -68.5)" fill="#b4b9de"/><path d="M179.1,185.3a42.36,42.36,0,0,1,1.9-11.1c1.8-4.6,8.2-11.8,12-17.4s2.2-13.5-.4-16-5.6,3.6-5.6,3.6-5.3,7.1-8.2,11.8-11.5,12-15.8,14.9-11.6,20.2-13.4,25.7-8,12.7-10.1,14.6-21.9,17.2-21.9,17.2,10.5,39.6,17.3,38.2,16.2-15.2,21.2-17.1,31.9-11.5,37.7-12.3,24.8-8.8,32.6-15.5,24.9-15,26.4-16.3,13.7-9.4,9.7-11-6.5-2.7-12.5-.1-15.6,9.9-19.1,11.2-7.1,4.8-7.1,4.8" transform="translate(-117.03 -68.5)" fill="none" stroke="#2e3192" stroke-miterlimit="10"/><path d="M181.1,174.2s23-2,26.7-4.3,26.1-10.7,27.3-11.6,19.7-8.4,24.1-7.1,6.5,2.1,6.1,4.2a15.65,15.65,0,0,1-9.5,9.4c-5.1,1.4-26.9,10.1-31.4,13-4.7,2.9-7.4,4.7-7.4,4.7" transform="translate(-117.03 -68.5)" fill="none" stroke="#2e3192" stroke-miterlimit="10"/><path d="M223.5,193.4s28.7-13.7,31.3-14.3,17.6-8,19.1-6.4,8.7,3.7.2,8.6c-8.5,5.1-23.5,13.1-23.5,13.1" transform="translate(-117.03 -68.5)" fill="none" stroke="#2e3192" stroke-miterlimit="10"/><path d="M262.6,160s11.3-4.9,12.8-3.3c0,0,6.6,1.4,3.7,6.4a20.15,20.15,0,0,1-8.4,7.4l-10.3,6.3" transform="translate(-117.03 -68.5)" fill="none" stroke="#2e3192" stroke-miterlimit="10"/></g><g style="isolation:isolate"><text transform="translate(110.02 52.91)" font-size="21.42" font-family="ArialMT, Arial" style="isolation:isolate">OLA-Simple</text><text transform="translate(110.02 78.61)" font-size="21.42" font-family="ArialMT, Arial" style="isolation:isolate"><tspan letter-spacing="-0.11em">T</tspan><tspan x="10.71" y="0">echnician ID</tspan></text></g><rect x="73.57" y="0.5" width="197.8" height="23.3" fill="#0d537c"/><text transform="translate(114.25 19.7)" font-size="21.67" fill="#16f70b" font-family="Arial-BoldMT, Arial" font-weight="700" style="isolation:isolate">AQUARIUM</text><rect x="104.47" y="89" width="3.2" height="30.4"/><rect x="109.37" y="89" width="1.9" height="30.4"/><rect x="114.27" y="89" width="1.8" height="30.4"/><rect x="122.97" y="89" width="3.1" height="30.4"/><rect x="127.67" y="89" width="5.1" height="30.4"/><rect x="138.07" y="89" width="1.5" height="30.4"/><rect x="140.97" y="89" width="2.1" height="30.4"/><rect x="146.17" y="89" width="5.2" height="30.4"/><rect x="152.87" y="89" width="3.4" height="30.4"/><rect x="159.47" y="89" width="2" height="30.4"/><rect x="213.75" y="88.9" width="2.9" height="30.4"/><rect x="210.47" y="88.9" width="1.7" height="30.4"/><rect x="205.96" y="88.9" width="1.7" height="30.4"/><rect x="196.81" y="88.9" width="2.9" height="30.4"/><rect x="190.63" y="88.9" width="4.7" height="30.4"/><rect x="184.43" y="88.9" width="1.4" height="30.4"/><rect x="181.26" y="88.9" width="1.9" height="30.4"/><rect x="173.56" y="88.9" width="4.8" height="30.4"/><rect x="168.98" y="88.9" width="3.1" height="30.4"/><rect x="164.19" y="88.9" width="1.8" height="30.4"/><rect x="221.97" y="89" width="3.2" height="30.4"/><rect x="226.77" y="89" width="1.9" height="30.4"/><rect x="231.77" y="89" width="1.8" height="30.4"/><rect x="240.37" y="89" width="3.1" height="30.4"/><rect x="246.77" y="89" width="1.5" height="30.4"/></svg>'
    )
    SVGElement.new(children: [child], boundx: 400, boundy: 200)
  end
end
