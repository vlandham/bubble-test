
class BubbleChart
  constructor: (data) ->
    @data = data
    @width = 950
    @height = 600
    @current_display = "all"

    @tooltip = CustomTooltip("bubble_tooltip", 240)

    # locations the nodes will move towards
    # depending on which view is currently being
    # used
    @center = {x: @width / 2, y: @height / 2}
    @year_centers = {
      "2008": {x: @width / 3, y: @height / 2},
      "2009": {x: @width / 2, y: @height / 2},
      "2010": {x: 2 * @width / 3, y: @height / 2}
    }

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
      .domain(["low", "medium", "high"])
      .range(["#d84b2a", "#beccae", "#7aa25c"])

    # use the max total_amount in the data as the max in the scale's domain
    max_amount = d3.max(@data, (d) -> parseInt(d.size))
    @radius_scale = d3.scale.pow().exponent(0.5).domain([0, max_amount]).range([2, 23])
    
    this.create_nodes()
    this.create_vis()

  # create node objects from original data
  # that will serve as the data behind each
  # bubble in the vis, then add each node
  # to @nodes to be used later
  create_nodes: () =>
    @data.forEach (d,i) =>
      node = {
        id: i
        radius: @radius_scale(d.size)
        value: d.size
        name: d.grant_title
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
      .attr("fill", (d) => @fill_color(d.group))
      .attr("stroke-width", 2)
      .attr("stroke", (d) => d3.rgb(@fill_color(d.group)).darker())
      .attr("id", (d) -> "bubble_#{d.id}")
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

    this.hide_years()

  # Moves all circles towards the @center
  # of the visualization
  move_towards_center: (alpha) =>
    (d) =>
      d.x = d.x + (@center.x - d.x) * (@damper + 0.02) * alpha
      d.y = d.y + (@center.y - d.y) * (@damper + 0.02) * alpha

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

  display_by_state: () =>
    console.log('state')

  display_rent_vs_remaining: () =>
    console.log('r_vs_r')

  # sets the display of bubbles to be separated
  # into each year. Does this by calling move_towards_year
  display_dc_vs_nation: () =>
    @force.gravity(@layout_gravity)
      .charge(this.charge)
      .friction(0.9)
      .on "tick", (e) =>
        @circles.each(this.move_towards_year(e.alpha))
          .attr("cx", (d) -> d.x)
          .attr("cy", (d) -> d.y)
    @force.start()

    this.display_years()

  # move all circles to their associated @year_centers 
  move_towards_year: (alpha) =>
    (d) =>
      target = @year_centers[d.year]
      d.x = d.x + (target.x - d.x) * (@damper + 0.02) * alpha * 1.1
      d.y = d.y + (target.y - d.y) * (@damper + 0.02) * alpha * 1.1

  # Method to display year titles
  display_years: () =>
    years_x = {"2008": 160, "2009": @width / 2, "2010": @width - 160}
    years_data = d3.keys(years_x)
    years = @vis.selectAll(".years")
      .data(years_data)

    years.enter().append("text")
      .attr("class", "years")
      .attr("x", (d) => years_x[d] )
      .attr("y", 40)
      .attr("text-anchor", "middle")
      .text((d) -> d)

  # Method to hide year titiles
  hide_years: () =>
    years = @vis.selectAll(".years").remove()

  show_details: (data, i, element) =>
    d3.select(element).attr("stroke", "black")
    content = "<span class=\"name\">Title:</span><span class=\"value\"> #{data.name}</span><br/>"
    content +="<span class=\"name\">Size:</span><span class=\"value\"> #{addCommas(data.value)}</span><br/>"
    @tooltip.showTooltip(content,d3.event)


  hide_details: (data, i, element) =>
    d3.select(element).attr("stroke", (d) => d3.rgb(@fill_color(d.group)).darker())
    @tooltip.hideTooltip()


root = exports ? this

cleanNum = (num) ->
  num.replace(/[\",\$]/,"")

cleanData = (raw) ->
  raw.forEach (d) ->
    d.size = parseInt(cleanNum(d.lease_rsf))
    d.rent_per_sf = parseFloat(cleanNum(d.rent_prsf))
  raw

$ ->
  chart = null

  render_vis = (csv) ->
    data = cleanData(csv)
    chart = new BubbleChart csv
    chart.start()
    chart.set_display('all')


  toggle_overlay = (selected_tab) =>
    overlays =
      all: {name:"#chart-all-overlay",height:550}
      dc_vs_nation: {name:"#chart-dc-vs-nation-overlay",height:550}
      rent_vs_remaining: {name:"#chart-rent-vs-remaining-overlay",height:550}
      state: {name:"#chart-state-overlay",height:550}

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
