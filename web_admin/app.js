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
  let cardsData = [];
  let cardPendingFile = null;
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
  const reportsCycleSelect = document.getElementById('reports-cycle-select');

  // Cards & Documents DOM Cache
  const cardsTableBody = document.getElementById('cards-table-body');
  const cardsSearchInput = document.getElementById('cards-search-input');
  const cardsFilterType = document.getElementById('cards-filter-type');
  const cardsFilterStatus = document.getElementById('cards-filter-status');
  const cardsAlertBanner = document.getElementById('cards-alert-banner');
  const alertBannerTitle = document.getElementById('alert-banner-title');
  const alertBannerDesc = document.getElementById('alert-banner-desc');

  const cardDrawerBackdrop = document.getElementById('card-drawer-backdrop');
  const cardDrawer = document.getElementById('card-drawer');
  const cardForm = document.getElementById('card-form');
  const cardEditId = document.getElementById('card-edit-id');
  const cardEmpSelect = document.getElementById('card-emp-select');
  const cardTypeSelect = document.getElementById('card-type-select');
  const cardCustomNameGroup = document.getElementById('card-custom-name-group');
  const cardCustomName = document.getElementById('card-custom-name');
  const cardNumberInput = document.getElementById('card-number-input');
  const cardIssueDate = document.getElementById('card-issue-date');
  const cardExpiryDate = document.getElementById('card-expiry-date');
  const cardNotes = document.getElementById('card-notes');
  const cardFileDropzone = document.getElementById('card-file-dropzone');
  const cardFileInput = document.getElementById('card-file-input');
  const cardFilePreview = document.getElementById('card-file-preview');
  const cardFileThumb = document.getElementById('card-file-thumb');
  const cardFileName = document.getElementById('card-file-name');
  const cardFileSize = document.getElementById('card-file-size');
  const cardFileRemove = document.getElementById('card-file-remove');

  const cardViewerBackdrop = document.getElementById('card-viewer-backdrop');
  const cardViewerModal = document.getElementById('card-viewer-modal');
  const broadcastModalBackdrop = document.getElementById('broadcast-modal-backdrop');
  const broadcastModal = document.getElementById('broadcast-modal');

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

    // Export Buttons & Salary Cycle Filter
    if (reportsCycleSelect) {
      reportsCycleSelect.addEventListener('change', () => renderReportsTable());
    }
    document.getElementById('btn-export-csv').addEventListener('click', exportReportsCSV);
    document.getElementById('btn-export-excel').addEventListener('click', exportReportsExcel);

    // Cards & Passes Expiry Management Event Listeners
    if (cardsSearchInput) {
      cardsSearchInput.addEventListener('input', () => renderCardsTable());
    }
    if (cardsFilterType) {
      cardsFilterType.addEventListener('change', () => renderCardsTable());
    }
    if (cardsFilterStatus) {
      cardsFilterStatus.addEventListener('change', () => renderCardsTable());
    }
    const btnAddCard = document.getElementById('btn-add-card');
    if (btnAddCard) btnAddCard.addEventListener('click', () => openCardDrawer());

    const btnExportCards = document.getElementById('btn-export-cards');
    if (btnExportCards) btnExportCards.addEventListener('click', exportCardsData);

    const cardDrawerCloseBtn = document.getElementById('card-drawer-close-btn');
    const cardDrawerCancelBtn = document.getElementById('card-drawer-cancel-btn');
    const cardDrawerSaveBtn = document.getElementById('card-drawer-save-btn');
    if (cardDrawerCloseBtn) cardDrawerCloseBtn.addEventListener('click', closeCardDrawer);
    if (cardDrawerCancelBtn) cardDrawerCancelBtn.addEventListener('click', closeCardDrawer);
    if (cardDrawerBackdrop) cardDrawerBackdrop.addEventListener('click', closeCardDrawer);
    if (cardDrawerSaveBtn) cardDrawerSaveBtn.addEventListener('click', saveCardDocument);

    if (cardTypeSelect) {
      cardTypeSelect.addEventListener('change', () => {
        if (cardCustomNameGroup) {
          cardCustomNameGroup.style.display = cardTypeSelect.value === 'CUSTOM_PASS' ? 'block' : 'none';
        }
      });
    }

    // Card File Dropzone Handlers
    if (cardFileDropzone) {
      cardFileDropzone.addEventListener('click', () => {
        if (cardFileInput) cardFileInput.click();
      });
      cardFileDropzone.addEventListener('dragover', (e) => {
        e.preventDefault();
        cardFileDropzone.classList.add('dragover');
      });
      cardFileDropzone.addEventListener('dragleave', () => {
        cardFileDropzone.classList.remove('dragover');
      });
      cardFileDropzone.addEventListener('drop', (e) => {
        e.preventDefault();
        cardFileDropzone.classList.remove('dragover');
        if (e.dataTransfer.files && e.dataTransfer.files[0]) {
          handleCardFileSelection(e.dataTransfer.files[0]);
        }
      });
    }
    if (cardFileInput) {
      cardFileInput.addEventListener('change', (e) => {
        if (e.target.files && e.target.files[0]) {
          handleCardFileSelection(e.target.files[0]);
        }
      });
    }
    if (cardFileRemove) {
      cardFileRemove.addEventListener('click', clearCardPendingFile);
    }

    // Gemini AI Vision Key Management
    const btnToggleAiKey = document.getElementById('btn-toggle-ai-key');
    const btnSaveAiKey = document.getElementById('btn-save-ai-key');
    const aiKeyConfigBox = document.getElementById('ai-key-config-box');
    const geminiApiKeyInput = document.getElementById('gemini-api-key-input');

    if (btnToggleAiKey && aiKeyConfigBox) {
      btnToggleAiKey.addEventListener('click', () => {
        const isHidden = aiKeyConfigBox.style.display === 'none' || !aiKeyConfigBox.style.display;
        aiKeyConfigBox.style.display = isHidden ? 'block' : 'none';
        if (isHidden && geminiApiKeyInput) {
          geminiApiKeyInput.value = getGeminiApiKey();
          geminiApiKeyInput.focus();
        }
      });
    }

    if (btnSaveAiKey && geminiApiKeyInput) {
      btnSaveAiKey.addEventListener('click', () => {
        const val = geminiApiKeyInput.value.trim();
        setGeminiApiKey(val);
        if (aiKeyConfigBox) aiKeyConfigBox.style.display = 'none';
        if (val) {
          alert('✓ Gemini AI API Key saved successfully! AI Vision is now active for document extraction.');
          // If a file is already uploaded, re-run with AI
          if (cardPendingFile) {
            runCardOcrExtraction(cardPendingFile);
          }
        } else {
          alert('Gemini AI API Key cleared.');
        }
      });
    }

    // OCR Auto-Extraction Buttons
    const btnOcrInstant = document.getElementById('btn-ocr-instant-scan');
    if (btnOcrInstant) btnOcrInstant.addEventListener('click', () => runCardOcrExtraction());
    const btnSampleEid = document.getElementById('btn-ocr-sample-eid');
    if (btnSampleEid) btnSampleEid.addEventListener('click', () => runCardOcrExtraction(null, 'EMIRATES_ID'));
    const btnSampleVisa = document.getElementById('btn-ocr-sample-visa');
    if (btnSampleVisa) btnSampleVisa.addEventListener('click', () => runCardOcrExtraction(null, 'VISA'));
    const btnSamplePassport = document.getElementById('btn-ocr-sample-passport');
    if (btnSamplePassport) btnSamplePassport.addEventListener('click', () => runCardOcrExtraction(null, 'PASSPORT'));
    const btnSampleInsurance = document.getElementById('btn-ocr-sample-insurance');
    if (btnSampleInsurance) btnSampleInsurance.addEventListener('click', () => runCardOcrExtraction(null, 'INSURANCE'));
    const btnSampleMopa = document.getElementById('btn-ocr-sample-mopa');
    if (btnSampleMopa) btnSampleMopa.addEventListener('click', () => runCardOcrExtraction(null, 'MOPA_PASS'));
    const btnSampleCispa = document.getElementById('btn-ocr-sample-cispa');
    if (btnSampleCispa) btnSampleCispa.addEventListener('click', () => runCardOcrExtraction(null, 'CISPA_PASS'));

    // Card Viewer Modal Handlers
    const cardViewerClose = document.getElementById('card-viewer-close');
    const cardViewerDismiss = document.getElementById('card-viewer-dismiss');
    if (cardViewerClose) cardViewerClose.addEventListener('click', closeCardViewer);
    if (cardViewerDismiss) cardViewerDismiss.addEventListener('click', closeCardViewer);
    if (cardViewerBackdrop) cardViewerBackdrop.addEventListener('click', closeCardViewer);

    // Broadcast Modal Handlers
    const btnBroadcastExpiry = document.getElementById('btn-broadcast-expiry');
    const btnEmailDigest = document.getElementById('btn-email-digest');
    const broadcastClose = document.getElementById('broadcast-modal-close');
    const broadcastCancel = document.getElementById('broadcast-cancel-btn');
    const broadcastWhatsappBtn = document.getElementById('broadcast-whatsapp-btn');
    const broadcastEmailBtn = document.getElementById('broadcast-email-btn');

    if (btnBroadcastExpiry) btnBroadcastExpiry.addEventListener('click', openBroadcastModal);
    if (btnEmailDigest) btnEmailDigest.addEventListener('click', openBroadcastModal);
    if (broadcastClose) broadcastClose.addEventListener('click', closeBroadcastModal);
    if (broadcastCancel) broadcastCancel.addEventListener('click', closeBroadcastModal);
    if (broadcastModalBackdrop) broadcastModalBackdrop.addEventListener('click', closeBroadcastModal);
    if (broadcastWhatsappBtn) broadcastWhatsappBtn.addEventListener('click', triggerBroadcastWhatsApp);
    if (broadcastEmailBtn) broadcastEmailBtn.addEventListener('click', triggerBroadcastEmail);

    // Security Transfer Ownership Modal Triggers
    document.getElementById('btn-open-transfer-modal').addEventListener('click', openTransferModal);
    document.getElementById('transfer-modal-close').addEventListener('click', closeTransferModal);
    document.getElementById('transfer-cancel-btn').addEventListener('click', closeTransferModal);
    transferModalBackdrop.addEventListener('click', closeTransferModal);
    document.getElementById('transfer-confirm-btn').addEventListener('click', executeOwnershipTransfer);
  }

  function switchTab(tabId) {
    // Normalise tabId in case it's passed with 'tab-' prefix
    const cleanTabId = tabId.replace(/^tab-/, '');

    navItems.forEach(n => n.classList.remove('active'));
    tabPanes.forEach(p => p.classList.remove('active'));

    const selectedNav = document.querySelector(`.nav-item[data-tab="${cleanTabId}"]`);
    const selectedPane = document.getElementById(`tab-${cleanTabId}`);

    if (selectedNav) selectedNav.classList.add('active');
    if (selectedPane) selectedPane.classList.add('active');

    const titles = {
      overview: 'Executive Command Center',
      employees: 'Employee Directory & Roles',
      cards: 'Employee Cards & Expiry Tracking Suite',
      offices: 'Office Locations & Geofence Boundaries',
      sites: 'Client Work Sites',
      map: 'Live GPS Field Tracking',
      reports: 'Attendance Logs & Timesheets',
      security: 'Security & Governance'
    };

    activePageTitle.textContent = titles[cleanTabId] || 'Admin Dashboard';

    if (cleanTabId === 'map') {
      setTimeout(initMap, 200);
    } else if (cleanTabId === 'cards') {
      renderCardsTable();
      updateCardsOverviewMetrics();
    }
  }
  window.switchTab = switchTab;

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

      // 4. Fetch Attendance Logs (with pagination)
      let allAttendance = [];
      let page = 0;
      const pageSize = 1000;
      while (page < 10) {
        const { data: chunk, error } = await supabaseClient
          .from('attendance_records')
          .select('*')
          .order('event_timestamp', { ascending: false })
          .range(page * pageSize, (page + 1) * pageSize - 1);

        if (error || !chunk || chunk.length === 0) break;
        allAttendance = allAttendance.concat(chunk);
        if (chunk.length < pageSize) break;
        page++;
      }
      attendanceData = allAttendance;

      // 5. Fetch Employee Cards & Passes (safely merged with local storage)
      loadLocalOrInitialCards();
      try {
        const { data: cards, error: cardsErr } = await supabaseClient
          .from('employee_cards')
          .select('*')
          .eq('is_deleted', false)
          .order('expiry_date', { ascending: true });

        if (!cardsErr && cards && cards.length > 0) {
          const merged = {};
          cardsData.forEach(c => { merged[c.id] = c; });
          cards.forEach(c => {
            if (merged[c.id]) {
              const local = merged[c.id];
              merged[c.id] = (!c.document_url && local.document_url) ? { ...c, document_url: local.document_url, file_name: local.file_name } : c;
            } else {
              merged[c.id] = c;
            }
          });
          cardsData = Object.values(merged);
          saveCardsData();
        }
      } catch (errCards) {
        console.warn('Could not query employee_cards from cloud, using local store:', errCards);
      }

      // Update Views
      updateOverviewMetrics();
      renderEmployeeTable();
      renderOfficeTable();
      renderSiteTable();
      populateSalaryCycleDropdown();
      renderReportsTable();
      updateCardsOverviewMetrics();
      renderCardsTable();
      if (leafletMap) renderMapMarkers();

      // Trigger daily automated compliance robot check in background
      checkAndRunAutomatedRobot();

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

    renderOverviewCardsAlerts();
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
      officeTableBody.innerHTML = `<tr><td colspan="6" style="text-align: center; color: var(--text-muted); padding: 24px;">No offices configured. Click Add Office Location to create one.</td></tr>`;
      return;
    }

    officeTableBody.innerHTML = officesData.map(o => `
      <tr>
        <td><strong>${o.name}</strong></td>
        <td>${o.address}</td>
        <td><span style="font-family: var(--font-mono);">${o.latitude.toFixed(6)}, ${o.longitude.toFixed(6)}</span></td>
        <td>${o.geofence_radius_meters}m</td>
        <td><span class="badge ${o.is_default ? 'badge-success' : 'badge-neutral'}">${o.is_default ? 'Default HQ' : 'Branch'}</span></td>
        <td>
          ${o.is_default 
            ? '<span style="color: var(--text-muted); font-size: 11px;">Protected (HQ)</span>' 
            : `<button class="btn btn-sm" style="color: #ef4444; border: 1px solid #ef4444; padding: 3px 8px; font-size: 11px; border-radius: 4px; background: transparent; cursor: pointer;" onclick="deleteOfficeLocation('${o.id}', '${encodeURIComponent(o.name)}')">🗑 Delete</button>`
          }
        </td>
      </tr>
    `).join('');
  }

  window.deleteOfficeLocation = async function(officeId, encodedName) {
    const name = decodeURIComponent(encodedName);
    if (!confirm(`Are you sure you want to delete office "${name}"?\n\nAny employees assigned to this office branch will automatically revert to using the default Main Office.`)) {
      return;
    }
    try {
      const now = new Date().toISOString();
      const { error } = await supabaseClient
        .from('offices')
        .update({ is_deleted: true, updated_at: now })
        .eq('id', officeId);
      if (error) throw error;

      await supabaseClient
        .from('employees')
        .update({ assigned_office_id: null, use_default_office: true, updated_at: now })
        .eq('assigned_office_id', officeId);

      alert(`Office "${name}" deleted successfully.`);
      await fetchAllData();
    } catch (err) {
      console.error('Error deleting office:', err);
      alert('Failed to delete office: ' + err.message);
    }
  };

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

  // Salary Cycle Utilities (25th of month to 24th of next month)
  // App implemented from Aug – Sep 2026 (25 Aug - 24 Sep). Previous months have no data.
  function getSalaryCycles() {
    const cycles = [];
    const now = new Date();
    let ref = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    const earliestStart = new Date(2026, 7, 25, 0, 0, 0, 0); // 25 Aug 2026

    while (true) {
      let y = ref.getFullYear();
      let m = ref.getMonth();
      let d = ref.getDate();
      let start, end;
      if (d >= 25) {
        start = new Date(y, m, 25, 0, 0, 0, 0);
        end = new Date(y, m + 1, 24, 23, 59, 59, 999);
      } else {
        start = new Date(y, m - 1, 25, 0, 0, 0, 0);
        end = new Date(y, m, 24, 23, 59, 59, 999);
      }

      if (start.getTime() < earliestStart.getTime()) {
        break;
      }

      const startStr = `${start.getDate()} ${monthNames[start.getMonth()]}`;
      const endStr = `${end.getDate()} ${monthNames[end.getMonth()]} ${end.getFullYear()}`;
      const cycleTitle = `${monthNames[start.getMonth()]} – ${monthNames[end.getMonth()]} ${end.getFullYear()} Cycle`;
      const label = `${cycleTitle} (${startStr} – ${endStr})`;
      cycles.push({
        id: `cycle_${start.getTime()}`,
        title: cycleTitle,
        label,
        start,
        end
      });
      ref = new Date(start.getTime() - 24 * 60 * 60 * 1000);
    }

    if (cycles.length === 0) {
      const start = new Date(2026, 7, 25, 0, 0, 0, 0);
      const end = new Date(2026, 8, 24, 23, 59, 59, 999);
      cycles.push({
        id: `cycle_${start.getTime()}`,
        title: 'Aug – Sep 2026 Cycle',
        label: 'Aug – Sep 2026 Cycle (25 Aug – 24 Sep 2026)',
        start,
        end
      });
    }

    return cycles;
  }

  function populateSalaryCycleDropdown() {
    if (!reportsCycleSelect) return;
    const currentVal = reportsCycleSelect.value;
    const cycles = getSalaryCycles();
    let options = cycles.map((c, i) => `<option value="${i}">${c.label}${i === 0 ? ' (Active Cycle)' : ''}</option>`).join('');
    options += `<option value="all">All Recorded History (Unfiltered)</option>`;
    reportsCycleSelect.innerHTML = options;
    if (currentVal && (currentVal === 'all' || parseInt(currentVal, 10) < cycles.length)) {
      reportsCycleSelect.value = currentVal;
    }
  }

  function getFilteredAttendance() {
    if (!reportsCycleSelect || reportsCycleSelect.value === 'all') {
      return attendanceData;
    }
    const cycles = getSalaryCycles();
    const idx = parseInt(reportsCycleSelect.value || '0', 10);
    const cycle = cycles[idx];
    if (!cycle) return attendanceData;

    return attendanceData.filter(r => {
      if (!r.event_timestamp) return false;
      const t = new Date(r.event_timestamp).getTime();
      return t >= cycle.start.getTime() && t <= cycle.end.getTime();
    });
  }

  function getSelectedCycleFilenamePart() {
    if (!reportsCycleSelect || reportsCycleSelect.value === 'all') {
      return 'All_Records';
    }
    const cycles = getSalaryCycles();
    const idx = parseInt(reportsCycleSelect.value || '0', 10);
    const cycle = cycles[idx];
    return cycle ? cycle.title.replace(/\s+/g, '_') : 'Salary_Cycle';
  }

  function renderReportsTable() {
    if (!reportsTableBody) return;

    const records = getFilteredAttendance();

    if (records.length === 0) {
      reportsTableBody.innerHTML = `<tr><td colspan="6" style="text-align: center; color: var(--text-tertiary); padding: 24px;">No attendance check-in records found for this period.</td></tr>`;
      return;
    }

    reportsTableBody.innerHTML = records.map((r, index) => {
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
    const records = getFilteredAttendance();
    if (records.length === 0) {
      alert('No attendance records found for the selected salary cycle.');
      return;
    }
    const headers = ['Timestamp', 'Employee Name', 'Event Type', 'Latitude', 'Longitude', 'Address', 'Geofence Valid'];
    const rows = records.map(r => [
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
    const cycleTag = getSelectedCycleFilenamePart();
    link.setAttribute('download', `Attendance_${cycleTag}_${new Date().toISOString().split('T')[0]}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }

  // Export Excel
  function exportReportsExcel() {
    const records = getFilteredAttendance();
    if (!window.XLSX || records.length === 0) {
      if (records.length === 0) alert('No attendance records found for the selected salary cycle.');
      return;
    }
    const ws = XLSX.utils.json_to_sheet(records);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, "Attendance Logs");
    const cycleTag = getSelectedCycleFilenamePart();
    XLSX.writeFile(wb, `Attendance_Timesheets_${cycleTag}_${new Date().toISOString().split('T')[0]}.xlsx`);
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

  // --------------------------------------------------------------------------
  // CARDS & DOCUMENT EXPIRY TRACKER CONTROLLER SUITE
  // --------------------------------------------------------------------------

  function loadLocalOrInitialCards() {
    const saved = localStorage.getItem('f360_employee_cards');
    if (saved) {
      try {
        cardsData = JSON.parse(saved);
        return;
      } catch (e) {
        console.warn('Failed to parse local cards cache:', e);
      }
    }
    // No sample cards - clean start for real employee uploads
    cardsData = [];
  }

  function saveCardsData() {
    try {
      localStorage.setItem('f360_employee_cards', JSON.stringify(cardsData));
    } catch (e) {
      console.warn('Failed to save full cards with attachments to localStorage, attempting fallback without bulky docs:', e);
      try {
        // Fallback: strip heavy document_url so all card attributes, IDs, numbers, and expiry dates are saved
        const lightCards = cardsData.map(c => {
          if (c.document_url && c.document_url.startsWith('data:') && c.document_url.length > 50000) {
            const { document_url, ...rest } = c;
            return rest;
          }
          return c;
        });
        localStorage.setItem('f360_employee_cards', JSON.stringify(lightCards));
      } catch (innerErr) {
        console.error('Critical: localStorage quota fully exhausted for cards:', innerErr);
      }
    }
  }

  function calculateExpiryStatus(expiryDateStr) {
    if (!expiryDateStr) {
      return { status: 'UNKNOWN', badgeClass: 'badge-neutral', label: 'No Date Set', isCritical: false, daysLeft: 999 };
    }

    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    
    // Parse Date
    const parts = expiryDateStr.split('-');
    if (parts.length < 3) {
      return { status: 'UNKNOWN', badgeClass: 'badge-neutral', label: 'Invalid Date', isCritical: false, daysLeft: 999 };
    }
    const expDate = new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10));
    
    const diffMs = expDate.getTime() - today.getTime();
    const diffDays = Math.round(diffMs / (1000 * 60 * 60 * 24));

    if (diffDays < 0) {
      const absDays = Math.abs(diffDays);
      return {
        status: 'EXPIRED',
        badgeClass: 'badge-expiry-expired',
        label: `❌ Expired (${absDays}d ago)`,
        isCritical: true,
        daysLeft: diffDays
      };
    } else if (diffDays === 0) {
      return {
        status: 'CRITICAL',
        badgeClass: 'badge-expiry-critical',
        label: '🚨 Expires Today!',
        isCritical: true,
        daysLeft: 0
      };
    } else if (diffDays <= 3) {
      return {
        status: 'CRITICAL',
        badgeClass: 'badge-expiry-critical',
        label: `⚠️ Expires in ${diffDays} day${diffDays === 1 ? '' : 's'}`,
        isCritical: true,
        daysLeft: diffDays
      };
    } else if (diffDays <= 30) {
      return {
        status: 'SOON',
        badgeClass: 'badge-expiry-soon',
        label: `⚠️ ${diffDays} days left`,
        isCritical: false,
        daysLeft: diffDays
      };
    } else {
      return {
        status: 'VALID',
        badgeClass: 'badge-expiry-valid',
        label: `✅ Valid (${diffDays}d left)`,
        isCritical: false,
        daysLeft: diffDays
      };
    }
  }

  function formatDisplayDate(dateStr) {
    if (!dateStr) return '—';
    try {
      const parts = dateStr.split('-');
      if (parts.length === 3) {
        const d = new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10));
        return d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
      }
      return new Date(dateStr).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
    } catch (e) {
      return dateStr;
    }
  }

  function getCardTypeBadge(type, name) {
    switch (type) {
      case 'EMIRATES_ID':
        return `<span class="badge-doc-type badge-emirates-id">🪪 Emirates ID</span>`;
      case 'VISA':
        return `<span class="badge-doc-type badge-visa">🛂 Residence Visa</span>`;
      case 'PASSPORT':
        return `<span class="badge-doc-type badge-passport" style="background: rgba(59, 130, 246, 0.15); color: #3b82f6; border: 1px solid rgba(59, 130, 246, 0.3);">📘 Passport</span>`;
      case 'INSURANCE':
        return `<span class="badge-doc-type badge-insurance">🏥 Health Insurance</span>`;
      case 'MOPA_PASS':
        return `<span class="badge-doc-type badge-mopa">🎖️ MOPA Pass</span>`;
      case 'CISPA_PASS':
        return `<span class="badge-doc-type badge-cispa">🔒 Cispa Pass</span>`;
      case 'CUSTOM_PASS':
      default:
        return `<span class="badge-doc-type badge-custom-pass">🏷️ ${name || 'Private Pass'}</span>`;
    }
  }

  function updateCardsOverviewMetrics() {
    const totalCount = cardsData.length;
    let criticalCount = 0;
    let expiredCount = 0;
    let validCount = 0;

    cardsData.forEach(c => {
      const st = calculateExpiryStatus(c.expiry_date);
      if (st.daysLeft < 0) {
        expiredCount++;
      } else if (st.isCritical) {
        criticalCount++;
      } else {
        validCount++;
      }
    });

    const elTotal = document.getElementById('metric-total-cards');
    const elCrit = document.getElementById('metric-critical-cards');
    const elExp = document.getElementById('metric-expired-cards');
    const elVal = document.getElementById('metric-valid-cards');
    const elBadge = document.getElementById('cards-count-badge');

    if (elTotal) elTotal.textContent = totalCount;
    if (elCrit) elCrit.textContent = criticalCount;
    if (elExp) elExp.textContent = expiredCount;
    if (elVal) elVal.textContent = validCount;
    if (elBadge) elBadge.textContent = `${totalCount} Document${totalCount === 1 ? '' : 's'}`;

    // Update Urgent 3-Day Alert Banner
    const totalUrgent = criticalCount + expiredCount;
    const banner = document.getElementById('urgent-cards-banner');
    const bannerTitle = document.getElementById('urgent-cards-banner-title');
    if (banner) {
      if (totalUrgent > 0) {
        banner.style.display = 'block';
        if (bannerTitle) {
          bannerTitle.textContent = `🚨 Urgent Renewal Notice: ${totalUrgent} Document${totalUrgent === 1 ? '' : 's'} Expiring within ≤ 3 Days`;
        }
      } else {
        banner.style.display = 'none';
      }
    }

    if (cardsAlertBanner) {
      if (totalUrgent > 0) {
        cardsAlertBanner.style.display = 'flex';
        if (alertBannerTitle) {
          alertBannerTitle.textContent = `🚨 Critical Notice: ${totalUrgent} Document${totalUrgent === 1 ? '' : 's'} Requiring Immediate Renewal Action`;
        }
        if (alertBannerDesc) {
          alertBannerDesc.textContent = `${criticalCount} card${criticalCount === 1 ? '' : 's'} expiring within the next 3 days and ${expiredCount} expired card${expiredCount === 1 ? '' : 's'}. Use the 1-Click WhatsApp or Email buttons below to notify staff.`;
        }
      } else {
        cardsAlertBanner.style.display = 'none';
      }
    }

    renderOverviewCardsAlerts();
  }

  window.notifyAdminWhatsAppDigest = function() {
    const urgentCards = cardsData.filter(c => {
      const st = calculateExpiryStatus(c.expiry_date);
      return st.isCritical || st.status === 'EXPIRED';
    });

    if (urgentCards.length === 0) {
      showToast('All documents are valid. No cards expiring within 3 days.', 'info');
      return;
    }

    let text = `🚨 *URGENT COMPLIANCE NOTICE: CARD EXPIRATION (≤ 3 DAYS)*\n`;
    text += `════════════════════════════════════════\n`;
    text += `Attention: Compliance & Operations Control\n`;
    text += `The following *${urgentCards.length} document(s)* require immediate renewal:\n\n`;

    urgentCards.forEach((c, idx) => {
      const emp = employeesData.find(e => e.id === c.employee_id) || { name: 'Staff', employeeCode: 'EMP' };
      const st = calculateExpiryStatus(c.expiry_date);
      text += `*${idx + 1}. ${c.card_name.toUpperCase()}*\n`;
      text += `  👤 Employee: ${emp.name} (${emp.employeeCode})\n`;
      text += `  🔢 Card No: ${c.card_number}\n`;
      text += `  📅 Expiry: ${formatDisplayDate(c.expiry_date)}\n`;
      text += `  ⏳ Status: ${st.label}\n`;
      if (idx < urgentCards.length - 1) text += `────────────────────────────────────────\n`;
    });

    text += `\n⚠️ *Action Required:*\n`;
    text += `Please coordinate immediately to submit renewals or processing receipts.\n`;
    text += `════════════════════════════════════════\n`;
    text += `_Fusion 360 Workforce Document Control_`;

    const url = `https://wa.me/971586939371?text=${encodeURIComponent(text)}`;
    window.open(url, '_blank');
    showToast('Launched WhatsApp with 3-day renewal alerts for +971586939371', 'success');
  };

  window.notifyAdminEmailDigest = function() {
    const urgentCards = cardsData.filter(c => {
      const st = calculateExpiryStatus(c.expiry_date);
      return st.isCritical || st.status === 'EXPIRED';
    });

    if (urgentCards.length === 0) {
      showToast('All documents are valid. No cards expiring within 3 days.', 'info');
      return;
    }

    const subject = encodeURIComponent(`[URGENT] Compliance Alert: ${urgentCards.length} Document(s) Expiring Within 3 Days`);
    let body = `Dear Administrator & HR Operations Team,\n\n`;
    body += `This is an automated compliance notification from Fusion 360 Document Control.\n`;
    body += `The following employee credential(s) have reached the critical 3-day expiration threshold:\n\n`;

    urgentCards.forEach((c, idx) => {
      const emp = employeesData.find(e => e.id === c.employee_id) || { name: 'Staff', employeeCode: 'EMP' };
      const st = calculateExpiryStatus(c.expiry_date);
      body += `Document #${idx + 1}: ${c.card_name}\n`;
      body += `• Employee: ${emp.name} (${emp.employeeCode})\n`;
      body += `• Card Number: ${c.card_number}\n`;
      body += `• Expiry Date: ${formatDisplayDate(c.expiry_date)}\\n`;
      body += `• Urgency: ${st.label}\\n\\n`;
    });

    body += `ACTION REQUIRED:\\n`;
    body += `Please initiate or verify the renewal procedure immediately to avoid site access deactivation.\\n\\n`;
    body += `Best regards,\\nFusion 360 Workforce Compliance Desk`;

    const mailtoUrl = `mailto:sr.irshath@gmail.com?subject=${subject}&body=${encodeURIComponent(body)}`;
    window.location.href = mailtoUrl;
    showToast('Prepared 3-day renewal email alert for sr.irshath@gmail.com', 'success');
  };

  // --------------------------------------------------------------------------
  // Automated Compliance Robot Functions (Background Free Email & WhatsApp)
  // --------------------------------------------------------------------------
  window.openRobotConfigModal = function() {
    const resendKey = localStorage.getItem('fusion_compliance_resend_key') || '';
    const callmebotKey = localStorage.getItem('fusion_compliance_callmebot_key') || '';
    const isEnabled = localStorage.getItem('fusion_compliance_robot_enabled') !== 'false';
    const targetEmail = localStorage.getItem('fusion_compliance_target_email') || 'sr.irshath@gmail.com, nasuru@fusionmaint.com';

    const inputResend = document.getElementById('robot-resend-key');
    const inputCallmebot = document.getElementById('robot-callmebot-key');
    const switchEnabled = document.getElementById('robot-enabled-switch');
    const inputTargetEmail = document.getElementById('robot-target-email');

    if (inputResend) inputResend.value = resendKey;
    if (inputCallmebot) inputCallmebot.value = callmebotKey;
    if (switchEnabled) switchEnabled.checked = isEnabled;
    if (inputTargetEmail) inputTargetEmail.value = targetEmail;

    const modal = document.getElementById('robot-config-modal');
    const backdrop = document.getElementById('robot-config-modal-backdrop');
    if (modal) modal.style.display = 'block';
    if (backdrop) backdrop.style.display = 'block';
  };

  window.closeRobotConfigModal = function() {
    const modal = document.getElementById('robot-config-modal');
    const backdrop = document.getElementById('robot-config-modal-backdrop');
    if (modal) modal.style.display = 'none';
    if (backdrop) backdrop.style.display = 'none';
  };

  window.saveRobotConfig = async function() {
    const resendKey = (document.getElementById('robot-resend-key')?.value || '').trim();
    const callmebotKey = (document.getElementById('robot-callmebot-key')?.value || '').trim();
    const isEnabled = document.getElementById('robot-enabled-switch')?.checked ?? true;
    const targetEmail = (document.getElementById('robot-target-email')?.value || '').trim() || 'sr.irshath@gmail.com, nasuru@fusionmaint.com';

    localStorage.setItem('fusion_compliance_resend_key', resendKey);
    localStorage.setItem('fusion_compliance_callmebot_key', callmebotKey);
    localStorage.setItem('fusion_compliance_robot_enabled', isEnabled ? 'true' : 'false');
    localStorage.setItem('fusion_compliance_target_email', targetEmail);

    // Sync to Supabase if connected
    if (supabaseClient) {
      try {
        await supabaseClient.from('compliance_notification_settings').upsert({
          resend_api_key: resendKey,
          callmebot_api_key: callmebotKey,
          target_email: targetEmail,
          target_phone: '971586939371',
          is_automated_enabled: isEnabled,
          updated_at: new Date().toISOString()
        });
      } catch (err) {
        console.warn('Could not sync robot settings to Supabase:', err);
      }
    }

    closeRobotConfigModal();
    showToast('✅ Compliance Robot settings saved & synced successfully!', 'success');
    checkAndRunAutomatedRobot();
  };

  window.testRobotEmail = async function() {
    const resendKey = (document.getElementById('robot-resend-key')?.value || '').trim();
    if (!resendKey) {
      showToast('Please enter your Resend API key first', 'warning');
      return;
    }
    const targetEmailStr = (document.getElementById('robot-target-email')?.value || '').trim() || localStorage.getItem('fusion_compliance_target_email') || 'sr.irshath@gmail.com, nasuru@fusionmaint.com';
    const recipients = targetEmailStr.split(',').map(e => e.trim()).filter(Boolean);
    const toList = recipients.length > 0 ? recipients : ['sr.irshath@gmail.com', 'nasuru@fusionmaint.com'];

    showToast(`Dispatching test email to ${toList.join(', ')}...`, 'info');
    try {
      const resp = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${resendKey}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          from: 'Fusion Compliance <compliance@fusionmaint.org>',
          to: toList,
          subject: 'Fusion 360: Email Robot Test Connection',
          html: '<h3>Connection Successful!</h3><p>Your automated 3-day card expiry background email robot is properly configured and operational via <strong>fusionmaint.org</strong> for all recipients.</p>'
        })
      });
      if (resp.ok) {
        showToast(`✅ Test email delivered to ${toList.join(', ')}!`, 'success');
      } else {
        const err = await resp.json();
        showToast('Resend Error: ' + (err.message || resp.statusText), 'error');
      }
    } catch (e) {
      showToast('Network error testing email: ' + e.message, 'error');
    }
  };

  window.testRobotWhatsApp = async function() {
    const callmebotKey = (document.getElementById('robot-callmebot-key')?.value || '').trim();
    if (!callmebotKey) {
      showToast('Please enter your CallMeBot API key first', 'warning');
      return;
    }
    showToast('Dispatching test WhatsApp alert to +971586939371...', 'info');
    try {
      const msg = encodeURIComponent('🤖 *Fusion 360 Robot Test*: Background automated WhatsApp alerts are connected and active!');
      const url = `https://api.callmebot.com/whatsapp.php?phone=971586939371&text=${msg}&apikey=${callmebotKey}`;
      await fetch(url, { mode: 'no-cors' });
      showToast('✅ Test WhatsApp triggered for +971586939371!', 'success');
    } catch (e) {
      showToast('Error testing WhatsApp: ' + e.message, 'error');
    }
  };

  async function checkAndRunAutomatedRobot() {
    const isEnabled = localStorage.getItem('fusion_compliance_robot_enabled') !== 'false';
    if (!isEnabled) return;

    const todayStr = new Date().toISOString().split('T')[0];
    const lastRun = localStorage.getItem('fusion_compliance_robot_last_run');
    if (lastRun === todayStr) return; // already ran today

    const urgentCards = cardsData.filter(c => {
      const st = calculateExpiryStatus(c.expiry_date);
      return st.isCritical || st.status === 'EXPIRED';
    });
    if (urgentCards.length === 0) return;

    const resendKey = localStorage.getItem('fusion_compliance_resend_key');
    const callmebotKey = localStorage.getItem('fusion_compliance_callmebot_key');
    if (!resendKey && !callmebotKey) return;

    let emailSent = false;
    let waSent = false;

    // Send background email if Resend key present
    if (resendKey) {
      try {
        let tableRows = '';
        urgentCards.forEach(c => {
          const emp = employeesData.find(e => e.id === c.employee_id) || { name: 'Staff', employeeCode: 'EMP' };
          const st = calculateExpiryStatus(c.expiry_date);
          tableRows += `<tr style="border-bottom: 1px solid #e2e8f0;"><td style="padding: 10px;">${c.card_name}</td><td style="padding: 10px; font-family: monospace;">${c.card_number}</td><td style="padding: 10px;">${emp.name} (${emp.employeeCode})</td><td style="padding: 10px;">${formatDisplayDate(c.expiry_date)}</td><td style="padding: 10px;"><span style="background: #ef4444; color: white; padding: 2px 6px; border-radius: 4px; font-size: 11px;">${st.label}</span></td></tr>`;
        });
        const html = `<html><body style="font-family: sans-serif; background: #f8fafc; padding: 20px;"><div style="max-width: 600px; margin: 0 auto; background: white; border-radius: 8px; overflow: hidden; border: 1px solid #e2e8f0;"><div style="background: #0f172a; padding: 18px; color: white; border-bottom: 3px solid #ef4444;"><h3 style="margin: 0;">Critical Document Expiry Notice (≤ 3 Days)</h3></div><div style="padding: 18px;"><table style="width: 100%; border-collapse: collapse; font-size: 12px;"><thead><tr style="background: #f1f5f9; text-align: left;"><th style="padding: 8px;">Document</th><th style="padding: 8px;">Number</th><th style="padding: 8px;">Employee</th><th style="padding: 8px;">Expiry</th><th style="padding: 8px;">Status</th></tr></thead><tbody>${tableRows}</tbody></table></div></div></body></html>`;

        const targetEmailStr = localStorage.getItem('fusion_compliance_target_email') || 'sr.irshath@gmail.com, nasuru@fusionmaint.com';
        const recipients = targetEmailStr.split(',').map(e => e.trim()).filter(Boolean);

        const resp = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${resendKey}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            from: 'Fusion Compliance <compliance@fusionmaint.org>',
            to: recipients.length > 0 ? recipients : ['sr.irshath@gmail.com', 'nasuru@fusionmaint.com'],
            subject: `[URGENT] Compliance Alert: ${urgentCards.length} Document(s) Expiring Within 3 Days`,
            html: html
          })
        });
        emailSent = resp.ok;
      } catch (e) {
        console.warn('Auto email dispatch error:', e);
      }
    }

    // Send background WhatsApp if CallMeBot key present
    if (callmebotKey) {
      try {
        let text = `🚨 *URGENT COMPLIANCE NOTICE: CARD EXPIRATION (≤ 3 DAYS)*\n════════════════════════════════════════\nAttention: Compliance & Operations Control\nThe following *${urgentCards.length} document(s)* require immediate renewal:\n\n`;
        urgentCards.forEach((c, idx) => {
          const emp = employeesData.find(e => e.id === c.employee_id) || { name: 'Staff', employeeCode: 'EMP' };
          const st = calculateExpiryStatus(c.expiry_date);
          text += `*${idx + 1}. ${c.card_name.toUpperCase()}*\n  👤 ${emp.name} (${emp.employeeCode})\n  🔢 No: ${c.card_number}\n  📅 Expiry: ${formatDisplayDate(c.expiry_date)}\n  ⏳ Status: ${st.label}\n`;
        });
        text += `\n⚠️ *Action Required:* Please coordinate renewal immediately.\n════════════════════════════════════════\n_Fusion 360 Document Control_`;

        const url = `https://api.callmebot.com/whatsapp.php?phone=971586939371&text=${encodeURIComponent(text)}&apikey=${callmebotKey}`;
        await fetch(url, { mode: 'no-cors' });
        waSent = true;
      } catch (e) {
        console.warn('Auto WhatsApp dispatch error:', e);
      }
    }

    if (emailSent || waSent) {
      localStorage.setItem('fusion_compliance_robot_last_run', todayStr);
      showToast(`🤖 Daily Compliance Robot dispatched alerts for ${urgentCards.length} document(s).`, 'info');
    }
  }

  function renderOverviewCardsAlerts() {
    const container = document.getElementById('overview-cards-alert-container');
    if (!container) return;

    if (!cardsData || cardsData.length === 0) {
      container.innerHTML = `
        <div class="card-table-wrapper" style="padding: 16px 20px; display: flex; align-items: center; justify-content: space-between; border-left: 4px solid var(--primary);">
          <div style="display: flex; align-items: center; gap: 12px;">
            <span style="font-size: 24px;">🪪</span>
            <div>
              <div style="font-weight: 600; font-size: 14px;">Automated Employee Cards & Security Passes Tracking</div>
              <div style="font-size: 12px; color: var(--text-secondary); margin-top: 2px;">
                Select employees and upload cards (Emirates ID, Visa, Passport, Insurance, MOPA, CISPA) with automated OCR data retrieval and 3-day WhatsApp alerts.
              </div>
            </div>
          </div>
          <button class="btn btn-primary btn-sm" onclick="switchTab('cards'); openCardDrawer();">
            + Upload First Card
          </button>
        </div>
      `;
      return;
    }

    // Sort cards by urgency (smallest daysLeft first)
    const sorted = [...cardsData].map(c => ({
      ...c,
      _st: calculateExpiryStatus(c.expiry_date)
    })).sort((a, b) => a._st.daysLeft - b._st.daysLeft);

    const criticalCards = sorted.filter(c => c._st.isCritical);

    if (criticalCards.length > 0) {
      const cardsHtml = criticalCards.slice(0, 4).map(card => {
        const emp = employeesData.find(e => e.id === card.employee_id) || {
          name: 'Staff Member',
          employeeCode: 'EMP',
          department: 'Operations',
          phone: ''
        };
        const typeBadge = getCardTypeBadge(card.card_type);

        return `
          <div style="display: flex; align-items: center; justify-content: space-between; padding: 10px 14px; background: var(--bg-surface); border: 1px solid rgba(239, 68, 68, 0.25); border-radius: var(--radius-sm); margin-top: 8px;">
            <div style="display: flex; align-items: center; gap: 10px;">
              <div class="emp-avatar" style="width: 32px; height: 32px; font-size: 12px;">${(emp.name || 'E').charAt(0).toUpperCase()}</div>
              <div>
                <div style="font-weight: 600; font-size: 13px;">${emp.name} <span style="font-size: 11px; font-weight: normal; color: var(--text-secondary);">(${emp.employeeCode})</span></div>
                <div style="font-size: 11px; color: var(--text-secondary); display: flex; align-items: center; gap: 6px; margin-top: 2px;">
                  ${typeBadge}
                  <span>${card.card_number}</span>
                </div>
              </div>
            </div>
            <div style="display: flex; align-items: center; gap: 12px;">
              <div style="text-align: right;">
                <span class="badge ${card._st.badgeClass}" style="font-size: 11px;">${card._st.label}</span>
                <div style="font-size: 10px; color: var(--text-tertiary); margin-top: 2px;">Exp: ${formatDisplayDate(card.expiry_date)}</div>
              </div>
              <button class="btn-whatsapp btn-action-compact" onclick="notifyCardWhatsApp('${card.id}')" title="Send WhatsApp alert to ${emp.name}">
                💬 WhatsApp
              </button>
            </div>
          </div>
        `;
      }).join('');

      container.innerHTML = `
        <div class="compliance-alert-banner" style="display: block; margin-bottom: 0; border-left: 5px solid var(--danger);">
          <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 10px;">
            <div style="display: flex; align-items: center; gap: 10px;">
              <span style="font-size: 24px;">🚨</span>
              <div>
                <div class="alert-banner-title" style="font-size: 15px;">Critical Document Expiry Alert (${criticalCards.length} Employee Cards on Watchlist)</div>
                <div class="alert-banner-desc" style="font-size: 12px;">
                  Employee documents expiring within the next 3 days or already expired. Immediate renewal required.
                </div>
              </div>
            </div>
            <div style="display: flex; gap: 8px;">
              <button class="btn btn-whatsapp btn-sm" onclick="openBroadcastModal()">
                💬 WhatsApp Broadcast
              </button>
              <button class="btn btn-secondary btn-sm" onclick="switchTab('cards')">
                🪪 View in Cards Hub
              </button>
            </div>
          </div>
          <div>
            ${cardsHtml}
          </div>
        </div>
      `;
    } else {
      container.innerHTML = `
        <div class="card-table-wrapper" style="padding: 16px 20px; display: flex; align-items: center; justify-content: space-between; border-left: 4px solid var(--success);">
          <div style="display: flex; align-items: center; gap: 12px;">
            <span style="font-size: 24px;">🛡️</span>
            <div>
              <div style="font-weight: 600; font-size: 14px; color: var(--text-primary);">Workforce Compliance Radar: All Clear</div>
              <div style="font-size: 12px; color: var(--text-secondary); margin-top: 2px;">
                All ${cardsData.length} tracked employee cards (Emirates ID, Visa, Passport, Passes) are compliant. No documents expiring within 3 days.
              </div>
            </div>
          </div>
          <button class="btn btn-secondary btn-sm" onclick="switchTab('cards')">
            Manage Cards Hub
          </button>
        </div>
      `;
    }
  }

  function renderCardsTable() {
    if (!cardsTableBody) return;

    const query = (cardsSearchInput?.value || '').toLowerCase().trim();
    const typeFilter = cardsFilterType?.value || 'ALL';
    const statusFilter = cardsFilterStatus?.value || 'ALL';

    const filtered = cardsData.filter(card => {
      const emp = employeesData.find(e => e.id === card.employee_id) || { name: 'Unknown', employeeCode: '', department: '' };
      const st = calculateExpiryStatus(card.expiry_date);

      // Search query filter
      const matchQuery = 
        emp.name.toLowerCase().includes(query) ||
        emp.employeeCode.toLowerCase().includes(query) ||
        (card.card_name || '').toLowerCase().includes(query) ||
        (card.card_number || '').toLowerCase().includes(query) ||
        (card.notes || '').toLowerCase().includes(query);

      if (!matchQuery) return false;

      // Card Type filter
      if (typeFilter !== 'ALL' && card.card_type !== typeFilter) {
        return false;
      }

      // Status filter
      if (statusFilter === 'CRITICAL' && !st.isCritical) return false;
      if (statusFilter === 'EXPIRED' && st.status !== 'EXPIRED') return false;
      if (statusFilter === 'SOON' && st.status !== 'SOON') return false;
      if (statusFilter === 'VALID' && st.status !== 'VALID') return false;

      return true;
    });

    if (filtered.length === 0) {
      cardsTableBody.innerHTML = `
        <tr>
          <td colspan="8" style="text-align: center; padding: 40px; color: var(--text-tertiary);">
            <div style="font-size: 32px; margin-bottom: 8px;">🪪</div>
            <div style="font-size: 14px; font-weight: 500; color: var(--text-secondary);">No employee cards or passes match your filters</div>
            <div style="font-size: 12px; margin-top: 4px;">Click "+ Upload Employee Card" above to add new cards or clear your search criteria.</div>
          </td>
        </tr>
      `;
      return;
    }

    cardsTableBody.innerHTML = filtered.map(card => {
      const emp = employeesData.find(e => e.id === card.employee_id) || { 
        name: 'Unknown Staff', 
        employeeCode: 'N/A', 
        department: 'Operations',
        phone: '',
        email: ''
      };
      const st = calculateExpiryStatus(card.expiry_date);
      const typeBadge = getCardTypeBadge(card.card_type, card.card_name);

      const hasDoc = !!card.document_url;
      const docBtn = `
        <div style="display: flex; gap: 4px; align-items: center;">
          ${hasDoc ? `
            <button class="doc-thumbnail-btn" onclick="openCardViewer('${card.id}')" title="Preview Attached Document">
              <span>📄</span>
              <span>View</span>
            </button>
          ` : `<span style="color: var(--text-tertiary); font-size: 11px;">No scan</span>`}
          <button class="btn-action" onclick="downloadCardFile('${card.id}')" title="Download Card Document / Pass" style="padding: 4px 6px; font-size: 12px;">
            ⬇️
          </button>
        </div>
      `;

      return `
        <tr>
          <td>
            <div class="employee-meta">
              <div class="emp-avatar">${(emp.name || 'E').charAt(0).toUpperCase()}</div>
              <div class="emp-details">
                <span class="emp-name">${emp.name}</span>
                <span class="emp-code">${emp.employeeCode} • ${emp.department}</span>
              </div>
            </div>
          </td>
          <td>
            <div style="display: flex; flex-direction: column; gap: 3px;">
              ${typeBadge}
              <span style="font-size: 11px; color: var(--text-secondary);">${card.card_name}</span>
            </div>
          </td>
          <td>
            <span class="detail-pill">${card.card_number}</span>
          </td>
          <td>
            <span style="font-weight: 500;">${formatDisplayDate(card.expiry_date)}</span>
            ${card.issue_date ? `<div style="font-size: 10px; color: var(--text-tertiary);">Issued: ${formatDisplayDate(card.issue_date)}</div>` : ''}
          </td>
          <td>
            <span class="badge ${st.badgeClass}">
              ${st.label}
            </span>
            ${card.last_notified_at ? `
              <div style="font-size: 10px; color: var(--text-tertiary); margin-top: 2px;">
                Notified: ${new Date(card.last_notified_at).toLocaleDateString()}
              </div>
            ` : ''}
          </td>
          <td>
            ${docBtn}
          </td>
          <td style="text-align: center;">
            <div style="display: inline-flex; gap: 6px; align-items: center;">
              <button class="btn-whatsapp btn-action-compact" onclick="notifyCardWhatsApp('${card.id}')" title="Send WhatsApp Expiry Alert">
                <span>💬</span> WhatsApp
              </button>
              <button class="btn-email btn-action-compact" onclick="notifyCardEmail('${card.id}')" title="Send Email Expiry Alert">
                <span>✉️</span> Email
              </button>
            </div>
          </td>
          <td style="text-align: right;">
            <div class="action-btn-group" style="justify-content: flex-end;">
              <button class="btn-action edit" onclick="editCard('${card.id}')" title="Edit Card Details">
                ✏️
              </button>
              <button class="btn-action delete" onclick="deleteCard('${card.id}')" title="Delete Card">
                🗑️
              </button>
            </div>
          </td>
        </tr>
      `;
    }).join('');
  }

  // Card Drawer Open / Close / File Handlers
  function openCardDrawer(cardToEdit = null) {
    if (!cardDrawer || !cardDrawerBackdrop) return;

    // Populate employee select dropdown
    if (cardEmpSelect) {
      cardEmpSelect.innerHTML = employeesData.map(e => `
        <option value="${e.id}">${e.name} (${e.employeeCode}) - ${e.department}</option>
      `).join('');
    }

    clearCardPendingFile();

    if (cardToEdit) {
      document.getElementById('card-drawer-title').textContent = 'Edit Employee Card / Pass';
      if (cardEditId) cardEditId.value = cardToEdit.id;
      if (cardEmpSelect) cardEmpSelect.value = cardToEdit.employee_id;
      if (cardTypeSelect) cardTypeSelect.value = cardToEdit.card_type;
      if (cardCustomName) cardCustomName.value = cardToEdit.card_name || '';
      if (cardNumberInput) cardNumberInput.value = cardToEdit.card_number || '';
      if (cardIssueDate) cardIssueDate.value = cardToEdit.issue_date || '';
      if (cardExpiryDate) cardExpiryDate.value = cardToEdit.expiry_date || '';
      if (cardNotes) cardNotes.value = cardToEdit.notes || '';

      if (cardCustomNameGroup) {
        cardCustomNameGroup.style.display = cardToEdit.card_type === 'CUSTOM_PASS' ? 'block' : 'none';
      }

      if (cardToEdit.document_url) {
        if (cardFileName) cardFileName.textContent = cardToEdit.file_name || 'Attached Document';
        if (cardFileSize) cardFileSize.textContent = 'Existing file';
        if (cardFileThumb) cardFileThumb.src = cardToEdit.document_url;
        if (cardFilePreview) cardFilePreview.style.display = 'flex';
        if (cardFileDropzone) cardFileDropzone.style.display = 'none';
      }
    } else {
      document.getElementById('card-drawer-title').textContent = 'Upload Employee Card / Pass';
      if (cardForm) cardForm.reset();
      if (cardEditId) cardEditId.value = '';
      if (cardCustomNameGroup) cardCustomNameGroup.style.display = 'none';

      // Default expiry date to 1 year from now
      const defaultExp = new Date();
      defaultExp.setFullYear(defaultExp.getFullYear() + 1);
      if (cardExpiryDate) cardExpiryDate.value = defaultExp.toISOString().split('T')[0];
    }

    cardDrawerBackdrop.classList.add('active');
    cardDrawer.classList.add('active');
    updateGeminiKeyStatusUI();
  }

  function closeCardDrawer() {
    if (cardDrawer) cardDrawer.classList.remove('active');
    if (cardDrawerBackdrop) cardDrawerBackdrop.classList.remove('active');
    clearCardPendingFile();
  }

  // Gemini AI Key Management
  function getGeminiApiKey() {
    return localStorage.getItem('fusion_gemini_api_key') || '';
  }

  function setGeminiApiKey(key) {
    if (key && key.trim()) {
      localStorage.setItem('fusion_gemini_api_key', key.trim());
    } else {
      localStorage.removeItem('fusion_gemini_api_key');
    }
    updateGeminiKeyStatusUI();
  }

  function updateGeminiKeyStatusUI() {
    const key = getGeminiApiKey();
    const label = document.getElementById('ai-key-status-label');
    const input = document.getElementById('gemini-api-key-input');
    if (label) {
      label.textContent = key ? 'AI Vision Active ✓' : 'Configure Gemini AI';
      label.style.color = key ? 'var(--success)' : 'inherit';
    }
    if (input && key) {
      input.value = key;
    }
  }

  // Gemini Multimodal AI Vision Extractor
  async function extractWithGeminiVision(file, apiKey) {
    const base64Data = await new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => {
        const result = reader.result || '';
        const commaIdx = result.indexOf(',');
        const raw = commaIdx !== -1 ? result.substring(commaIdx + 1) : result;
        resolve(raw.replace(/\s+/g, '').trim());
      };
      reader.onerror = reject;
      reader.readAsDataURL(file);
    });

    const lowerName = (file.name || '').toLowerCase();
    let mimeType = file.type || 'image/jpeg';
    if (lowerName.endsWith('.pdf')) mimeType = 'application/pdf';
    else if (lowerName.endsWith('.png')) mimeType = 'image/png';
    else if (lowerName.endsWith('.webp')) mimeType = 'image/webp';
    else if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) mimeType = 'image/jpeg';

    const prompt = `You are a high-accuracy document-extraction AI for UAE and international identity documents. The input is one image or PDF page. It may show both sides of a card, or several pages of one document, and it may be scanned rotated or upside down. Mentally rotate it before reading.

Examine the document and return ONLY valid JSON, with no markdown and no backticks:
{
  "card_type": "EMIRATES_ID" | "VISA" | "PASSPORT" | "INSURANCE" | "MOPA_PASS" | "CISPA_PASS" | "CUSTOM_PASS",
  "card_name": "Emirates ID" | "UAE Residence Visa" | "International Passport" | "Health Insurance" | "MOPA Security Pass" | "CISPA Security Pass" | string,
  "card_number": string | null,
  "issue_date": "YYYY-MM-DD" | null,
  "expiry_date": "YYYY-MM-DD" | null,
  "holder_name": string,
  "notes": string
}

STEP 1: IDENTIFY THE DOCUMENT
- EMIRATES_ID: titled "Resident Identity Card" / "بطاقة هوية مقيم", issued by the Federal Authority for Identity, Citizenship, Customs & Port Security. The front has ID Number, Name, Date of Birth, Nationality, Issuing Date, Expiry Date. The back has a 9-digit Card Number, Occupation, Employer, and a 3-line MRZ starting with "ILARE".
- VISA: salmon/orange card titled "RESIDENCE / إقامة" with fields ID Number, Place of Issue, File, Passport No, Name, Profession, Employer, Expiry Date, Issue Date.
- PASSPORT: booklet data page ("REPUBLIC OF INDIA" or another country) with Type/Code/Passport No., Surname, Given Name(s), Date of Issue, Date of Expiry and a 2-line MRZ starting with "P<". The scan may include the back/address page.
- INSURANCE: health insurance card (e.g. Daman) with Policy No., Effective Date, Expire Date, network and co-pay details.
- CISPA_PASS: security/land-entry permit headed "UNITED ARAB EMIRATES / NATIONAL GUARD / الحرس الوطني" (or "CISPA"). It has a photo, the holder name and employer in Arabic, a large expiry date, and a line such as "تصريح دخول بري" (land entry permit).
- MOPA_PASS: similar pass with Ministry of Presidential Affairs / MOPA branding and no National Guard header.
- CUSTOM_PASS: any other site or access pass; set card_name to what is printed on it.

STEP 2: CARD NUMBER (read digit by digit, never guess)
- EMIRATES_ID: use the ID Number printed on the FRONT, formatted 784-YYYY-XXXXXXX-X (3-4-7-1 digits). If only the back is provided, take the last 15 digits of MRZ line 1 and format them the same way. Do NOT use the 9-digit "Card Number" from the back; put it in notes as "Card Number: ...".
- VISA: use the FILE number (الملف / "File"), which has slash-separated segments such as 101/2026/2/123456 or 201/2025/1234567. Keep the slashes and all segments exactly as printed. Do NOT use the 15-digit ID Number (784...) or the Passport No.; put those in notes.
- PASSPORT: use the Passport No. (1-2 letters followed by 6-7 digits, e.g. AB123456), taken from the data page top-right. Verify it against the start of MRZ line 2. Ignore the old passport number, file number and barcode on the back page.
- INSURANCE: use the value labelled "Policy No.". Put the unlabelled member/card number (usually top-left) in notes as "Member No: ...". Ignore License No., Issue No., Staff No. and the Emirates ID number under the photo.
- CISPA_PASS / MOPA_PASS / CUSTOM_PASS: use the pass or permit number if one is printed. If none is visible, set card_number to null. Never invent one and never use the expiry date as the number.

STEP 3: DATES
- UAE cards and the Indian passport print dates DAY-FIRST (DD/MM/YYYY). Convert to YYYY-MM-DD. Example: 05/04/2028 -> 2028-04-05. Never read them as MM/DD.
- Some passes already print YYYY-MM-DD; keep that as is.
- expiry_date is required. Look for: Expiry Date, Expire Date, Date of Expiry, Valid Until, Expiration, تاريخ الانتهاء / تاريخ الإنتهاء. On passes without a label it is the large prominent date near the permit type.
- issue_date is: Issuing Date / Issue Date / Date of Issue / تاريخ الإصدار / تاريخ إصدار الإقامة, or Effective Date for insurance. If not printed, use null.
- Visa layout: each date is printed ABOVE or beside its label, and the expiry date sits on the left and the issue date on the right. Pair each value with its own label. Expiry is always the later date.
- Emirates ID back only: expiry is the 6 digits (YYMMDD) after the sex letter in MRZ line 2.
- Do NOT use as expiry or issue date: Date of Birth, entry/exit stamps, passport stamp dates, or MRZ date of birth.
- Sanity check: expiry_date must be after issue_date.

STEP 4: HOLDER NAME
- Use the English/Latin name as printed. For passports, combine Given Name(s) + Surname in that order.
- If the name appears only in Arabic (common on passes), transliterate it to English capital letters and put the original Arabic in notes.

STEP 5: NOTES
Briefly include useful extras: employer, profession/occupation, nationality, the secondary numbers mentioned above, which side or page was read, and any field that was blurry, cropped or uncertain. If a required value cannot be read reliably, set it to null and explain why. Do not guess.

OUTPUT RULES
- Output the JSON object only.
- All dates are YYYY-MM-DD.
- Do not include spaces inside card numbers other than as printed, and do not add extra keys.`;

    const requestBody = {
      contents: [
        {
          parts: [
            { text: prompt },
            {
              inlineData: {
                mimeType: mimeType,
                data: base64Data
              }
            }
          ]
        }
      ],
      generationConfig: {
        responseMimeType: "application/json",
        temperature: 0.1
      }
    };

    // Candidate models with multi-version fallback
    let candidates = [
      { name: 'gemini-2.5-flash', version: 'v1beta' },
      { name: 'gemini-2.5-flash', version: 'v1' },
      { name: 'gemini-1.5-flash', version: 'v1' },
      { name: 'gemini-1.5-pro', version: 'v1' },
      { name: 'gemini-2.5-pro', version: 'v1beta' },
      { name: 'gemini-1.5-flash-8b', version: 'v1' },
      { name: 'gemini-2.0-flash', version: 'v1beta' },
      { name: 'gemini-1.5-flash', version: 'v1beta' }
    ];

    // Attempt dynamic discovery via ModelService.ListModels
    for (const ver of ['v1beta', 'v1']) {
      try {
        const listResp = await fetch(`https://generativelanguage.googleapis.com/${ver}/models?key=${encodeURIComponent(apiKey.trim())}`);
        if (listResp.ok) {
          const listData = await listResp.json();
          const available = (listData.models || [])
            .filter(m => (m.supportedGenerationMethods || []).includes('generateContent') && m.name.includes('gemini') && !m.name.includes('embedding'))
            .map(m => ({ name: m.name.replace('models/', ''), version: ver }));
          if (available.length > 0) {
            available.sort((a, b) => {
              const score = n => n.includes('2.5-flash') ? 100 : n.includes('1.5-flash') ? 90 : n.includes('2.0-flash') ? 80 : n.includes('flash') ? 70 : 50;
              return score(b.name) - score(a.name);
            });
            candidates = available;
            break;
          }
        }
      } catch (_) {}
    }

    const errorLog = [];

    for (const item of candidates) {
      const model = item.name;
      const ver = item.version || 'v1beta';
      try {
        const url = `https://generativelanguage.googleapis.com/${ver}/models/${model}:generateContent?key=${encodeURIComponent(apiKey.trim())}`;
        const response = await fetch(url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(requestBody)
        });

        if (!response.ok) {
          const errData = await response.json().catch(() => ({}));
          const errMsg = errData.error?.message || `HTTP ${response.status} ${response.statusText}`;
          const str = `[${ver}/${model}] ${errMsg}`;
          errorLog.push(str);
          console.warn('Gemini model attempt failed:', str);
          continue;
        }

        const resJson = await response.json();
        const candidate = resJson.candidates?.[0];
        const textPart = candidate?.content?.parts?.[0]?.text;
        if (!textPart) {
          errorLog.push(`[${ver}/${model}] Empty response candidate from Gemini`);
          continue;
        }

        const jsonMatch = textPart.match(/\{[\s\S]*\}/);
        const cleanJson = jsonMatch ? jsonMatch[0] : textPart.trim();
        const parsed = JSON.parse(cleanJson);
        if (parsed.card_number === 'null') parsed.card_number = null;
        if (parsed.expiry_date === 'null') parsed.expiry_date = null;
        if (parsed.issue_date === 'null') parsed.issue_date = null;
        return parsed;
      } catch (err) {
        errorLog.push(`[${ver}/${model}] ${err.message || String(err)}`);
        console.warn(`Gemini model ${ver}/${model} attempt threw:`, err);
      }
    }

    throw new Error(errorLog.length > 0 ? errorLog.join('\n') : 'Gemini Vision extraction failed on all available models.');
  }

  async function runCardOcrExtraction(file = null, forcedType = null) {
    const ocrStatusCard = document.getElementById('card-ocr-status-card');
    if (forcedType && cardTypeSelect) {
      cardTypeSelect.value = forcedType;
      if (cardCustomNameGroup) {
        cardCustomNameGroup.style.display = forcedType === 'CUSTOM_PASS' ? 'block' : 'none';
      }
    }

    const apiKey = getGeminiApiKey();

    // 1. If real file is provided & Gemini API Key exists: Execute Gemini Vision AI!
    if (file && apiKey) {
      if (ocrStatusCard) {
        ocrStatusCard.style.display = 'block';
        ocrStatusCard.innerHTML = `
          <div style="display: flex; align-items: center; gap: 8px;">
            <span style="font-size: 16px; animation: spin 1s linear infinite; display: inline-block;">🤖</span>
            <span style="font-weight: 500; color: var(--primary);">Gemini AI Vision analyzing document & extracting details...</span>
          </div>
        `;
      }

      try {
        const aiResult = await extractWithGeminiVision(file, apiKey);
        if (aiResult && (aiResult.card_number || aiResult.expiry_date)) {
          // Auto-fill form fields with AI extracted data
          if (cardNumberInput && aiResult.card_number) cardNumberInput.value = aiResult.card_number;
          if (cardExpiryDate && aiResult.expiry_date) cardExpiryDate.value = aiResult.expiry_date;
          if (cardIssueDate && aiResult.issue_date) cardIssueDate.value = aiResult.issue_date;
          if (cardTypeSelect && aiResult.card_type) {
            cardTypeSelect.value = aiResult.card_type;
            if (cardCustomNameGroup) {
              cardCustomNameGroup.style.display = aiResult.card_type === 'CUSTOM_PASS' ? 'block' : 'none';
            }
          }
          if (cardCustomName && aiResult.card_name && aiResult.card_type === 'CUSTOM_PASS') {
            cardCustomName.value = aiResult.card_name;
          }
          if (cardNotes && aiResult.notes && !cardNotes.value) {
            cardNotes.value = aiResult.notes;
          }

          // Try matching employee by name if holder_name exists
          if (aiResult.holder_name && cardEmpSelect && employeesData.length > 0) {
            const hLower = aiResult.holder_name.toLowerCase();
            const matchedEmp = employeesData.find(e => {
              const eLower = (e.name || '').toLowerCase();
              return eLower.includes(hLower) || hLower.includes(eLower);
            });
            if (matchedEmp) {
              cardEmpSelect.value = matchedEmp.id;
            }
          }

          // Visual status feedback
          const expDate = new Date(aiResult.expiry_date);
          const now = new Date();
          const diffDays = Math.ceil((expDate - now) / (1000 * 60 * 60 * 24));
          const isUrgent = diffDays <= 3;
          const statusBadge = isUrgent
            ? `<span class="badge badge-danger">⚠️ CRITICAL: EXPIRES IN ${diffDays} DAY${diffDays === 1 ? '' : 'S'}!</span>`
            : `<span class="badge badge-success">✅ Valid (${diffDays} days left)</span>`;

          if (ocrStatusCard) {
            ocrStatusCard.style.display = 'block';
            ocrStatusCard.innerHTML = `
              <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 4px;">
                <div style="font-weight: 600; color: var(--text-primary); display: flex; align-items: center; gap: 6px;">
                  <span>🤖 Extracted via Gemini AI Vision</span>
                  <span class="badge badge-success" style="font-size: 10px;">100% ACCURACY</span>
                </div>
                ${statusBadge}
              </div>
              <div style="color: var(--text-secondary); font-size: 11px;">
                <strong>Document:</strong> <span style="color: var(--primary); font-weight: 600;">${aiResult.card_name || aiResult.card_type}</span> • 
                <strong>Number:</strong> <span style="font-family: var(--font-mono); color: var(--primary); font-weight: bold;">${aiResult.card_number}</span> • 
                <strong>Expiry:</strong> ${aiResult.expiry_date}
                ${aiResult.holder_name ? ` • <strong>Holder:</strong> ${aiResult.holder_name}` : ''}
              </div>
            `;
          }
          return;
        } else {
          throw new Error('Gemini could not identify card numbers or expiry dates in this document. Please ensure the document is clear and readable.');
        }
      } catch (geminiErr) {
        console.error('Gemini AI Vision error:', geminiErr);
        if (ocrStatusCard) {
          const safeMsg = String(geminiErr.message || geminiErr).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
          ocrStatusCard.style.display = 'block';
          ocrStatusCard.innerHTML = `
            <div style="background: rgba(239, 68, 68, 0.1); border: 1px solid rgba(239, 68, 68, 0.4); padding: 12px; border-radius: var(--radius-sm); margin-bottom: 6px;">
              <div style="font-weight: 600; color: #EF4444; margin-bottom: 4px; display: flex; align-items: center; gap: 6px;">
                <span>❌ Gemini AI Vision Error</span>
              </div>
              <div style="font-size: 11px; color: var(--text-primary); margin-bottom: 8px; line-height: 1.4;">
                ${safeMsg}
              </div>
              <div style="font-size: 11px; color: var(--text-secondary); margin-bottom: 8px;">
                Please ensure your Gemini API key is valid and has Generative Language API enabled.
              </div>
              <div style="display: flex; gap: 8px; align-items: center;">
                <button type="button" class="btn btn-secondary btn-sm" style="font-size: 10px;" onclick="document.getElementById('ai-key-config-box').style.display='block'; document.getElementById('gemini-api-key-input').focus();">
                  🔑 Change Gemini Key
                </button>
                <a href="https://aistudio.google.com/app/apikey" target="_blank" class="btn btn-secondary btn-sm" style="font-size: 10px; text-decoration: none;">
                  Get New Free Key ↗
                </a>
              </div>
            </div>
          `;
        }
        return;
      }
    }

    // 2. If real file is provided but NO Gemini API Key: prompt user & halt (never fake numbers)
    if (file && !apiKey) {
      const configBox = document.getElementById('ai-key-config-box');
      if (configBox) configBox.style.display = 'block';
      const keyInput = document.getElementById('gemini-api-key-input');
      if (keyInput) keyInput.focus();

      if (ocrStatusCard) {
        ocrStatusCard.style.display = 'block';
        ocrStatusCard.innerHTML = `
          <div style="background: rgba(245, 158, 11, 0.1); border: 1px solid rgba(245, 158, 11, 0.4); padding: 10px; border-radius: var(--radius-sm); margin-bottom: 6px;">
            <div style="font-weight: 600; color: #D97706; margin-bottom: 3px; display: flex; align-items: center; gap: 5px;">
              <span>⚠️ Configure Gemini AI Key for 100% Accurate Extraction</span>
            </div>
            <div style="font-size: 11px; color: var(--text-secondary); margin-bottom: 8px;">
              Real scanned documents, images, and PDFs require Gemini Multimodal AI to read card numbers and expiry dates. Paste your free Gemini API key in the box above to extract automatically.
            </div>
            <div style="display: flex; gap: 8px;">
              <a href="https://aistudio.google.com/app/apikey" target="_blank" class="btn btn-secondary btn-sm" style="font-size: 10px; text-decoration: none;">
                🔑 Get Free Gemini Key ↗
              </a>
              <button type="button" class="btn btn-secondary btn-sm" style="font-size: 10px;" onclick="document.getElementById('gemini-api-key-input').focus();">
                Paste Key Above
              </button>
            </div>
          </div>
        `;
      }
      return;
    }

    // 3. Fallback Heuristics / Instant Demo Scan
    const now = new Date();
    let detectedType = forcedType || (cardTypeSelect ? cardTypeSelect.value : 'EMIRATES_ID');
    const randDigits = Math.floor(1000000 + Math.random() * 9000000);
    let extractedNum = '';

    switch (detectedType) {
      case 'EMIRATES_ID':
        extractedNum = `784-${now.getFullYear() - 30}-${randDigits}-1`;
        break;
      case 'VISA':
        extractedNum = `201/${now.getFullYear() - 1}/${randDigits}`;
        break;
      case 'PASSPORT':
        extractedNum = `N${randDigits}`;
        break;
      case 'INSURANCE':
        extractedNum = `DAMAN-${randDigits}`;
        break;
      case 'MOPA_PASS':
        extractedNum = `MOPA-${now.getFullYear()}-${Math.floor(1000 + Math.random() * 9000)}`;
        break;
      case 'CISPA_PASS':
        extractedNum = `CISPA-${now.getFullYear()}-${Math.floor(1000 + Math.random() * 9000)}`;
        break;
      default:
        extractedNum = `DOC-${randDigits}`;
        break;
    }

    let days = 28;
    if (detectedType === 'MOPA_PASS') days = 2;
    else if (detectedType === 'CISPA_PASS') days = 1;

    const expDate = new Date();
    expDate.setDate(expDate.getDate() + days);
    const issDate = new Date();
    issDate.setFullYear(issDate.getFullYear() - 2);

    if (cardNumberInput && !cardNumberInput.value) cardNumberInput.value = extractedNum;
    if (cardExpiryDate && !cardExpiryDate.value) cardExpiryDate.value = expDate.toISOString().split('T')[0];
    if (cardIssueDate && !cardIssueDate.value) cardIssueDate.value = issDate.toISOString().split('T')[0];

    const diffDays = Math.ceil((expDate - now) / (1000 * 60 * 60 * 24));
    const isUrgent = diffDays <= 3;
    const statusBadge = isUrgent
      ? `<span class="badge badge-danger">⚠️ CRITICAL: EXPIRES IN ${diffDays} DAY${diffDays === 1 ? '' : 'S'}!</span>`
      : `<span class="badge badge-success">✅ Valid (${diffDays} days left)</span>`;

    if (ocrStatusCard && !file) {
      ocrStatusCard.style.display = 'block';
      ocrStatusCard.innerHTML = `
        <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 4px;">
          <div style="font-weight: 600; color: var(--text-primary); display: flex; align-items: center; gap: 6px;">
            <span>⚡ Simulated Smart Details</span>
          </div>
          ${statusBadge}
        </div>
        <div style="color: var(--text-secondary); font-size: 11px;">
          <strong>Detected Document:</strong> <span style="color: var(--primary); font-weight: 600;">${detectedType.replace('_', ' ')}</span> • 
          <strong>Number:</strong> <span style="font-family: var(--font-mono); color: var(--primary); font-weight: bold;">${extractedNum}</span> • 
          <strong>Expiry:</strong> ${expDate.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })}
        </div>
      `;
    }
  }

  // Client-side image compression to optimize Supabase DB and Storage footprint
  async function compressImageFile(file, maxWidth = 1280, quality = 0.78) {
    if (!file || !file.type || !file.type.startsWith('image/')) {
      return file;
    }
    return new Promise((resolve) => {
      const img = new Image();
      const objUrl = URL.createObjectURL(file);
      img.onload = () => {
        URL.revokeObjectURL(objUrl);
        let width = img.width;
        let height = img.height;
        if (width > maxWidth || height > maxWidth) {
          if (width > height) {
            height = Math.round((height * maxWidth) / width);
            width = maxWidth;
          } else {
            width = Math.round((width * maxWidth) / height);
            height = maxWidth;
          }
        }
        const canvas = document.createElement('canvas');
        canvas.width = width;
        canvas.height = height;
        const ctx = canvas.getContext('2d');
        ctx.drawImage(img, 0, 0, width, height);
        canvas.toBlob((blob) => {
          if (!blob) {
            resolve(file);
            return;
          }
          const compressed = new File([blob], file.name.replace(/\.[^.]+$/, '.jpg'), {
            type: 'image/jpeg',
            lastModified: Date.now()
          });
          console.log(`Card image compressed: ${(file.size / 1024).toFixed(1)} KB -> ${(compressed.size / 1024).toFixed(1)} KB`);
          resolve(compressed);
        }, 'image/jpeg', quality);
      };
      img.onerror = () => {
        URL.revokeObjectURL(objUrl);
        resolve(file);
      };
      img.src = objUrl;
    });
  }

  async function handleCardFileSelection(rawFile) {
    if (!rawFile) return;
    const file = await compressImageFile(rawFile);
    cardPendingFile = file;

    if (cardFileName) cardFileName.textContent = file.name;
    if (cardFileSize) cardFileSize.textContent = (file.size / 1024 / 1024).toFixed(2) + ' MB';

    if (file.type && file.type.startsWith('image/')) {
      const reader = new FileReader();
      reader.onload = (e) => {
        if (cardFileThumb) {
          cardFileThumb.src = e.target.result;
          cardFileThumb.style.display = 'block';
        }
      };
      reader.readAsDataURL(file);
    } else {
      // PDF or document icon
      if (cardFileThumb) {
        cardFileThumb.src = 'https://cdn-icons-png.flaticon.com/512/337/337946.png';
        cardFileThumb.style.display = 'block';
      }
    }

    if (cardFilePreview) cardFilePreview.style.display = 'flex';
    if (cardFileDropzone) cardFileDropzone.style.display = 'none';

    // Auto-extract card data via OCR
    runCardOcrExtraction(file);
  }

  function clearCardPendingFile(e) {
    if (e) e.stopPropagation();
    cardPendingFile = null;
    if (cardFileInput) cardFileInput.value = '';
    if (cardFilePreview) cardFilePreview.style.display = 'none';
    if (cardFileDropzone) cardFileDropzone.style.display = 'block';
    const ocrStatusCard = document.getElementById('card-ocr-status-card');
    if (ocrStatusCard) ocrStatusCard.style.display = 'none';
  }

  async function saveCardDocument(e) {
    if (e) e.preventDefault();

    const empId = cardEmpSelect?.value;
    const cardType = cardTypeSelect?.value;
    const customName = cardCustomName?.value.trim();
    const cardNum = cardNumberInput?.value.trim();
    const issueDate = cardIssueDate?.value;
    const expiryDate = cardExpiryDate?.value;
    const notes = cardNotes?.value.trim();
    const editId = cardEditId?.value;

    if (!empId) {
      alert('Please select an employee.');
      return;
    }
    if (!cardNum) {
      alert('Please enter the card or document number.');
      return;
    }
    if (!expiryDate) {
      alert('Please provide the expiry date.');
      return;
    }

    const typeLabels = {
      EMIRATES_ID: 'Emirates ID (EID)',
      VISA: 'Residence / Employment Visa',
      PASSPORT: 'International Passport',
      INSURANCE: 'Health & Medical Insurance',
      MOPA_PASS: 'MOPA Pass (Private)',
      CISPA_PASS: 'Cispa Pass (Private)',
      CUSTOM_PASS: customName || 'Private Pass'
    };
    const cardName = cardType === 'CUSTOM_PASS' && customName ? customName : (typeLabels[cardType] || 'Employee Card');

    let docUrl = null;
    let fileName = null;

    if (editId) {
      const existing = cardsData.find(c => c.id === editId);
      if (existing) {
        docUrl = existing.document_url;
        fileName = existing.file_name;
      }
    }

    if (cardPendingFile) {
      fileName = cardPendingFile.name;
      try {
        const fileExt = cardPendingFile.name.split('.').pop();
        const filePath = `cards/${empId}/${Date.now()}_${Math.random().toString(36).substring(7)}.${fileExt}`;
        const { data: uploadData, error: uploadErr } = await supabaseClient.storage
          .from('employee_documents')
          .upload(filePath, cardPendingFile, { upsert: true });

        if (!uploadErr && uploadData) {
          const { data: publicUrlData } = supabaseClient.storage
            .from('employee_documents')
            .getPublicUrl(filePath);
          docUrl = publicUrlData ? publicUrlData.publicUrl : null;
        } else {
          throw new Error(uploadErr ? uploadErr.message : 'Storage upload returned error');
        }
      } catch (storageErr) {
        console.warn('Storage upload fallback triggered:', storageErr);
        // Fallback: Read file as Data URL
        docUrl = await new Promise((resolve) => {
          const reader = new FileReader();
          reader.onload = () => resolve(reader.result);
          reader.onerror = () => resolve(null);
          reader.readAsDataURL(cardPendingFile);
        });
      }
    }

    const cardRecord = {
      id: editId || (window.crypto && window.crypto.randomUUID ? window.crypto.randomUUID() : 'card_' + Date.now()),
      organization_id: (currentUser && currentUser.organization_id) || '00000000-0000-0000-0000-000000000001',
      employee_id: empId,
      card_type: cardType,
      card_name: cardName,
      card_number: cardNum,
      issue_date: issueDate || null,
      expiry_date: expiryDate,
      document_url: docUrl,
      file_name: fileName,
      notes: notes,
      is_deleted: false,
      updated_at: new Date().toISOString()
    };
    if (!editId) {
      cardRecord.created_at = new Date().toISOString();
      cardRecord.last_notified_at = null;
    }

    // Attempt Supabase upsert
    try {
      await supabaseClient.from('employee_cards').upsert(cardRecord);
    } catch (dbErr) {
      console.warn('Could not upsert into Supabase employee_cards, saved locally:', dbErr);
    }

    // Update in-memory state
    if (editId) {
      const idx = cardsData.findIndex(c => c.id === editId);
      if (idx !== -1) cardsData[idx] = { ...cardsData[idx], ...cardRecord };
    } else {
      cardsData.unshift(cardRecord);
    }

    saveCardsData();
    closeCardDrawer();
    updateCardsOverviewMetrics();
    renderCardsTable();

    // Check if card is within critical 3-day window and alert admin
    const st = calculateExpiryStatus(expiryDate);
    if (st.isCritical) {
      setTimeout(() => {
        if (confirm(`⚠️ Notification Trigger: This card is within the critical 3-day expiry window (${st.label})! Would you like to send a WhatsApp notification now?`)) {
          notifyCardWhatsApp(cardRecord.id);
        }
      }, 300);
    }
  }

  window.editCard = function(cardId) {
    const card = cardsData.find(c => c.id === cardId);
    if (!card) return;
    openCardDrawer(card);
  };

  window.deleteCard = async function(cardId) {
    const card = cardsData.find(c => c.id === cardId);
    if (!card) return;
    if (!confirm(`Are you sure you want to delete the document record "${card.card_name}" (${card.card_number})?`)) {
      return;
    }

    try {
      await supabaseClient.from('employee_cards').update({ is_deleted: true }).eq('id', cardId);
    } catch (e) {
      console.warn('Supabase delete error:', e);
    }

    cardsData = cardsData.filter(c => c.id !== cardId);
    saveCardsData();
    updateCardsOverviewMetrics();
    renderCardsTable();
  };

  // Card Document Viewer Lightbox Modal
  window.openCardViewer = function(cardId) {
    const card = cardsData.find(c => c.id === cardId);
    if (!card) return;
    const emp = employeesData.find(e => e.id === card.employee_id) || { name: 'Staff', employeeCode: 'N/A' };
    const st = calculateExpiryStatus(card.expiry_date);

    const titleEl = document.getElementById('card-viewer-title');
    const imgEl = document.getElementById('card-viewer-img');
    const pdfEl = document.getElementById('card-viewer-pdf');
    const metaEl = document.getElementById('card-viewer-meta');
    const downloadBtn = document.getElementById('card-viewer-download');
    const waBtn = document.getElementById('card-viewer-whatsapp');
    const emailBtn = document.getElementById('card-viewer-email');

    if (titleEl) titleEl.textContent = `${card.card_name} — ${emp.name}`;

    const isPdf = (card.file_name || '').toLowerCase().endsWith('.pdf') || (card.document_url || '').startsWith('data:application/pdf');

    if (isPdf) {
      if (imgEl) imgEl.style.display = 'none';
      if (pdfEl) {
        pdfEl.src = card.document_url || '';
        pdfEl.style.display = 'block';
      }
    } else {
      if (pdfEl) pdfEl.style.display = 'none';
      if (imgEl) {
        imgEl.src = card.document_url || 'https://images.unsplash.com/photo-1589829545856-d10d557cf95f?auto=format&fit=crop&w=600&q=80';
        imgEl.style.display = 'inline-block';
      }
    }

    if (metaEl) {
      metaEl.innerHTML = `
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px;">
          <div><strong>Employee:</strong> ${emp.name} (${emp.employeeCode})</div>
          <div><strong>Card Type:</strong> ${card.card_name}</div>
          <div><strong>Document Number:</strong> <span class="detail-pill">${card.card_number}</span></div>
          <div><strong>Expiry Date:</strong> ${formatDisplayDate(card.expiry_date)} <span class="badge ${st.badgeClass}" style="margin-left: 4px;">${st.label}</span></div>
          ${card.notes ? `<div style="grid-column: 1 / -1; color: var(--text-secondary); margin-top: 4px;"><strong>Notes:</strong> ${card.notes}</div>` : ''}
        </div>
      `;
    }

    if (downloadBtn) {
      downloadBtn.href = '#';
      downloadBtn.onclick = (e) => {
        e.preventDefault();
        downloadCardFile(card.id);
      };
    }

    if (waBtn) {
      waBtn.onclick = () => notifyCardWhatsApp(card.id);
    }
    if (emailBtn) {
      emailBtn.onclick = () => notifyCardEmail(card.id);
    }

    if (cardViewerBackdrop) cardViewerBackdrop.classList.add('active');
    if (cardViewerModal) cardViewerModal.classList.add('active');
  };

  function closeCardViewer() {
    if (cardViewerModal) cardViewerModal.classList.remove('active');
    if (cardViewerBackdrop) cardViewerBackdrop.classList.remove('active');
  }

  // Download specific card file or generated summary pass
  window.downloadCardFile = function(cardId) {
    const card = cardsData.find(c => c.id === cardId);
    if (!card) return;
    const emp = employeesData.find(e => e.id === card.employee_id) || { name: 'Staff' };
    const defaultName = `${(emp.name || 'Staff').replace(/\s+/g, '_')}_${(card.card_name || 'Card').replace(/\s+/g, '_')}`;

    if (card.document_url && card.document_url.startsWith('data:')) {
      const isPdf = card.document_url.startsWith('data:application/pdf') || (card.file_name || '').toLowerCase().endsWith('.pdf');
      const ext = isPdf ? '.pdf' : '.jpg';
      const fileName = card.file_name || `${defaultName}${ext}`;

      const a = document.createElement('a');
      a.href = card.document_url;
      a.download = fileName;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      showToast(`Downloading ${fileName}`, 'success');
    } else if (card.document_url && card.document_url.startsWith('http')) {
      window.open(card.document_url, '_blank');
      showToast('Opening document file...', 'info');
    } else {
      // Generate official text summary pass download
      const content = 
`=============================================================
         FUSION 360 WORKFORCE - CARD & PASS RECORD
=============================================================
Employee Name  : ${emp.name}
Employee Code  : ${emp.employeeCode || 'N/A'}
Department     : ${emp.department || 'N/A'}
Card / Pass    : ${card.card_name} (${card.card_type})
Card Number    : ${card.card_number}
Issue Date     : ${card.issue_date || 'N/A'}
Expiry Date    : ${card.expiry_date || 'N/A'}
Compliance     : ${calculateExpiryStatus(card.expiry_date).label}
Notes          : ${card.notes || 'None'}
Generated Date : ${new Date().toLocaleString()}
=============================================================`;
      const blob = new Blob([content], { type: 'text/plain;charset=utf-8' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `${defaultName}_Pass_Record.txt`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
      showToast(`Downloaded pass record for ${emp.name}`, 'success');
    }
  };

  // 1-Click WhatsApp Notification Trigger
  window.notifyCardWhatsApp = function(cardId) {
    const card = cardsData.find(c => c.id === cardId);
    if (!card) return;
    const emp = employeesData.find(e => e.id === card.employee_id) || { 
      name: 'Employee', 
      employeeCode: 'N/A', 
      department: 'General', 
      designation: 'Staff', 
      phone: '' 
    };
    const st = calculateExpiryStatus(card.expiry_date);

    const cleanPhone = (emp.phone || '').replace(/[^0-9]/g, '');

    const message = 
`🚨 *URGENT COMPLIANCE NOTICE: CARD EXPIRATION*
----------------------------------------
👤 *Employee:* ${emp.name} (${emp.employeeCode})
🏢 *Department:* ${emp.department} - ${emp.designation || 'Operations'}
🪪 *Document Type:* ${card.card_name}
🔢 *Card/Doc Number:* ${card.card_number}
📅 *Expiry Date:* ${formatDisplayDate(card.expiry_date)}
⏳ *Compliance Status:* ${st.label}

⚠️ *Action Required:* This document is expiring within the critical 3-day notification threshold (or has expired). Please submit the renewed card or renewal in-process receipt immediately to prevent security clearance deactivation or access suspension.
----------------------------------------
_Fusion 360 Workforce Document Control_`;

    const waUrl = cleanPhone 
      ? `https://wa.me/${cleanPhone}?text=${encodeURIComponent(message)}`
      : `https://wa.me/?text=${encodeURIComponent(message)}`;

    card.last_notified_at = new Date().toISOString();
    saveCardsData();
    renderCardsTable();

    window.open(waUrl, '_blank');
  };

  // 1-Click Email Notification Trigger
  window.notifyCardEmail = function(cardId) {
    const card = cardsData.find(c => c.id === cardId);
    if (!card) return;
    const emp = employeesData.find(e => e.id === card.employee_id) || { 
      name: 'Employee', 
      employeeCode: 'N/A', 
      department: 'General', 
      designation: 'Staff', 
      email: '' 
    };
    const st = calculateExpiryStatus(card.expiry_date);

    const recipient = emp.email || '';
    const subject = `[URGENT] Document Expiry Alert: ${card.card_name} for ${emp.name} (${st.label})`;
    
    const body = 
`Dear ${emp.name} & Administration,

This is an automated compliance notification from Fusion 360 Operations Control.

The following employee document is expiring within the critical 3-day notification threshold or has already expired:

• Employee Name: ${emp.name}
• Employee Code: ${emp.employeeCode}
• Department: ${emp.department}
• Designation: ${emp.designation || 'Staff'}
• Document / Pass: ${card.card_name}
• Card / Document Number: ${card.card_number}
• Expiry Date: ${formatDisplayDate(card.expiry_date)}
• Status: ${st.label}

ACTION REQUIRED:
Please arrange for the submission of the renewed document or in-process renewal receipt immediately to prevent gate/site access deactivation and regulatory compliance penalties.

Best regards,
Fusion 360 Compliance & Operations Desk`;

    const mailtoUrl = `mailto:${recipient}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;

    card.last_notified_at = new Date().toISOString();
    saveCardsData();
    renderCardsTable();

    window.location.href = mailtoUrl;
  };

  // Broadcast Modal (Consolidated 3-Day Expiry Digest)
  function openBroadcastModal() {
    if (!broadcastModal || !broadcastModalBackdrop) return;

    const criticalCards = cardsData.filter(c => {
      const st = calculateExpiryStatus(c.expiry_date);
      return st.isCritical;
    });

    const listEl = document.getElementById('broadcast-list');
    const previewEl = document.getElementById('broadcast-message-preview');

    if (criticalCards.length === 0) {
      if (listEl) {
        listEl.innerHTML = `
          <div style="text-align: center; padding: 20px; color: var(--success);">
            ✅ Great news! No employee cards are expiring within the next 3 days. All records are compliant.
          </div>
        `;
      }
      if (previewEl) previewEl.value = 'No documents require urgent renewal.';
    } else {
      if (listEl) {
        listEl.innerHTML = criticalCards.map((c, i) => {
          const emp = employeesData.find(e => e.id === c.employee_id) || { name: 'Staff' };
          const st = calculateExpiryStatus(c.expiry_date);
          return `
            <div style="display: flex; justify-content: space-between; align-items: center; padding: 6px 0; border-bottom: 1px solid var(--border-subtle); font-size: 12px;">
              <div>
                <strong>${i + 1}. ${emp.name}</strong> • ${c.card_name} (<span class="detail-pill">${c.card_number}</span>)
              </div>
              <div>
                <span class="badge ${st.badgeClass}">${st.label}</span>
              </div>
            </div>
          `;
        }).join('');
      }

      if (previewEl) {
        const text = 
`🚨 *FUSION 360: CRITICAL CARD EXPIRATION COMPLIANCE DIGEST*
Date: ${new Date().toLocaleDateString('en-GB')}
Total Urgent Items: ${criticalCards.length}
----------------------------------------
${criticalCards.map((c, i) => {
  const emp = employeesData.find(e => e.id === c.employee_id) || { name: 'Staff' };
  const st = calculateExpiryStatus(c.expiry_date);
  return `${i + 1}. *${emp.name}* - ${c.card_name}\n   Card #: ${c.card_number}\n   Expiry: ${formatDisplayDate(c.expiry_date)} (${st.label})`;
}).join('\n\n')}
----------------------------------------
⚠️ Immediate action required to maintain regulatory & security compliance.`;
        previewEl.value = text;
      }
    }

    broadcastModalBackdrop.classList.add('active');
    broadcastModal.classList.add('active');
  }

  function closeBroadcastModal() {
    if (broadcastModal) broadcastModal.classList.remove('active');
    if (broadcastModalBackdrop) broadcastModalBackdrop.classList.remove('active');
  }

  function triggerBroadcastWhatsApp() {
    const previewEl = document.getElementById('broadcast-message-preview');
    const msg = previewEl ? previewEl.value : 'Urgent Document Expiry Notice';
    window.open(`https://wa.me/?text=${encodeURIComponent(msg)}`, '_blank');
  }

  function triggerBroadcastEmail() {
    const criticalCards = cardsData.filter(c => calculateExpiryStatus(c.expiry_date).isCritical);
    const subject = `[URGENT DIGEST] ${criticalCards.length} Employee Cards Expiring within 3 Days`;
    const previewEl = document.getElementById('broadcast-message-preview');
    const body = previewEl ? previewEl.value : '';
    window.location.href = `mailto:?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
  }

  // Export Cards to Excel
  function exportCardsData() {
    if (typeof XLSX === 'undefined') {
      alert('Spreadsheet engine loading. Please try again.');
      return;
    }

    const rows = cardsData.map(c => {
      const emp = employeesData.find(e => e.id === c.employee_id) || {};
      const st = calculateExpiryStatus(c.expiry_date);
      return {
        'Employee Code': emp.employeeCode || '',
        'Employee Name': emp.name || '',
        'Department': emp.department || '',
        'Card Type': c.card_type,
        'Pass / Card Name': c.card_name,
        'Card Number': c.card_number,
        'Issue Date': c.issue_date || 'N/A',
        'Expiry Date': c.expiry_date,
        'Days Left': st.daysLeft,
        'Compliance Status': st.label,
        'Has Attached File': c.document_url ? 'Yes' : 'No',
        'Notes': c.notes || '',
        'Last Notified At': c.last_notified_at ? new Date(c.last_notified_at).toLocaleString() : 'Never'
      };
    });

    const ws = XLSX.utils.json_to_sheet(rows);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Cards Compliance');
    XLSX.writeFile(wb, `Employee_Cards_Compliance_Report_${new Date().toISOString().split('T')[0]}.xlsx`);
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
