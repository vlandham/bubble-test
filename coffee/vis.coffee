
class BubbleChart
  constructor: (data) ->
    @data = data
    @width = 950
    @height = 700
    @pb = 30
    @pt = 120
    @pl = 80
    @pr = 10
    @current_display = "all"

    @tooltip = CustomTooltip("bubble_tooltip", 240)

    # locations the nodes will move towards
    # depending on which view is currently being
    # used
    @center = {x: @width / 2, y: @height / 2}
    @location_centers = [
      {x: @width / 3, y: @height / 2},
      {x: 2 * @width / 3, y: @height / 2}
    ]

    # used when setting up force and
    # moving around nodes
    @layout_gravity = -0.01
    @damper = 0.1

    # these will be set in create_nodes and create_vis
    @vis = null
    @nodes = []
    @force = null
    @circles = null

    # nice looking colors - no reason to buck the trend
    @fill_color = d3.scale.ordinal()
      .domain([1,2,3,4,5])
      .range(["#D7191C", "#FDAE61", "#FFFFBF", "#ABD9E9", "#2C7BB6"])

    # use the max total_amount in the data as the max in the scale's domain
    max_amount = d3.max(@data, (d) -> parseInt(d.size))
    @radius_scale = d3.scale.pow().exponent(0.5).domain([0, max_amount]).range([1, 40])

    category_extent = d3.extent(@data, (d) -> d.category_value)
    @category_scale = d3.scale.quantize().domain(category_extent).range([1,2,3,4,5])

    remaining_lease_extent = d3.extent(@data, (d) -> d.remaining_term_years)
    @lease_scale = d3.scale.linear().domain([0,20]).range([0, (@width - (@pl + @pr))])
    @x_axis = d3.svg.axis().scale(@lease_scale).tickSubdivide(1).tickSize(5,0).orient("bottom")

    total_rent_extent = d3.extent(@data, (d) -> d.total_rent)
    @total_rent_scale = d3.scale.linear().domain(total_rent_extent).range([0, @height - (@pt + @pb)].reverse())
    @y_axis = d3.svg.axis().scale(@total_rent_scale).ticks(5).orient("left").tickSize(-@width,0)
    
    this.create_nodes()
    this.add_key()
    this.create_vis()

  add_key: () =>
    key = d3.select("#chart-key-svg")

    key.append("circle")
      .attr("r", @radius_scale(1000000))
      .attr("class", "chart-key-circle")
      .attr('cx', 30)
      .attr('cy', 30)

    key.append("circle")
      .attr("r", @radius_scale(100000))
      .attr("class", "chart-key-circle")
      .attr('cx', 30)
      .attr('cy', 42)

    key.append("circle")
      .attr("r", @radius_scale(10000))
      .attr("class", "chart-key-circle")
      .attr('cx', 30)
      .attr('cy', 44)

    that = this
    color_key = d3.select("#chart-key-color-svg")
    rect_width = 30
    rect_height = 10
    console.log(@category_scale.domain())
    color_key.selectAll("rect").data(@category_scale.range())
      .enter().append("rect")
        .attr("x", (d,i) -> (i) * rect_width)
        .attr("width", rect_width)
        .attr("height", rect_height)
        .attr("fill", (d) -> that.fill_color(d))


  # create node objects from original data
  # that will serve as the data behind each
  # bubble in the vis, then add each node
  # to @nodes to be used later
  create_nodes: () =>
    @data.forEach (d,i) =>
      node = {
        id: i
        radius: @radius_scale(d.size)
        category: @category_scale(d.category_value)
        location: if (d.state_category == "District of Columbia") then 0 else 1
        value: d.size
        state: d.state
        remaining_term_years: d.remaining_term_years
        total_rent: d.total_rent
        org: d.organization
        group: d.group
        year: d.start_year
        x: Math.random() * 900
        y: Math.random() * 800
      }
      @nodes.push node

    @nodes.sort (a,b) -> b.value - a.value


  # create svg at #vis and then 
  # create circle representation for each node
  create_vis: () =>
    @vis = d3.select("#chart-canvas").append("svg")
      .attr("width", @width)
      .attr("height", @height)
      .attr("id", "svg_vis")

    @circles = @vis.selectAll("circle")
      .data(@nodes, (d) -> d.id)

    # used because we need 'this' in the 
    # mouse callbacks
    that = this

    # radius will be set to 0 initially.
    # see transition below
    @circles.enter().append("circle")
      .attr("r", 0)
      .attr("fill", (d) => @fill_color(d.category))
      .attr("stroke-width", 2)
      .attr("stroke", (d) => d3.rgb(@fill_color(d.category)).darker())
      .attr("id", (d) -> "bubble_#{d.id}")
      .attr("class", "chart-bubble")
      .on("mouseover", (d,i) -> that.show_details(d,i,this))
      .on("mouseout", (d,i) -> that.hide_details(d,i,this))

    # Fancy transition to make bubbles appear, ending with the
    # correct radius
    @circles.transition().duration(2000).attr("r", (d) -> d.radius)


  # Charge function that is called for each node.
  # Charge is proportional to the diameter of the
  # circle (which is stored in the radius attribute
  # of the circle's associated data.
  # This is done to allow for accurate collision 
  # detection with nodes of different sizes.
  # Charge is negative because we want nodes to 
  # repel.
  # Dividing by 8 scales down the charge to be
  # appropriate for the visualization dimensions.
  charge: (d) ->
    -Math.pow(d.radius, 2.0) / 8

  # Starts up the force layout with
  # the default values
  start: () =>
    @force = d3.layout.force()
      .nodes(@nodes)
      .size([@width, @height])

  set_display: (display_id) =>
    @current_display = display_id
    if @current_display == "all"
      this.display_group_all()
    else if @current_display == "dc_vs_nation"
      this.display_dc_vs_nation()
    else if @current_display == "rent_vs_remaining"
      this.display_rent_vs_remaining()
    else if @current_display == "state"
      this.display_by_state()
    else
      console.log("warning cannot display by #{display_id}")
      this.display_group_all()

  # Sets up force layout to display
  # all nodes in one circle.
  display_group_all: () =>
    @force.gravity(@layout_gravity)
      .charge(this.charge)
      .friction(0.9)
      .on "tick", (e) =>
        @circles.each(this.move_towards_center(e.alpha))
          .attr("cx", (d) -> d.x)
          .attr("cy", (d) -> d.y)
    @force.start()

    this.hide_scales()

  # Moves all circles towards the @center
  # of the visualization
  move_towards_center: (alpha) =>
    (d) =>
      d.x = d.x + (@center.x - d.x) * (@damper + 0.02) * alpha
      d.y = d.y + (@center.y - d.y) * (@damper + 0.02) * alpha

  display_rent_vs_remaining: () =>
    @force.gravity(0)
      .charge(0)
      .friction(0.2)
      .on "tick", (e) =>
        @circles.each(this.move_torwards_scale(e.alpha))
          .attr("cx", (d) -> d.x)
          .attr("cy", (d) -> d.y)
    @force.start()
    # @force.stop()
    this.display_scales()

  display_by_state: () =>
    @force.gravity(@layout_gravity)
      .charge(this.charge)
      .friction(0.9)
      .on "tick", (e) =>
        @circles.each(this.move_torwards_location_center(e.alpha))
          .attr("cx", (d) -> d.x)
          .attr("cy", (d) -> d.y)
    @force.start()
    this.hide_scales()

  # sets the display of bubbles to be separated
  # into each year. Does this by calling move_towards_year
  display_dc_vs_nation: () =>
    @force.gravity(@layout_gravity)
      .charge(this.charge)
      .friction(0.9)
      .on "tick", (e) =>
        @circles.each(this.move_torwards_location_center(e.alpha))
          .attr("cx", (d) -> d.x)
          .attr("cy", (d) -> d.y)
    @force.start()
    this.hide_scales()

  move_torwards_scale: (alpha) =>
    (d) =>
      target = {}
      target.x = @lease_scale(d.remaining_term_years) + @pl
      target.y = @total_rent_scale(d.total_rent) + @pt
      # console.log(target)
      # d.x = d.x + (target.x - d.x) * (@damper + 0.02) * alpha * 1.1
      # d.y = d.y + (target.y - d.y) * (@damper + 0.02) * alpha * 1.1
      # TODO: ??? force does some weird projection?
      d.y = d.y + (target.y - d.y) * Math.sin(Math.PI * (1 - alpha*10)) * 0.2
      d.x = d.x + (target.x - d.x) * Math.sin(Math.PI * (1 - alpha*10)) * 0.1

  # move all circles to their associated @location_centers 
  move_torwards_location_center: (alpha) =>
    (d) =>
      target = @location_centers[d.location]
      d.x = d.x + (target.x - d.x) * (@damper + 0.02) * alpha * 1.1
      d.y = d.y + (target.y - d.y) * (@damper + 0.02) * alpha * 1.1

  # Method to display year titles
  display_scales: () =>
    @vis.insert("g", ".chart-bubble")
      .attr("id", "chart-x-axis")
      .attr("class", "x axis")
      .attr("transform", "translate(#{@pl},#{(@height - @pb)})")
      .call(@x_axis)

    @vis.insert("g", ".chart-bubble")
      .attr("id", "chart-y-axis")
      .attr("class", "y axis")
      .attr("transform", "translate(#{@pl},#{@pt})")
      .call(@y_axis)

  # Method to hide scales
  hide_scales: () =>
    @vis.select("#chart-x-axis").remove()
    @vis.select("#chart-y-axis").remove()

  show_details: (data, i, element) =>
    d3.select(element).attr("stroke", "black")
    content = "<span class=\"name\">Title:</span><span class=\"value\"> #{data.name}</span><br/>"
    content +="<span class=\"name\">Size:</span><span class=\"value\"> #{addCommas(data.value)}</span><br/>"
    content +="<span class=\"name\">Term Years (x):</span><span class=\"value\"> #{data.remaining_term_years}</span><br/>"
    content +="<span class=\"name\">Total Rent (y):</span><span class=\"value\"> $#{addCommas(data.total_rent)}</span><br/>"
    @tooltip.showTooltip(content,d3.event)


  hide_details: (data, i, element) =>
    d3.select(element).attr("stroke", (d) => d3.rgb(@fill_color(d.category)).darker())
    @tooltip.hideTooltip()


root = exports ? this

cleanNum = (num) ->
  num.replace(/[\"\,\$]/g,"")

cleanData = (raw) ->
  raw.forEach (d) ->
    d.size = parseInt(cleanNum(d.lease_rsf))
    d.lease_rsf_value = parseInt(cleanNum(d.lease_rsf))
    d.category_value = parseFloat(cleanNum(d.rent_prsf))
    d.rent_prsf_value = parseFloat(cleanNum(d.rent_prsf))
    d.remaining_term_years = parseFloat(d.remaining_term_years)
    d.total_rent = parseFloat(cleanNum(d.annual_rent))
  raw

$ ->
  chart = null

  render_vis = (csv) ->
    data = cleanData(csv)
    chart = new BubbleChart csv
    chart.start()
    chart.set_display('all')


  toggle_overlay = (selected_tab) =>
    h = 700
    overlays =
      all: {name:"#chart-all-overlay",height:h}
      dc_vs_nation: {name:"#chart-dc-vs-nation-overlay",height:h}
      rent_vs_remaining: {name:"#chart-rent-vs-remaining-overlay",height:h+30}
      state: {name:"#chart-state-overlay",height:h}

    d3.values(overlays).forEach (overlay) ->
      $(overlay.name).hide()

    currentOverlay = overlays[selected_tab]
    if !currentOverlay
      console.log("warning: #{selected_tab} overlay not found")
      currentOverlay = overlays["all"]
    currentOverlayDiv = $(currentOverlay.name)
    currentOverlayDiv.delay(300).fadeIn(500)
    $("#chart-frame").css({'height':currentOverlay.height})


  root.toggle_view = (view_type) =>
    toggle_overlay(view_type)
    chart.set_display(view_type)

  d3.csv "data/short.csv", render_vis
  # d3.csv "data/inventory_abridged.csv", render_vis
