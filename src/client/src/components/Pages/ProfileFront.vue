<template>
  <div class="profile-page">
    <div class="profile-container">
      <!-- Profile Header -->
      <div class="profile-header">
        <div class="profile-picture">
          <img :src="profilePicturePreview" alt="Profile Picture" />
          <input
            type="file"
            accept="image/*"
            @change="onFileChange"
            class="file-input"
          />
        </div>
        <div class="profile-info">
          <input v-model="editableUser.name" type="text" placeholder="Name" disabled  />
          <input v-model="editableUser.position" type="text" placeholder="Position" disabled  />
        </div>
      </div>

      <!-- Profile Details -->
      <div class="profile-details">
        <h2>Profile Info</h2>
        <div class="info-block">
          <label>Name:</label>
          <input v-model="editableUser.name" type="text" />
        </div>
        <div class="info-block">
          <label>Email:</label>
          <input v-model="editableUser.email" type="email" />
        </div>
        <div class="info-block">
          <label>Role:</label>
          <input v-model="editableUser.role" type="text" />
        </div>
        <div class="info-block">
          <label>Position:</label>
          <input v-model="editableUser.position" type="text" />
        </div>
      </div>

      <!-- Save Button -->
      <div class="save-section">
        <button @click="saveProfile">Save Profile</button>
      </div>

      <!-- Contributions / Stats -->
      <div class="profile-contributions">
        <h2>Contributions</h2>
        <table>
          <thead>
            <tr>
              <th>Project</th>
              <th>Contribution</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(item, index) in contributions" :key="index">
              <td>{{ item.project }}</td>
              <td>{{ item.amount }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: "ProfileFront",
  data() {
    return {
      userDetails: {
        name: "William",
        email: "william@gmail.com",
        role: "Admin",
        position: "Marine Biologist"
      },
      editableUser: {
        name: "William",
        email: "william@gmail.com",
        role: "Admin",
        position: "Marine Biologist"
      },
      profilePicture: require("@/assets/default-profile.jpg"),
      profilePicturePreview: require("@/assets/default-profile.jpg"),
      contributions: [
        { project: "Blue Whale Sightings", amount: 23 },
        { project: "Fin Whale Sightings", amount: 15 },
        { project: "Harbor Whale Sightings", amount: 8 },
      ],
    };
  },
  methods: {
    onFileChange(e) {
      const file = e.target.files[0];
      if (file) {
        this.profilePicture = file;
        this.profilePicturePreview = URL.createObjectURL(file);
      }
    },
    saveProfile() {
      this.userDetails = { ...this.editableUser };
      alert("Profile saved successfully ✅");
    },
  },
};
</script>

<style scoped>
.profile-page {
  display: flex;
  justify-content: center;
  align-items: flex-start;
  background-color: #f5f7fa;
  min-height: 100vh;
  padding: 2rem;
  font-family: "Montserrat", sans-serif;
  color: #3d3951;
}

.profile-container {
  background: #fff;
  border-radius: 12px;
  padding: 2rem;
  max-width: 600px;
  width: 100%;
  box-shadow: 0px 4px 12px rgba(0,0,0,0.05);
}

/* Header */
.profile-header {
  display: flex;
  align-items: center;
  gap: 1.5rem;
  margin-bottom: 2rem;
}

.profile-picture {
  position: relative;
}

.profile-picture img {
  width: 100px;
  height: 100px;
  border-radius: 50%;
  border: 3px solid #3d3951;
  object-fit: cover;
}

.file-input {
  position: absolute;
  bottom: -5px;
  left: 0;
  width: 100%;
  opacity: 0;
  cursor: pointer;
  height: 100%;
}

.profile-info input {
  display: block;
  margin-bottom: 0.5rem;
  padding: 0.5rem;
  width: 200px;
  border: 1px solid #eef1f4;
  border-radius: 6px;
  font-size: 1rem;
}

/* Profile details */
.profile-details {
  margin-bottom: 2rem;
}

.profile-details h2 {
  font-size: 1.2rem;
  font-weight: 600;
  margin-bottom: 1rem;
  color: #3d3951;
}

.info-block {
  background: #fafafa;
  padding: 0.75rem 1rem;
  border-radius: 8px;
  margin-bottom: 0.5rem;
  border: 1px solid #eef1f4;
}

.info-block label {
  display: block;
  font-weight: 600;
  margin-bottom: 0.25rem;
}

.info-block input {
  width: 100%;
  padding: 0.5rem;
  border: 1px solid #eef1f4;
  border-radius: 6px;
  font-size: 1rem;
}

/* Save Button */
.save-section {
  text-align: right;
  margin-bottom: 2rem;
}

.save-section button {
  background-color: #3d3951;
  color: #fff;
  padding: 0.7rem 1.5rem;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  font-size: 1rem;
  transition: background 0.2s;
}

.save-section button:hover {
  background-color: #2a2736;
}

/* Contributions Table */
.profile-contributions h2 {
  font-size: 1.2rem;
  font-weight: 600;
  margin-bottom: 1rem;
  color: #3d3951;
}

.profile-contributions table {
  width: 100%;
  border-collapse: collapse;
  border-radius: 8px;
  overflow: hidden;
  border: 1px solid #eef1f4;
  background: #fff;
}

.profile-contributions th,
.profile-contributions td {
  padding: 0.75rem 1rem;
  border: 1px solid #eef1f4;
  text-align: left;
}

.profile-contributions th {
  background: #f9f9f9;
  font-weight: 600;
  color: #3d3951;
}

.profile-contributions tr:hover td {
  background: #eef1f4;
}
</style>
