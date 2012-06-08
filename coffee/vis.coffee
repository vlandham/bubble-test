
class BubbleChart
  constructor: (data) ->
    @data = data
    @width = 950
    @height = 700
    @pb = 40
    @pt = 120
    @pl = 90
    @pr = 10
    @tick_inc = 0
    @current_display = "all"
    @states_centers = {}

    @tooltip = CustomTooltip("bubble_tooltip", 240)

    # locations the nodes will move towards
    # depending on which view is currently being
    # used
    @center = {x: @width / 2 + 70, y: @height / 2 + 20}
    @location_centers = [
      {x: @width / 3, y: @height / 2},
      {x: (2 * @width / 3) - 30, y: @height / 2}
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
      .range(["#D7191C", "#FDAE61", "#FFFFBF", "#ABD9E9", "#2C7BB6"].reverse())

    # use the max total_amount in the data as the max in the scale's domain
    # max_amount = d3.max(@data, (d) -> parseInt(d.size))
    # console.log(max_amount)
    # 2386940
    max_amount = 2386940
    @radius_scale = d3.scale.pow().exponent(0.5).domain([0, max_amount]).range([1, 42])

    category_extent = d3.extent(@data, (d) -> d.category_value)
    category_extent = [3.33, 68.75]
    @category_scale = d3.scale.quantize().domain(category_extent).range([1,2,3,4,5])
    @category_scale = (v) ->
      if v < 15
        1
      else if v < 30
        2
      else if v < 45
        3
      else if v < 60
        4
      else
        5

    # [Math.round(category_extent[0])..category_extent[1]].forEach (i) =>
    #   console.log(i + "- " + @category_scale(i))

    remaining_lease_extent = d3.extent(@data, (d) -> d.remaining_term_years)
    @lease_scale = d3.scale.linear().domain([0,20]).range([0, (@width - (@pl + @pr))])
    @x_axis = d3.svg.axis().scale(@lease_scale).tickSubdivide(1).tickSize(5,0).orient("bottom")

    total_rent_extent = d3.extent(@data, (d) -> d.total_rent)
    @total_rent_scale = d3.scale.linear().domain(total_rent_extent).range([0, @height - (@pt + @pb)].reverse())
    @y_axis = d3.svg.axis().scale(@total_rent_scale).ticks(5).orient("left").tickSize(-@width,0).tickFormat( (d) -> "$#{d/1000000} million")

    # states_nest = d3.nest()
    #   .key((d) -> d.state_category)
    #   .sortKeys(d3.descending)
    #   .rollup (d) ->
    #     lease_rsf_sum: d3.sum(d, (g) -> g.lease_rsf_value)
    #     lease_rsf_sum_mil: Math.round(d3.sum(d, (g) -> g.lease_rsf_value)/100000)/10
    #     count: d.length
    #     name: d[0].state_category
    #   .entries(@data)

    # @states_data = states_nest.map((d) -> d.values).sort( (a,b) -> b.lease_rsf_sum - a.lease_rsf_sum)

    this.create_nodes()
    this.set_annotations()
    this.add_key()
    # this.setup_states()
    this.create_vis()

  # setup_states: () =>
  #   x_inc = @width / 4
  #   cur_x = x_inc / 2
  #   cur_y = @pt + 100

  #   @states_data.forEach (s) =>
  #     if cur_x > @width
  #       cur_x = x_inc / 2
  #       cur_y += 120
  #     @states_centers[s.name] = {x:cur_x, y:cur_y}
  #     cur_x += x_inc

  # display_state_labels: () =>
  #   that = this
  #   labelG = @vis.append("g").attr("id", "state-labels")
  #   labels = labelG.selectAll(".state-label").data(@states_data)
  #     .enter().append("g")
  #       .attr("class", "state-label")
  #       .attr("transform", (d) -> "translate(#{that.states_centers[d.name].x},#{that.states_centers[d.name].y - 100})")

  #   labels.append("text")
  #     .attr("class", "state-label-main")
  #     .attr("text-anchor", "middle")
  #     .attr("dy", "-8px")
  #     .text((d) -> "#{d.lease_rsf_sum_mil} MSF (#{d.count} leases)")

  #   labels.append("text")
  #     .attr("class","state-label-sub")
  #     .attr("text-anchor", "middle")
  #     .attr("dy", "8px")
  #     .text((d) -> d.name)


  # hide_state_labels: () =>
  #   @vis.select("#state-labels").remove()

  set_annotations: () =>
    total_rsf = d3.sum(@data, (d) -> d.lease_rsf_value)
    total_annual_rent = d3.sum(@data, (d) -> d.annual_rent_value)
    total_rent_billion = Math.round(total_annual_rent / 10000000)/100
    inventory_text = "There are #{@data.length} leases in the United States that are larger than 75,000 RSF.  Together, these total #{addCommas(total_rsf)} RSF and $#{addCommas(total_rent_billion)} billion in annual rent."
    $("#inventory-annotation-text").html(inventory_text)

    dc_rentals = @data.filter((d) -> parseInt(d.region) == 11)
    nation_rentals = @data.filter((d) -> parseInt(d.region) != 11)
    dc_total_rsf = d3.sum(dc_rentals, (d) -> d.lease_rsf_value)
    nation_total_rsf = d3.sum(nation_rentals, (d) -> d.lease_rsf_value)

    dc_text = "#{dc_rentals.length} leases totaling #{addCommas(dc_total_rsf)} RSF"
    nation_text = "#{nation_rentals.length} leases totaling #{addCommas(nation_total_rsf)} RSF"

    $("#dc-annotation-text").html(dc_text)
    $("#nation-annotation-text").html(nation_text)

    long_lease_rentals = @data.filter((d) -> (parseFloat(d.remaining_term_years) >= 10.0))
    long_lease_rsf = d3.sum(long_lease_rentals, (d) -> d.lease_rsf_value)
    long_lease_percent = Math.round(long_lease_rentals.length / @data.length * 1000)/10

    rent_text = "#{long_lease_rentals.length} leases (#{addCommas(long_lease_rsf)} RSF) have remaining lease terms longer than 10 years.  This is #{long_lease_percent}% of the number of leases in the analysis size range."

    $("#rent-annotation-text").html(rent_text)

  add_key: () =>
    key = d3.select("#chart-key-svg")

    key.append("circle")
      .attr("r", @radius_scale(2000000))
      .attr("class", "chart-key-circle")
      .attr('cx', 40)
      .attr('cy', 44)

    key.append("circle")
      .attr("r", @radius_scale(1000000))
      .attr("class", "chart-key-circle")
      .attr('cx', 40)
      .attr('cy', 55)

    key.append("circle")
      .attr("r", @radius_scale(500000))
      .attr("class", "chart-key-circle")
      .attr('cx', 40)
      .attr('cy', 63)

    that = this
    color_key = d3.select("#chart-key-color-svg")
    rect_width = 34
    rect_height = 12

    colors = color_key.selectAll("rect").data([1,2,3,4,5]).enter()
    colors.append("rect")
        .attr("x", (d,i) -> (i) * rect_width)
        .attr("width", rect_width)
        .attr("height", rect_height)
        .attr("fill", (d) -> that.fill_color(d))
    color_key.selectAll("color-label").data([15,30,45,60,75]).enter()
      .append("text")
      .attr("class", "color-label")
      .attr("x", (d,i) -> (i * rect_width) + rect_width)
      .attr("y", (d,i) -> rect_height + 12)
      .attr("text-anchor", "end")
      .text((d) -> "$#{d}")

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
        location_index: if (parseInt(d.region) == 11) then 0 else 1
        value: d.size
        city: d.city.toUpperCase()
        state: d.state.toUpperCase()
        state_category: d.state_category
        address: d.address.toUpperCase()
        remaining_term_years: d.remaining_term_years
        total_rent: d.total_rent
        rent_prsf: d.rent_prsf
        rent_prsf_value: d.rent_prsf_value
        lease_rsf_value: d.lease_rsf_value
        org: d.organization
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
      .attr("stroke-width", 0.7)
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
    # else if @current_display == "state"
    #   this.display_by_state()
    else
      # console.log("warning cannot display by #{display_id}")
      this.display_group_all()

  # Sets up force layout to display
  # all nodes in one circle.
  display_group_all: () =>
    @force.gravity(@layout_gravity)
      .charge(this.charge)
      .friction(0.9)
      .on "tick", (e) =>
        @circles
          .each(this.move_towards_center(e.alpha))
          .each(this.buoyancy(e.alpha))
        # if (@tick_inc % 2) == 0
        @circles.attr("cx", (d) -> d.x)
          .attr("cy", (d) -> d.y)
        @tick_inc += 1
    @force.start()

    this.hide_scales()
    # this.hide_state_labels()


  buoyancy: (alpha) =>
    (d) =>
      targetY = @center.y - (d.category ) * 130
      d.y = d.y + (targetY - d.y) * (0.07) * alpha * alpha * alpha * 100


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
        @circles
          .each(this.move_torwards_scale(e.alpha))
          .each(this.buoyancy(e.alpha))
          .attr("cx", (d) -> d.x)
          .attr("cy", (d) -> d.y)
    @force.start()
    # @force.stop()
    # this.hide_state_labels()
    this.display_scales()

  # display_by_state: () =>
  #   @force.gravity(@layout_gravity)
  #     .charge(this.charge)
  #     .friction(0.9)
  #     .on "tick", (e) =>
  #       @circles.each(this.move_torwards_states(e.alpha))
  #         .attr("cx", (d) -> d.x)
  #         .attr("cy", (d) -> d.y)
  #   @force.start()
  #   this.display_state_labels()
  #   this.hide_scales()


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
    # this.hide_state_labels()

  # move_torwards_states: (alpha) =>
  #   (d) =>
  #     target = @states_centers[d.state_category]
  #     r =  Math.max(5, d.radius)
  #     d.x = d.x + (target.x - d.x) * (0.05) * alpha * 0.5 * r
  #     d.y = d.y + (target.y - d.y) * (0.05) * alpha * 0.5 * r
  #     # d.y += (target.y - d.y) * Math.sin(Math.PI * (1 - alpha*10)) * 0.6
  #     # d.x += (target.x - d.x) * Math.sin(Math.PI * (1 - alpha*10)) * 0.4
  #     
  #     # d.x = d.x + (target.x - d.x) * (@damper + 0.02) * alpha * 1.1
  #     # d.y = d.y + (target.y - d.y) * (@damper + 0.02) * alpha * 1.1


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
      target = @location_centers[d.location_index]
      d.x = d.x + (target.x - d.x) * (@damper + 0.02) * alpha * 1.1
      d.y = d.y + (target.y - d.y) * (@damper + 0.02) * alpha * 1.1

  # Method to display year titles
  display_scales: () =>
    xax = @vis.insert("g", ".chart-bubble")
      .attr("id", "chart-x-axis")
      .attr("class", "x axis")
      .attr("transform", "translate(#{@pl},#{(@height - @pb)})")
    xax.call(@x_axis)

    yax = @vis.insert("g", ".chart-bubble")
      .attr("id", "chart-y-axis")
      .attr("class", "y axis")
      .attr("transform", "translate(#{@pl},#{@pt})")
    yax.call(@y_axis)

    xax.append("text")
      .attr("class", "axis-text")
      .attr("transform", "translate(#{@width/2 - 40},#{30})")
      .attr("text-anchor", "middle")
      .text("Remaining Lease Term (Yrs)")

    yax.append("text")
      .attr("class", "axis-text")
      .attr("transform", "translate(#{-@pl + 10},#{@height/2 - 55})rotate(-90)")
      .attr("text-anchor", "start")
      .text("Total Annual Rent")

    yax.append("line")
      .attr("class", "axis-line")
      .attr("x1", @lease_scale(10))
      .attr("y1", 0)
      .attr("x2", @lease_scale(10))
      .attr("y2", @height - (@pb + @pt))

    yax.append("line")
      .attr("class", "axis-line")
      .attr("x1", @lease_scale(5))
      .attr("y1", 0)
      .attr("x2", @lease_scale(5))
      .attr("y2", @height - (@pb + @pt))
      
    yax.append("line")
      .attr("class", "axis-line")
      .attr("x1", @lease_scale(15))
      .attr("y1", 0)
      .attr("x2", @lease_scale(15))
      .attr("y2", @height - (@pb + @pt))

    # yax.append("line")
    #   .attr("class", "axis-line")
    #   .attr("x1", -5)
    #   .attr("y1", @total_rent_scale(15000000))
    #   .attr("x2", @width)
    #   .attr("y2", @total_rent_scale(15000000))

  # Method to hide scales
  hide_scales: () =>
    @vis.select("#chart-x-axis").remove()
    @vis.select("#chart-y-axis").remove()

  show_details: (data, i, element) =>
    d3.select(element).attr("stroke", "black")
    content = "<p class=\"main\">#{data.address}<br/>#{data.city}, #{data.state}</p><hr class=\"tooltip-hr\">"
    content +="<span class=\"name\">RSF:</span><span class=\"value\"> #{addCommas(data.lease_rsf_value)}</span><br/>"
    content +="<span class=\"name\">Rent:</span><span class=\"value\"> #{data.rent_prsf}/RSF</span><br/>"
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
    d.annual_rent_value = parseFloat(cleanNum(d.annual_rent))
    d.total_rent = parseFloat(cleanNum(d.annual_rent))
  raw

filterData = (data) ->
  filter = data.filter (d) ->
    d.lease_rsf_value > 75000
  filter


$ ->
  chart = null

  render_vis = (csv) ->
    data = filterData(cleanData(csv))
    chart = new BubbleChart data
    chart.start()
    chart.set_display('all')


  toggle_overlay = (selected_tab) =>
    h = 700
    overlays =
      all: {name:"#chart-all-overlay",height:h}
      dc_vs_nation: {name:"#chart-dc-vs-nation-overlay",height:h}
      rent_vs_remaining: {name:"#chart-rent-vs-remaining-overlay",height:h+40}
      state: {name:"#chart-state-overlay",height:h}

    d3.values(overlays).forEach (overlay) ->
      $(overlay.name).hide()

    currentOverlay = overlays[selected_tab]
    if !currentOverlay
      # console.log("warning: #{selected_tab} overlay not found")
      currentOverlay = overlays["all"]
    currentOverlayDiv = $(currentOverlay.name)
    currentOverlayDiv.delay(300).fadeIn(500)
    $("#chart-frame").css({'height':currentOverlay.height})


  root.toggle_view = (view_type) =>
    toggle_overlay(view_type)
    chart.set_display(view_type)

  # d3.csv "data/short.csv", render_vis
  d3.csv "data/inventory_abridged.csv", render_vis
