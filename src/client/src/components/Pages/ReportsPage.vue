<template>

  <div>
    <LoadingSpinner v-if="isLoading" />

    <div v-else class="all-components-container">
     <!-- Global Year Filter Bar (CSV-backed) -->
<div class="global-filter">
  <label class="gf-label" for="gf-year">Year</label>
  <select
    id="gf-year"
    class="gf-select"
    :value="selectedYear"
    @change="onYearChange($event.target.value)"
    :disabled="!yearOptions.length"
    aria-label="Filter charts by year"
  >
    <option v-for="y in yearOptions" :key="y" :value="String(y)">{{ y }}</option>
  </select>
</div>



      <div class="top-row">
        <div class="component width-9 ">
          <Anomaly  />
        </div>
        <div class="component width-3 ">
          <LastSighting />
        </div>
      </div>

      <div class="middle-row ">
        <div class="component width-32">
          <TopContributors />
        </div>
        <div class="component width-36">
          <Complexa />
        </div>
        <div class="component width-32">
          <SpeciesDiscovered />
        </div>
      </div>
   <div class="bottom-row ">
        <div class="component width-12 ">
          <PodSizeAnalysis2/>
        </div>
      </div>

    </div>
  </div>

</template>

<script>

import { mapActions, mapState } from 'vuex';
import * as d3 from 'd3';

import Anomaly from './ReportComponents/Anomaly.vue';
import LastSighting from './ReportComponents/LastSighting.vue';
import TopContributors from './ReportComponents/TopContributors.vue';
import Complexa from './ReportComponents/Complexa.vue';
import SpeciesDiscovered from './ReportComponents/SpeciesDiscovered.vue';
import PodSizeAnalysis2 from './ReportComponents/PodSizeAnalysis2.vue';
import LoadingSpinner from './ReportComponents/LoadingSpinner.vue';

export default {
  name: 'ReportsPage',
  components: {
    Anomaly,
    LastSighting,

    TopContributors,
    Complexa,
    SpeciesDiscovered,

    PodSizeAnalysis2,

    LoadingSpinner
  },

  data() {
    return {
      yearOptions: [] // NEW: year list is built from CSV here (not from store)
    };
  },

  methods: {
    // keep existing actions; add CSV loader action if present in store
    ...mapActions(['fill_store', 'loadCsvSightings']), // NEW: add 'loadCsvSightings' for CSV fallback

    onYearChange(val) {
      // global year setter shared by all charts
      this.$store.commit('setSelectedYear', val);
    },

    // NEW: CSV date parsing (same approach as the chart)
    _parseDate(raw) {
      if (raw == null) return null;
      const n = Number(raw);
      if (!isNaN(n)) return new Date(n > 1e12 ? n : n * 1000); // epoch ms/s
      const t = Date.parse(raw);
      return isNaN(t) ? null : new Date(t);
    },

    // NEW: load the year list directly from /data/acartia-export.csv (not from store)
    async loadYearsFromCsv() {
      try {
        const res = await fetch(this.csvUrl, { cache: 'no-store' });
        if (!res.ok) {
          console.error('[ReportsPage] CSV fetch failed:', res.status, this.csvUrl);
          this.yearOptions = [];
          return;
        }
        const text = await res.text();
        const parsed = d3.csvParse(text);

        const dates = parsed
          .map(row => {
            const rawDate =
              row.created || row.created_at || row.date || row.timestamp || row.time || row.observed_at;
            return this._parseDate(rawDate);
          })
          .filter(d => d instanceof Date && !isNaN(+d));

        const years = [...new Set(dates.map(d => d.getFullYear()))].sort((a, b) => a - b);
        this.yearOptions = years;

        // If nothing selected yet, default to latest CSV year so all charts sync
        if (!this.$store.state.selectedYear && years.length) {
          this.$store.commit('setSelectedYear', String(years[years.length - 1]));
        }
      } catch (e) {
        console.error('[ReportsPage] loadYearsFromCsv error:', e);
        this.yearOptions = [];
      }
    }
  },

  computed: {
    ...mapState({
      isAuth: state => state.isAuthenticated
    }),
    isLoading() {
      return this.$store.state.loading;
    },
    lastSighting() {
      return this.$store.state.lastSighting;
    },

    // global year filter state (selected value lives in the store so all charts can consume it)
    selectedYear() {
      return this.$store.state.selectedYear;
    },

    // NEW: the CSV URL used by the global year filter (and also by PodSizeAnalysis2)
    csvUrl() {
      const base = (process.env.BASE_URL || '/').replace(/\/$/, '/');
      return base + 'data/acartia-export.csv';
    }
  },

  // loder for the charts
  async created() {
    // NEW: 1) Build the year list from CSV first (your request: global year reads CSV like the chart)
    await this.loadYearsFromCsv();

    // Try API first (existing behavior)
    await this.$store.dispatch('fill_store');

    // Fallback to CSV if API returns nothing (populates store.state.sightings for other components)
    if (!this.$store.state.sightings.length) {
      await this.$store.dispatch('loadCsvSightings'); // requires action in store.js
    }

    // Ensure a default shared year is set (after data load as well)
    if (!this.$store.state.selectedYear && this.yearOptions.length) {
      this.$store.commit('setSelectedYear', String(this.yearOptions[this.yearOptions.length - 1]));
    }
  }
};
</script>



<style scoped>
.all-components-container {
  padding: 20px;
  background: #e8e8e8;
}

.top-row {
  display: flex;
  height: 50vh;
  min-height: 50vh;
  gap: 20px;
  margin-bottom: 20px;
}

.bottom-row {
  height: fit-content;
}

.middle-row {
  display: flex;
  height: 30vh;
  min-height: 30vh;
  flex-wrap: nowrap;
  gap: 20px;
  margin-bottom: 30px;
}


.component {
  background: white;
  height: 100%;
  border-radius: 20px;
  padding: 10px;
}

.width-3 {
  width: 25%;
}

.width-36 {
  width: 36%;
}

.width-32 {
  width: 32%;
}

.width-12 {
  width: 100%;
}

.width-8 {
  width: 66%;
}

.width-9 {
  width: 75%;
}


.width-4 {
  width: 33%;
}

@media (max-width: 768px) {

  .width-3,
  .width-8,
  .width-9,
  .width-4,
  .width-32,
  .width-36,
  .width-12 {
    width: 100%;
  }

  .component {
    background: white;
    height: 100%;
    border-radius: 20px;
    padding: 10px;
  }

  .top-row,
  .middle-row {
    display: flex;
    flex-direction: column;
    flex-wrap: wrap;
    height: fit-content;
  }

  .middle-row {
    display: flex;
    height: auto;
    gap: 20px;
    margin-bottom: 30px;
  }
}

/**global filter button */
.global-filter {
  display: flex;
  align-items: center;
  gap: 10px;
  margin: 0 0 12px 0;
  padding: 8px 12px;
  background: #ffffff;
  border-radius: 10px;
  box-shadow: 0 1px 2px rgba(0,0,0,0.06);
}

.gf-label {
  font-size: 0.95rem;
  color: #333;
  font-weight: 600;
}

.gf-select {
  appearance: none;
  -webkit-appearance: none;
  -moz-appearance: none;

  background: #f9fafb;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  padding: 6px 10px;
  font-size: 0.95rem;
  color: #111827;
  outline: none;
  min-width: 120px;
  cursor: pointer;
}

.gf-select:focus {
  border-color: #3b82f6;
  box-shadow: 0 0 0 3px rgba(59,130,246,0.15);
}

.gf-select:disabled {
  color: #9ca3af;
  cursor: not-allowed;
  background: #f3f4f6;
}

</style>
