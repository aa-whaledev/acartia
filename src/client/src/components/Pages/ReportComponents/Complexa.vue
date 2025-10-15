<template>
  <div class="complexa-root">
    <!--<h2>Temporal Species Sightings Heat Map with <u>D3</u></h2>-->

    <!-- Optional export buttons (kept but disabled as per your current setup) -->
    <div class="export-buttons">
      <!--<button class="expobutt" @click="exportHeatmap('png')">Export PNG</button>-->
      <!--<button class="expobutt" @click="exportHeatmap('jpeg')">Export JPEG</button>-->
      <!-- <button class="expobutt" @click="exportHeatmapPDF">Export PDF</button> -->
    </div>

    <!-- NEW: Species category toggles (top-left), OR logic across selected categories -->
    <div class="species-filters">
      <label class="switch">
        <input type="checkbox" v-model="fltOrca" @change="updateHeatmap" />
        <span>Orca</span>
      </label>
      <label class="switch">
        <input type="checkbox" v-model="fltWhale" @change="updateHeatmap" />
        <span>Whale</span>
      </label>
      <label class="switch">
        <input type="checkbox" v-model="fltDolphin" @change="updateHeatmap" />
        <span>Dolphin</span>
      </label>
      <label class="switch">
        <input type="checkbox" v-model="fltOther" @change="updateHeatmap" />
        <span>Other</span>
      </label>
    </div>

    <!-- Mode toggle (top-right) -->
    <div class="mode-toggle">
      <label class="mode-label">
        <span>Color by</span>
        <select v-model="colorBy" @change="updateHeatmap">
          <option value="delta">Change (Δ vs prev)</option>
          <option value="absolute">Absolute count</option>
        </select>
      </label>
    </div>

    <!-- Heatmap Container (fills the component; parent controls the card size) -->
    <div ref="heatmap" class="heatmap-container"></div>
  </div>
</template>

<script>
import html2canvas from 'html2canvas';
import * as d3 from 'd3';

export default {
  name: 'Complexa',
  data() {
    return {
      rawSightings: [],
      filteredSightings: [],
      selectedYear: 2023, // legacy local value; global is used for filtering
      availableYears: [],
      // Palette used for absolute counts
      // colorRange: ['#DAFDBA', '#f51b1b', '#45C4B0', '#f51b1b', '#8a1313']
      // colorRange: ['#1B2B7B', '#1B2BCF', '#38A7FF', '#38E1FF', '#D8E1FF']
      colorRange: ['#D8E1FF', '#38E1FF', '#38A7FF', '#1B2BCF', '#1B2B7B'],

      // NEW: how to color cells: 'delta' (default) or 'absolute'
      colorBy: 'delta',

      // NEW: species filters (checkboxes); OR logic across selected
      fltOrca: false,
      fltWhale: false,
      fltDolphin: false,
      fltOther: false,
    };
  },

  computed: {
    csvUrl() {
      const base = (process.env.BASE_URL || '/').replace(/\/$/, '/');
      return base + 'data/acartia-export.csv';
    },
    // Global year from the shared Vuex store
    selectedYearNum() {
      const y = this.$store?.state?.selectedYear;
      return y ? +y : NaN;
    }
  },

  async mounted() {
    await this.loadData();

    // If no global year set yet, default to the latest from CSV so all charts sync
    if (!this.$store.state.selectedYear && this.availableYears.length) {
      this.$store.commit('setSelectedYear', String(this.availableYears[this.availableYears.length - 1]));
    }

    this.updateHeatmap();

    // Redraw on global year change
    this.$watch(() => this.$store?.state?.selectedYear, () => {
      this.updateHeatmap();
    });

    // Redraw on resize for responsiveness
    window.addEventListener('resize', this.updateHeatmap);
  },

  beforeDestroy() {
    window.removeEventListener('resize', this.updateHeatmap);
  },

  methods: {
    async loadData() {
      const raw = await d3.csv(this.csvUrl);

      // include original species text and a derived category for filtering
      this.rawSightings = raw.map(d => {
        const speciesRaw = (d.type ?? d.species ?? d.Species ?? '').toString().trim();
        const species = speciesRaw.toLowerCase();
        return {
          species,                                  // lowercased for grouping
          speciesLabel: speciesRaw || 'Unknown',    // original text for display
          category: this.classifyCategory(species), // NEW: orca/whale/dolphin/other
          source: d.data_source_witness?.trim().toLowerCase() || 'unknown',
          date: new Date(d.created),
          lat: Math.round(+d.latitude || 0),
          lon: Math.round(+d.longitude || 0)
        };
      }).filter(d => d.species && !d.species.includes('other'));

      // Dynamically extract years from the date field
      const allYears = Array.from(new Set(this.rawSightings.map(d => d.date.getFullYear()))).sort();
      this.availableYears = allYears;

      // Default to most recent year (legacy local; global is authoritative)
      this.selectedYear = allYears[allYears.length - 1];
    },

    // NEW: simple keyword-based classifier → 'orca' | 'whale' | 'dolphin' | 'other'
    classifyCategory(speciesLower) {
      const s = (speciesLower || '').toLowerCase();

      // orca synonyms
      const isOrca = /\b(orca|killer\s*whale|orcinus)\b/.test(s);

      // dolphins & porpoises
      const isDolphin = /\b(dolphin|porpoise|bottlenose|spinner|dusky|common\s*dolphin)\b/.test(s);

      // whales (exclude orca which we already caught)
      const isWhale = /\b(whale|humpback|blue|fin|minke|sei|right\s*whale|sperm|pilot\s*whale|baleen)\b/.test(s);

      if (isOrca) return 'orca';
      if (isDolphin) return 'dolphin';
      if (isWhale) return 'whale';
      return 'other';
    },

    updateHeatmap() {
      if (isNaN(this.selectedYearNum)) {
        this.filteredSightings = [];
      } else {
        // filter first by year
        let rows = this.rawSightings.filter(d => d.date.getFullYear() === this.selectedYearNum);

        // then by species category toggles (OR logic; if none selected => show all)
        const anyToggle = this.fltOrca || this.fltWhale || this.fltDolphin || this.fltOther;
        if (anyToggle) {
          rows = rows.filter(r =>
            (this.fltOrca && r.category === 'orca') ||
            (this.fltWhale && r.category === 'whale') ||
            (this.fltDolphin && r.category === 'dolphin') ||
            (this.fltOther && r.category === 'other')
          );
        }

        this.filteredSightings = rows;
      }

      d3.select(this.$refs.heatmap).selectAll('*').remove();
      this.drawHeatmap();
    },

    drawHeatmap() {
      const host = this.$refs.heatmap;
      if (!host) return;

      // Measure available space from the placeholder/card
      const { width: hostW, height: hostH } = host.getBoundingClientRect();

      // Guard: if parent hasn't laid out yet, avoid drawing
      if (!hostW || !hostH) return;

      // Margins inside the container
      const margin = { top: 0, right: 0, bottom: 0, left: 0 };
      const width = Math.max(0, hostW);
      const height = Math.max(0, hostH); // use full container height

      const innerW = Math.max(0, width - margin.left - margin.right);
      const innerH = Math.max(0, height - margin.top - margin.bottom);

      const months = d3.range(0, 12);

      // group by original species label (not the lowercase key), so rows look nice
      const speciesList = Array.from(new Set(this.filteredSightings.map(d => d.speciesLabel))).sort();

      const monthNames = months.map(m =>
        new Date(this.selectedYearNum || this.selectedYear, m).toLocaleString('default', { month: 'short' })
      );

      // Build per-cell data: absolute 'value' and delta vs previous month using log-diff
      const heatData = [];
      const dominantSource = {};
      const sightingsMap = new Map();

      speciesList.forEach(speciesLabel => {
        const monthCounts = {};
        months.forEach(month => {
          const filtered = this.filteredSightings.filter(d =>
            d.speciesLabel === speciesLabel && d.date.getMonth() === month
          );
          const count = filtered.length;

          const topSource = d3.rollup(filtered, v => v.length, d => d.source);
          const topSourceArr = Array.from(topSource.entries()).sort((a, b) => b[1] - a[1]);
          const top = topSourceArr.length ? topSourceArr[0][0] : '';

          // compute log-diff delta vs previous month
          const prev = monthCounts[month - 1] ?? 0;
          const deltaLog = Math.log1p(count) - Math.log1p(prev); // robust for zeros

          monthCounts[month] = count;
          dominantSource[`${speciesLabel}_${monthNames[month]}`] = top;

          heatData.push({
            species: speciesLabel,
            month: monthNames[month],
            monthIndex: month,
            value: count,
            delta: deltaLog
          });
        });
        sightingsMap.set(speciesLabel, monthCounts);
      });

      // SVG sized to container; viewBox ensures crisp scaling
      const svg = d3.select(host)
        .append('svg')
        .attr('width', '100%')
        .attr('height', '70%') // keep your working layout
        .attr('viewBox', `0 0 ${width} ${height}`)
        .attr('preserveAspectRatio', 'xMidYMid meet');

      const g = svg.append('g').attr('transform', `translate(${margin.left},${margin.top})`);

      const x = d3.scaleBand()
        .domain(monthNames)
        .range([0, innerW])
        .padding(0.05);

      const y = d3.scaleBand()
        .domain(speciesList)
        .range([0, innerH])
        .padding(0.05);

      // ABSOLUTE counts palette (your existing threshold logic)
      const maxValue = d3.max(heatData, d => d.value) || 0;
      const colorAbs = d3.scaleThreshold()
        .domain(d3.range(1, this.colorRange.length).map(i => maxValue * i / this.colorRange.length))
        .range(this.colorRange);

      // DELTA (change vs previous month): diverging scale centered at 0
      const maxAbsDelta = d3.max(heatData, d => Math.abs(d.delta)) || 1e-6;

      // Prefer RdYlGn if available; otherwise fall back to a custom diverging ramp
      const divergeInterp = d3.interpolateRgbBasis([
        "#08306b", // deep navy (large negative change)
        "#4292c6", // medium blue
        "#deebf7", // pale blue/near neutral
        "#9ecae1", // medium-light blue for small positive
        "#08519c"  // stronger blue for large positive
      ]);

      const colorDelta = d3.scaleDiverging()
        .domain([-maxAbsDelta, 0, maxAbsDelta])
        .interpolator(divergeInterp);

      // Axes
      g.append('g')
        .attr('transform', `translate(0, ${innerH})`)
        .call(d3.axisBottom(x).tickSize(0))
        .style('font-size', Math.max(10, Math.min(14, innerW / 60)) + 'px')
        .select('.domain').remove();

      g.append('g')
        .call(d3.axisLeft(y).tickSize(0))
        .style('font-size', Math.max(10, Math.min(14, innerH / (speciesList.length || 1))) + 'px')
        .select('.domain').remove();

      // Tooltip (ensure only one exists)
      d3.select('body').selectAll('.complexa-tooltip').remove();
      const tooltip = d3.select('body')
        .append('div')
        .attr('class', 'complexa-tooltip')
        .style('opacity', 0)
        .style('position', 'absolute')
        .style('background-color', 'white')
        .style('border', 'solid 1px #ccc')
        .style('padding', '6px')
        .style('border-radius', '4px')
        .style('font-size', '12px')
        .style('pointer-events', 'none')
        .style('z-index', 1000);

      const blocks = g.selectAll('rect')
        .data(heatData)
        .enter()
        .append('rect')
        .attr('x', d => x(d.month))
        .attr('y', d => y(d.species))
        .attr('rx', 4)
        .attr('ry', 4)
        .attr('width', Math.max(0, x.bandwidth()))
        .attr('height', Math.max(0, y.bandwidth()))
        .style('fill', d => this.colorBy === 'delta' ? colorDelta(d.delta) : colorAbs(d.value))
        .style('stroke-width', 2)
        .style('stroke', 'none')
        .style('opacity', 0.8)
        .on('mouseover', function () {
          d3.select(this).style('stroke', '#fff').style('opacity', 1);
          tooltip.style('opacity', 1);
        })
        .on('mousemove', (event, d) => {
          const prevMonth = d.monthIndex - 1;
          const speciesCounts = sightingsMap.get(d.species) || {};
          const prevValue = speciesCounts[prevMonth] || 0;
          const currValue = d.value;

          // % change for display (uses prev guard)
          let changeText = '–';
          if (prevValue > 0) {
            const pct = ((currValue - prevValue) / prevValue) * 100;
            changeText = `${pct >= 0 ? '🟢 ↑' : '🔴 ↓'} ${Math.abs(pct).toFixed(1)}%`;
          } else if (currValue > 0) {
            changeText = `🟢 ↑ new`;
          }

          tooltip
            .html(
              `<strong>${d.species}</strong><br>
               Month: ${d.month}<br>
               Sightings: ${currValue}<br>
               Change: ${changeText}<br>
               Top Source: ${dominantSource[`${d.species}_${d.month}`] || 'N/A'}`
            )
            .style('left', (event.pageX + 10) + 'px')
            .style('top', (event.pageY - 28) + 'px');
        })
        .on('mouseleave', function () {
          d3.select(this).style('stroke', 'none').style('opacity', 0.8);
          tooltip.style('opacity', 0);
        });

      blocks
        .style('opacity', 0)
        .transition()
        .duration(800)
        .ease(d3.easeCubicInOut)
        .style('opacity', 0.8);

      // Title (inside inner area, scaled with width)
      g.append('text')
        .attr('x', 0)
        .attr('y', -20)
        .attr('font-size', Math.max(14, Math.min(22, innerW / 20)))
        .text(`Species Sightings by Month (${this.selectedYearNum || this.selectedYear})`);
    },

    exportHeatmap(format) {
      const node = this.$refs.heatmap;
      html2canvas(node).then(canvas => {
        const link = document.createElement('a');
        const yr = this.$store?.state?.selectedYear || this.selectedYear;
        link.download = `heatmap_${yr}.${format}`;
        link.href = canvas.toDataURL(`image/${format}`);
        link.click();
      });
    }
  }
};
</script>

<style scoped>
.complexa-root {
  display: flex;
  flex-direction: column;
  gap: 0px;
  height: 70%;
}

/* Container fills the card: Reports page controls the card size */
.heatmap-container {
  position: relative;
  width: 100%;
  height: 70%;
  /* Ensure there’s at least some height if parent collapses on very small screens */
  min-height: 240px;
}

.tooltip,
.complexa-tooltip {
  pointer-events: none;
  z-index: 1000;
}

.expobutt {
  background-color: #13678A;
  color: white;
  border: none;
  padding: 6px 12px;
  border-radius: 4px;
  cursor: pointer;
  margin-left: 5px;
}
.expobutt:hover {
  background-color: #0d4d6d;
}

/* NEW: compact mode toggle in top-right */
.mode-toggle {
  position: absolute;
  top: 8px;
  right: 8px;
  z-index: 2;
}
.mode-label {
  font-size: 12px;
  display: flex;
  gap: 6px;
  align-items: center;
  background: rgba(255,255,255,.9);
  padding: 6px 8px;
  border-radius: 8px;
  border: 1px solid #e5e7eb;
}
.mode-label select {
  font-size: 12px;
  padding: 2px 6px;
}

/* NEW: species filter pill group (top-left) */
.species-filters {
  position: absolute;
  top: 8px;
  left: 8px;
  z-index: 2;
  background: rgba(255,255,255,0.95);
  backdrop-filter: blur(2px);
  padding: 8px 10px;
  border-radius: 10px;
  box-shadow: 0 1px 2px rgba(0,0,0,0.08);
  display: flex;
  gap: 12px;
  align-items: center;
  flex-wrap: wrap;
  max-width: calc(100% - 16px);
}
.switch {
  display: inline-flex;
  gap: 6px;
  align-items: center;
  font-size: 12px;
  color: #111827;
  user-select: none;
}
.switch input {
  transform: scale(1.0);
  cursor: pointer;
}
</style>
