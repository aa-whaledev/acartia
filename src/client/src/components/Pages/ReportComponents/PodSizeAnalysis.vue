<template>
  <div class="chart-wrapper">
    <div class="controls">
      <label>
        Year:
        <select v-model="selectedYear" @change="drawChart">
          <option v-for="year in yearOptions" :key="year">{{ year }}</option>
        </select>
      </label>

      <label>
        Species:
        <select v-model="selectedSpecies" @change="drawChart">
          <option value="All">All</option>
          <option v-for="s in speciesOptions" :key="s">{{ s }}</option>
        </select>
      </label>

      <label>
        Log Scale:
        <input type="checkbox" v-model="useLogScale" @change="drawChart" />
      </label>
    </div>

    <div ref="chartContainer" class="chart-container">
      <svg ref="chart"></svg>
    </div>
  </div>
</template>

<script>
import * as d3 from "d3";

export default {
  name: "SpeciesLineChart",
  data() {
    return {
      selectedYear: "2025",
      selectedSpecies: "All",
      useLogScale: false,
      fullData: [],
      yearOptions: [],
      speciesOptions: [],
      margin: { top: 40, right: 30, bottom: 50, left: 60 }
    };
  },
  mounted() {
    d3.csv("/data/acartia-export.csv").then(data => {
      data.forEach(d => {
        d.date = new Date(d.created);
        d.size = +d.no_sighted;
        d.type = d.type.trim();
      });
      this.fullData = data;
      this.yearOptions = Array.from(new Set(data.map(d => d.date.getFullYear())))
        .filter(y => !isNaN(y))
        .sort();
      this.speciesOptions = Array.from(new Set(data.map(d => d.type))).sort();
      this.drawChart();
      window.addEventListener("resize", this.drawChart);
    });
  },
  beforeDestroy() {
    window.removeEventListener("resize", this.drawChart);
  },
  methods: {
    drawChart() {
      const svg = d3.select(this.$refs.chart);
      const container = this.$refs.chartContainer;
      svg.selectAll("*").remove();

      const { top, right, bottom, left } = this.margin;
      const width = container.clientWidth - left - right;
      const height = 500 - top - bottom;
      svg.attr("width", width + left + right).attr("height", height + top + bottom);

      const g = svg.append("g").attr("transform", `translate(${left},${top})`);
      const formatMonth = d3.timeFormat("%Y-%m");

      const filtered = this.fullData.filter(d => {
        const y = d.date.getFullYear();
        const matchY = this.selectedYear === "All" || y === +this.selectedYear;
        const matchS = this.selectedSpecies === "All" || d.type === this.selectedSpecies;
        return matchY && matchS;
      });

      const fullYearMonths = d3.timeMonths(
        new Date(+this.selectedYear, 0, 1),
        new Date(+this.selectedYear, 11, 31)
      );

      const grouped = this.selectedSpecies === "All"
        ? d3.groups(filtered, d => d.type).map(([species, values]) => {
            const monthMap = new Map(
              d3.rollups(values, v => d3.sum(v, d => d.size), d => formatMonth(d.date))
            );
            return {
              species,
              values: fullYearMonths.map(m => ({
                date: m,
                size: monthMap.get(formatMonth(m)) ?? 0
              }))
            };
          })
        : [{
            species: this.selectedSpecies,
            values: (() => {
              const monthMap = new Map(
                d3.rollups(filtered, v => d3.sum(v, d => d.size), d => formatMonth(d.date))
              );
              return fullYearMonths.map(m => ({
                date: m,
                size: monthMap.get(formatMonth(m)) ?? 0
              }));
            })()
          }];

      const x = d3.scaleTime()
        .domain(d3.extent(fullYearMonths))
        .range([0, width]);

      const y = this.useLogScale
        ? d3.scaleLog()
            .clamp(true)
            .range([height, 0])
            .domain([1, d3.max(grouped.flatMap(d => d.values), d => Math.max(1, d.size))])
        : d3.scaleLinear()
            .range([height, 0])
            .domain([0, d3.max(grouped.flatMap(d => d.values), d => d.size)])
            .nice();

      g.append("g")
        .attr("transform", `translate(0,${height})`)
        .attr("class", "x-axis")
        .call(d3.axisBottom(x).ticks(width / 80));

      g.append("g").call(d3.axisLeft(y));

      const color = d3
        .scaleOrdinal(d3.schemeTableau10)
        .domain(grouped.map(d => d.species));

      const line = d3
        .line()
        .defined(d => d.size !== null)
        .x(d => x(d.date))
        .y(d => y(this.useLogScale ? Math.max(1, d.size) : d.size));

      const body = g.append("g");

      const linePaths = body
        .selectAll(".line")
        .data(grouped)
        .enter()
        .append("path")
        .attr("class", "line")
        .attr("fill", "none")
        .attr("stroke-width", 2)
        .attr("stroke", d => color(d.species))
        .attr("d", d => line(d.values));

      // Crosshair lines
      const crosshairGroup = g.append("g").attr("class", "crosshair");
      const crosshairX = crosshairGroup.append("line")
        .attr("stroke", "#aaa")
        .attr("stroke-dasharray", "4")
        .attr("y1", 0)
        .attr("y2", height)
        .style("opacity", 0);

      const crosshairY = crosshairGroup.append("line")
        .attr("stroke", "#aaa")
        .attr("stroke-dasharray", "4")
        .attr("x1", 0)
        .attr("x2", width)
        .style("opacity", 0);

      // Mouse interaction
      svg.on("mousemove", function (event) {
        const [xm, ym] = d3.pointer(event);
        const allPoints = grouped.flatMap(g =>
          g.values.map(v => ({ ...v, species: g.species }))
        );

        const closest = allPoints.reduce((a, b) => {
          const da = Math.hypot(x(a.date) - xm + left, y(this.useLogScale ? Math.max(1, a.size) : a.size) - ym + top);
          const db = Math.hypot(x(b.date) - xm + left, y(this.useLogScale ? Math.max(1, b.size) : b.size) - ym + top);
          return da < db ? a : b;
        });

        const selectedSpecies = closest.species;
        const cx = x(closest.date);
        const cy = y(this.useLogScale ? Math.max(1, closest.size) : closest.size);

        // Update crosshair
        crosshairX
          .attr("x1", cx)
          .attr("x2", cx)
          .style("opacity", 1);
        crosshairY
          .attr("y1", cy)
          .attr("y2", cy)
          .style("opacity", 1);

        // Highlight selected line
        linePaths
          .attr("stroke-width", d => (d.species === selectedSpecies ? 2.5 : 2))
          .style("opacity", d => (d.species === selectedSpecies ? 1 : 0.5))
          .attr("stroke", d =>
            d.species === selectedSpecies ? color(d.species) : "#ccc"
          );
      }.bind(this));

      svg.on("mouseleave", () => {
        crosshairX.style("opacity", 0);
        crosshairY.style("opacity", 0);

        linePaths
          .attr("stroke-width", 2)
          .style("opacity", 1)
          .attr("stroke", d => color(d.species));
      });

      svg.on("dblclick", () => {
        x.domain(d3.extent(fullYearMonths));
        g.select(".x-axis")
          .transition()
          .call(d3.axisBottom(x).ticks(width / 80));
        linePaths.transition().attr("d", d => line(d.values));
      });
    }
  }
};
</script>

<style scoped>
.chart-wrapper {
  width: 100%;
  max-width: 1000px;
  margin: auto;
}
.controls {
  display: flex;
  flex-wrap: wrap;
  gap: 1rem;
  margin-bottom: 10px;
  align-items: center;
}
.chart-container {
  position: relative;
}
</style>
