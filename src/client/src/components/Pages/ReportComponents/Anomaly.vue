<template>
  <div class="anomaly-root">
    <!-- Special Feature Filters -->
    <div class="filters">
      <label class="switch">
        <input type="checkbox" v-model="fltMortality" @change="refreshData" />
        <span>Mortality</span>
      </label>
      <label class="switch">
        <input type="checkbox" v-model="fltEntanglement" @change="refreshData" />
        <span>Entanglement</span>
      </label>
      <label class="switch">
        <input type="checkbox" v-model="fltCalf" @change="refreshData" />
        <span>Calf</span>
      </label>
    </div>

    <!-- Map container fills the ReportsPage card placeholder -->
    <div ref="map" class="mapbox-container"></div>
  </div>
</template>

<script>
import mapboxgl from "mapbox-gl";
import * as d3 from "d3";

export default {
  name: "Anomaly",

  data() {
    return {
      map: null,
      sourceId: "anomaly-src",
      layerId: "anomaly-layer",
      rows: [],            // normalized + flagged sightings
      localLatestYear: null,

      // UI filter toggles (OR logic across selected categories)
      fltMortality: false,
      fltEntanglement: false,
      fltCalf: false,

      // keyword sets (edit here if needed)
      anomalyKeywords: {
        mortality: ["dead", "carcass", "deceased", "stranded"],
        entanglement: ["entangled", "net", "rope", "hooked"],
        calf: ["calf", "juvenile", "baby"],
      },

      hoverPopup: null,   // reused Mapbox popup for hover  (renamed)
    };
  },

  computed: {
    // Mapbox token (same pattern as LastSightingMap.vue)
    mapboxKey() {
      return process.env.VUE_APP_MAPBOX_KEY;
    },

    // CSV path
    csvUrl() {
      const base = (process.env.BASE_URL || "/").replace(/\/$/, "/");
      return base + "data/acartia-export.csv";
    },

    // Global year from ReportsPage
    selectedYearNum() {
      const y = this.$store?.state?.selectedYear;
      return y ? +y : NaN;
    },
  },

  async mounted() {
    mapboxgl.accessToken = this.mapboxKey;

    await this.loadCsv();

    if (!this.$store.state.selectedYear && this.localLatestYear != null) {
      this.$store.commit("setSelectedYear", String(this.localLatestYear));
    }

    this.initMap();

    this.$watch(() => this.$store?.state?.selectedYear, () => this.refreshData());
    window.addEventListener("resize", this.handleResize);
  },

  beforeDestroy() {
    window.removeEventListener("resize", this.handleResize);
    if (this.hoverPopup) this.hoverPopup.remove();
    if (this.map) this.map.remove();
  },

  methods: {
    // -------- CSV loading & flagging (based on data_source_comments) ---------------
    async loadCsv() {
      const raw = await d3.csv(this.csvUrl);

      const rows = raw.map((d) => {
        // date
        const rawDate =
          d.created || d.created_at || d.date || d.timestamp || d.time || d.observed_at;
        let date = null;
        if (rawDate != null) {
          const n = Number(rawDate);
          if (!isNaN(n)) date = new Date(n > 1e12 ? n : n * 1000);
          else {
            const t = Date.parse(rawDate);
            if (!isNaN(t)) date = new Date(t);
          }
        }

        // coords
        const lat = Number(d.latitude ?? d.lat ?? d.Latitude);
        const lon = Number(d.longitude ?? d.lon ?? d.Longitude);

        // fields for tooltip
        const species = (d.type ?? d.species ?? d.Species ?? "").toString().trim();
        const source = (d.data_source_witness ?? d.source ?? d.Source ?? "").toString().trim();
        const comment = (d.data_source_comments ?? d.comments ?? d.comment ?? "").toString();

        // derive flags strictly from comments (per your spec)
        const { mortality, entanglement, calf } = this._flagsFromComment(comment);

        return {
          date,
          lat: +lat,
          lon: +lon,
          species,
          source,
          comment,
          mortality,
          entanglement,
          calf,
        };
      });

      // keep only valid points on Earth
      const cleaned = rows.filter(
        (r) =>
          r.date instanceof Date &&
          !isNaN(+r.date) &&
          isFinite(r.lat) &&
          isFinite(r.lon) &&
          Math.abs(r.lat) <= 90 &&
          Math.abs(r.lon) <= 180
      );

      // keep only anomalies (must match at least one category by comment)
      this.rows = cleaned.filter((r) => r.mortality || r.entanglement || r.calf);

      // track latest year to seed global year if needed
      const years = Array.from(new Set(this.rows.map((r) => r.date.getFullYear()))).sort(
        (a, b) => a - b
      );
      this.localLatestYear = years.length ? years[years.length - 1] : null;
    },

    _flagsFromComment(comment) {
      const c = (comment || "").toString().toLowerCase();

      const mortality = this.anomalyKeywords.mortality.some((k) => c.includes(k));
      const entanglement = this.anomalyKeywords.entanglement.some((k) => c.includes(k));
      const calf = this.anomalyKeywords.calf.some((k) => c.includes(k));

      return { mortality, entanglement, calf };
    },

    // ---------------------------- Map --------------------------------------------
    initMap() {
      if (!this.mapboxKey) {
        console.error("[Anomaly] Missing Mapbox key (VUE_APP_MAPBOX_KEY).");
      }

      this.map = new mapboxgl.Map({
        container: this.$refs.map,
        style: "mapbox://styles/mapbox/light-v11",
        center: [0, 0],  // will fit to data
        zoom: 2,
      });

      this.map.addControl(new mapboxgl.NavigationControl({ showCompass: false }), "top-right");

      this.map.on("load", () => {
        this.map.addSource(this.sourceId, {
          type: "geojson",
          data: { type: "FeatureCollection", features: [] },
        });

        this.map.addLayer({
          id: this.layerId,
          type: "circle",
          source: this.sourceId,
          paint: {
            "circle-radius": [
              "interpolate",
              ["linear"],
              ["zoom"],
              3, 2,
              6, 4,
              9, 6,
              12, 8
            ],
            // priority color: mortality > entanglement > calf > default
            "circle-color": [
              "case",
              ["get", "mortality"], "#ba0b0b",     // red
              ["get", "entanglement"], "#d9ae14",  // yellow
              ["get", "calf"], "#098de6",          // green
              "#000000"                            // black (shouldn’t happen; all are anomalies)
            ],
            "circle-opacity": 0.70,
            "circle-stroke-width": 0.80,
            "circle-stroke-color": "#ffffff",
          },
        });

        // hover tooltip
        this.hoverPopup = new mapboxgl.Popup({
          closeButton: false,
          closeOnClick: false,
          offset: 10,
          className: "anomaly-popup",
        });

        this.map.on("mouseenter", this.layerId, () => {
          this.map.getCanvas().style.cursor = "pointer";
        });
        this.map.on("mouseleave", this.layerId, () => {
          this.map.getCanvas().style.cursor = "";
          if (this.hoverPopup) this.hoverPopup.remove();
        });
        this.map.on("mousemove", this.layerId, (e) => {
          const f = e.features && e.features[0];
          if (!f) return;
          const { species, date, source, comment } = f.properties || {};
          const dt = date ? new Date(date) : null;
          const coords = f.geometry?.coordinates || e.lngLat?.toArray?.() || [0,0];
          const [lon, lat] = coords;

          const html = `
            <div style="font-size:12px; line-height:1.35; max-width:260px;">
              <div><strong>${species || "Unknown"}</strong></div>
              ${dt ? `<div>${dt.toLocaleString()}</div>` : ""}
              <div>Location: ${(+lat).toFixed(5)}, ${(+lon).toFixed(5)}</div>
              ${source ? `<div>Source: ${this._escape(source)}</div>` : ""}
              ${comment ? `<hr style="margin:6px 0; border-top:1px solid #e5e7eb;"><div>${this._escape(comment)}</div>` : ""}
            </div>
          `;

          this.hoverPopup
            .setLngLat(e.lngLat)
            .setHTML(html)
            .addTo(this.map);
        });

        this.refreshData();
      });
    },

    refreshData() {
      if (!this.map || !this.map.getSource(this.sourceId)) return;

      const year = this.selectedYearNum || this.localLatestYear;
      if (!year) {
        this.map.getSource(this.sourceId).setData({ type: "FeatureCollection", features: [] });
        return;
      }

      // OR logic across toggles: if none selected -> show all anomalies; else show matching any selected
      const anyToggle = this.fltMortality || this.fltEntanglement || this.fltCalf;

      const filtered = this.rows.filter((r) => {
        if (r.date.getFullYear() !== year) return false;
        if (!anyToggle) return true; // show all anomaly points if no toggle selected
        return (
          (this.fltMortality && r.mortality) ||
          (this.fltEntanglement && r.entanglement) ||
          (this.fltCalf && r.calf)
        );
      });

      const features = filtered.map((r) => ({
        type: "Feature",
        geometry: { type: "Point", coordinates: [r.lon, r.lat] },
        properties: {
          species: r.species || "Unknown",
          source: r.source || "",
          comment: r.comment || "",
          date: r.date.toISOString(),
          mortality: !!r.mortality,
          entanglement: !!r.entanglement,
          calf: !!r.calf,
        },
      }));

      const fc = { type: "FeatureCollection", features };
      this.map.getSource(this.sourceId).setData(fc);

      if (features.length) {
        const bounds = new mapboxgl.LngLatBounds();
        features.forEach((f) => bounds.extend(f.geometry.coordinates));
        const valid = isFinite(bounds._ne?.lng) && isFinite(bounds._sw?.lng);
        if (valid) this.map.fitBounds(bounds, { padding: 24, duration: 600, maxZoom: 9 });
      }
    },

    handleResize() {
      if (this.map) this.map.resize();
    },

    _escape(s) {
      // simple HTML escape for tooltip content
      return String(s)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;");
    },
  },
};
</script>

<style scoped>
.anomaly-root {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 0;
  height: 100%;
}

.mapbox-container {
  position: relative;
  width: 100%;
  height: 100%;
  min-height: 240px; /* ensure visibility on small screens */
  border-radius: 10px;
}

/* Compact overlay filter panel (top-left) */
.filters {
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

/* Mapbox default controls spacing */
.mapboxgl-ctrl-top-right {
  margin: 8px;
}
</style>
