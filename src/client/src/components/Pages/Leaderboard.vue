<template>
  <div class="leaderboard-container">
    <h1 class="page-title">🌊 Marine Life Leaderboards</h1>
    <p class="subtitle">
      Updated daily — celebrate our top contributors and species discoveries!
    </p>

    <!-- Loading state -->
    <div v-if="loading" class="loading-message">
      <p>Loading leaderboard data... 🌊</p>
    </div>

    <div v-else>
      <!-- Year toggle -->
      <div class="year-toggle">
        <button
          :class="{ active: selectedYear === 2025 }"
          @click="setYear(2025)"
        >
          2025
        </button>
        <button
          :class="{ active: selectedYear === 2024 }"
          @click="setYear(2024)"
        >
          2024
        </button>
      </div>

      <!-- Leaderboard cards -->
      <div class="leaderboard-grid">
        <!-- Most Sightings -->
        <div class="leaderboard-card">
          <h2>Most Sightings in {{ selectedYear }}</h2>
          <ol>
            <li v-for="(entry, index) in topSightings" :key="entry.name">
              <div class="rank">{{ index + 1 }}.</div>
              <img :src="entry.avatar" alt="Avatar" class="avatar" />
              <div class="info">
                <span class="username">{{ entry.name }}</span>
                <span class="count">{{ entry.sightings.toLocaleString() }} sightings</span>
              </div>
            </li>
          </ol>
          <small class="footnote">Total recorded sightings this year.</small>
        </div>

        <!-- Most Species -->
        <div class="leaderboard-card">
          <h2>Most Species in {{ selectedYear }}</h2>
          <ol>
            <li v-for="(entry, index) in topSpecies" :key="entry.name">
              <div class="rank">{{ index + 1 }}.</div>
              <img :src="entry.avatar" alt="Avatar" class="avatar" />
              <div class="info">
                <span class="username">{{ entry.name }}</span>
                <span class="count">{{ entry.species.toLocaleString() }} species</span>
              </div>
            </li>
          </ol>
          <small class="footnote">Unique species identified this year.</small>
        </div>

        <!-- Most Verified -->
        <div class="leaderboard-card">
          <h2>Most Verified Sightings in {{ selectedYear }}</h2>
          <ol>
            <li v-for="(entry, index) in topVerified" :key="entry.name">
              <div class="rank">{{ index + 1 }}.</div>
              <img :src="entry.avatar" alt="Avatar" class="avatar" />
              <div class="info">
                <span class="username">{{ entry.name }}</span>
                <span class="count">{{ entry.verified.toLocaleString() }} verifications</span>
              </div>
            </li>
          </ol>
          <small class="footnote">Sightings confirmed by experts.</small>
        </div>
      </div>

      <!-- Highlights section -->
      <div class="yearly-section">
        <h2>🏆 Highlights of {{ selectedYear }}</h2>
        <div class="highlight-card">
          <p>📅 <strong>Busiest Month:</strong> {{ busiestMonth.name }} — {{ busiestMonth.sightings.toLocaleString() }} sightings logged.</p>
          <p>🔎 <strong>Top Verifier:</strong> {{ topVerifier.name }} — {{ topVerifier.verified.toLocaleString() }} verifications.</p>
          <p>🌿 <strong>Most Biodiverse Contributor:</strong> {{ topBiodiversity.name }} — {{ topBiodiversity.species.toLocaleString() }} species observed.</p>

          <p class="story">
            {{ seasonStory }}
          </p>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import Papa from "papaparse";

export default {
  name: "Leaderboard",
  data() {
    return {
      users: [],
      selectedYear: 2025,
      loading: true,
    };
  },
  computed: {
    filteredUsers() {
      return this.users.filter(
        (u) => u.date && u.date.getFullYear() === this.selectedYear
      );
    },
    topSightings() {
      return [...this.filteredUsers]
        .sort((a, b) => b.sightings - a.sightings)
        .slice(0, 5);
    },
    topSpecies() {
      return [...this.filteredUsers]
        .sort((a, b) => b.species - a.species)
        .slice(0, 5);
    },
    topVerified() {
      return [...this.filteredUsers]
        .sort((a, b) => b.verified - a.verified)
        .slice(0, 5);
    },
    busiestMonth() {
      const byMonth = {};
      this.filteredUsers.forEach((u) => {
        const month = u.date.getMonth();
        if (!byMonth[month]) byMonth[month] = 0;
        byMonth[month] += u.sightings;
      });
      const bestMonth = Object.entries(byMonth).sort((a, b) => b[1] - a[1])[0];
      const monthNames = [
        "January","February","March","April","May","June",
        "July","August","September","October","November","December"
      ];
      return bestMonth
        ? { name: monthNames[bestMonth[0]], sightings: bestMonth[1] }
        : { name: "N/A", sightings: 0 };
    },
    topVerifier() {
      const sorted = [...this.filteredUsers].sort((a, b) => b.verified - a.verified);
      return sorted[0] || { name: "N/A", verified: 0 };
    },
    topBiodiversity() {
      const sorted = [...this.filteredUsers].sort((a, b) => b.species - a.species);
      return sorted[0] || { name: "N/A", species: 0 };
    },
    seasonStory() {
      if (this.selectedYear === 2025)
        return "2025 saw record sightings across the southern reefs — particularly in March, where plankton blooms brought in hundreds of whale sharks. Community verifiers worked overtime confirming over 50,000 sightings — truly the 'Year of the Giants'.";
      if (this.selectedYear === 2024)
        return "2024 was dubbed 'The Coral Recovery Year' — steady regrowth in northern regions led to a surge in biodiversity, and species counts climbed 20% from the previous year. Volunteers from all coasts contributed to over 150,000 logged observations.";
      return "Each year tells a new story beneath the waves...";
    },
  },
  methods: {
    setYear(year) {
      this.selectedYear = year;
    },
  },
  mounted() {
    Papa.parse("leaderboard.csv", {
      download: true,
      header: true,
      complete: (results) => {
        this.users = results.data.map((row) => ({
          name: row.name || "Unknown",
          sightings: +row.sightings || 0,
          species: +row.species || 0,
          verified: +row.verified || 0,
          avatar: row.avatar || "https://i.pravatar.cc/100?u=" + row.name,
          date: row.date ? new Date(row.date) : null,
        }));
        this.loading = false;
      },
    });
  },
};
</script>

<style scoped>
.leaderboard-container {
  background-color: #e6f7f9;
  color: #00585d;
  font-family: "Mukta", sans-serif;
  padding: 2rem;
  min-height: 100vh;
}

.page-title {
  font-size: 2rem;
  font-weight: 700;
  text-align: center;
  margin-bottom: 0.25rem;
}

.subtitle {
  text-align: center;
  margin-bottom: 2rem;
  font-size: 1.1rem;
  color: #00777d;
}

.year-toggle {
  display: flex;
  justify-content: center;
  gap: 1rem;
  margin-bottom: 2rem;
}

.year-toggle button {
  background: #ffffff;
  color: #00585d;
  border: 2px solid #00afba;
  padding: 0.5rem 1.25rem;
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.2s ease-in-out;
  font-weight: 600;
}

.year-toggle button.active {
  background: #00afba;
  color: #0c0826;
}

.year-toggle button:hover {
  background: #00afba;
  color: #0c0826;
}

.leaderboard-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 1.5rem;
}

.leaderboard-card {
  background: #ffffff;
  border-radius: 14px;
  box-shadow: 0 2px 6px rgba(0, 88, 93, 0.2);
  padding: 1.25rem;
}

.leaderboard-card h2 {
  font-weight: 700;
  color: #00585d;
  margin-bottom: 1rem;
}

ol {
  list-style: none;
  padding: 0;
  margin: 0;
}

li {
  display: flex;
  align-items: center;
  padding: 0.6rem 0;
  border-bottom: 1px solid #e1f0f2;
}

.rank {
  font-weight: bold;
  width: 2rem;
}

.avatar {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  margin-right: 0.75rem;
}

.info {
  display: flex;
  flex-direction: column;
}

.username {
  font-weight: 600;
  color: #004049;
}

.count {
  font-size: 0.9rem;
  color: #00777d;
}

.footnote {
  display: block;
  text-align: center;
  font-size: 0.85rem;
  color: #00585d;
  margin-top: 0.75rem;
}

.yearly-section {
  margin-top: 3rem;
  text-align: center;
}

.highlight-card {
  background: #ffffff;
  border-radius: 16px;
  box-shadow: 0 4px 10px rgba(0, 88, 93, 0.15);
  padding: 1.5rem;
  margin: 0 auto;
  max-width: 700px;
}

.highlight-card p {
  font-size: 1.05rem;
  color: #00585d;
  margin: 0.5rem 0;
}

.highlight-card .story {
  margin-top: 1rem;
  font-style: italic;
  color: #004049;
}

.loading-message {
  text-align: center;
  font-size: 1.2rem;
  color: #00777d;
  padding: 2rem;
}
</style>
