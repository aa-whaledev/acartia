<template>
<div class="manage-users-container">
    <div class="page-container">
        <h1 class="page-title">Manage Users</h1>
        <!-- User Requests Section -->
        <div class="user-list">
            <h2>User Requests</h2>
            <table class="user-requests-table">
                <thead>
                    <tr>
                        <th>Name</th>
                        <th>Email</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                    <tr v-for="user in userRequests" :key="user.id">
                        <td>{{ user.name }}</td>
                        <td>{{ user.email }}</td>
                        <td>
                            <div class="user-actions">
                                <button class="approve-btn" @click="approveUser(user.id)">Approve</button>
                                <button class="deny-btn" @click="denyUser(user.id)">Deny</button>
                            </div>
                        </td>
                    </tr>
                </tbody>
            </table>
        </div>
        <!-- Current Users Role Totals -->
        <div class="role-totals-section">
            <h2>Current User Roles</h2>
            <table class="role-totals-table">
                <thead>
                    <tr>
                        <th v-for="role in Object.keys(roleTotals)" :key="role">{{ role }}</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td v-for="role in Object.keys(roleTotals)" :key="role + '-count'">{{ roleTotals[role] }}</td>
                    </tr>
                </tbody>
            </table>
        </div>
        <!-- Current Users Section -->
        <div class="current-users-section">
            <h2>Current Users</h2>
            <button class="export-btn" @click="exportUsersToCSV">Export All Users to CSV</button>
            <table class="current-users-table">
                <thead>
                    <tr>
                        <th>Name</th>
                        <th>Email</th>
                        <th>Role</th>
                        <th>Last Login</th>
                        <th>Contributions</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                    <tr v-for="user in currentUsers" :key="user.id">
                        <td>{{ user.name }}</td>
                        <td>{{ user.email }}</td>
                        <td>{{ user.role }}</td>
                        <td>{{ user.lastLogin }}</td>
                        <td>{{ user.contributions }}</td>
                        <td>
                            <button v-if="user.role !== 'Admin'" class="promote-btn" @click="promoteToAdmin(user.id)">Promote to Admin</button>
                        </td>
                    </tr>
                </tbody>
            </table>
        </div>
    </div>
</div>
</template>

<script>
export default {
    name: 'ManageUsers',
    //mock user data - replace with actual data fetching logic
    data() {
        return {
            userRequests: [
                { id: 1, name: 'Alice Smith', email: 'alice.smith@email.com' },
                { id: 2, name: 'Bob Johnson', email: 'bob.johnson@email.com' },
                { id: 3, name: 'Charlie Lee', email: 'charlie.lee@email.com' },
            ],
            currentUsers: [
                { id: 101, name: 'Dana White', email: 'dana.white@email.com', role: 'Admin', lastLogin: '2025-09-12 14:23', contributions: 12 },
                { id: 102, name: 'Eli Brown', email: 'eli.brown@email.com', role: 'User', lastLogin: '2025-09-13 09:10', contributions: 5 },
                { id: 103, name: 'Sam Green', email: 'sam.green@email.com', role: 'User', lastLogin: '2025-09-11 18:45', contributions: 8 },
                { id: 104, name: 'Priya Patel', email: 'priya.patel@email.com', role: 'User', lastLogin: '2025-09-13 12:30', contributions: 3 },
                { id: 105, name: 'Liam Chen', email: 'liam.chen@email.com', role: 'User', lastLogin: '2025-09-12 20:05', contributions: 15 },
                { id: 106, name: 'Maria Garcia', email: 'maria.garcia@email.com', role: 'User', lastLogin: '2025-09-13 08:55', contributions: 7 },
            ]
        };
    },
    computed: {
        roleTotals() {
            // Count users by role
            const totals = {};
            this.currentUsers.forEach(user => {
                totals[user.role] = (totals[user.role] || 0) + 1;
            });
            return totals;
        }
    },
    methods: {
        approveUser(id) {
            // Find the user in userRequests
            const user = this.userRequests.find(user => user.id === id);
            if (user) {
                // Add to currentUsers with default properties as mock data is being used
                this.currentUsers.push({
                    id: user.id,
                    name: user.name,
                    email: user.email,
                    role: 'User',
                    lastLogin: '-',
                    contributions: 0
                });
            }
            // Remove from userRequests
            this.userRequests = this.userRequests.filter(user => user.id !== id);
        },
        denyUser(id) {
            // Implement deny logic here, are users notified? For now, just remove from requests
            this.userRequests = this.userRequests.filter(user => user.id !== id);
        },
        exportUsersToCSV() {
            const users = this.currentUsers;
            const headers = ['Name', 'Email', 'Role', 'Last Login', 'Contributions'];
            const rows = users.map(user => [user.name, user.email, user.role, user.lastLogin, user.contributions]);
            let csvContent = '';
            csvContent += headers.join(',') + '\n';
            rows.forEach(row => {
                csvContent += row.map(field => `"${String(field).replace(/"/g, '""')}"`).join(',') + '\n';
            });
            const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
            const link = document.createElement('a');
            link.href = URL.createObjectURL(blob);
            link.setAttribute('download', 'users.csv');
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
        },
        promoteToAdmin(id) {
            this.currentUsers = this.currentUsers.map(user =>
                user.id === id ? { ...user, role: 'Admin' } : user
            );
        },
    },
};
</script>

<style scoped>
.promote-btn {
    background: #bdbdbd;
    color: #fff;
    border: none;
    padding: 0.5rem 1.5rem;
    border-radius: 4px;
    font-size: 1rem;
    cursor: pointer;
    font-weight: 500;
    margin-left: 0.5rem;
}
.promote-btn:hover {
    background: #757575;
}
.page-container {
    font-family: 'Montserrat', sans-serif;
    color: #545F71;
    max-width: 1440px;
    margin: 0 auto;
    padding: 48px 32px 32px 32px;
}
.manage-users-container {
    font-family: 'Montserrat', sans-serif;
    color: #545F71;
    max-width: 1440px;
    margin: 0 auto;
    padding: 0;
}
.page-title {
        font-family: 'Mukta', sans-serif;
        font-size: 44px;
        font-weight: 600;
        margin-bottom: 2.5rem;
        margin-top: 0;
}
.user-list {
    display: flex;
    flex-direction: column;
    gap: 1rem;
}
.user-item {
    display: flex;
    align-items: center;
    justify-content: space-between;
    background: #f8f8f8;
    padding: 1rem;
    border-radius: 8px;
}
.user-actions {
    margin-left: auto;
    display: flex;
    gap: 0.5rem;
}
.user-name {
    font-weight: 500;
}
.user-requests-table {
    width: 100%;
    border-collapse: collapse;
    margin-bottom: 2rem;
}
.user-requests-table th, .user-requests-table td {
    border: 1px solid #ddd;
    padding: 0.75rem;
    text-align: left;
}
.user-requests-table th {
    background: #e6f7f9;
    font-weight: 600;
}
.user-requests-table tr:nth-child(even) {
    background: #f8f8f8;
}
.user-email {
    font-size: 0.95rem;
    color: #555;
    margin-left: 1rem;
}
.approve-btn {
    background: #4caf50;
    color: white;
    border: none;
    padding: 0.5rem 1rem;
    margin-right: 0.5rem;
    border-radius: 4px;
    cursor: pointer;
}
.deny-btn {
    background: #f44336;
    color: white;
    border: none;
    padding: 0.5rem 1rem;
    border-radius: 4px;
    cursor: pointer;
}
.approve-btn:hover {
    background: #388e3c;
}
.deny-btn:hover {
    background: #d32f2f;
}

.current-users-section {
    margin-top: 2.5rem;
}
.export-btn {
    margin-bottom: 1rem;
    background: #00afba;
    color: #fff;
    border: none;
    padding: 0.5rem 1.5rem;
    border-radius: 4px;
    font-size: 1rem;
    cursor: pointer;
    font-weight: 500;
}
.export-btn:hover {
    background: #00979d;
}
.role-totals-section {
    margin-bottom: 1.5rem;
}

.role-totals-table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 0.5rem;
    margin-bottom: 1rem;
}
.role-totals-table th, .role-totals-table td {
    border: 1px solid #ddd;
    padding: 0.75rem;
    text-align: center;
}
.role-totals-table th {
    background: #e6f7f9;
    font-weight: 600;
}
.role-totals-table td {
    background: #f8f8f8;
    font-weight: 500;
}
.current-users-table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 1rem;
}
.current-users-table th, .current-users-table td {
    border: 1px solid #ddd;
    padding: 0.75rem;
    text-align: left;
}
.current-users-table th {
    background: #e6f7f9;
    font-weight: 600;
}
.current-users-table tr:nth-child(even) {
    background: #f8f8f8;
}
</style>