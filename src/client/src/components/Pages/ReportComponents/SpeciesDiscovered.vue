<template>
  <div class="content shape">
    <h2>Species Discovered (Monthly)</h2>
    <div id="species-chart" ref="chartContainer"></div>
  </div>
</template>

<script>
import * as d3 from "d3";
import { getSpeciesCounts } from "../../../mapUtils";

export default {
  name: "SpeciesDiscovered",

  methods: {
    drawChart() {
      const container = this.$refs.chartContainer;
      if (!container) return;

      const el = d3.select(container);
      el.selectAll("svg").remove();

      const data = getSpeciesCounts(this.$store.state.sightings) || [];
      if (!data.length) return;

      // Use only top 5 species
      const sliced = data.slice(0, 5);

      // --- Responsive container sizing (same logic as Heatmap)
      const outerWidth = container.clientWidth;
      const outerHeight = container.clientHeight;
      const margin = { top: 10, right: 10, bottom: 25, left: 100 };
      const width = outerWidth - margin.left - margin.right;
      const height = outerHeight - margin.top - margin.bottom;

      // Create SVG inside container
      const svg = el
        .append("svg")
        .attr("width", outerWidth)
        .attr("height", outerHeight)
        .append("g")
        .attr("transform", `translate(${margin.left},${margin.top})`);

      // --- Scales
      const xMax = d3.max(sliced, (d) => d.value) || 1;
      const x = d3.scaleLinear().domain([0, xMax]).nice().range([0, width]);
      const y = d3
        .scaleBand()
        .domain(sliced.map((d) => d.species))
        .range([0, height])
        .padding(0.2);

      // --- Axes
      svg
        .append("g")
        .attr("transform", `translate(0,${height})`)
        .call(d3.axisBottom(x).ticks(5))
        .call((g) => g.select(".domain").attr("opacity", 0.3));

      svg.append("g").call(d3.axisLeft(y)).call((g) => g.select(".domain").remove());

      // --- Bars
      const colors = ["#4D76B8", "#5FAAFF", "#224DBA", "#9DC4E8", "#3B62C2"];
      svg
        .selectAll(".bar")
        .data(sliced)
        .enter()
        .append("rect")
        .attr("class", "bar")
        .attr("x", 0)
        .attr("y", (d) => y(d.species))
        .attr("height", y.bandwidth())
        .attr("width", 0)
        .attr("fill", (_, i) => colors[i % colors.length])
        .transition()
        .duration(600)
        .attr("width", (d) => x(d.value));

      // --- Labels
      svg
        .selectAll(".label")
        .data(sliced)
        .enter()
        .append("text")
        .attr("class", "label")
        .attr("x", (d) => x(d.value) + 5)
        .attr("y", (d) => y(d.species) + y.bandwidth() / 2)
        .attr("dy", "0.35em")
        .text((d) => d.value)
        .style("font-size", "11px")
        .style("fill", "#333");
    },
  },

  mounted() {
    // Initial draw
    this.drawChart();

    // Redraw when data or container size changes
    this.$watch(
      () => this.$store.state.sightings,
      () => this.drawChart(),
      { deep: true, immediate: false }
    );

    // Responsive ResizeObserver (same as Heatmap)
    const container = this.$refs.chartContainer;
    this._resizeObserver = new ResizeObserver(() => {
      this.drawChart();
    });
    this._resizeObserver.observe(container);
  },

  beforeUnmount() {
    if (this._resizeObserver) this._resizeObserver.disconnect();
  },
};
</script>

<style scoped>
.content {
  display: flex;
  flex-direction: column;
  height: 100%;
  padding: 10px;
  overflow: hidden;
}

h2 {
  font-family: Mukta;
  font-size: 1.2rem;
  font-weight: 600;
  line-height: 1.1;
  text-align: center;
  margin: 0 0 8px 0;
}

#species-chart {
  flex: 1 1 auto;
  width: 100%;
  height: 100%;
  min-height: 0;
}

.bar {
  rx: 6;
  ry: 6;
}

.label {
  font-family: Mukta, sans-serif;
}

:deep(.x-axis text),
:deep(.y-axis text) {
  font-size: 11px;
  fill: #333;
}
</style>
