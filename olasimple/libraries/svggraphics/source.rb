############################################
#
# Generic SVG Graphics for lab work
#
############################################

require 'matrix'

module Graphics

  class Tag
    # an HTML/XML like tag
    #
    def initialize(tag_name, value: nil, properties: nil)
      if properties.nil?
        properties = {}
      end
      if value.nil?
        value = ""
      end
      @tag_name = tag_name
      @properties = properties
      @value = value
    end

    def Tag.property(label, value)
      return "#{label}=\"#{value}\""
    end

    def value
      @value
    end

    def update(props)
      @properties = @properties.merge(props)
    end

    def properties
      @properties.select {|_, v|
        !v.nil? and v != ""}.map {|k, v|
        Tag.property(k, v)
      }.join(' ')
    end

    def formatter
      REXML::Formatters::Pretty.new
    end

    def to_str
      props = self.properties
      if props != ""
        props = " " + props
      end
      if self.value == ""
        return "<#{@tag_name}#{props} />"
      end

      mystr = "<#{@tag_name}#{props}>#{self.value}</#{@tag_name}>"
      return mystr
      mydoc = REXML::Document.new(mystr)
      self.formatter.write(mydoc.root, "")
    end

    def dump
      {
          properties: @properties,
          value: @value,
          tag_name: @tag_name
      }
    end

    def self.load(props)
      print("loading #{self}")
      return self.new(props[:tag_name], value: props[:value], properties: props[:properties])
    end

    def inst
      self.class.load(self.dump)
    end

    # def inst
    #   Marshal.load(Marshal.dump(self))
    # end

    def to_s
      self.to_str
    end
  end

  # A vector image, like an icon
  class SVGElement < Tag
    attr_accessor :alignment, :value, :boundx, :boundy
    attr_reader :x, :y, :yscale, :rot, :xposrot, :yposrot, :xscale, :yscale, :name, :classname, :transformations

    @@debug = false

    # A SVG element to display in an image
    #
    def initialize(children: nil,
                   name: nil,
                   classname: nil,
                   x: 0,
                   y: 0,
                   boundx: 0,
                   boundy: 0,
                   alignment: 'top-left',
                   xscale: 1,
                   yscale: 1,
                   rot: 0,
                   xposrot: 0,
                   yposrot: 0,
                   properties: nil,
                   transformations: nil,
                   style: nil)
      properties = properties || {}
      classname = classname || ""
      children = [children] unless children.is_a?(Array)
      super("g", properties: properties)
      @name = name
      @classname = classname
      @boundx = boundx
      @boundy = boundy
      @children = children
      @alignment = alignment
      @style = style || ""
      @transformations = transformations || []
      self.update_coordinates!(x, y)
      @xscale = xscale
      @yscale = yscale
      if @transformations.empty?
        self.transform!(x: x, y: y, xscale: xscale, yscale: yscale, rot: rot, xposrot: xposrot, yposrot: yposrot)
      end
    end

    def update_coordinates!(x, y)
      @x = x
      @y = y
    end

    def dump
      tag_props = super
      tag_props.reject! {|k, v| ["tag_name", "value"].include?(k.to_s)}
      props = {
          x: @x,
          y: @y,
          xscale: @xscale,
          yscale: @yscale,
          name: @name,
          classname: @classname,
          alignment: @alignment,
          style: @style,
          transformations: @transformations.dup.compact,
          children: @children.dup.compact,
          boundx: @boundx,
          boundy: @boundy
      }
      props.merge(tag_props)
    end

    def self.load(props)
      self.new(**props)
    end

    # sets the debug mode on or off
    # debug mode will display bounding boxes and anchors
    def self.debug onoroff
      @@debug = onoroff
    end

    def value
      # override the Tag value for converting SVGElement to a string
      @value = "\n#{self.display}"
      super
    end

    def new_class(myclass)
      inst = self.inst
      inst.new_class!(myclass)
    end

    def new_name(myname)
      inst = self.inst
      inst.new_name!(myname)
    end

    def new_class!(myclass)
      @classname = myclass
      self
    end

    def new_name!(myname)
      @name = myname
      self
    end

    def svg_properties
      # additional svg properties
      props = {}
      if @name != ""
        props["id"] = @name
      end
      if @classname != ""
        props["class"] = @classname
      end
      props["transform"] = self.get_transform_attribute
      props
    end

    def properties
      # override the Tab properties to add additional svg-specific properties
      # such as id="" and transform
      @properties = @properties.merge(self.svg_properties)
      super
    end

    def origin
      self.get_anchor("upper-left")
    end

    def bounds
      self.bounds_helper(0, 0)
      # use min?
    end

    def align_with(other, other_anchor)
      self.translate!(-@x, -@y)
      v = other.get_abs_anchor(other_anchor)
      v = v - other.abs_anchor_vector
      # v = other.get_abs_anchor_vector(other_anchor)
      #
      self.translate!(*v)
    end

    def g id: nil, classname: nil
      # return a external new group with svg element as a child
      new_g = SVGElement.new(name: id, properties: {"class" => classname}, x: 0, y: 0)
      new_g.update_coordinates!(@x, @y)
      new_g.boundx = @boundx * @xscale
      new_g.boundy = @boundy * @yscale
      new_g.add_child(self)
    end

    # Sets the children array
    def children=(g)
      @children = g
    end

    # Returns the children array
    def children
      @children
    end

    def display
      inst = self
      if @@debug
        inst = inst.display_with_anchors.bb
      end
      if inst.children.is_a?(Array)
        inst.children.map do |child|
          if child.is_a?(SVGElement)
            "#{child}"
          else
            child
          end
        end.join("\n")
      else
        "#{inst.children}"
      end
    end

    def add_child(child)
      if child.is_a?(String)
        @children.push(child)
      else
        @children.push(child.inst)
      end
      self
    end

    def group_children id: nil, classname: nil
      # make an internal grouping of this elements children. Return that grouping
      child_group = SVGElement.new(name: id, classname: classname)
      child_group.children = self.children
      self.children = [child_group]
      return child_group
    end

    def cx
      return (@x + @boundx) / 2.0
    end

    def cy
      return (@y + @boundy) / 2.0
    end

    # ########################################################
    # Transformation
    # ########################################################

    # scaling always happens last in SVG transform attribute to avoid unusual SVG behavior
    def get_transform_attribute
      # transformations = [self.apply_scale, self.apply_translate, self.apply_rotate]
      transformations = []
      transformations += @transformations.dup
      transformations.push("scale(#{@xscale} #{@yscale})")
      transformations.push(self.anchor_translate)
      attr = transformations.join(' ')
      zero = "(-){0,1}0(\.0){0,1}"
      attr.gsub!(/translate\((-){0,1}0(\.0){0,1} (-){0,1}0(\.0){0,1}\)/, '')
      attr.gsub!(/translate\((-){0,1}0(\.0){0,1}\)/, '')
      attr.gsub!(/rotate\((-){0,1}0(\.0){0,1} (-){0,1}0(\.0){0,1} (-){0,1}0(\.0){0,1}\)\s+/, "")
      attr.gsub!(/scale\(1\)\s+/, "")
      attr.gsub!(/scale\(1 1\)\s+/, "")
      attr.strip.gsub(/\s+/, " ")
    end

    def align!(alignment)
      self.alignment = alignment
      self
    end

    def mirror_horizontal
      child_group = self.group_children(id: "mirror_horizontal")
      child_group.scale!(-1, 1).translate!(@boundx, 0)
      return self
    end

    def mirror_vertical
      child_group = self.group_children(id: "mirror_vertical")
      child_group.scale!(1, -1).translate!(0, @boundy)
      return self
    end

    def translate!(x, y = 0)
      @x += x
      y = y || 0
      @y += y
      if x != 0 or y != 0
        @transformations.push self.translate_helper(x, y)
      end
      self
    end

    def rotate!(a, x = 0, y = 0)
      if a != 0
        @transformations.push self.rotate_helper(a, x, y)
      end
      self
    end

    # Scalings must always happen last to avoid unusual SVG behaviors
    def scale!(x, y = nil)
      if y.nil?
        y = x
      end
      @xscale = x
      @yscale = y
      # if x != 1 and y != 1
      #   @transformations.push self.scale_helper(x, y)
      # end
      self
    end

    def transform!(x: 0, y: 0, xscale: 1, yscale: 1, rot: 0, xposrot: 0, yposrot: 0)
      # update the tranform values
      self.translate!(x, y)
          .rotate!(rot, xposrot, yposrot)
          .scale!(xscale, yscale)
    end

    def translate(x, y = nil)
      i = self.inst
      i.translate!(x, y)
    end

    def rotate(a, x = 0, y = 0)
      i = self.inst
      i.rotate!(a, x, y)
    end

    def scale(x, y = nil)
      i = self.inst
      i.scale!(x, y)
    end

    def align(alignment)
      inst = self.inst
      inst.align!(alignment)
    end

    def transform(x: 0, y: 0, xscale: 1, yscale: 1, rot: 0, xposrot: 0, yposrot: 0)
      # update the tranform values
      inst = self.inst
      inst.transform!(x: x, y: y, xscale: xscale, yscale: yscale, rot: rot, xposrot: xposrot, yposrot: yposrot)
    end

    def translate_helper(x, y = 0)
      "translate(#{x} #{y})"
    end

    def rotate_helper(a, x = 0, y = 0)
      # a: degrees
      # x: rotate point
      # y: rotate point
      "rotate(#{a} #{x} #{y})"
    end


    def scale_helper(x, y = 1)
      # a: degrees
      # x: rotate point
      # y: rotate point
      "scale(#{x} #{y})"
    end

    def anchor_translate
      x = self.anchor_vector
      self.translate_helper(-x[-0], -x[1])
    end

    def apply_rotate
      self.rotate_helper(@rot, @xposrot, @yposrot)
    end

    def apply_scale
      self.scale_helper(@xscale, @yscale)
    end

    # ########################################################
    # Anchors
    # ########################################################

    def get_anchor_vector(alignment)
      anchor_matrix = self.parse_alignment alignment
      cw = @boundx / 2.0
      cy = @boundy / 2.0
      Vector[(anchor_matrix[0] + 1) * cw, (anchor_matrix[1] + 1) * cy]
    end

    def anchor_vector
      self.get_anchor_vector @alignment
    end

    def get_anchor alignment
      p = Vector[@x, @y]
      p + self.get_anchor_vector(alignment)
    end

    def anchor
      p = Vector[@x, @y]
      p + self.get_anchor_vector(@alignment)
    end

    def get_abs_anchor alignment
      p = Vector[@x, @y]
      p + self.get_abs_anchor_vector(alignment)
    end

    def abs_anchor
      self.get_abs_anchor(@alignment)
    end

    # multiple the anchor vector by the scaling vector
    def abs_anchor_vector
      return self.get_abs_anchor_vector(@alignment)
    end

    def get_abs_anchor_vector alignment
      a = self.get_anchor_vector(alignment)
      return Vector[@xscale * a[0], @yscale * a[1]]
    end

    def display_with_anchors
      if @name == 'debuganchor'
        return self
      end
      cross = SVGElement.new(name: "debuganchor", boundx: 10, boundy: 10)
      cross.add_child Tag.new('line', properties: {x1: 0, y1: 0, x2: 10, y2: 10, stroke: 'red', 'stroke-width' => 0.5})
      cross.add_child Tag.new('line', properties: {x2: 0, y1: 0, x1: 10, y2: 10, stroke: 'red', 'stroke-width' => 0.5})
      cross.add_child Tag.new('rect', properties: {x: 0, y: 0, width: 10, height: 10, stroke: 'red', fill: 'none', 'stroke-width' => 0.5})
      cross.scale!(0.75)
      cross.align!('center-center')
      inst = self.inst
      halign = ['left', 'center', 'right']
      valign = ['top', 'center', 'bottom']
      halign.each do |h|
        valign.each do |v|
          inst.add_child(cross.translate(*inst.get_anchor_vector("#{h}-#{v}")))
        end
      end
      inst
    end

    def bb
      if @name == "debuganchor"
        return self
      end
      inst = self.inst
      ax, ay = self.anchor
      bounding_box = Tag.new('rect', properties: {
          x: 0,
          y: 0,
          width: @boundx,
          height: @boundy,
          "stroke-width" => 0.5,
          stroke: 'red',
          fill: 'none'
      })
      inst.add_child(bounding_box)
    end

    def parse_alignment(alignment)
      # parses an alignment string like 'center-left'

      tokens = alignment.split('-')
      if tokens.length != 2
        raise "Property 'alignment=#{alignment}' is improperly formatted (e.g. use 'alignment=\"center-left\"')"
      end

      if ['left', 'right'].include?(tokens[1])
        tokens[0], tokens[1] = tokens[1], tokens[0]
      end

      if ['upper', 'bottom', 'top'].include?(tokens[0])
        tokens[0], tokens[1] = tokens[1], tokens[0]
      end

      if ['left', 'right'].include?(tokens[1])
        raise "Property 'alignment' not understood. Cannot be aligned to both left and right. Found '#{alignment}'"
      end

      if ['top', 'upper', 'bottom'].include?(tokens[0])
        raise "Property 'alignment' not understood. Cannot be aligned to both top and bottom. Found '#{alignment}'"
      end

      anchor_dict = {
          left: -1,
          center: 0,
          right: 1,
          upper: -1,
          top: -1,
          bottom: 1
      }
      tokens.map {|t| anchor_dict[t.to_sym]}
    end

    # change relative coordinates to absolute coordinates
    def v(x, y)
      return Vector[x, y]
    end

    def abs_v(x, y)
      return Vector[@xscale * x, @yscale * y]
    end

    def style(mystyle)
      inst = self.inst
      inst.style!(mystyle)
    end

    def style!(mystyle)
      @style = Tag.new("style", value: mystyle)
    end

    def svg(width=nil, height=nil, scale = 1.0)
      width = width || @boundx * @xscale
      height = height || @boundy * @yscale
      Tag.new('svg',
              value: [@style, self.g(id: "svg").to_str].join(''), properties: {
              width: "#{width * scale}px",
              height: "#{height * scale}px",
              viewBox: "0 0 #{width} #{height}",
              version: "1.1",
              xmlns: "http://www.w3.org/2000/svg"
          })
    end
  end

  class Shape < SVGElement
    def initialize(x, y, shape, stroke = 'black', stroke_width = 1, shapevalue = nil, *args)

      super(*args)
      if @shape_properties.nil?
        @shape_properties = {}
      end
      @shape = shape
      @shapevalue = shapevalue
      self.update({stroke: stroke, "stroke-width" => stroke_width})
    end

    def dump
      elements_props = super
      {
          shape_properties: @shape_properties,
          shape: @shape,
          shapevalue: @shapevalue,
          element_props: elements_props
      }
    end

    def self.load(props)
      new = self.new(0, 0, props[:shape], 'black', 1, props[:shapevalue], **props[:element_props])
      new.update(props[:shape_properties])
    end

    def inst
      self.class.load(self.dump)
    end

    # def inst
    #   Marshal.load(Marshal.dump(self))
    # end

    def get_child
      Tag.new(@shape, value: @shapevalue, properties: @shape_properties)
    end

    def update new_hash
      @shape_properties.merge!(new_hash)
      @children[0] = self.get_child
      self
    end
  end

  class Rect < Shape
    def initialize(x, y, width, height, *args)
      @shape_properties = {width: width, height: height}
      super(x, y, 'rect', *args)
      @boundx = width
      @boundy = height
    end
  end

  class Circle < Shape
    def initialize(x, y, r, *args)
      @shape_properties = {r: r, cx: 0, cy: 0}
      super(x, y, 'circle', *args)
    end
  end

  class Line < Shape
    def initialize(x1, y1, x2, y2, *args)
      @shape_properties = {
          x1: x1,
          y1: y1,
          x2: x2,
          y2: y2}
      super(0, 0, 'line', *args)
    end
  end

  class VectorLine < Shape
    def initialize(x, y, dx, dy, *args)
      @shape_properties = {x1: 0, y1: 0, x2: dx, y2: dy}
      super(x, y, 'line', *args)
    end
  end

  def label(text, properties = nil)
    properties = properties || {}
    font_size = properties[:font_size] || 12
    boundx = font_size * text.length * 0.5
    boundy = font_size
    mylabel = SVGElement.new(boundx: boundx, boundy: boundy)
    a = mylabel.get_anchor_vector('center-center')
    properties[:x] = a[0]
    properties[:y] = a[1]
    properties["alignment-baseline".to_sym] = 'middle'
    properties["text-anchor".to_sym] = 'middle'
    properties['font-family'.to_sym] = "Verdana"
    mylabel.add_child(
        Tag.new("text", value: text, properties: properties)
    )
  end

  # class Label < Shape
  #   def initialize(label, font_size, x = 0, y = 0, font_family = "Arial", stroke='black', stroke_width=0, *args)
  #     @shape_properties = {
  #         x: 0, y: 0,
  #         "font-size" => font_size,
  #         "font-family" => font_family,
  #         'alignment-baseline' => 'middle',
  #         'text-anchor' => 'middle'}
  #     label = label || ""
  #     super(x, y, 'text', stroke, stroke_width, @shapevalue, *args)
  #     @shapevalue = label
  #     @boundy = font_size
  #     @boundx = @shapevalue.length * font_size
  #     self.update({})
  #   end
  #
  #   def self.load(props)
  #     new = self.new(props[:shapevalue], 0, 0, 0, "Arial", "black", 0, props[:element_props])
  #     new.update(props[:shape_properties])
  #   end
  #
  #   # Override x, y position so that label aligns with anchor
  #   def get_child
  #     s = @shape_properties.dup
  #     av = self.get_anchor_vector('center-center')
  #     s[:x] = av[0]
  #     s[:y] = av[1]
  #     Tag.new(@shape, value: @shapevalue, properties: s)
  #   end
  #
  #   # auto | baseline | before-edge | text-before-edge | middle | central | after-edge | text-after-edge | ideographic | alphabetic | hanging | mathematical | inherit
  #   def vertical_alignment(alignment)
  #     self.update('alignment-baseline' => alignment)
  #   end
  #
  #   # start | middle | end | inherit
  #   def text_anchor(alignment)
  #     self.update('text-anchor' => alignment)
  #   end
  # end

  # Organizes SVGElements on a grid of your choosing.
  # Makes it easier to position elements
  class SVGGrid < SVGElement
    attr_accessor :elements

    def initialize(xnum, ynum, xspacing, yspacing, *args)
      super(*args)
      if @name == ""
        @name = "grid"
      end
      @xnum = xnum
      @ynum = ynum
      @xspacing = xspacing
      @yspacing = yspacing
      @boundx = self.boundx
      @boundy = self.boundy
      @elements = Array.new(xnum) {Array.new(ynum) {[]}} # 3d array for displaying some elements on a 2D grid
    end

    def dump
      element_props = super
      {
          xspacing: @xspacing,
          yspacing: @yspacing,
          xnum: @xnum,
          ynum: @ynum,
          element_props: element_props,
          elements: @elements
      }
    end

    def self.load(props)
      newgrid = SVGGrid.new(props[:xnum], props[:ynum], props[:xspacing], props[:yspacing], props[:element_props])
      newgrid.update_elements(props[:elements])
      newgrid
    end

    def update_elements elements
      if elements.length != @xnum
        raise "Cannot update_elements. Number of rows must equal #{xnum} but was #{elements.length}"
      end

      col_lengths = elements.map {|row| row.length}.uniq

      if col_lengths.length != 1
        raise "Cannot update_elements. Rows have different number of columns."
      end

      if elements[0].length != @ynum
        raise "Cannot update_elements. Number of columns must equal #{@ynum} but was #{elements[0].length}"
      end

      @elements = elements
    end

    def inst
      self.class.load(self.dump)
    end

    # def inst
    #   Marshal.load(Marshal.dump(self))
    # end


    def pos(r, c)
      return Vector[r * @xspacing, c * @yspacing]
    end

    def abs_pos_vector(r, c)
      v = self.pos(r, c)
      return Vector[@xscale * v[0], @yscale * v[1]]
    end

    def grid_coor(r, c, x, y)
      px, py = self.pos(r, c)
      return [px + x, py + y]
    end

    def grid_elements
      @elements.map.with_index do |row, r|
        x = self.pos(r, 0)[0]
        row_element = SVGElement.new(name: "gridrow#{r}").translate(x, 0)
        row.each.with_index do |element, c|
          y = pos(0, c)[1]
          col_element = SVGElement.new(name: "gridcol#{c}").translate(0, y)
          col_element.children = element

          # don't add empty columns
          if not element.nil? and not element == "" and not element == []
            row_element.add_child(col_element)
          end
        end

        # don't add empty rows
        row_element unless row_element.children.empty?
      end.compact
    end

    def children
      children = @children.dup
      grid_elements = self.grid_elements
      grid_elements + children
    end

    def group_children id: nil, classname: nil
      raise "Cannot group children of a SVGGrid. Group using '.g' before grouping children"
    end

    def add(element, x, y)
      xfloor = x.floor
      xrem = (x - xfloor).round(1)
      yfloor = y.floor
      yrem = (y - yfloor).round(1)

      if xrem > 0 or yrem > 0
        element = element.g(id: "gridshift").translate(xrem * @xspacing, yrem * @yspacing)
      end
      ele = @elements[xfloor][yfloor]
      if ele.nil?
        ele = []
      end
      ele.push(element)
      @elements[xfloor][yfloor] = ele
    end

    # TODO: maximum width from individual elements bounding boxes...
    def boundx
      @xnum * @xspacing
    end

    # TODO: maximum height from individual elements bounding boxes...
    def boundy
      @ynum * @yspacing
    end

    # Applies the block through each element in the grid
    def each
      raise "#{self.class.name}.each needs a selection block" unless block_given?
      @elements.each.with_index do |row, r|
        row.each.with_index do |col, c|
          col.each do |element|
            Proc.new.call(element)
          end
        end
      end
    end

    # Applies the block through each row, col in the grid
    def each_pos
      raise "#{self.class.name}.each_pos needs a selection block" unless block_given?
      @elements.each.with_index do |row, r|
        row.each.with_index do |col, c|
          Proc.new.call(r, c)
        end
      end
    end

    def elements_at(r, c)
      @elements[r][c]
    end

    def select
      raise "#{self.class.name}.select needs a selection block" unless block_given?
      selected = []
      @elements.each.with_index do |row, r|
        row.each.with_index do |col, c|
          if Proc.new.call(r, c)
            selected.push(col)
          end
        end
      end
      return selected
    end

    # def add_each_pos
    #   raise "#{self.class.name}.add_each_pos needs a selection block" unless block_given?
    #   @elements.each.with_index do |row, r|
    #     row.each.with_index do |col, c|
    #       new_element = Proc.new.call(r, c)
    #       self.add(new_element, r, c)
    #     end
    #   end
    # end

    # return a copy of this grid with grid dots
    def griddots
      dot = Tag.new('circle', properties: {r: 3})
      inst = self.inst
      inst.each_pos do |r, c|
        inst.add(dot, r, c)
      end
      inst
    end
  end

  module FunctionalSVG
    def roundedtube(opened: false, contents: 'empty')
      _roundedtube = SVGElement.new(boundx: 46.92, boundy: 140)
      if contents == 'full'
        _roundedtube.add_child(
              '<svg><defs><style>.cls-1{fill:#26afe5;}.cls-2{fill:#fff;}.cls-2,.cls-3{stroke:#231f20;stroke-miterlimit:10;stroke-width:0.5px;}.cls-3{fill:none;}</style></defs><title>Untitled-18</title><path class="cls-1" d="M412.76,285.62c-8.82,5.75-17.91,3.62-26.54.87l-10.47,3v45.4c0,.05,0,.1,0,.15.12,1.91,4.52,35.39,19.95,31.76,0,0,12.62,4.63,17.42-30.86a2.67,2.67,0,0,0,0-.37Z" transform="translate(-372.39 -241.25)"/><path class="cls-1" d="M383.88,285.72a15.52,15.52,0,0,0-8.13-.66v4.44l10.47-3Z" transform="translate(-372.39 -241.25)"/><rect class="cls-2" x="5.5" y="2.53" width="33.11" height="9.82" rx="2.36" ry="2.36"/><rect class="cls-2" x="0.25" y="0.25" width="42.88" height="7.39" rx="2.36" ry="2.36"/><path class="cls-3" d="M412.06,252" transform="translate(-372.39 -241.25)"/><path class="cls-3" d="M412.67,253.6a3.88,3.88,0,0,0,3.29-2.79,4.85,4.85,0,0,0-.42-4.28" transform="translate(-372.39 -241.25)"/><path class="cls-3" d="M412.67,255.44a6,6,0,0,0,6.16-4.86,5.79,5.79,0,0,0-3.17-7" transform="translate(-372.39 -241.25)"/><path class="cls-3" d="M375.39,257.57v77.6c0,.05,0,.1,0,.15.12,1.91,4.52,35.39,19.95,31.76,0,0,12.62,4.63,17.42-30.86a2.66,2.66,0,0,0,0-.37l-.61-78.29a2.52,2.52,0,0,0-2.52-2.5H377.91A2.52,2.52,0,0,0,375.39,257.57Z" transform="translate(-372.39 -241.25)"/><rect class="cls-2" x="0.53" y="11.4" width="42.32" height="4.79" rx="2.4" ry="2.4"/></svg>'
              )
      elsif contents == 'empty'
        _roundedtube.add_child(
                '<svg><defs><style>.cls-1-emptytube{fill:#fff;}.cls-2{fill:#fff;}.cls-2,.cls-3{stroke:#231f20;stroke-miterlimit:10;stroke-width:0.5px;}.cls-3{fill:none;}</style></defs><title>Untitled-18</title><path class="cls-1-emptytube" d="M412.76,285.62c-8.82,5.75-17.91,3.62-26.54.87l-10.47,3v45.4c0,.05,0,.1,0,.15.12,1.91,4.52,35.39,19.95,31.76,0,0,12.62,4.63,17.42-30.86a2.67,2.67,0,0,0,0-.37Z" transform="translate(-372.39 -241.25)"/><path class="cls-1-emptytube" d="M383.88,285.72a15.52,15.52,0,0,0-8.13-.66v4.44l10.47-3Z" transform="translate(-372.39 -241.25)"/><rect class="cls-2" x="5.5" y="2.53" width="33.11" height="9.82" rx="2.36" ry="2.36"/><rect class="cls-2" x="0.25" y="0.25" width="42.88" height="7.39" rx="2.36" ry="2.36"/><path class="cls-3" d="M412.06,252" transform="translate(-372.39 -241.25)"/><path class="cls-3" d="M412.67,253.6a3.88,3.88,0,0,0,3.29-2.79,4.85,4.85,0,0,0-.42-4.28" transform="translate(-372.39 -241.25)"/><path class="cls-3" d="M412.67,255.44a6,6,0,0,0,6.16-4.86,5.79,5.79,0,0,0-3.17-7" transform="translate(-372.39 -241.25)"/><path class="cls-3" d="M375.39,257.57v77.6c0,.05,0,.1,0,.15.12,1.91,4.52,35.39,19.95,31.76,0,0,12.62,4.63,17.42-30.86a2.66,2.66,0,0,0,0-.37l-.61-78.29a2.52,2.52,0,0,0-2.52-2.5H377.91A2.52,2.52,0,0,0,375.39,257.57Z" transform="translate(-372.39 -241.25)"/><rect class="cls-2" x="0.53" y="11.4" width="42.32" height="4.79" rx="2.4" ry="2.4"/></svg>'
              )
      else
        return roundedtube(opened: false, contents: 'empty')
      end
      _roundedtube.translate!(0,70)
    end

    def screwbottle(opened: false, contents: 'empty')
      _screwbottle = SVGElement.new(boundx: 46.92, boundy: 140)
      _screwbottle.add_child(
          '<svg><defs><style>.cls-1{fill:#26afe5;}.cls-2,.cls-3{fill:none;}.cls-3,.cls-4{stroke:#231f20;stroke-miterlimit:10;stroke-width:0.5px;}.cls-4{fill:#fff;}</style></defs><path class="cls-1" d="M377.92,325.7c-4.23-1-8.46.27-11.89,2v31.86a8.73,8.73,0,0,0,8.71,8.71h41.68a8.73,8.73,0,0,0,8.71-8.71V328.25c-9.24.24-7.87,3.46-19.44,7.63S387.64,328,377.92,325.7Z" transform="translate(-365.78 -243.8)"/><path class="cls-2" d="M369,280.29" transform="translate(-365.78 -243.8)"/><rect class="cls-3" x="0.25" y="43.66" width="59.09" height="80.08" rx="8.6" ry="8.6"/><path class="cls-4" d="M395.58,244c-16.32,0-29.55,3.59-29.55,8V285.6c0,4.42,13.23,8,29.55,8s29.55-3.59,29.55-8V252.05C425.12,247.63,411.89,244,395.58,244Z" transform="translate(-365.78 -243.8)"/><ellipse class="cls-4" cx="29.8" cy="8.12" rx="22.86" ry="4.76"/><line class="cls-3" x1="5.46" y1="14.46" x2="5.46" y2="41.93"/><line class="cls-3" x1="30.86" y1="18.98" x2="30.86" y2="46.45"/><line class="cls-3" x1="55.9" y1="12.89" x2="55.9" y2="40.36"/><line class="cls-3" x1="44.1" y1="17.66" x2="44.1" y2="45.13"/><line class="cls-3" x1="17.63" y1="17.66" x2="17.63" y2="45.13"/></svg>'
          ).translate!(0, 70)
    end
    
    def samplecolumn(opened: false, contents: 'empty')
      column =  SVGElement.new(boundx: 46.92, boundy: 140)
      if contents == 'empty' && !opened
        column.add_child(
          '<svg><defs><style>.cls-1_sc{fill:#fff;}.cls-1_sc,.cls-2_sc{stroke:#231f20;stroke-miterlimit:10;stroke-width:0.5px;}.cls-2_sc{fill:none;}</style></defs><path class="cls-1_sc" d="M375.23,260.43V338c0,.05,0,.1,0,.15.12,1.91,4.52,35.39,19.95,31.76,0,0,12.62,4.63,17.42-30.86a2.66,2.66,0,0,0,0-.37L412,260.41a2.52,2.52,0,0,0-2.52-2.5H377.75A2.52,2.52,0,0,0,375.23,260.43Z" transform="translate(-371.72 -237.72)"/><rect class="cls-1_sc" x="5.5" y="2.53" width="33.11" height="9.82" rx="2.36" ry="2.36"/><rect class="cls-1_sc" x="3.51" y="9.99" width="36.77" height="4.72" rx="1.19" ry="1.19"/><path class="cls-1_sc" d="M377.22,252.44v51.26a1.65,1.65,0,0,0,.85,1.44l5.56,3.06a1.65,1.65,0,0,1,.85,1.44v7.3a1.65,1.65,0,0,0,1.65,1.65h14.54a1.65,1.65,0,0,0,1.65-1.65v-7.25a1.65,1.65,0,0,1,.91-1.48l6.18-3.09a1.65,1.65,0,0,0,.91-1.48V252.44" transform="translate(-371.72 -237.72)"/><rect class="cls-1_sc" x="14.16" y="70.95" width="15.06" height="6.09" rx="0.98" ry="0.98"/><rect class="cls-1_sc" x="0.25" y="0.25" width="42.88" height="7.39" rx="2.36" ry="2.36"/><path class="cls-2_sc" d="M416.1,248" transform="translate(-371.72 -237.72)"/><path class="cls-2_sc" d="M411.38,248.51" transform="translate(-371.72 -237.72)"/><path class="cls-2_sc" d="M412,250.08a3.88,3.88,0,0,0,3.29-2.79,4.85,4.85,0,0,0-.42-4.28" transform="translate(-371.72 -237.72)"/><path class="cls-2_sc" d="M412,251.91a6,6,0,0,0,6.16-4.86,5.79,5.79,0,0,0-3.17-7" transform="translate(-371.72 -237.72)"/><rect class="cls-1_sc" x="1.05" y="17.78" width="42.32" height="4.79" rx="2.4" ry="2.4"/></svg>'
          )
      elsif contents == 'no-collector' && closed
        column.add_child(
          '<svg><defs><style>.cls-1_sc{fill:#fff;}.cls-1_sc,.cls-2_sc{stroke:#231f20;stroke-miterlimit:10;stroke-width:0.5px;}.cls-2_sc{fill:none;}</style></defs><rect class="cls-1_sc" x="5.5" y="2.53" width="33.11" height="9.82" rx="2.36" ry="2.36"/><rect class="cls-1_sc" x="3.51" y="9.99" width="36.77" height="4.72" rx="1.19" ry="1.19"/><path class="cls-1_sc" d="M377.46,280.13v51.26a1.65,1.65,0,0,0,.85,1.44l5.56,3.06a1.65,1.65,0,0,1,.85,1.44v7.3a1.65,1.65,0,0,0,1.65,1.65h14.54a1.65,1.65,0,0,0,1.65-1.65v-7.25a1.65,1.65,0,0,1,.91-1.48l6.18-3.09a1.65,1.65,0,0,0,.91-1.48V280.13" transform="translate(-371.95 -265.42)"/><rect class="cls-1_sc" x="14.16" y="70.95" width="15.06" height="6.09" rx="0.98" ry="0.98"/><rect class="cls-1_sc" x="0.25" y="0.25" width="42.88" height="7.39" rx="2.36" ry="2.36"/><path class="cls-2_sc" d="M416.34,275.65" transform="translate(-371.95 -265.42)"/><path class="cls-2_sc" d="M411.62,276.2" transform="translate(-371.95 -265.42)"/><path class="cls-2_sc" d="M412.23,277.77a3.88,3.88,0,0,0,3.29-2.79,4.85,4.85,0,0,0-.42-4.28" transform="translate(-371.95 -265.42)"/><path class="cls-2_sc" d="M412.23,279.61a6,6,0,0,0,6.16-4.86,5.79,5.79,0,0,0-3.17-7" transform="translate(-371.95 -265.42)"/></svg>'
          )
      else
        column.add_child(samplecolumn.translate!(0,-70)) #default to closed and empty if options could not be matched
      end
      column.translate!(0,70)
    end
    
    def collectiontube(contents: 'empty')
      ctube = SVGElement.new(boundx: 46.92, boundy: 140)
      if contents == 'empty'
        ctube.add_child(
          '<svg><defs><style>.cls-1_collection_tube{fill:none;stroke:#231f20;stroke-miterlimit:10;stroke-width:0.5px;}</style></defs><path class="cls-1_collection_tube" d="M377.69,251.62v77.6c0,.05,0,.1,0,.15.12,1.91,4.52,35.39,19.95,31.76,0,0,12.62,4.63,17.42-30.86a2.66,2.66,0,0,0,0-.37l-.61-78.29a2.52,2.52,0,0,0-2.52-2.5H380.21A2.52,2.52,0,0,0,377.69,251.62Z" transform="translate(-374.97 -246.46)"/><rect class="cls-1_collection_tube" x="0.25" y="0.25" width="42.32" height="4.79" rx="2.4" ry="2.4"/></svg>'
          )
      elsif contents == 'full'
        ctube.add_child(
          '<svg><defs><style>.cls-1_collection_tube{fill:#26afe5;}.cls-2_collection_tube{fill:#fff;}.cls-2_collection_tube,.cls-3_collection_tube{stroke:#231f20;stroke-miterlimit:10;stroke-width:0.5px;}.cls-3_collection_tube{fill:none;}</style></defs><path class="cls-1_collection_tube" d="M412.76,285.62c-8.82,5.75-17.91,3.62-26.54.87l-10.47,3v45.4c0,.05,0,.1,0,.15.12,1.91,4.52,35.39,19.95,31.76,0,0,12.62,4.63,17.42-30.86a2.67,2.67,0,0,0,0-.37Z" transform="translate(-372.39 -241.25)"/><path class="cls-1_collection_tube" d="M383.88,285.72a15.52,15.52,0,0,0-8.13-.66v4.44l10.47-3Z" transform="translate(-372.39 -241.25)"/><rect class="cls-2_collection_tube" x="5.5" y="2.53" width="33.11" height="9.82" rx="2.36" ry="2.36"/></svg>'
          )
      end
    end    
    
    def svg_from_html(html, bx=50, by=140)
      __svg = SVGElement.new(boundx: bx, boundy: by)
      __svg.add_child(html)
      __svg
    end

    def icon_from_html(html)
      __svg = SVGElement.new(boundx: 500, boundy: 500)
      __svg.add_child(html)
      __svg
    end

    # svg_func: a symbol method name for a function that returns an SVGElement
    # svg_label: label for svg
    # opts: option hash to be applied to svg_func as named parameters
    #
    # example: svg = draw_svg(:tube, svg_label: "Hello\nWorld", opened: true, full: true)
    def draw_svg(svg_func, svg_label: nil, svg_label_initial_offset: 0, **opts)
      if opts.any?
        svg = method(svg_func).call(**opts)
      else
        svg = method(svg_func).call
      end
      svg = label_object(svg, svg_label, svg_label_initial_offset) if svg_label
      svg
    end

    def label_object(svg, _label, initial_offset=0)
      def label_helper(svg, labels, offsety = 0)
        l = label(labels.shift, "font-size".to_sym => 25)
        l.align!('center-center')
        l.translate!(svg.boundx / 2, svg.boundy / 2 + offsety.to_i)
        svg.add_child(l)
        return label_helper(svg, labels, offsety + 25) unless labels.empty?
        return svg
      end

      labels = _label.split("\n")
      return labels.empty? ? svg : label_helper(svg, labels, initial_offset)
    end
  end

  module MyGraphics
    attr_reader :tube, :openlid, :closedlid, :closedtube, :opentube, :detection_strip, :strip, :striplabel

    # bounding box for tube elements
    @@tubebb = SVGElement.new(boundx: 78.35, boundy: 242.95)

    def rarrow
      arrow = SVGElement.new(boundx: 33.48, boundy: 38.65)
      arrow.new_class!("rarrow")
      arrow.add_child('<polygon points="0,0 33.477,19.328 0,38.655 "/>')
    end

    def larrow
      self.rarrow.mirror_horizontal.new_class("larrow")
    end

    def uparrow
      arrow = SVGElement.new(boundx: 38.65, boundy: 33.48)
      arrow.new_class!("uparrow")
      arrow.add_child('<polygon points="0,33.477 19.328,0 38.655,33.477 "/>')
    end

    def downarrow
      self.uparrow.mirror_vertical.new_class("downarrow")
    end

    def tube
      _tube = @@tubebb.inst
      _tube.new_class!("tube")
      _tube.add_child(<<EOF
      <path fill="#F7FCFE" stroke="#000000" stroke-miterlimit="10" d="M4.75,99.697v45.309l14.998,90.066
        c0,4.35,5.036,7.875,11.25,7.875c6.215,0,11.25-3.525,11.25-7.875l15-90.066V99.697H4.75z"/>
      <g>
        <path fill="#F7FCFE" d="M61.998,95.697c0,2.199-1.799,4-4,4h-54c-2.2,0-4-1.801-4-4v-1.875c0-2.201,1.8-4,4-4h54
          c2.201,0,4,1.799,4,4V95.697z"/>
        <path fill="none" stroke="#000000" stroke-miterlimit="10" d="M61.998,95.697c0,2.199-1.799,4-4,4h-54c-2.2,0-4-1.801-4-4v-1.875
          c0-2.201,1.8-4,4-4h54c2.201,0,4,1.799,4,4V95.697z"/>
      </g>
EOF
      )
      # <line fill="#F7FCFE" stroke="#000000" stroke-miterlimit="10" x1="7.721" y1="123.572" x2="53.387" y2="123.572"/>
      _tube.inst
    end

    def tube2mL
      _tube = @@tubebb.inst
      _tube.new_class!("tube")
      _tube.add_child(<<EOF
        	<g id="2mLTube">
		<path id="_x32_mLTube" fill="#F7FCFE" stroke="#000000" stroke-miterlimit="10" d="M57,96.698H4.503v42.581l0.479,2.704
		c-0.311,1.553-0.479,3.153-0.479,4.792v70.798c0,13.955,11.812,25.374,26.249,25.374c14.436,0,26.248-11.419,26.248-25.374v-70.798
		c0-1.639-0.17-3.239-0.48-4.792l0.48-2.704V96.698z"/></g>
EOF
      )
      _tube
    end

    def closedlid
      _closedlid = @@tubebb.inst
      _closedlid.new_class!("closedlid")
      _closedlid.add_child(<<EOF
      <g>
        <path fill="#F7FCFE" d="M55.854,80.713c22.801,0,22.801,18.312,0,18.312c0-1.189,0-2.38,0-3.57c13.912,0,13.912-11.173,0-11.173
          C55.854,83.092,55.854,81.902,55.854,80.713z"/>
        <path fill="none" stroke="#000000" stroke-miterlimit="10" d="M55.854,80.713c22.801,0,22.801,18.312,0,18.312
          c0-1.189,0-2.38,0-3.57c13.912,0,13.912-11.173,0-11.173C55.854,83.092,55.854,81.902,55.854,80.713z"/>
      </g>
      <g>
        <path fill="#F7FCFE" d="M10.375,101.744c0,1.1,0.9,2,2,2h37.25c1.1,0,2-0.9,2-2v-0.688c0-1.1-0.535-2-1.188-2
          c-0.654,0-1.188-0.9-1.188-2v-8.938c0-1.1-0.9-2-2-2h-32.5c-1.1,0-2,0.9-2,2v8.938c0,1.1-0.534,2-1.188,2s-1.188,0.9-1.188,2
          V101.744z"/>
        <path fill="none" stroke="#000000" stroke-miterlimit="10" d="M10.375,101.744c0,1.1,0.9,2,2,2h37.25c1.1,0,2-0.9,2-2v-0.688
          c0-1.1-0.535-2-1.188-2c-0.654,0-1.188-0.9-1.188-2v-8.938c0-1.1-0.9-2-2-2h-32.5c-1.1,0-2,0.9-2,2v8.938c0,1.1-0.534,2-1.188,2
          s-1.188,0.9-1.188,2V101.744z"/>
      </g>
      <g>
        <path fill="#F7FCFE" d="M1,81.851c-0.55-0.952-0.101-1.731,1-1.731h55.473c1.1,0,2.311,0.845,2.689,1.877l1.146,3.121
          c0.381,1.032-0.209,1.877-1.309,1.877H5.972c-1.1,0-2.45-0.779-3-1.731L1,81.851z"/>
        <path fill="none" stroke="#000000" stroke-miterlimit="10" d="M1,81.851c-0.55-0.952-0.101-1.731,1-1.731h55.473
          c1.1,0,2.311,0.845,2.689,1.877l1.146,3.121c0.381,1.032-0.209,1.877-1.309,1.877H5.972c-1.1,0-2.45-0.779-3-1.731L1,81.851z"/>
      </g>
      <line fill="none" stroke="#000000" stroke-miterlimit="10" x1="72.809" y1="92.338" x2="73.953" y2="92.338"/>
EOF
      )
      _closedlid.inst
    end

    def openlid
      _openlid = @@tubebb.inst
      _openlid.new_class!("openlid")
      _openlid.add_child(<<EOF
      <g>
        <path fill="#F7FCFE" d="M72.42,77.695c-3.271,7.512-10.102,12.477-16.996,13.795c0.375,1.254,0.75,2.506,1.125,3.76
          c17.402-5.207,26.029-24.734,18.164-41.105c-1.178,0.566-2.357,1.133-3.537,1.699C74.844,61.828,75.77,70.221,72.42,77.695z"/>
        <path fill="none" stroke="#000000" stroke-miterlimit="10" d="M72.42,77.695c-3.271,7.512-10.102,12.477-16.996,13.795
          c0.375,1.254,0.75,2.506,1.125,3.76c17.402-5.207,26.029-24.734,18.164-41.105c-1.178,0.566-2.357,1.133-3.537,1.699
          C74.844,61.828,75.77,70.221,72.42,77.695z"/>
      </g>
      <g>
        <path fill="#F7FCFE" d="M56.721,10.375c-1.1,0-2,0.9-2,2v37.25c0,1.1,0.9,2,2,2h0.688c1.1,0,2-0.534,2-1.188s0.9-1.188,2-1.188
          h8.938c1.1,0,2-0.9,2-2v-32.5c0-1.1-0.9-2-2-2h-8.938c-1.1,0-2-0.534-2-1.188s-0.9-1.188-2-1.188H56.721z"/>
        <path fill="none" stroke="#000000" stroke-miterlimit="10" d="M56.721,10.375c-1.1,0-2,0.9-2,2v37.25c0,1.1,0.9,2,2,2h0.688
          c1.1,0,2-0.534,2-1.188s0.9-1.188,2-1.188h8.938c1.1,0,2-0.9,2-2v-32.5c0-1.1-0.9-2-2-2h-8.938c-1.1,0-2-0.534-2-1.188
          s-0.9-1.188-2-1.188H56.721z"/>
      </g>
      <g>
        <path fill="#F7FCFE" d="M76.613,1c0.953-0.55,1.732-0.1,1.732,1v55.471c0,1.1-0.846,2.311-1.877,2.69l-3.121,1.148
          c-1.033,0.38-1.877-0.21-1.877-1.31V5.971c0-1.1,0.779-2.45,1.73-3L76.613,1z"/>
        <path fill="none" stroke="#000000" stroke-miterlimit="10" d="M76.613,1c0.953-0.55,1.732-0.1,1.732,1v55.471
          c0,1.1-0.846,2.311-1.877,2.69l-3.121,1.148c-1.033,0.38-1.877-0.21-1.877-1.31V5.971c0-1.1,0.779-2.45,1.73-3L76.613,1z"/>
      </g>
      <line fill="#F7FCFE" stroke="#000000" stroke-miterlimit="10" x1="60.408" y1="47.721" x2="60.408" y2="14.471"/>
EOF
      )
      _openlid.inst
    end

    def opentube
      _opentube = @@tubebb.inst
      _opentube.new_name!("opentube")
      _opentube.add_child(self.openlid)
      _opentube.add_child(self.tube).inst
    end

    def closedtube
      _closedtube = @@tubebb.inst
      _closedtube.new_name!("closedtube")
      _closedtube.add_child(self.closedlid)
      _closedtube.add_child(self.tube).inst
    end

    def strip
      mystrip = SVGElement.new(boundx: 83.1, boundy: 247.45)
      mystrip.add_child(<<EOF
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
EOF
      )
    end

    def fluid_small
      fluid = @@tubebb.inst
      fluid.new_class!("fluid")
      fluid.new_name!("small_fluid")
      fluid.add_child(<<EOF
      <path id="FluidSmall" fill="#00AEEF" stroke="#000000" stroke-miterlimit="10" d="M44.565,216.853
	c-12.031,0-12.031,8.833-24.062,8.833c-0.825,0-1.589-0.045-2.309-0.122l1.584,9.509c0,4.35,5.036,7.875,11.249,7.875
	c6.215,0,11.25-3.525,11.25-7.875l3.031-18.202C45.063,216.862,44.821,216.853,44.565,216.853z"/>
EOF
      )
    end

    def fluid_medium
      fluid = @@tubebb.inst
      fluid.new_class!("fluid")
      fluid.new_name!("med_fluid")
      fluid.add_child(<<EOF
<path id="FluidMedium" fill="#00AEEF" stroke="#000000" stroke-miterlimit="10" d="M44.315,166.187
	c-12.031,0-12.031,8.833-24.062,8.833c-5.585,0-8.576-1.904-11.383-3.944l10.657,63.997c0,4.35,5.036,7.875,11.249,7.875
	c6.215,0,11.25-3.525,11.25-7.875l11.101-66.649C50.918,167.142,48.268,166.187,44.315,166.187z"/>
EOF
      )
    end

    def fluid_large
      fluid = @@tubebb.inst
      fluid.new_class!("fluid")
      fluid.new_name!("small_fluid")
      fluid.add_child(<<EOF
<path id="FluidLarge" fill="#BCE6FB" stroke="#000000" stroke-miterlimit="10" d="M43.202,110.52
	c-12.031,0-12.031,8.833-24.062,8.833c-7.554,0-10.365-3.483-14.39-6.075v31.729l14.998,90.066c0,4.35,5.036,7.875,11.249,7.875
	c6.215,0,11.25-3.525,11.25-7.875l15-90.066v-28.64C53.402,113.803,50.538,110.52,43.202,110.52z"/>
EOF
      )
    end

    def powder
      powder = @@tubebb.inst
      powder.new_class!("powder")
      powder.new_name!("powder")
      powder.add_child(<<EOF
         <path id="Powder" fill="#FFFFFF" stroke="#000000" stroke-miterlimit="10" d="M27.784,234.289c-0.647-2.643,1.036-2.308,2.842-2.495
	c1.183-0.124,3.538-0.179,4.792,0.55c0.33,0.957,1.645,1.147,1.775,1.945c0.106,0.649-1.18,1.446-1.407,1.983
	c-0.399,0.946,0.521,1.041-0.603,2.289c-0.534,0.593-2.338,1.107-3.088,1.463c-0.073,0.265-0.021,0.495-0.09,0.763
	c-1.498,0.401-7.79-0.416-4.875-2.518c-1.888-1.042-0.182-4.734,1.506-4.551"/>
EOF
      )
    end

    def striplabel
      mylabel = SVGElement.new(boundx: 83.1, boundy: 247.45)
      mylabel.add_child(<<EOF
<g id="StripLabel" class="fluid">
	<rect x="4.75" stroke="#000000" stroke-miterlimit="10" width="78.346" height="46.433"/>
</g>
EOF
      )
    end

    def detection_strip
      mystrip = SVGElement.new(boundx: 83.1, boundy: 247.45)
      mystrip.add_child(self.strip)
      mystrip.add_child(self.striplabel)
    end

    def control_band
      band = SVGElement.new(boundx: 83.1, boundy: 247.45)
      band.add_child(<<EOF
<line id="ControlBand" fill="none" stroke="#F7A7AB" stroke-width="6" stroke-miterlimit="10" x1="27.083" y1="68.432" x2="58.75" y2="68.432"/>
EOF
      )
    end

    def wt_band
      band = SVGElement.new(boundx: 83.1, boundy: 247.45)
      band.add_child(<<EOF
<line id="WTBand" fill="none" stroke="#F7A7AB" stroke-width="6" stroke-miterlimit="10" x1="27.089" y1="89.433" x2="58.756" y2="89.433"/>
EOF
      )
    end

    def mut_band
      band = SVGElement.new(boundx: 83.1, boundy: 247.45)
      band.add_child(<<EOF
<line id="MutantBand" fill="none" stroke="#F7A7AB" stroke-width="6" stroke-miterlimit="10" x1="27.089" y1="111.099" x2="58.756" y2="111.099"/>
EOF
      )
    end
  end

  ########################################################################
  # ####
  # ####
  # #### GRAPHICS TESTING
  # ####
  # ####
  ########################################################################


  def save_svg(filename, svg)
    File.write(filename, svg.to_str)
  end
end


