(function() {
  var BubbleChart, cleanData, cleanNum, filterData, root,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  BubbleChart = (function() {

    function BubbleChart(data) {
      this.hide_details = __bind(this.hide_details, this);
      this.show_details = __bind(this.show_details, this);
      this.hide_scales = __bind(this.hide_scales, this);
      this.display_scales = __bind(this.display_scales, this);
      this.move_torwards_location_center = __bind(this.move_torwards_location_center, this);
      this.move_torwards_scale = __bind(this.move_torwards_scale, this);
      this.display_dc_vs_nation = __bind(this.display_dc_vs_nation, this);
      this.display_rent_vs_remaining = __bind(this.display_rent_vs_remaining, this);
      this.move_towards_center = __bind(this.move_towards_center, this);
      this.buoyancy = __bind(this.buoyancy, this);
      this.display_group_all = __bind(this.display_group_all, this);
      this.set_display = __bind(this.set_display, this);
      this.start = __bind(this.start, this);
      this.create_vis = __bind(this.create_vis, this);
      this.create_nodes = __bind(this.create_nodes, this);
      this.add_key = __bind(this.add_key, this);
      this.set_annotations = __bind(this.set_annotations, this);
      var category_extent, max_amount, remaining_lease_extent, total_rent_extent;
      this.data = data;
      this.width = 950;
      this.height = 700;
      this.pb = 40;
      this.pt = 120;
      this.pl = 90;
      this.pr = 10;
      this.tick_inc = 0;
      this.current_display = "all";
      this.states_centers = {};
      this.tooltip = CustomTooltip("bubble_tooltip", 240);
      this.center = {
        x: this.width / 2 + 70,
        y: this.height / 2 + 20
      };
      this.location_centers = [
        {
          x: this.width / 3,
          y: this.height / 2
        }, {
          x: (2 * this.width / 3) - 30,
          y: this.height / 2
        }
      ];
      this.layout_gravity = -0.01;
      this.damper = 0.1;
      this.vis = null;
      this.nodes = [];
      this.force = null;
      this.circles = null;
      this.fill_color = d3.scale.ordinal().domain([1, 2, 3, 4, 5]).range(["#D7191C", "#FDAE61", "#FFFFBF", "#ABD9E9", "#2C7BB6"].reverse());
      max_amount = 2386940;
      this.radius_scale = d3.scale.pow().exponent(0.5).domain([0, max_amount]).range([1, 42]);
      category_extent = d3.extent(this.data, function(d) {
        return d.category_value;
      });
      category_extent = [3.33, 68.75];
      this.category_scale = d3.scale.quantize().domain(category_extent).range([1, 2, 3, 4, 5]);
      this.category_scale = function(v) {
        if (v < 15) {
          return 1;
        } else if (v < 30) {
          return 2;
        } else if (v < 45) {
          return 3;
        } else if (v < 60) {
          return 4;
        } else {
          return 5;
        }
      };
      remaining_lease_extent = d3.extent(this.data, function(d) {
        return d.remaining_term_years;
      });
      this.lease_scale = d3.scale.linear().domain([0, 20]).range([0, this.width - (this.pl + this.pr)]);
      this.x_axis = d3.svg.axis().scale(this.lease_scale).tickSubdivide(1).tickSize(5, 0).orient("bottom");
      total_rent_extent = d3.extent(this.data, function(d) {
        return d.total_rent;
      });
      this.total_rent_scale = d3.scale.linear().domain(total_rent_extent).range([0, this.height - (this.pt + this.pb)].reverse());
      this.y_axis = d3.svg.axis().scale(this.total_rent_scale).ticks(5).orient("left").tickSize(-this.width, 0).tickFormat(function(d) {
        return "$" + (d / 1000000) + " million";
      });
      this.create_nodes();
      this.set_annotations();
      this.add_key();
      this.create_vis();
    }

    BubbleChart.prototype.set_annotations = function() {
      var dc_rentals, dc_text, dc_total_rsf, inventory_text, long_lease_percent, long_lease_rentals, long_lease_rsf, nation_rentals, nation_text, nation_total_rsf, rent_text, total_annual_rent, total_rent_billion, total_rsf;
      total_rsf = d3.sum(this.data, function(d) {
        return d.lease_rsf_value;
      });
      total_annual_rent = d3.sum(this.data, function(d) {
        return d.annual_rent_value;
      });
      total_rent_billion = Math.round(total_annual_rent / 10000000) / 100;
      inventory_text = "There are " + this.data.length + " leases in the United States that are larger than 75,000 RSF.  Together, these total " + (addCommas(total_rsf)) + " RSF and $" + (addCommas(total_rent_billion)) + " billion in annual rent.";
      $("#inventory-annotation-text").html(inventory_text);
      dc_rentals = this.data.filter(function(d) {
        return parseInt(d.region) === 11;
      });
      nation_rentals = this.data.filter(function(d) {
        return parseInt(d.region) !== 11;
      });
      dc_total_rsf = d3.sum(dc_rentals, function(d) {
        return d.lease_rsf_value;
      });
      nation_total_rsf = d3.sum(nation_rentals, function(d) {
        return d.lease_rsf_value;
      });
      dc_text = "" + dc_rentals.length + " leases totaling " + (addCommas(dc_total_rsf)) + " RSF";
      nation_text = "" + nation_rentals.length + " leases totaling " + (addCommas(nation_total_rsf)) + " RSF";
      $("#dc-annotation-text").html(dc_text);
      $("#nation-annotation-text").html(nation_text);
      long_lease_rentals = this.data.filter(function(d) {
        return parseFloat(d.remaining_term_years) >= 10.0;
      });
      long_lease_rsf = d3.sum(long_lease_rentals, function(d) {
        return d.lease_rsf_value;
      });
      long_lease_percent = Math.round(long_lease_rentals.length / this.data.length * 1000) / 10;
      rent_text = "" + long_lease_rentals.length + " leases (" + (addCommas(long_lease_rsf)) + " RSF) have remaining lease terms longer than 10 years.  This is " + long_lease_percent + "% of the number of leases in the analysis size range.";
      return $("#rent-annotation-text").html(rent_text);
    };

    BubbleChart.prototype.add_key = function() {
      var color_key, colors, key, rect_height, rect_width, that;
      key = d3.select("#chart-key-svg");
      key.append("circle").attr("r", this.radius_scale(2000000)).attr("class", "chart-key-circle").attr('cx', 40).attr('cy', 44);
      key.append("circle").attr("r", this.radius_scale(1000000)).attr("class", "chart-key-circle").attr('cx', 40).attr('cy', 55);
      key.append("circle").attr("r", this.radius_scale(500000)).attr("class", "chart-key-circle").attr('cx', 40).attr('cy', 63);
      that = this;
      color_key = d3.select("#chart-key-color-svg");
      rect_width = 34;
      rect_height = 12;
      colors = color_key.selectAll("rect").data([1, 2, 3, 4, 5]).enter();
      colors.append("rect").attr("x", function(d, i) {
        return i * rect_width;
      }).attr("width", rect_width).attr("height", rect_height).attr("fill", function(d) {
        return that.fill_color(d);
      });
      return color_key.selectAll("color-label").data([15, 30, 45, 60, 75]).enter().append("text").attr("class", "color-label").attr("x", function(d, i) {
        return (i * rect_width) + rect_width;
      }).attr("y", function(d, i) {
        return rect_height + 12;
      }).attr("text-anchor", "end").text(function(d) {
        return "$" + d;
      });
    };

    BubbleChart.prototype.create_nodes = function() {
      var _this = this;
      this.data.forEach(function(d, i) {
        var node;
        node = {
          id: i,
          radius: _this.radius_scale(d.size),
          category: _this.category_scale(d.category_value),
          location_index: parseInt(d.region) === 11 ? 0 : 1,
          value: d.size,
          city: d.city.toUpperCase(),
          state: d.state.toUpperCase(),
          state_category: d.state_category,
          address: d.address.toUpperCase(),
          remaining_term_years: d.remaining_term_years,
          total_rent: d.total_rent,
          rent_prsf: d.rent_prsf,
          rent_prsf_value: d.rent_prsf_value,
          lease_rsf_value: d.lease_rsf_value,
          org: d.organization,
          year: d.start_year,
          x: Math.random() * 900,
          y: Math.random() * 800
        };
        return _this.nodes.push(node);
      });
      return this.nodes.sort(function(a, b) {
        return b.value - a.value;
      });
    };

    BubbleChart.prototype.create_vis = function() {
      var that,
        _this = this;
      this.vis = d3.select("#chart-canvas").append("svg").attr("width", this.width).attr("height", this.height).attr("id", "svg_vis");
      this.circles = this.vis.selectAll("circle").data(this.nodes, function(d) {
        return d.id;
      });
      that = this;
      this.circles.enter().append("circle").attr("r", 0).attr("fill", function(d) {
        return _this.fill_color(d.category);
      }).attr("stroke-width", 0.7).attr("stroke", function(d) {
        return d3.rgb(_this.fill_color(d.category)).darker().toString();
      }).attr("id", function(d) {
        return "bubble_" + d.id;
      }).attr("class", "chart-bubble").on("mouseover", function(d, i) {
        return that.show_details(d, i, this);
      }).on("mouseout", function(d, i) {
        return that.hide_details(d, i, this);
      });
      return this.circles.transition().duration(2000).attr("r", function(d) {
        return d.radius;
      });
    };

    BubbleChart.prototype.charge = function(d) {
      return -Math.pow(d.radius, 2.0) / 8;
    };

    BubbleChart.prototype.start = function() {
      return this.force = d3.layout.force().nodes(this.nodes).size([this.width, this.height]);
    };

    BubbleChart.prototype.set_display = function(display_id) {
      this.current_display = display_id;
      if (this.current_display === "all") {
        return this.display_group_all();
      } else if (this.current_display === "dc_vs_nation") {
        return this.display_dc_vs_nation();
      } else if (this.current_display === "rent_vs_remaining") {
        return this.display_rent_vs_remaining();
      } else {
        return this.display_group_all();
      }
    };

    BubbleChart.prototype.display_group_all = function() {
      var _this = this;
      this.force.gravity(this.layout_gravity).charge(this.charge).friction(0.9).on("tick", function(e) {
        _this.circles.each(_this.move_towards_center(e.alpha)).each(_this.buoyancy(e.alpha));
        _this.circles.attr("cx", function(d) {
          return d.x;
        }).attr("cy", function(d) {
          return d.y;
        });
        return _this.tick_inc += 1;
      });
      this.force.start();
      return this.hide_scales();
    };

    BubbleChart.prototype.buoyancy = function(alpha) {
      var _this = this;
      return function(d) {
        var targetY;
        targetY = _this.center.y - d.category * 130;
        return d.y = d.y + (targetY - d.y) * 0.07 * alpha * alpha * alpha * 100;
      };
    };

    BubbleChart.prototype.move_towards_center = function(alpha) {
      var _this = this;
      return function(d) {
        d.x = d.x + (_this.center.x - d.x) * (_this.damper + 0.02) * alpha;
        return d.y = d.y + (_this.center.y - d.y) * (_this.damper + 0.02) * alpha;
      };
    };

    BubbleChart.prototype.display_rent_vs_remaining = function() {
      var _this = this;
      this.force.gravity(0).charge(0).friction(0.2).on("tick", function(e) {
        return _this.circles.each(_this.move_torwards_scale(e.alpha)).each(_this.buoyancy(e.alpha)).attr("cx", function(d) {
          return d.x;
        }).attr("cy", function(d) {
          return d.y;
        });
      });
      this.force.start();
      return this.display_scales();
    };

    BubbleChart.prototype.display_dc_vs_nation = function() {
      var _this = this;
      this.force.gravity(this.layout_gravity).charge(this.charge).friction(0.9).on("tick", function(e) {
        return _this.circles.each(_this.move_torwards_location_center(e.alpha)).attr("cx", function(d) {
          return d.x;
        }).attr("cy", function(d) {
          return d.y;
        });
      });
      this.force.start();
      return this.hide_scales();
    };

    BubbleChart.prototype.move_torwards_scale = function(alpha) {
      var _this = this;
      return function(d) {
        var target;
        target = {};
        target.x = _this.lease_scale(d.remaining_term_years) + _this.pl;
        target.y = _this.total_rent_scale(d.total_rent) + _this.pt;
        d.y = d.y + (target.y - d.y) * Math.sin(Math.PI * (1 - alpha * 10)) * 0.2;
        return d.x = d.x + (target.x - d.x) * Math.sin(Math.PI * (1 - alpha * 10)) * 0.1;
      };
    };

    BubbleChart.prototype.move_torwards_location_center = function(alpha) {
      var _this = this;
      return function(d) {
        var target;
        target = _this.location_centers[d.location_index];
        d.x = d.x + (target.x - d.x) * (_this.damper + 0.02) * alpha * 1.1;
        return d.y = d.y + (target.y - d.y) * (_this.damper + 0.02) * alpha * 1.1;
      };
    };

    BubbleChart.prototype.display_scales = function() {
      var xax, yax;
      xax = this.vis.insert("g", ".chart-bubble").attr("id", "chart-x-axis").attr("class", "x axis").attr("transform", "translate(" + this.pl + "," + (this.height - this.pb) + ")");
      xax.call(this.x_axis);
      yax = this.vis.insert("g", ".chart-bubble").attr("id", "chart-y-axis").attr("class", "y axis").attr("transform", "translate(" + this.pl + "," + this.pt + ")");
      yax.call(this.y_axis);
      xax.append("text").attr("class", "axis-text").attr("transform", "translate(" + (this.width / 2 - 40) + "," + 30 + ")").attr("text-anchor", "middle").text("Remaining Lease Term (Yrs)");
      yax.append("text").attr("class", "axis-text").attr("transform", "translate(" + (-this.pl + 10) + "," + (this.height / 2 - 55) + ")rotate(-90)").attr("text-anchor", "start").text("Total Annual Rent");
      yax.append("line").attr("class", "axis-line").attr("x1", this.lease_scale(10)).attr("y1", 0).attr("x2", this.lease_scale(10)).attr("y2", this.height - (this.pb + this.pt));
      yax.append("line").attr("class", "axis-line").attr("x1", this.lease_scale(5)).attr("y1", 0).attr("x2", this.lease_scale(5)).attr("y2", this.height - (this.pb + this.pt));
      return yax.append("line").attr("class", "axis-line").attr("x1", this.lease_scale(15)).attr("y1", 0).attr("x2", this.lease_scale(15)).attr("y2", this.height - (this.pb + this.pt));
    };

    BubbleChart.prototype.hide_scales = function() {
      this.vis.select("#chart-x-axis").remove();
      return this.vis.select("#chart-y-axis").remove();
    };

    BubbleChart.prototype.show_details = function(data, i, element) {
      var content;
      d3.select(element).attr("stroke", "black");
      content = "<p class=\"main\">" + data.address + "<br/>" + data.city + ", " + data.state + "</p><hr class=\"tooltip-hr\">";
      content += "<span class=\"name\">RSF:</span><span class=\"value\"> " + (addCommas(data.lease_rsf_value)) + "</span><br/>";
      content += "<span class=\"name\">Rent:</span><span class=\"value\"> " + data.rent_prsf + "/RSF</span><br/>";
      return this.tooltip.showTooltip(content, d3.event);
    };

    BubbleChart.prototype.hide_details = function(data, i, element) {
      var _this = this;
      d3.select(element).attr("stroke", function(d) {
        return d3.rgb(_this.fill_color(d.category)).darker().toString();
      });
      return this.tooltip.hideTooltip();
    };

    return BubbleChart;

  })();

  root = typeof exports !== "undefined" && exports !== null ? exports : this;

  cleanNum = function(num) {
    return num.replace(/[\"\,\$]/g, "");
  };

  cleanData = function(raw) {
    raw.forEach(function(d) {
      d.size = parseInt(cleanNum(d.lease_rsf));
      d.lease_rsf_value = parseInt(cleanNum(d.lease_rsf));
      d.category_value = parseFloat(cleanNum(d.rent_prsf));
      d.rent_prsf_value = parseFloat(cleanNum(d.rent_prsf));
      d.remaining_term_years = parseFloat(d.remaining_term_years);
      d.annual_rent_value = parseFloat(cleanNum(d.annual_rent));
      return d.total_rent = parseFloat(cleanNum(d.annual_rent));
    });
    return raw;
  };

  filterData = function(data) {
    var filter;
    filter = data.filter(function(d) {
      return d.lease_rsf_value > 75000;
    });
    return filter;
  };

  $(function() {
    var chart, render_vis, toggle_overlay,
      _this = this;
    chart = null;
    render_vis = function(csv) {
      var data;
      data = filterData(cleanData(csv));
      chart = new BubbleChart(data);
      chart.start();
      return chart.set_display('all');
    };
    toggle_overlay = function(selected_tab) {
      var currentOverlay, currentOverlayDiv, h, overlays;
      h = 700;
      overlays = {
        all: {
          name: "#chart-all-overlay",
          height: h
        },
        dc_vs_nation: {
          name: "#chart-dc-vs-nation-overlay",
          height: h
        },
        rent_vs_remaining: {
          name: "#chart-rent-vs-remaining-overlay",
          height: h + 40
        },
        state: {
          name: "#chart-state-overlay",
          height: h
        }
      };
      d3.values(overlays).forEach(function(overlay) {
        return $(overlay.name).hide();
      });
      currentOverlay = overlays[selected_tab];
      if (!currentOverlay) currentOverlay = overlays["all"];
      currentOverlayDiv = $(currentOverlay.name);
      currentOverlayDiv.delay(300).fadeIn(500);
      return $("#chart-frame").css({
        'height': currentOverlay.height
      });
    };
    root.toggle_view = function(view_type) {
      toggle_overlay(view_type);
      return chart.set_display(view_type);
    };
    return d3.csv("data/inventory_abridged.csv", render_vis);
  });

}).call(this);
