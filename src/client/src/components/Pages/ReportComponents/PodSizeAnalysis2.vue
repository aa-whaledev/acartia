<template>
  <div class="chart-wrapper">
    <div class="controls">
      <label>
        Species:
        <select v-model="selectedSpecies" @change="drawChart">
          <option value="All">All</option>
          <option v-for="s in speciesOptions" :key="s">{{ s }}</option>
        </select>
      </label>

      <div>Log Scale</div>
      <label class="switch">
        <input type="checkbox" v-model="useLogScale" @change="drawChart" />
        <span class="slider round"></span>
      </label>

      <div class="export-buttons">
        <!--<button class="expobutt" @click="exportChart('png')">Export PNG</button>-->
        <!--<button class="expobutt" @click="exportChart('jpeg')">Export JPEG</button>-->
      </div>
    </div>

    <div ref="chartContainer" class="chart-container">
      <svg ref="chart"></svg>
      <div v-if="!hasData" class="empty-hint">No data to display for the current settings.</div>
    </div>
  </div>
</template>

<script>
import * as d3 from "d3";
import html2canvas from "html2canvas";

export default {
  name: "PodSizeAnalysis2",
  data() {
    return {
      selectedSpecies: "All",
      useLogScale: false,
      fullData: [],
      yearOptions: [],
      speciesOptions: [],
      margin: { top: 40, right: 30, bottom: 50, left: 60 },
      hasData: false,
    };
  },

  computed: {
    csvUrl() {
      const base = (process.env.BASE_URL || "/").replace(/\/$/, "/");
      return base + "data/acartia-export.csv";
    },
    // Shared year comes from the store; fallback to latest year in dataset
    selectedYearNum() {
      const y = this.$store?.state?.selectedYear;
      if (y) return +y;
      return this.yearOptions.length ? this.yearOptions[this.yearOptions.length - 1] : NaN;
    },
  },

  async mounted() {
    await this.loadFromCsv();         // CSV is the source of truth for this chart
    window.addEventListener("resize", this.drawChart);

    // Redraw any time the shared year changes
    this.$watch(() => this.$store?.state?.selectedYear, () => {
      this.drawChart();
    });
  },

  beforeDestroy() {
    window.removeEventListener("resize", this.drawChart);
  },

  methods: {
    async loadFromCsv() {
      try {
        const res = await fetch(this.csvUrl, { cache: "no-store" });
        if (!res.ok) {
          console.error("[PodSizeAnalysis2] CSV fetch failed:", res.status, this.csvUrl);
          return;
        }
        const text = await res.text();
        const parsed = d3.csvParse(text);
        const rows = parsed
          .map(this.normalizeRow)
          .filter(r => r.date instanceof Date && !isNaN(+r.date));

        this.fullData = rows;

        // Build filters
        this.yearOptions = Array.from(
          new Set(rows.map(r => r.date.getFullYear()).filter(y => !isNaN(y)))
        ).sort((a,b)=>a-b);

        this.speciesOptions = Array.from(new Set(rows.map(r => r.type))).sort();

        // If no shared year set yet, pick latest and push to store so all charts sync
        if (!this.$store.state.selectedYear && this.yearOptions.length) {
          this.$store.commit('setSelectedYear', String(this.yearOptions[this.yearOptions.length - 1]));
        }

        this.drawChart();
      } catch (e) {
        console.error("[PodSizeAnalysis2] loadFromCsv error:", e);
      }
    },

    normalizeRow(d) {
      const rawDate =
        d.created || d.created_at || d.date || d.timestamp || d.time || d.observed_at;

      let date = null;
      if (rawDate != null) {
        const n = typeof rawDate === "number" ? rawDate : Number(rawDate);
        if (!isNaN(n)) {
          date = new Date(n > 1e12 ? n : n * 1000);
        } else {
          const t = Date.parse(rawDate);
          if (!isNaN(t)) date = new Date(t);
        }
      }

      const sizeRaw =
        d.no_sighted ?? d.noSighted ?? d.no_sightings ?? d.group_size ?? d.count ?? d.size ?? d.pod_size;
      const size = Number(sizeRaw ?? 1) || 1;

      const type =
        (d.type ?? d.species ?? d.Species ?? d.species_name ?? d.SpeciesName ?? d.category ?? d.name ?? "Unknown")
        .toString()
        .trim();

      return { date, size, type };
    },

    exportChart(format) {
      const node = this.$refs.chartContainer;
      html2canvas(node).then(canvas => {
        const link = document.createElement("a");
        link.download = `podsize_${this.$store?.state?.selectedYear || "all"}.${format}`;
        link.href = canvas.toDataURL(`image/${format}`);
        link.click();
      });
    },

    drawChart() {
      const svg = d3.select(this.$refs.chart);
      const container = this.$refs.chartContainer;
      svg.selectAll("*").remove();

      if (!container || !this.fullData.length || !this.yearOptions.length || isNaN(this.selectedYearNum)) {
        this.hasData = false;
        return;
      }

      const { top, right, bottom, left } = this.margin;
      const width = Math.max(0, (container.clientWidth || 0) - left - right);
      const height = Math.max(0, 500 - top - bottom);
      if (width <= 0 || height <= 0) { this.hasData = false; return; }

      svg.attr("width", width + left + right).attr("height", height + top + bottom);
      const g = svg.append("g").attr("transform", `translate(${left},${top})`);
      const formatMonth = d3.timeFormat("%Y-%m");

      const filtered = this.fullData.filter(d => {
        const y = d.date.getFullYear();
        return (y === this.selectedYearNum) &&
               (this.selectedSpecies === "All" || d.type === this.selectedSpecies);
      });

      // Months across entire selected year (end is exclusive)
      const fullYearMonths = d3.timeMonths(
        new Date(this.selectedYearNum, 0, 1),
        new Date(this.selectedYearNum + 1, 0, 1)
      );

      const grouped = this.selectedSpecies === "All"
        ? d3.groups(filtered, d => d.type).map(([species, values]) => {
            const monthMap = new Map(d3.rollups(values, v => d3.sum(v, d => d.size), d => formatMonth(d.date)));
            return {
              species,
              values: fullYearMonths.map(m => ({ date: m, size: monthMap.get(formatMonth(m)) ?? 0 }))
            };
          })
        : [{
            species: this.selectedSpecies,
            values: (() => {
              const monthMap = new Map(d3.rollups(filtered, v => d3.sum(v, d => d.size), d => formatMonth(d.date)));
              return fullYearMonths.map(m => ({ date: m, size: monthMap.get(formatMonth(m)) ?? 0 }));
            })()
          }];

      const flatVals = grouped.flatMap(d => d.values);
      if (!grouped.length || !flatVals.length) { this.hasData = false; return; }
      this.hasData = true;

      const x = d3.scaleTime().domain(d3.extent(fullYearMonths)).range([0, width]);
      const y = this.useLogScale
        ? d3.scaleLog().clamp(true).range([height, 0])
            .domain([1, d3.max(flatVals, d => Math.max(1, d.size))])
        : d3.scaleLinear().range([height, 0])
            .domain([0, d3.max(flatVals, d => d.size)]).nice();

      g.append("g").attr("transform", `translate(0,${height})`).call(d3.axisBottom(x).ticks(width / 80));
      g.append("g").call(d3.axisLeft(y));

      const color = d3.scaleOrdinal(d3.schemeTableau10).domain(grouped.map(d => d.species));
      const line = d3.line()
        .defined(d => d.size !== null)
        .x(d => x(d.date))
        .y(d => y(this.useLogScale ? Math.max(1, d.size) : d.size));

      const body = g.append("g");
      const linePaths = body.selectAll(".line").data(grouped).enter()
        .append("path")
        .attr("fill", "none")
        .attr("stroke-width", 2)
        .attr("class", "line")
        .attr("stroke", d => color(d.species))
        .attr("d", d => line(d.values));

      // animated draw
      linePaths
        .attr("stroke-dasharray", function () {
          const totalLength = this.getTotalLength();
          return `${totalLength} ${totalLength}`;
        })
        .attr("stroke-dashoffset", function () {
          return this.getTotalLength();
        })
        .transition()
        .duration(1000)
        .delay((d, i) => i * 100)
        .attr("stroke-dashoffset", 0);

      // crosshair + label
      const vLine = g.append("line").attr("stroke", "#999").attr("stroke-dasharray", "4").style("opacity", 0);
      const hLine = g.append("line").attr("stroke", "#999").attr("stroke-dasharray", "4").style("opacity", 0);
      const label = g.append("text").attr("font-size", "13px").style("font-weight", "bold").style("opacity", 0);

      svg.on("mousemove", (event) => {
        const [xm, ym] = d3.pointer(event);
        const points = grouped.flatMap(gp => gp.values.map(v => ({ ...v, species: gp.species })));
        if (!points.length) return;

        const closest = points.reduce((a, b) => {
          const da = Math.hypot(x(a.date) - xm, y(this.useLogScale ? Math.max(1, a.size) : a.size) - ym);
          const db = Math.hypot(x(b.date) - xm, y(this.useLogScale ? Math.max(1, b.size) : b.size) - ym);
          return da < db ? a : b;
        });

        const cx = x(closest.date);
        const cy = y(this.useLogScale ? Math.max(1, closest.size) : closest.size);
        const selectedSpecies = closest.species;
        const selectedColor = color(selectedSpecies);

        vLine.attr("x1", cx).attr("x2", cx).attr("y1", 0).attr("y2", height).style("opacity", 1);
        hLine.attr("x1", 0).attr("x2", width).attr("y1", cy).attr("y2", cy).style("opacity", 1);

        label.text(`${selectedSpecies}: ${closest.size}`)
          .attr("x", cx + 6)
          .attr("y", cy - 8)
          .style("fill", selectedColor)
          .style("opacity", 1);

        linePaths
          .attr("stroke-width", d => d.species === selectedSpecies ? 3 : 2)
          .style("opacity", d => d.species === selectedSpecies ? 1 : 0.5)
          .attr("stroke", d => d.species === selectedSpecies ? color(d.species) : "#ccc");
      });

      svg.on("mouseleave", () => {
        vLine.style("opacity", 0);
        hLine.style("opacity", 0);
        label.style("opacity", 0);
        linePaths
          .attr("stroke-width", 2)
          .style("opacity", 1)
          .attr("stroke", d => color(d.species));
      });
    },
  },
};
</script>

<style scoped>
.chart-wrapper { width: 100%; max-width: 1000px; margin: auto; }
.controls { display: flex; flex-wrap: wrap; gap: 1rem; margin-bottom: 10px; align-items: center; }
.chart-container { position: relative; }
.empty-hint { padding: 16px; color: #666; text-align: center; }

/* Toggle Switch */
.switch { position: relative; display: inline-block; width: 60px; height: 34px; }
.switch input { opacity: 0; width: 0; height: 0; }
.slider { position: absolute; cursor: pointer; inset: 0; background-color: #ccc; transition: .4s; }
.slider:before { content: ""; position: absolute; height: 26px; width: 26px; left: 4px; bottom: 4px; background: white; transition: .4s; }
input:checked + .slider { background-color: #2196F3; }
input:checked + .slider:before { transform: translateX(26px); }
.slider.round { border-radius: 34px; }
.slider.round:before { border-radius: 50%; }

.export-buttons { display: flex; gap: 10px; }
.expobutt { background-color: #13678A; color: white; border: none; padding: 6px 12px; border-radius: 4px; cursor: pointer; }
.expobutt:hover { background-color: #0d4d6d; }
</style>
