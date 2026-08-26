/* ==========================================================================
   FUSION 360 - ENTERPRISE ADMIN WEB PORTAL CONTROLLER
   ========================================================================== */

(function () {
  'use strict';

  // Supabase Project Credentials (matching mobile app config)
  const SUPABASE_URL = 'https://agkuybibzrjqcxtlnlrm.supabase.co';
  const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFna3V5YmlienJqcWN4dGxubHJtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5Njc1OTgsImV4cCI6MjA5ODU0MzU5OH0.lmhZ8TIklkj7I9oSRawuitWvnsZ6jMaL-95raMVLNTA';

  // State Management
  let supabaseClient = null;
  let currentUser = null;
  let employeesData = [];
  let officesData = [];
  let sitesData = [];
  let attendanceData = [];
  let leafletMap = null;
  let mapMarkers = [];

  // DOM Cache
  const loginOverlay = document.getElementById('login-overlay');
  const loginForm = document.getElementById('login-form');
  const loginEmail = document.getElementById('login-email');
  const loginPassword = document.getElementById('login-password');
  const loginErrorAlert = document.getElementById('login-error-alert');

  const navItems = document.querySelectorAll('.nav-item');
  const tabPanes = document.querySelectorAll('.tab-pane');
  const activePageTitle = document.getElementById('active-page-title');

  const employeeTableBody = document.getElementById('employee-table-body');
  const employeeSearchInput = document.getElementById('employee-search-input');
  const officeTableBody = document.getElementById('office-table-body');
  const siteTableBody = document.getElementById('site-table-body');
  const reportsTableBody = document.getElementById('reports-table-body');

  const drawerBackdrop = document.getElementById('employee-drawer-backdrop');
  const drawer = document.getElementById('employee-drawer');
  const employeeForm = document.getElementById('employee-form');
  
  const transferModalBackdrop = document.getElementById('transfer-modal-backdrop');
  const transferModal = document.getElementById('transfer-modal');
  const transferTargetSelect = document.getElementById('transfer-target-select');

  // Initialize App
  document.addEventListener('DOMContentLoaded', () => {
    initSupabase();
    setupEventListeners();
  });

  function initSupabase() {
    if (window.supabase) {
      supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
      console.log('Supabase initialized in Web Admin Application.');
      checkExistingSession();
    } else {
      showLoginError('Supabase SDK failed to load. Check network connection.');
    }
  }

  async function checkExistingSession() {
    const savedUserJson = localStorage.getItem('f360_admin_session');
    if (savedUserJson) {
      try {
        const user = JSON.parse(savedUserJson);
        if (user && (user.role === 'SUPER_ADMIN' || user.role === 'ADMIN')) {
          onLoginSuccess(user);
          return;
        }
      } catch (e) {
        localStorage.removeItem('f360_admin_session');
      }
    }
    // Show login overlay
    loginOverlay.style.display = 'flex';
  }

  function setupEventListeners() {
    // Login Submission
    loginForm.addEventListener('submit', async (e) => {
      e.preventDefault();
      const email = loginEmail.value.trim();
      const password = loginPassword.value.trim();

      if (!email || !password) return;
      hideLoginError();

      try {
        // Query users table for admin authentication
        const { data: user, error } = await supabaseClient
          .from('users')
          .select('*')
          .eq('email', email.toLowerCase())
          .eq('is_deleted', false)
          .maybeSingle();

        if (error) throw error;

        if (!user) {
          showLoginError('Invalid credentials. No administrative account found.');
          return;
        }

        if (user.role !== 'SUPER_ADMIN' && user.role !== 'ADMIN') {
          showLoginError('Access denied: Account lacks administrative privileges.');
          return;
        }

        if (!user.is_active) {
          showLoginError('Account disabled. Contact organization super admin.');
          return;
        }

        // Save session & login
        localStorage.setItem('f360_admin_session', JSON.stringify(user));
        onLoginSuccess(user);
      } catch (err) {
        console.error('Login error:', err);
        showLoginError('Authentication failed: ' + (err.message || 'Check database connection.'));
      }
    });

    // Logout Button
    document.getElementById('logout-btn').addEventListener('click', () => {
      localStorage.removeItem('f360_admin_session');
      currentUser = null;
      loginOverlay.style.display = 'flex';
    });

    // Theme Toggle
    document.getElementById('btn-theme-toggle').addEventListener('click', () => {
      const currentTheme = document.documentElement.getAttribute('data-theme');
      const newTheme = currentTheme === 'light' ? 'dark' : 'light';
      document.documentElement.setAttribute('data-theme', newTheme);
    });

    // Refresh Data Button
    document.getElementById('btn-refresh-data').addEventListener('click', () => {
      loadAllCloudData();
    });

    // Navigation Tabs Switcher
    navItems.forEach((item) => {
      item.addEventListener('click', () => {
        const targetTab = item.getAttribute('data-tab');
        switchTab(targetTab);
      });
    });

    // Search Filtering
    if (employeeSearchInput) {
      employeeSearchInput.addEventListener('input', () => renderEmployeeTable());
    }

    // Add Employee Drawer Trigger
    document.getElementById('btn-add-employee').addEventListener('click', () => {
      openEmployeeDrawer();
    });

    document.getElementById('drawer-close-btn').addEventListener('click', closeEmployeeDrawer);
    document.getElementById('drawer-cancel-btn').addEventListener('click', closeEmployeeDrawer);
    drawerBackdrop.addEventListener('click', closeEmployeeDrawer);

    // Save Employee Form Submission
    document.getElementById('drawer-save-btn').addEventListener('click', saveEmployee);

    // Export Buttons
    document.getElementById('btn-export-csv').addEventListener('click', exportReportsCSV);
    document.getElementById('btn-export-excel').addEventListener('click', exportReportsExcel);

    // Security Transfer Ownership Modal Triggers
    document.getElementById('btn-open-transfer-modal').addEventListener('click', openTransferModal);
    document.getElementById('transfer-modal-close').addEventListener('click', closeTransferModal);
    document.getElementById('transfer-cancel-btn').addEventListener('click', closeTransferModal);
    transferModalBackdrop.addEventListener('click', closeTransferModal);
    document.getElementById('transfer-confirm-btn').addEventListener('click', executeOwnershipTransfer);
  }

  function switchTab(tabId) {
    navItems.forEach(n => n.classList.remove('active'));
    tabPanes.forEach(p => p.classList.remove('active'));

    const selectedNav = document.querySelector(`.nav-item[data-tab="${tabId}"]`);
    const selectedPane = document.getElementById(`tab-${tabId}`);

    if (selectedNav) selectedNav.classList.add('active');
    if (selectedPane) selectedPane.classList.add('active');

    const titles = {
      overview: 'Executive Command Center',
      employees: 'Employee Directory & Roles',
      offices: 'Office Locations & Geofence Boundaries',
      sites: 'Client Work Sites',
      map: 'Live GPS Field Tracking',
      reports: 'Attendance Logs & Timesheets',
      security: 'Security & Governance'
    };

    activePageTitle.textContent = titles[tabId] || 'Admin Dashboard';

    if (tabId === 'map') {
      setTimeout(initMap, 200);
    }
  }

  function onLoginSuccess(user) {
    currentUser = user;
    loginOverlay.style.display = 'none';
    
    document.getElementById('user-display-name').textContent = user.full_name || 'Admin';
    document.getElementById('user-display-role').textContent = user.role || 'ADMIN';
    document.getElementById('user-avatar').textContent = (user.full_name || 'A').charAt(0).toUpperCase();

    loadAllCloudData();
  }

  async function loadAllCloudData() {
    if (!supabaseClient) return;

    try {
      // 1. Fetch Employees & Users
      const { data: users } = await supabaseClient.from('users').select('*').eq('is_deleted', false);
      const { data: emps } = await supabaseClient.from('employees').select('*').eq('is_deleted', false);

      employeesData = combineUserEmployeeRecords(users || [], emps || []);

      // 2. Fetch Offices
      const { data: offices } = await supabaseClient.from('offices').select('*').eq('is_deleted', false);
      officesData = offices || [];

      // 3. Fetch Work Sites
      const { data: sites } = await supabaseClient.from('work_sites').select('*').eq('is_deleted', false);
      sitesData = sites || [];

      // 4. Fetch Attendance Logs
      const { data: attendance } = await supabaseClient
        .from('attendance_records')
        .select('*')
        .order('event_timestamp', { ascending: false })
        .limit(200);
      attendanceData = attendance || [];

      // Update Views
      updateOverviewMetrics();
      renderEmployeeTable();
      renderOfficeTable();
      renderSiteTable();
      renderReportsTable();
      if (leafletMap) renderMapMarkers();

    } catch (e) {
      console.error('Error fetching cloud data:', e);
    }
  }

  function combineUserEmployeeRecords(users, employees) {
    return users.map(u => {
      const emp = employees.find(e => e.user_id === u.id) || {};
      return {
        id: u.id,
        name: u.full_name || 'Unknown',
        email: u.email || '',
        phone: u.phone_number || '',
        role: u.role || 'EMPLOYEE',
        isActive: u.is_active,
        employeeCode: emp.employee_code || `EMP-${u.id.substring(0, 4).toUpperCase()}`,
        designation: emp.designation || 'Staff',
        department: emp.department || 'Operations',
        assignedOfficeId: emp.assigned_office_id
      };
    });
  }

  function updateOverviewMetrics() {
    document.getElementById('metric-total-employees').textContent = employeesData.length;
    
    // Calculate checked in & on duty today
    const now = new Date();
    const todayStr = now.toISOString().split('T')[0];

    const todayRecords = attendanceData.filter(r => r.event_timestamp && r.event_timestamp.startsWith(todayStr));
    const checkedInEmpIds = new Set(todayRecords.map(r => r.employee_id));
    const completedEmpIds = new Set(
      todayRecords
        .filter(r => r.workflow_step === 'officeCheckOut' || r.workflow_step === 'completed')
        .map(r => r.employee_id)
    );

    document.getElementById('metric-checked-in-today').textContent = checkedInEmpIds.size;
    
    const onDutyCount = Math.max(0, checkedInEmpIds.size - completedEmpIds.size);
    document.getElementById('metric-on-duty').textContent = onDutyCount;
    document.getElementById('metric-offices-count').textContent = officesData.length;
  }

  function renderEmployeeTable() {
    if (!employeeTableBody) return;
    const query = (employeeSearchInput?.value || '').toLowerCase();

    const filtered = employeesData.filter(e => 
      e.name.toLowerCase().includes(query) || 
      e.employeeCode.toLowerCase().includes(query) || 
      e.email.toLowerCase().includes(query)
    );

    document.getElementById('employee-count-badge').textContent = `${filtered.length} Employees`;

    if (filtered.length === 0) {
      employeeTableBody.innerHTML = `<tr><td colspan="8" style="text-align: center; color: var(--text-muted); padding: 24px;">No matching employees found.</td></tr>`;
      return;
    }

    employeeTableBody.innerHTML = filtered.map(e => {
      const assignedOffice = officesData.find(o => o.id === e.assignedOfficeId);
      const officeDisplay = assignedOffice ? assignedOffice.name : 'Main HQ Office';

      return `
        <tr>
          <td><strong style="font-family: var(--font-mono);">${e.employeeCode}</strong></td>
          <td>${e.name}</td>
          <td>${e.email}<br><span style="font-size: 11px; color: var(--text-muted);">${e.phone || 'No phone'}</span></td>
          <td>${e.designation}</td>
          <td>${e.department}</td>
          <td>${officeDisplay}</td>
          <td>
            <span class="badge ${e.isActive ? 'badge-success' : 'badge-danger'}">
              <span class="badge-dot"></span>
              ${e.isActive ? 'Active' : 'Inactive'}
            </span>
            <span class="badge badge-neutral">
              ${e.role}
            </span>
          </td>
          <td style="text-align: right;">
            <button class="btn btn-secondary btn-sm" onclick="window.editEmployee('${e.id}')">Edit</button>
          </td>
        </tr>
      `;
    }).join('');
  }

  function renderOfficeTable() {
    if (!officeTableBody) return;
    document.getElementById('office-count-badge').textContent = `${officesData.length} Offices`;

    if (officesData.length === 0) {
      officeTableBody.innerHTML = `<tr><td colspan="5" style="text-align: center; color: var(--text-muted); padding: 24px;">No offices configured. Click Add Office Location to create one.</td></tr>`;
      return;
    }

    officeTableBody.innerHTML = officesData.map(o => `
      <tr>
        <td><strong>${o.name}</strong></td>
        <td>${o.address}</td>
        <td><span style="font-family: var(--font-mono);">${o.latitude.toFixed(6)}, ${o.longitude.toFixed(6)}</span></td>
        <td>${o.geofence_radius_meters}m</td>
        <td><span class="badge ${o.is_default ? 'badge-success' : 'badge-neutral'}">${o.is_default ? 'Default HQ' : 'Branch'}</span></td>
      </tr>
    `).join('');
  }

  function renderSiteTable() {
    if (!siteTableBody) return;
    document.getElementById('site-count-badge').textContent = `${sitesData.length} Sites`;

    if (sitesData.length === 0) {
      siteTableBody.innerHTML = `<tr><td colspan="5" style="text-align: center; color: var(--text-muted); padding: 24px;">No client work sites added.</td></tr>`;
      return;
    }

    siteTableBody.innerHTML = sitesData.map(s => `
      <tr>
        <td><strong>${s.site_name}</strong></td>
        <td>${s.client_name}</td>
        <td>${s.address}</td>
        <td><span style="font-family: var(--font-mono);">${s.latitude.toFixed(6)}, ${s.longitude.toFixed(6)}</span></td>
        <td>${s.radius_meters}m</td>
      </tr>
    `).join('');
  }

  function getLocationName(r) {
    if (!r) return 'HQ Office';

    let site = r.site_name || r.siteName;
    if (site && typeof site === 'string' && site.trim().length > 0) {
      return site.trim();
    }

    if (r.work_site_id || r.workSiteId) {
      const targetId = r.work_site_id || r.workSiteId;
      const foundSite = sitesData.find(s => s.id === targetId);
      if (foundSite && foundSite.site_name) {
        return foundSite.site_name;
      }
    }

    if (r.office_id || r.officeId) {
      const targetId = r.office_id || r.officeId;
      const foundOffice = officesData.find(o => o.id === targetId);
      if (foundOffice && foundOffice.name) {
        return foundOffice.name;
      }
    }

    if (r.address && typeof r.address === 'string' && r.address.trim().length > 0) {
      return r.address.trim();
    }

    return 'Main HQ Office';
  }

  function getPhotoSrc(record) {
    if (!record) return null;
    let photo = record.photo_url || record.photo_base64 || record.photo_data || record.photo_path || record.photo || record.photo_proof;
    if (!photo || typeof photo !== 'string' || photo.trim() === '') return null;
    photo = photo.trim();

    if (photo.startsWith('http://') || photo.startsWith('https://') || photo.startsWith('data:image/')) {
      return photo;
    }
    
    // Clean whitespace & newline characters from base64 string
    const cleanBase64 = photo.replace(/[\r\n\s]+/g, '');
    if (cleanBase64.length > 20) {
      return `data:image/jpeg;base64,${cleanBase64}`;
    }

    return photo;
  }

  function renderReportsTable() {
    if (!reportsTableBody) return;

    if (attendanceData.length === 0) {
      reportsTableBody.innerHTML = `<tr><td colspan="6" style="text-align: center; color: var(--text-tertiary); padding: 24px;">No attendance check-in records available.</td></tr>`;
      return;
    }

    reportsTableBody.innerHTML = attendanceData.map((r, index) => {
      const dateStr = new Date(r.event_timestamp).toLocaleString();
      const photoSrc = getPhotoSrc(r);
      const locationText = getLocationName(r);

      const photoCell = photoSrc ? `
        <div style="display: flex; align-items: center; gap: 8px;">
          <img src="${photoSrc}" alt="Selfie" onclick="window.openPhotoModal(${index})" style="width: 34px; height: 34px; border-radius: var(--radius-sm); object-fit: cover; border: 1px solid var(--border-subtle); cursor: pointer;" title="Click to enlarge photo">
          <button class="btn btn-secondary btn-sm" onclick="window.openPhotoModal(${index})">📷 View Photo</button>
        </div>
      ` : `<span class="badge badge-neutral">No Photo</span>`;

      return `
        <tr>
          <td><span style="font-family: var(--font-mono); font-size: 11px;">${dateStr}</span></td>
          <td><strong>${r.employee_name || 'Field Staff'}</strong></td>
          <td><span class="badge badge-neutral">${r.workflow_step || 'Check In'}</span></td>
          <td>
            <strong>${locationText}</strong>
            ${r.address && r.address !== locationText ? `<br><span style="font-size: 11px; color: var(--text-tertiary);">${r.address}</span>` : ''}
          </td>
          <td><span class="badge ${r.is_geofence_valid ? 'badge-success' : 'badge-danger'}"><span class="badge-dot"></span>${r.is_geofence_valid ? 'Valid Geofence' : 'Out of Geofence'}</span></td>
          <td>${photoCell}</td>
        </tr>
      `;
    }).join('');
  }

  function initMap() {
    if (leafletMap) return;
    const mapContainer = document.getElementById('leaflet-map');
    if (!mapContainer) return;

    // Default map coordinates: Business Bay Dubai HQ (24.3655, 54.5005) or first office
    const initialLat = officesData.length > 0 ? officesData[0].latitude : 24.3655;
    const initialLng = officesData.length > 0 ? officesData[0].longitude : 54.5005;

    leafletMap = L.map('leaflet-map').setView([initialLat, initialLng], 12);

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '© OpenStreetMap contributors'
    }).addTo(leafletMap);

    renderMapMarkers();
  }

  function renderMapMarkers() {
    if (!leafletMap) return;

    // Clear existing markers
    mapMarkers.forEach(m => leafletMap.removeLayer(m));
    mapMarkers = [];

    const staffListEl = document.getElementById('map-staff-list');
    if (staffListEl) staffListEl.innerHTML = '';

    // Render Office Circles
    officesData.forEach(o => {
      const circle = L.circle([o.latitude, o.longitude], {
        color: '#4f46e5',
        fillColor: '#4f46e5',
        fillOpacity: 0.12,
        radius: o.geofence_radius_meters || 200
      }).addTo(leafletMap);
      circle.bindPopup(`<b>${o.name} (HQ)</b><br>${o.address}`);
      mapMarkers.push(circle);
    });

    // Render Employee Check-in Pins
    attendanceData.forEach(r => {
      if (r.latitude && r.longitude) {
        const photoSrc = getPhotoSrc(r);
        const marker = L.marker([r.latitude, r.longitude]).addTo(leafletMap);
        marker.bindPopup(`
          <div style="font-family: var(--font-sans); min-width: 140px;">
            <strong style="color: #0f172a; font-size: 13px;">${r.employee_name || 'Staff'}</strong><br>
            <span style="font-size: 11px; color: #64748b;">${r.workflow_step} - ${new Date(r.event_timestamp).toLocaleTimeString()}</span><br>
            ${photoSrc ? `<img src="${photoSrc}" width="140" style="border-radius: 6px; margin-top: 6px; border: 1px solid #cbd5e1; max-height: 140px; object-fit: cover;">` : ''}
          </div>
        `);
        mapMarkers.push(marker);

        if (staffListEl) {
          const item = document.createElement('div');
          item.className = 'map-staff-card';
          item.innerHTML = `
            <div>
              <strong style="font-size: 12px;">${r.employee_name || 'Staff'}</strong>
              <div style="font-size: 11px; color: var(--text-tertiary);">${r.workflow_step}</div>
            </div>
            <span class="badge badge-success"><span class="badge-dot"></span>On Duty</span>
          `;
          item.addEventListener('click', () => {
            leafletMap.setView([r.latitude, r.longitude], 15);
            marker.openPopup();
          });
          staffListEl.appendChild(item);
        }
      }
    });
  }

  // Employee Edit Drawer Handlers
  window.editEmployee = function(empId) {
    const emp = employeesData.find(e => e.id === empId);
    if (!emp) return;

    document.getElementById('emp-id').value = emp.id;
    document.getElementById('emp-code').value = emp.employeeCode;
    document.getElementById('emp-name').value = emp.name;
    document.getElementById('emp-email').value = emp.email;
    document.getElementById('emp-phone').value = emp.phone;
    document.getElementById('emp-designation').value = emp.designation;
    document.getElementById('emp-department').value = emp.department;
    document.getElementById('emp-role').value = emp.role;

    document.getElementById('drawer-title').textContent = 'Edit Employee Details';
    openEmployeeDrawer();
  };

  function openEmployeeDrawer() {
    drawerBackdrop.classList.add('active');
    drawer.classList.add('active');
  }

  function closeEmployeeDrawer() {
    drawerBackdrop.classList.remove('active');
    drawer.classList.remove('active');
    employeeForm.reset();
    document.getElementById('emp-id').value = '';
  }

  async function saveEmployee() {
    const empId = document.getElementById('emp-id').value;
    const empCode = document.getElementById('emp-code').value.trim();
    const name = document.getElementById('emp-name').value.trim();
    const email = document.getElementById('emp-email').value.trim();
    const phone = document.getElementById('emp-phone').value.trim();
    const designation = document.getElementById('emp-designation').value.trim();
    const department = document.getElementById('emp-department').value.trim();
    const role = document.getElementById('emp-role').value;

    if (!empCode || !name || !email) {
      alert('Please fill in all required fields.');
      return;
    }

    try {
      if (empId) {
        // Update user
        await supabaseClient.from('users').update({
          full_name: name,
          phone_number: phone,
          role: role,
          updated_at: new Date().toISOString()
        }).eq('id', empId);

        await supabaseClient.from('employees').update({
          designation: designation,
          department: department,
          updated_at: new Date().toISOString()
        }).eq('user_id', empId);
      }

      closeEmployeeDrawer();
      loadAllCloudData();
    } catch (e) {
      alert('Failed to save employee: ' + e.message);
    }
  }

  // Export CSV
  function exportReportsCSV() {
    if (attendanceData.length === 0) return;
    const headers = ['Timestamp', 'Employee Name', 'Event Type', 'Latitude', 'Longitude', 'Address', 'Geofence Valid'];
    const rows = attendanceData.map(r => [
      r.event_timestamp,
      `"${r.employee_name || ''}"`,
      r.workflow_step,
      r.latitude,
      r.longitude,
      `"${r.address || ''}"`,
      r.is_geofence_valid
    ]);

    const csvContent = 'data:text/csv;charset=utf-8,' + [headers.join(','), ...rows.map(e => e.join(','))].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `Attendance_Report_${new Date().toISOString().split('T')[0]}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }

  // Export Excel
  function exportReportsExcel() {
    if (!window.XLSX || attendanceData.length === 0) return;
    const ws = XLSX.utils.json_to_sheet(attendanceData);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, "Attendance Logs");
    XLSX.writeFile(wb, `Attendance_Timesheets_${new Date().toISOString().split('T')[0]}.xlsx`);
  }

  // Ownership Transfer Modal Handlers
  function openTransferModal() {
    const adminOptions = employeesData
      .filter(e => e.role === 'ADMIN' && e.id !== currentUser.id)
      .map(e => `<option value="${e.id}">${e.name} (${e.email})</option>`);

    if (adminOptions.length === 0) {
      alert('No other eligible ADMIN users found in organization. Assign ADMIN role to a user first.');
      return;
    }

    transferTargetSelect.innerHTML = adminOptions.join('');
    transferModalBackdrop.classList.add('active');
    transferModal.classList.add('active');
  }

  function closeTransferModal() {
    transferModalBackdrop.classList.remove('active');
    transferModal.classList.remove('active');
  }

  async function executeOwnershipTransfer() {
    const targetAdminId = transferTargetSelect.value;
    if (!targetAdminId) return;

    try {
      const { data, error } = await supabaseClient.rpc('transfer_organization_ownership', {
        p_org_id: currentUser.organization_id || '00000000-0000-0000-0000-000000000001',
        p_current_super_admin_id: currentUser.id,
        p_target_admin_id: targetAdminId
      });

      if (error) throw error;
      alert('Ownership successfully transferred! Your account is now demoted to ADMIN.');
      closeTransferModal();
      loadAllCloudData();
    } catch (e) {
      alert('Transfer Ownership RPC error: ' + e.message);
    }
  }

  // Photo Lightbox Modal Handlers
  window.openPhotoModal = function(index) {
    const r = attendanceData[index];
    if (!r) return;
    const photoSrc = getPhotoSrc(r);
    if (!photoSrc) return;

    const modalImg = document.getElementById('photo-modal-img');
    const modalTitle = document.getElementById('photo-modal-title');
    const modalMeta = document.getElementById('photo-modal-meta');

    if (modalImg) modalImg.src = photoSrc;
    if (modalTitle) modalTitle.textContent = `Selfie Audit: ${r.employee_name || 'Staff'}`;
    if (modalMeta) {
      modalMeta.innerHTML = `
        <strong>${r.workflow_step || 'Check-in'}</strong> • ${new Date(r.event_timestamp).toLocaleString()}<br>
        <span style="color: var(--text-tertiary);">${r.address || (r.latitude ? `${r.latitude.toFixed(5)}, ${r.longitude.toFixed(5)}` : '')}</span>
      `;
    }

    const backdrop = document.getElementById('photo-modal-backdrop');
    const modal = document.getElementById('photo-modal');
    if (backdrop) backdrop.classList.add('active');
    if (modal) modal.classList.add('active');
  };

  function closePhotoModal() {
    const backdrop = document.getElementById('photo-modal-backdrop');
    const modal = document.getElementById('photo-modal');
    if (backdrop) backdrop.classList.remove('active');
    if (modal) modal.classList.remove('active');
  }

  const photoCloseBtn = document.getElementById('photo-modal-close');
  const photoBackdrop = document.getElementById('photo-modal-backdrop');
  if (photoCloseBtn) photoCloseBtn.addEventListener('click', closePhotoModal);
  if (photoBackdrop) photoBackdrop.addEventListener('click', closePhotoModal);

  function showLoginError(msg) {
    loginErrorAlert.textContent = msg;
    loginErrorAlert.classList.add('active');
  }

  function hideLoginError() {
    loginErrorAlert.classList.remove('active');
  }

})();
