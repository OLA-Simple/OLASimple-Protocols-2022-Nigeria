# require_relative 'graphics'
needs "OLASimple/SVGGraphics"
module OLAGraphics
  include Graphics
  include Graphics::MyGraphics

  @@colors = ["red", "yellow", "green", "blue", "purple", "gray"]

  def self.set_tube_colors(new_colors)
    @@colrs = new_colors
  end


  #####################################
  # BASICS
  #####################################

  def get_style
    <<EOF
      /* <![CDATA[ */
      
      #svg .yellow path {
          fill: #f7f9c2;
      }
      
      #svg .white rect {
          fill: #ffffff;
      }
      
      #svg .gray path {
          fill: #d4d4d4;
      }
      
      #svg .blue path {
          fill: #bdf8f9;
      }
      
      #svg .red path {
          fill: #ffc4c4;
      }
      
      #svg .green path {
          fill: #c4f9c2;
      }
      
      #svg .purple path {
          fill: #f1e0fc;
      }

      #svg .hidden {
        opacity: 0.3;
      }

      #svg .yellowstrip rect {
          fill: #f7f9c2;
      }
      
      #svg .bluestrip rect {
          fill: #bdf8f9;
      }
      
      #svg .whitestrip rect {
          fill: #ffffff;
      }
      
      #svg .redstrip rect {
          fill: #ffc4c4;
      }
      
      #svg .graystrip rect {
          fill: #d4d4d4;
      }
      
      #svg .greenstrip rect {
          fill: #c4f9c2;
      }
      
      #svg .purplestrip rect {
          fill: #f1e0fc;
      }

      #svg .redfluid path {
        fill: #ff7c66;
      }
      
      #svg .brownfluid path {
        fill: #8B4513;
      }

      #svg .pinkfluid path {
        fill: #ff8eec;
      }
      
      #svg .palefluid path {
          fill: #F2F5D1;
      }
      /* ]]> */
EOF
  end

  def display_svg(element, scale = 1)
    element.style!(self.get_style)
    element.svg(element.boundx, element.boundy, scale).to_str
  end

  # two labels on top of each other
  def two_labels(text1, text2)
    label1 = label(text1, "font-size".to_sym => 25)
    label2 = label(text2, "font-size".to_sym => 25)
    label2.align!('center-top')
    label2.align_with(label1, 'center-bottom')
    label2.translate!(0, 12)
    SVGElement.new(children: [label1, label2], boundx: label1.boundx, boundy: label1.boundy * 2)
  end

  # make a tube label
  def tube_label(kit, unit, component, sample)
    self.two_labels("#{unit}#{component}", "#{sample}")
  end

  def make_arrow(from, to, tlabel = nil, blabel = nil, tfontsize = 25, bfontsize = 25)
    # make right arrow
    top_label = label(tlabel, "font-size".to_sym => tfontsize)
    bottom_label = label(blabel, "font-size".to_sym => bfontsize)
    arrow = rarrow.scale(0.75)
    arrow.align!('center-right')
    arrow.align_with(to, 'center-left')
    v1 = from.get_abs_anchor('center-right') - from.abs_anchor_vector
    v2 = to.get_abs_anchor('center-left') - to.abs_anchor_vector
    m = (v1 + v2) / 2.0
    line = Line.new(*v1, *v2, 'black', 3)
    unless top_label.nil?
      top_label.translate!(*m)
      top_label.align!('center-bottom').translate!(0, -10)
    end
    unless bottom_label.nil?
      bottom_label.translate!(*m)
      puts bottom_label
      bottom_label.align!('center-top').translate!(0, 10)
    end
    myarrow = SVGElement.new(children: [line, arrow, bottom_label, top_label].compact)
  end

  def make_transfer(from, to, spacing, top_label, bottom_label)
    to.align_with(from, 'center-right').align!('center-left')
    to.translate!(spacing)
    arrow = make_arrow(from, to, top_label, bottom_label)
    elements = [arrow, from, to]
    puts elements.map {|e| Vector[e.x, e.y] + e.get_abs_anchor('center-right')}
    max_x = elements.map {|e| (Vector[e.x, e.y] + e.get_abs_anchor('center-right'))[0]}.max
    max_y = elements.map {|e| (Vector[e.x, e.y] + e.get_abs_anchor('center-bottom'))[1]}.max
    svg = SVGElement.new(
        children: elements,
        boundx: 1000,
        boundy: 300,
        )
    svg.translate!(20)
  end

  def make_tube(tube, bottom_label, middle_label, fluid = nil, cropped_for_closed_tube = false, fluidclass: nil)
    bottom_label = bottom_label.join("\n") if bottom_label.is_a?(Array)
    middle_label = middle_label.join("\n") if middle_label.is_a?(Array)
    img = SVGElement.new(boundx: tube.boundx, boundy: tube.boundy)
    tube_group = tube
    bottom_labels = bottom_label.split("\n")
    middle_labels = middle_label.split("\n")

    img.add_child(tube)
    fluidImage = nil
    if fluid == "small"
      fluidImage = fluid_small
    elsif fluid == "medium"
      fluidImage = fluid_medium
    elsif fluid == "large"
      fluidImage = fluid_large
    elsif fluid == "powder"
      fluidImage = powder
    end
    puts fluid
    fluidImage.new_class!(fluidclass) unless fluidImage.nil? or fluidclass.nil?
    img.add_child(fluidImage) unless fluidImage.nil?
    puts fluid
    if bottom_label != ""
      bl = nil
      if bottom_labels.length == 2
        bl = two_labels(*bottom_labels)
      else
        label = label(bottom_label, "font-size".to_sym => 25)
        bl = label
      end
      bl.align!('center-top')
      bl.align_with(tube, 'center-bottom')
      bl.translate!(-5 * tube.xscale, 5 * tube.yscale)
      tube.boundy = tube.boundy + bl.boundy
      img.add_child(bl)
    end

    if middle_label != ""
      ml = nil
      if middle_labels.length == 2
        ml = two_labels(*middle_labels)
      else
        ml = label(middle_label, "font-size".to_sym => 25)
      end
      ml.align!('center-center')
      ml.align_with(tube, 'center-bottom')
      ml.translate!(-9 * tube.xscale, -110 * tube.yscale)
      img.add_child(ml)
    end


    img.boundx = tube.boundx
    img.boundy = tube.boundy
    if cropped_for_closed_tube
      shift = 70
      img.boundy = img.boundy - shift
      img.group_children.translate!(0, -shift)
    end
    img.translate!(10)
  end

  #####################################
  # LIGATIONS
  #####################################

  def stripwell(kit, unit, components, sample, open_tubes, apply_classes, hide, spacing)
    open_tubes = open_tubes || []
    hide = hide || []
    apply_classes = apply_classes || []
    num = components.length
    grid = SVGGrid.new(num, 1, spacing, opentube.boundy)
    grid.each_pos do |r, c|

      # add label
      tube_label = ["#{unit}#{components[r]}", "#{sample}"]
      tube_type = closedtube
      if open_tubes.include?(r)
        tube_type = opentube
      end
      tube = make_tube(tube_type,
                       "",
                       tube_label,
                       nil,
                       false)
      tube.new_class!(apply_classes[r])
      if hide.include?(r)
        tube = tube.g(classname: 'hidden')
      end
      grid.add(tube, r, c)
    end
    grid
  end

  def display_ligation_tubes(kit, unit, components, sample, colors, open_tubes = nil, hide = nil, spacing = 70)
    
    mystripwell = stripwell(kit, unit, components, sample, open_tubes, colors, hide, spacing).scale!(0.75)
    myimage = SVGElement.new(boundx: 500, boundy: 190)
    myimage.add_child(mystripwell)
  end

  def highlight_ligation_tube(i, kit, unit, components, sample, colors)
    ligation_tubes = self.display_ligation_tubes(
        kit, unit, components, sample, colors, [i], (0..components.length - 1).to_a.reject {|x| x == i})
    ligation_tubes
  end

  def transfer_to_ligation_tubes_with_highlight(from, i, kit, unit, components, sample, colors, vol, bottom_label = nil)
    bottom_label = bottom_label || ""
    ligation_tubes = self.highlight_ligation_tube(i, kit, unit, components, sample, colors)
    ligation_tubes.align_with(from, 'center-right').align!('center-left')
    ligation_label = label("ligation tubes", "font-size".to_sym => 25)
    # ligation_label.align_with(ligation_tubes, 'center-bottom').align!('center-top')
    svg = self.make_transfer(from, ligation_tubes, 300, "#{vol}uL", bottom_label)
    svg.translate!(20)
    svg.boundy = svg.boundy - 20
    svg.boundx = 700
    svg.boundy = 295
    svg
  end

  #####################################
  # DETECTION
  #####################################

  def display_strip_panel(kit, unit, components, sample, colors)
    def panel kit, unit, components, sample, apply_classes
      apply_classes = apply_classes || []
      num = components.length
      strip = make_strip(nil, "")
      grid = SVGGrid.new(num, 1, 90, strip.boundy)
      grid.each_pos do |r, c|

        # add label
        strip_label = self.tube_label(kit, unit, components[r], sample).scale(0.8)
        strip = make_strip(strip_label, apply_classes[r] + "strip")
        grid.add(strip, r, c)
      end
      grid.scale!(0.75)
    end
    
    mypanel = panel(kit, unit, components, sample, colors)
    mypanel.boundx = 600
    mypanel
  end

  def display_panel_and_tubes(kit, panel_unit, tube_unit, components, sample, colors)
    tubes = display_ligation_tubes(kit, tube_unit, components, sample, colors)
    panel = display_strip_panel(kit, panel_unit, components, sample, colors)
    tubes.align_with(panel, 'center-bottom')
    tubes.align!('center-top')
    tubes.translate!(0, -50)
    img = SVGElement.new(children: [tubes, panel], boundy: 330, boundx: panel.boundx)
  end

  def make_strip mylabel, classname
    mystrip = SVGElement.new(boundx: 83.1, boundy: 247.45)
    mystrip.add_child(self.strip)
    mystrip.add_child(self.striplabel.new_class(classname))
    # mylabel = label("Strip", "font-size".to_sym=>20)
    unless mylabel.nil?
      mylabel.align_with(mystrip, 'center-top')
      mylabel.align!('center-center')
      mylabel.translate!(0, 20)
      mystrip.add_child(mylabel)
    end
    mystrip
  end

  def detection_strip_diagram
    img = SVGElement.new(boundx: 270, boundy: 350)
    img.add_child(<<EOF
     <g id="Strip">
	<g>
		<rect x="4.75" fill="#E6E7E8" stroke="#000000" stroke-miterlimit="10" width="78.346" height="242.948"/>
		<line fill="#E6E7E8" stroke="#000000" stroke-miterlimit="10" x1="0" y1="247.448" x2="4.75" y2="242.948"/>
		<polygon fill="#E6E7E8" stroke="#000000" stroke-miterlimit="10" points="-0.067,4.777 4.75,0.001 4.75,242.948 0,247.448 		"/>
		<polygon fill="#E6E7E8" stroke="#000000" stroke-miterlimit="10" points="74.917,247.448 0,247.448 4.75,242.948 83.096,242.948 
					"/>
	</g>
	<g>
		<rect x="19.583" y="49.433" fill="#E6E7E8" stroke="#000000" stroke-miterlimit="10" width="46.667" height="80"/>
		<rect x="27.083" y="57.433" fill="#FFFFFF" stroke="#000000" stroke-miterlimit="10" width="31.667" height="64"/>
		<line fill="none" stroke="#000000" stroke-miterlimit="10" x1="27.083" y1="121.433" x2="19.583" y2="129.433"/>
		<line fill="none" stroke="#000000" stroke-miterlimit="10" x1="58.75" y1="121.433" x2="66.25" y2="129.433"/>
		<line fill="none" stroke="#000000" stroke-miterlimit="10" x1="58.75" y1="57.433" x2="66.25" y2="49.433"/>
		<line fill="none" stroke="#000000" stroke-miterlimit="10" x1="27.083" y1="57.433" x2="19.583" y2="49.433"/>
	</g>
	<g>
		<path fill="#E6E7E8" stroke="#000000" stroke-miterlimit="10" d="M57.524,216.515c0,4.385-3.693,7.938-8.249,7.938H36.557
			c-4.556,0-8.249-3.554-8.249-7.938v-22.164c0-4.385,3.693-7.939,8.249-7.939h12.718c4.556,0,8.249,3.554,8.249,7.939V216.515z"/>
		<path fill="#FFFFFF" stroke="#000000" stroke-miterlimit="10" d="M52.917,213.019c0,3.002-2.528,5.435-5.647,5.435h-8.706
			c-3.119,0-5.647-2.433-5.647-5.435v-15.172c0-3.001,2.528-5.435,5.647-5.435h8.706c3.119,0,5.647,2.433,5.647,5.435V213.019z"/>
		<line fill="none" stroke="#000000" stroke-miterlimit="10" x1="34.01" y1="216.224" x2="30.27" y2="221.647"/>
		<line fill="none" stroke="#000000" stroke-miterlimit="10" x1="51.823" y1="216.224" x2="55.562" y2="221.647"/>
		<line fill="none" stroke="#000000" stroke-miterlimit="10" x1="51.823" y1="194.642" x2="55.023" y2="188.663"/>
		<line fill="none" stroke="#000000" stroke-miterlimit="10" x1="34.01" y1="194.195" x2="30.27" y2="189.666"/>
		<line fill="none" stroke="#000000" stroke-miterlimit="10" x1="32.917" y1="205.433" x2="28.308" y2="205.433"/>
		<line fill="none" stroke="#000000" stroke-miterlimit="10" x1="52.917" y1="205.433" x2="57.524" y2="205.433"/>
	</g>
</g>
<g id="StripLabel">
	<rect x="4.75" fill="#ED1C24" stroke="#000000" stroke-miterlimit="10" width="78.346" height="46.433"/>
</g>
<polygon fill="#BBC9E7" stroke="#000000" stroke-miterlimit="10" points="43.923,198.542 48.016,201.414 166.567,59.148 
	141.463,41.534 "/>
<text transform="matrix(1 0 0 1 -60.75 216.2236)" font-family="'MyriadPro-Regular'" font-size="20">Port</text>
<text transform="matrix(1 0 0 1 -87.2627 91.1001)"><tspan x="0" y="0" font-family="'MyriadPro-Regular'" font-size="20">Reading</tspan><tspan x="0" y="24" font-family="'MyriadPro-Regular'" font-size="20">Window</tspan></text>
<line fill="none" stroke="#000000" stroke-width="4" stroke-miterlimit="10" x1="-11.417" y1="95.1" x2="32.917" y2="94.1"/>
<line fill="none" stroke="#000000" stroke-width="4" stroke-miterlimit="10" x1="-17.417" y1="209.401" x2="26.917" y2="208.401"/>
EOF
    )
    img.translate!(100)
    return img
  end

  def negative_selection_diagram
    img = SVGElement.new(boundx: 600, boundy: 262)
    img.add_child(<<EOF
<g id="SingleTubes_3_">
	<g id="ClosedLid_3_">
		<g>
			<path fill="#F7FCFE" d="M363.205,46.889c22.801,0,22.801,18.312,0,18.312c0-1.189,0-2.38,0-3.57c13.912,0,13.912-11.173,0-11.173
				C363.205,49.268,363.205,48.078,363.205,46.889z"/>
			<path fill="none" stroke="#000000" stroke-miterlimit="10" d="M363.205,46.889c22.801,0,22.801,18.312,0,18.312
				c0-1.189,0-2.38,0-3.57c13.912,0,13.912-11.173,0-11.173C363.205,49.268,363.205,48.078,363.205,46.889z"/>
		</g>
		<g>
			<path fill="#F7FCFE" d="M317.727,67.92c0,1.1,0.9,2,2,2h37.25c1.1,0,2-0.9,2-2v-0.688c0-1.1-0.535-2-1.188-2
				c-0.654,0-1.188-0.9-1.188-2v-8.938c0-1.1-0.9-2-2-2h-32.5c-1.1,0-2,0.9-2,2v8.938c0,1.1-0.534,2-1.188,2s-1.188,0.9-1.188,2
				V67.92z"/>
			<path fill="none" stroke="#000000" stroke-miterlimit="10" d="M317.727,67.92c0,1.1,0.9,2,2,2h37.25c1.1,0,2-0.9,2-2v-0.688
				c0-1.1-0.535-2-1.188-2c-0.654,0-1.188-0.9-1.188-2v-8.938c0-1.1-0.9-2-2-2h-32.5c-1.1,0-2,0.9-2,2v8.938c0,1.1-0.534,2-1.188,2
				s-1.188,0.9-1.188,2V67.92z"/>
		</g>
		<g>
			<path fill="#F7FCFE" d="M308.352,48.026c-0.55-0.952-0.1-1.731,1-1.731h55.473c1.1,0,2.311,0.845,2.689,1.877l1.146,3.121
				c0.381,1.032-0.209,1.877-1.309,1.877h-54.028c-1.101,0-2.45-0.779-3.001-1.731L308.352,48.026z"/>
			<path fill="none" stroke="#000000" stroke-miterlimit="10" d="M308.352,48.026c-0.55-0.952-0.1-1.731,1-1.731h55.473
				c1.1,0,2.311,0.845,2.689,1.877l1.146,3.121c0.381,1.032-0.209,1.877-1.309,1.877h-54.028c-1.101,0-2.45-0.779-3.001-1.731
				L308.352,48.026z"/>
		</g>
		<line fill="none" stroke="#000000" stroke-miterlimit="10" x1="380.16" y1="58.514" x2="381.305" y2="58.514"/>
	</g>
	<g id="Tube_3_">
		<path fill="#F7FCFE" stroke="#000000" stroke-miterlimit="10" d="M312.102,65.873v45.309l14.998,90.066
			c0,4.35,5.037,7.875,11.25,7.875c6.215,0,11.25-3.525,11.25-7.875l15-90.066V65.873H312.102z"/>
		<g>
			<path fill="#F7FCFE" d="M369.35,61.873c0,2.199-1.799,4-4,4h-54c-2.199,0-4-1.801-4-4v-1.875c0-2.201,1.801-4,4-4h54
				c2.201,0,4,1.799,4,4V61.873z"/>
			<path fill="none" stroke="#000000" stroke-miterlimit="10" d="M369.35,61.873c0,2.199-1.799,4-4,4h-54c-2.199,0-4-1.801-4-4
				v-1.875c0-2.201,1.801-4,4-4h54c2.201,0,4,1.799,4,4V61.873z"/>
		</g>
	</g>
</g>
<g id="SingleTubes_1_">
	<g id="ClosedLid_1_">
		<g>
			<path fill="#F7FCFE" d="M175.96,48.821c22.801,0,22.801,18.312,0,18.312c0-1.189,0-2.38,0-3.57c13.912,0,13.912-11.173,0-11.173
				C175.96,51.2,175.96,50.011,175.96,48.821z"/>
			<path fill="none" stroke="#000000" stroke-miterlimit="10" d="M175.96,48.821c22.801,0,22.801,18.312,0,18.312
				c0-1.189,0-2.38,0-3.57c13.912,0,13.912-11.173,0-11.173C175.96,51.2,175.96,50.011,175.96,48.821z"/>
		</g>
		<g>
			<path fill="#F7FCFE" d="M130.481,69.853c0,1.1,0.9,2,2,2h37.25c1.1,0,2-0.9,2-2v-0.688c0-1.1-0.535-2-1.188-2
				c-0.654,0-1.188-0.9-1.188-2v-8.938c0-1.1-0.9-2-2-2h-32.5c-1.1,0-2,0.9-2,2v8.938c0,1.1-0.534,2-1.188,2s-1.188,0.9-1.188,2
				V69.853z"/>
			<path fill="none" stroke="#000000" stroke-miterlimit="10" d="M130.481,69.853c0,1.1,0.9,2,2,2h37.25c1.1,0,2-0.9,2-2v-0.688
				c0-1.1-0.535-2-1.188-2c-0.654,0-1.188-0.9-1.188-2v-8.938c0-1.1-0.9-2-2-2h-32.5c-1.1,0-2,0.9-2,2v8.938c0,1.1-0.534,2-1.188,2
				s-1.188,0.9-1.188,2V69.853z"/>
		</g>
		<g>
			<path fill="#F7FCFE" d="M121.106,49.959c-0.55-0.952-0.1-1.731,1-1.731h55.473c1.1,0,2.311,0.845,2.689,1.877l1.146,3.121
				c0.381,1.032-0.209,1.877-1.309,1.877h-54.028c-1.101,0-2.45-0.779-3.001-1.731L121.106,49.959z"/>
			<path fill="none" stroke="#000000" stroke-miterlimit="10" d="M121.106,49.959c-0.55-0.952-0.1-1.731,1-1.731h55.473
				c1.1,0,2.311,0.845,2.689,1.877l1.146,3.121c0.381,1.032-0.209,1.877-1.309,1.877h-54.028c-1.101,0-2.45-0.779-3.001-1.731
				L121.106,49.959z"/>
		</g>
		<line fill="none" stroke="#000000" stroke-miterlimit="10" x1="192.915" y1="60.446" x2="194.06" y2="60.446"/>
	</g>
	<g id="Tube_1_">
		<path fill="#F7FCFE" stroke="#000000" stroke-miterlimit="10" d="M124.856,67.806v45.309l14.998,90.066
			c0,4.35,5.037,7.875,11.25,7.875c6.215,0,11.25-3.525,11.25-7.875l15-90.066V67.806H124.856z"/>
		<g>
			<path fill="#F7FCFE" d="M182.104,63.806c0,2.2-1.8,4-4,4h-54c-2.2,0-4-1.8-4-4v-1.875c0-2.2,1.8-4,4-4h54c2.2,0,4,1.8,4,4V63.806
				z"/>
			<path fill="none" stroke="#000000" stroke-miterlimit="10" d="M182.104,63.806c0,2.2-1.8,4-4,4h-54c-2.2,0-4-1.8-4-4v-1.875
				c0-2.2,1.8-4,4-4h54c2.2,0,4,1.8,4,4V63.806z"/>
		</g>
	</g>
</g>
<g id="SingleTubes_2_">
	<g id="ClosedLid_2_">
		<g>
			<path fill="#F7FCFE" d="M272.545,47.965c22.801,0,22.801,18.312,0,18.312c0-1.189,0-2.38,0-3.57c13.912,0,13.912-11.173,0-11.173
				C272.545,50.344,272.545,49.154,272.545,47.965z"/>
			<path fill="none" stroke="#000000" stroke-miterlimit="10" d="M272.545,47.965c22.801,0,22.801,18.312,0,18.312
				c0-1.189,0-2.38,0-3.57c13.912,0,13.912-11.173,0-11.173C272.545,50.344,272.545,49.154,272.545,47.965z"/>
		</g>
		<g>
			<path fill="#F7FCFE" d="M227.066,68.996c0,1.1,0.9,2,2,2h37.25c1.1,0,2-0.9,2-2v-0.688c0-1.101-0.534-2-1.188-2
				s-1.188-0.9-1.188-2v-8.938c0-1.1-0.9-2-2-2h-32.5c-1.1,0-2,0.9-2,2v8.938c0,1.1-0.534,2-1.188,2s-1.188,0.899-1.188,2V68.996z"
				/>
			<path fill="none" stroke="#000000" stroke-miterlimit="10" d="M227.066,68.996c0,1.1,0.9,2,2,2h37.25c1.1,0,2-0.9,2-2v-0.688
				c0-1.101-0.534-2-1.188-2s-1.188-0.9-1.188-2v-8.938c0-1.1-0.9-2-2-2h-32.5c-1.1,0-2,0.9-2,2v8.938c0,1.1-0.534,2-1.188,2
				s-1.188,0.899-1.188,2V68.996z"/>
		</g>
		<g>
			<path fill="#F7FCFE" d="M217.691,49.103c-0.55-0.953-0.1-1.732,1-1.732h55.473c1.1,0,2.311,0.845,2.69,1.877l1.146,3.121
				c0.38,1.032-0.21,1.877-1.31,1.877h-54.028c-1.1,0-2.45-0.779-3-1.732L217.691,49.103z"/>
			<path fill="none" stroke="#000000" stroke-miterlimit="10" d="M217.691,49.103c-0.55-0.953-0.1-1.732,1-1.732h55.473
				c1.1,0,2.311,0.845,2.69,1.877l1.146,3.121c0.38,1.032-0.21,1.877-1.31,1.877h-54.028c-1.1,0-2.45-0.779-3-1.732L217.691,49.103z
				"/>
		</g>
		<line fill="none" stroke="#000000" stroke-miterlimit="10" x1="289.5" y1="59.59" x2="290.645" y2="59.59"/>
	</g>
	<g id="Tube_2_">
		<path fill="#F7FCFE" stroke="#000000" stroke-miterlimit="10" d="M221.441,66.949v45.309l14.998,90.066
			c0,4.35,5.037,7.875,11.25,7.875c6.215,0,11.25-3.525,11.25-7.875l15-90.066V66.949H221.441z"/>
		<g>
			<path fill="#F7FCFE" d="M278.689,62.949c0,2.2-1.8,4-4,4h-54c-2.2,0-4-1.8-4-4v-1.875c0-2.2,1.8-4,4-4h54c2.2,0,4,1.8,4,4V62.949
				z"/>
			<path fill="none" stroke="#000000" stroke-miterlimit="10" d="M278.689,62.949c0,2.2-1.8,4-4,4h-54c-2.2,0-4-1.8-4-4v-1.875
				c0-2.2,1.8-4,4-4h54c2.2,0,4,1.8,4,4V62.949z"/>
		</g>
	</g>
</g>
<g id="SingleTubes_4_">
	<g id="ClosedLid_4_">
		<g>
			<path fill="#F7FCFE" d="M459.754,47.131c22.801,0,22.801,18.312,0,18.312c0-1.189,0-2.38,0-3.57c13.912,0,13.912-11.173,0-11.173
				C459.754,49.51,459.754,48.32,459.754,47.131z"/>
			<path fill="none" stroke="#000000" stroke-miterlimit="10" d="M459.754,47.131c22.801,0,22.801,18.312,0,18.312
				c0-1.189,0-2.38,0-3.57c13.912,0,13.912-11.173,0-11.173C459.754,49.51,459.754,48.32,459.754,47.131z"/>
		</g>
		<g>
			<path fill="#F7FCFE" d="M414.275,68.162c0,1.1,0.9,2,2,2h37.25c1.1,0,2-0.9,2-2v-0.688c0-1.1-0.535-2-1.188-2
				c-0.654,0-1.188-0.9-1.188-2v-8.938c0-1.1-0.9-2-2-2h-32.5c-1.1,0-2,0.9-2,2v8.938c0,1.1-0.534,2-1.188,2s-1.188,0.9-1.188,2
				V68.162z"/>
			<path fill="none" stroke="#000000" stroke-miterlimit="10" d="M414.275,68.162c0,1.1,0.9,2,2,2h37.25c1.1,0,2-0.9,2-2v-0.688
				c0-1.1-0.535-2-1.188-2c-0.654,0-1.188-0.9-1.188-2v-8.938c0-1.1-0.9-2-2-2h-32.5c-1.1,0-2,0.9-2,2v8.938c0,1.1-0.534,2-1.188,2
				s-1.188,0.9-1.188,2V68.162z"/>
		</g>
		<g>
			<path fill="#F7FCFE" d="M404.9,48.269c-0.55-0.952-0.1-1.731,1-1.731h55.473c1.1,0,2.311,0.845,2.689,1.877l1.146,3.121
				c0.381,1.032-0.209,1.877-1.309,1.877h-54.028c-1.101,0-2.45-0.779-3.001-1.731L404.9,48.269z"/>
			<path fill="none" stroke="#000000" stroke-miterlimit="10" d="M404.9,48.269c-0.55-0.952-0.1-1.731,1-1.731h55.473
				c1.1,0,2.311,0.845,2.689,1.877l1.146,3.121c0.381,1.032-0.209,1.877-1.309,1.877h-54.028c-1.101,0-2.45-0.779-3.001-1.731
				L404.9,48.269z"/>
		</g>
		<line fill="none" stroke="#000000" stroke-miterlimit="10" x1="476.709" y1="58.756" x2="477.854" y2="58.756"/>
	</g>
	<g id="Tube_4_">
		<path fill="#F7FCFE" stroke="#000000" stroke-miterlimit="10" d="M408.65,66.115v45.309l14.998,90.066
			c0,4.35,5.037,7.875,11.25,7.875c6.215,0,11.25-3.525,11.25-7.875l15-90.066V66.115H408.65z"/>
		<g>
			<path fill="#F7FCFE" d="M465.898,62.115c0,2.199-1.799,4-4,4h-54c-2.199,0-4-1.801-4-4V60.24c0-2.201,1.801-4,4-4h54
				c2.201,0,4,1.799,4,4V62.115z"/>
			<path fill="none" stroke="#000000" stroke-miterlimit="10" d="M465.898,62.115c0,2.199-1.799,4-4,4h-54c-2.199,0-4-1.801-4-4
				V60.24c0-2.201,1.801-4,4-4h54c2.201,0,4,1.799,4,4V62.115z"/>
		</g>
	</g>
</g>
<rect x="180.021" y="67.951" fill="#58595B" stroke="#000000" stroke-miterlimit="10" width="16.705" height="143.104"/>
<rect x="276.023" y="68.36" fill="#58595B" stroke="#000000" stroke-miterlimit="10" width="16.705" height="143.104"/>
<rect x="366.934" y="66.539" fill="#58595B" stroke="#000000" stroke-miterlimit="10" width="16.705" height="143.104"/>
<g>
	<path fill="#F2F5D1" stroke="#000000" stroke-miterlimit="10" d="M151.104,211.465c6.215,0,11.25-3.525,11.25-7.875l15-90.066
		V92.904c-3.914-4.414-7.246-9.508-14.937-9.508c-13.567,0-13.567,15.856-27.136,15.856c-4.752,0-7.837-1.947-10.426-4.476v18.746
		l14.998,90.066C139.854,207.939,144.891,211.465,151.104,211.465z"/>
	<path id="largegoop_1_" fill="#BE1E2D" d="M176.233,99.027c-0.539-0.592-1.101-1.156-1.7-1.677
		c-2.18-1.891-4.767-3.295-7.818-4.106c-3.108-0.959-5.194-0.299-6.55,1.576c-1.355,1.877-1.983,4.971-2.176,8.881
		c-0.043,4.081,0.029,8.187,0.148,12.31c-0.371,3.683-0.492,7.357-0.467,11.022c0.897,18.184,3.846,37.165-0.056,56.177
		c-0.8,1.744-1.673,3.365-2.61,4.925c-3.899,3.502-12.119,3.583-12.802,9.137c-1.465,7.144,6.075,12.614,13.855,11.348
		c1.231-0.126,2.429-0.324,3.597-0.573c0.996-1.113,1.578-2.408,1.578-3.796l15-85.266V99.027z"/>
</g>
<g>
	<path fill="#F2F5D1" stroke="#000000" stroke-miterlimit="10" d="M338.349,210.596c6.215,0,11.25-3.525,11.25-7.875l15-90.066
		V92.035c-3.914-4.414-7.246-9.508-14.937-9.508c-13.567,0-13.567,15.856-27.136,15.856c-4.752,0-7.837-1.947-10.426-4.476v18.746
		l14.998,90.066C327.099,207.07,332.136,210.596,338.349,210.596z"/>
	<path id="smallgoop_1_" fill="#BE1E2D" d="M351.601,187.893c-0.48,0.29-0.853,0.667-1.167,1.104
		c-0.286,0.446-0.544,0.889-0.791,1.329c-0.345,0.425-0.624,0.832-0.864,1.229c-0.991,1.92-1.5,3.797-3.802,6.113
		c-0.326,0.24-0.664,0.473-1.014,0.702c-1.255,0.63-3.409,1.163-3.962,1.811c-0.864,0.87,0.737,0.984,2.856,0.351
		c2.816-0.787,5.354-1.938,7.215-3.107c0.564-0.939,0.878-1.972,0.878-3.055l1.118-6.713
		C351.903,187.729,351.745,187.806,351.601,187.893z"/>
</g>
<g>
	<path fill="#F2F5D1" stroke="#000000" stroke-miterlimit="10" d="M247.69,210.199c6.215,0,11.25-3.525,11.25-7.875l15-90.066
		V91.639c-3.914-4.414-7.246-9.508-14.937-9.508c-13.567,0-13.567,15.856-27.136,15.856c-4.752,0-7.837-1.947-10.426-4.476v18.746
		l14.998,90.066C236.44,206.674,241.478,210.199,247.69,210.199z"/>
	<path id="mediumgoop_1_" fill="#BE1E2D" d="M265.456,155.475c-1.722-0.177-2.978,0.252-3.904,1.138s-1.526,2.229-1.938,3.884
		c-0.338,1.716-0.611,3.433-0.859,5.154c-0.497,1.573-0.849,3.123-1.115,4.659c-0.877,7.564-0.631,15.315-4.343,23.576
		c-0.596,0.789-1.225,1.533-1.886,2.255c-2.521,1.753-7.274,2.385-8.095,4.764c-1.395,3.104,2.541,4.853,7.132,3.756
		c3.25-0.642,6.229-1.791,8.848-3.264c0.022-0.203,0.044-0.406,0.044-0.613l7.516-45.127
		C266.412,155.575,265.951,155.51,265.456,155.475z"/>
</g>
<g>
	<path fill="#F2F5D1" stroke="#000000" stroke-miterlimit="10" d="M434.899,209.771c6.215,0,11.25-3.525,11.25-7.875l15-90.066
		V91.211c-3.914-4.414-7.246-9.508-14.937-9.508c-13.567,0-13.567,15.856-27.136,15.856c-4.752,0-7.837-1.947-10.426-4.476v18.746
		l14.998,90.066C423.649,206.246,428.687,209.771,434.899,209.771z"/>
</g>
<text transform="matrix(1 0 0 1 11.918 253.2422)" font-family="'MyriadPro-Regular'" font-size="25">Unwanted Cells</text>
<text transform="matrix(1 0 0 1 12.8271 173.3662)" font-family="'MyriadPro-Regular'" font-size="25">CD+ Cells</text>
<g>
	<polygon stroke="#000000" stroke-miterlimit="10" points="158.353,205.239 150.153,202.41 156.704,194.296 	"/>
	<line fill="none" stroke="#000000" stroke-width="3" stroke-miterlimit="10" x1="154.61" y1="202.672" x2="147.199" y2="232.312"/>
</g>
<g>
	<polygon stroke="#000000" stroke-miterlimit="10" points="135.032,139.835 133.309,134.386 142.02,130.715 	"/>
	
		<line fill="none" stroke="#000000" stroke-width="3" stroke-miterlimit="10" x1="135.147" y1="136.361" x2="110.832" y2="156.343"/>
</g>
<text transform="matrix(1 0 0 1 140.5879 38.501)" font-family="'MyriadPro-Regular'" font-size="41">1</text>
<text transform="matrix(1 0 0 1 234.8652 36.8428)" font-family="'MyriadPro-Regular'" font-size="41">2</text>
<text transform="matrix(1 0 0 1 326.0049 38.4541)" font-family="'MyriadPro-Regular'" font-size="41">3</text>
<text transform="matrix(1 0 0 1 435.0049 38.4541)" font-family="'MyriadPro-Regular'" text-anchor="middle" font-size="25">CD4+/RBC</text>
EOF
    )
    img
  end
end