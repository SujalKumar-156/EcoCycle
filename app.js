const pageNames = {
  overview: "Overview",
  waste: "Waste items",
  pickups: "Pickup requests",
  inventory: "Inventory",
  shipments: "Shipments",
  recycling: "Recycling",
};

const pageContent = document.querySelector("#page-content");
const searchInput = document.querySelector("#global-search");
const pickupDialog = document.querySelector("#pickup-dialog");
const pickupForm = document.querySelector("#pickup-form");
const formFeedback = document.querySelector("#form-feedback");

let currentPage = "overview";
let currentSearch = "";
let currentStatus = "all";
let pageData = null;
let demoMode = false;

const demoData = {
  dashboard: {
    total_registered_items: 6,
    pending_pickup_requests: 2,
    total_shipments: 6,
    completed_recycling_batches: 2,
    total_recovered_material_kg: "3.80",
  },
  items: [
    { item_id: 6, item_name: "Laptop", brand: "Dell", item_condition: "Damaged", category_name: "Computers", user_name: "Priya Singh", user_email: "priya@example.com", weight_kg: "2.50", status: "REGISTERED", registered_at: "2026-11-23" },
    { item_id: 5, item_name: "Smartphone", brand: "Samsung", item_condition: "Broken screen", category_name: "Mobile Devices", user_name: "Priya Singh", user_email: "priya@example.com", weight_kg: "0.30", status: "REGISTERED", registered_at: "2026-11-23" },
    { item_id: 4, item_name: "Desktop computer", brand: "HP", item_condition: "Old", category_name: "Computers", user_name: "Aman Kumar", user_email: "aman@example.com", weight_kg: "8.00", status: "COLLECTED", registered_at: "2026-11-22" },
    { item_id: 3, item_name: "Microwave oven", brand: "LG", item_condition: "Not working", category_name: "Home Appliances", user_name: "Aman Kumar", user_email: "aman@example.com", weight_kg: "12.00", status: "IN_TRANSIT", registered_at: "2026-11-21" },
  ],
  pickup_requests: [
    { request_id: 6, item_name: "Laptop", user_name: "Priya Singh", user_email: "priya@example.com", centre_name: "Patna E-Waste Centre", city: "Patna", requested_date: "2026-11-24", preferred_slot: "10 AM – 12 PM", status: "PENDING" },
    { request_id: 5, item_name: "Smartphone", user_name: "Priya Singh", user_email: "priya@example.com", centre_name: "Patna E-Waste Centre", city: "Patna", requested_date: "2026-11-24", preferred_slot: "12 PM – 2 PM", status: "PENDING" },
    { request_id: 4, item_name: "Desktop computer", user_name: "Aman Kumar", user_email: "aman@example.com", centre_name: "Bihta Collection Hub", city: "Bihta", requested_date: "2026-11-25", preferred_slot: "10 AM – 12 PM", status: "ASSIGNED" },
  ],
  batches: [
    {
      batch_id: 2,
      batch_code: "ECO-BATCH-002",
      facility_name: "Tech Recovery Unit",
      facility_city: "Bihta",
      processed_at: "2026-11-22",
      status: "COMPLETED",
      recovered_materials: [
        { material_name: "Copper", recovered_weight_kg: "0.80", unit: "kg" },
        { material_name: "Iron", recovered_weight_kg: "1.20", unit: "kg" },
        { material_name: "Plastic", recovered_weight_kg: "0.50", unit: "kg" },
      ],
    },
  ],
};

const escapeHtml = (value) => String(value ?? "").replace(/[&<>"']/g, (character) => ({
  "&": "&amp;",
  "<": "&lt;",
  ">": "&gt;",
  '"': "&quot;",
  "'": "&#39;",
}[character]));

async function api(path, options = {}) {
  let response;
  try {
    response = await fetch(path, {
      ...options,
      headers: {
        ...(options.body ? { "Content-Type": "application/json" } : {}),
        ...options.headers,
      },
    });
  } catch {
    throw new Error("Cannot reach the EcoCycle API. Start Flask with `python app.py` and open http://127.0.0.1:5000.");
  }

  const result = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(result.error || `Request failed (${response.status}).`);
  }
  return result;
}

function formatWeight(value, unit = "kg") {
  const weight = Number(value);
  return Number.isFinite(weight) ? `${weight.toFixed(2)} ${unit}` : "—";
}

function formatDate(value) {
  if (!value) return "—";
  const parsed = new Date(`${String(value).slice(0, 10)}T00:00:00`);
  return Number.isNaN(parsed.getTime())
    ? escapeHtml(value)
    : new Intl.DateTimeFormat("en-IN", { day: "numeric", month: "short", year: "numeric" }).format(parsed);
}

function formatStatus(status) {
  const value = String(status || "UNKNOWN");
  return value.toLowerCase().replace(/_/g, " ").replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function statusBadge(status) {
  const label = formatStatus(status);
  const className = label.toLowerCase().replace(/\s+/g, "-");
  return `<span class="status ${escapeHtml(className)}">${escapeHtml(label)}</span>`;
}

function heading(title, subtitle, eyebrow = "E-WASTE MANAGEMENT", showPickupAction = false) {
  const today = new Intl.DateTimeFormat("en-IN", {
    weekday: "long",
    day: "numeric",
    month: "long",
    year: "numeric",
  }).format(new Date());
  return `
    <div class="page-heading">
      <div>
        <div class="eyebrow">${escapeHtml(eyebrow)}</div>
        <h1>${title}</h1>
        <p class="heading-subtitle">${escapeHtml(subtitle)}</p>
      </div>
      <div class="heading-actions">
        <div class="date-pill"><span aria-hidden="true">▦</span> ${escapeHtml(today)}</div>
        ${showPickupAction ? `<button class="primary-button" type="button" data-open-pickup><span aria-hidden="true">＋</span> Schedule a pickup</button>` : ""}
      </div>
    </div>`;
}

function updateNavigation() {
  document.querySelector("#breadcrumb-current").textContent = pageNames[currentPage];
  const banner = document.querySelector(".prototype-banner");
  if (banner) {
    const bannerText = banner.querySelector("span:nth-child(2)");
    if (bannerText) {
      bannerText.innerHTML = demoMode
        ? "<strong>Demo mode</strong> &nbsp;Showing sample records because MySQL is unavailable. Live database actions remain enabled in the API."
        : "<strong>Database-backed preview</strong> &nbsp;Records load from MySQL. Waste registration and pickup scheduling are available.";
    }
  }
  document.querySelectorAll(".nav-link").forEach((link) => {
    const active = link.dataset.page === currentPage;
    link.classList.toggle("active", active);
    if (active) link.setAttribute("aria-current", "page");
    else link.removeAttribute("aria-current");
  });
  document.querySelector("#sidebar").classList.remove("open");

  if (pageData?.items) {
    document.querySelector("#waste-count").textContent = String(pageData.items.length).padStart(2, "0");
  }
  if (pageData?.pickup_requests) {
    document.querySelector("#pickup-count").textContent = String(pageData.pickup_requests.length).padStart(2, "0");
  }
}

function renderLoading() {
  pageContent.innerHTML = `<div class="panel loading-state" role="status"><span class="loading-spinner"></span> Loading ${escapeHtml(pageNames[currentPage].toLowerCase())} from EcoCycle…</div>`;
}

function renderError(error) {
  pageContent.innerHTML = `
    <section class="panel api-error" role="alert">
      <span class="api-error-icon" aria-hidden="true">!</span>
      <div><h2>Could not load ${escapeHtml(pageNames[currentPage].toLowerCase())}</h2><p>${escapeHtml(error.message)}</p>
      <button class="secondary-button" type="button" data-retry>Try again</button></div>
    </section>`;
}

function categoryBreakdown(items) {
  const categories = new Map();
  for (const item of items) {
    const weight = Number(item.weight_kg);
    if (Number.isFinite(weight) && weight > 0) {
      const label = item.category_name || "Other";
      categories.set(label, (categories.get(label) || 0) + weight);
    }
  }
  const total = [...categories.values()].reduce((sum, weight) => sum + weight, 0);
  if (!total) return `<div class="empty-state">No item weights are available yet.</div>`;
  return [...categories.entries()]
    .sort((left, right) => right[1] - left[1])
    .map(([name, weight], index) => {
      const percent = Math.round((weight / total) * 100);
      return `<div class="category-row">
        <div class="category-heading"><span>${escapeHtml(name)}</span><strong>${percent}%</strong></div>
        <div class="category-track"><div class="category-fill tone-${(index % 4) + 1}" style="width:${percent}%"></div></div>
      </div>`;
    }).join("");
}

function wasteRow(item) {
  const brandAndCondition = [item.brand, item.item_condition].filter(Boolean).join(" · ");
  const initials = (item.item_name || "E").slice(0, 1).toUpperCase();
  return [
    `<span class="item-cell"><span class="item-thumb">${escapeHtml(initials)}</span><span class="item-name">${escapeHtml(item.item_name)}<small>EW-${escapeHtml(item.item_id)}${brandAndCondition ? ` · ${escapeHtml(brandAndCondition)}` : ""}</small></span></span>`,
    escapeHtml(item.category_name),
    escapeHtml(item.user_name),
    formatDate(item.registered_at),
    formatWeight(item.weight_kg),
    statusBadge(item.status),
  ];
}

function pickupRow(pickup) {
  return [
    `PR-${escapeHtml(pickup.request_id)}`,
    `<span class="item-name">${escapeHtml(pickup.item_name)}<small>${escapeHtml(pickup.user_name)} · ${escapeHtml(pickup.user_email)}</small></span>`,
    `<span class="item-name">${escapeHtml(pickup.centre_name)}<small>${escapeHtml(pickup.city)}</small></span>`,
    formatDate(pickup.requested_date),
    escapeHtml(pickup.preferred_slot || "Not specified"),
    statusBadge(pickup.status),
  ];
}

function recyclingRow(batch) {
  const materials = batch.recovered_materials || [];
  const materialNames = materials.length
    ? materials.map((material) => `${material.material_name} (${formatWeight(material.recovered_weight_kg, material.unit || "kg")})`).join(", ")
    : "None recorded";
  return [
    escapeHtml(batch.batch_code),
    `<span class="item-name">${escapeHtml(batch.facility_name)}<small>${escapeHtml(batch.facility_city)}</small></span>`,
    formatDate(batch.processed_at),
    materialNames,
    statusBadge(batch.status),
  ];
}

function renderTable(rows, columns, emptyMessage) {
  const headings = columns.map((column) => `<th>${escapeHtml(column)}</th>`).join("");
  const body = rows.length
    ? rows.map((row) => `<tr>${row.map((cell) => `<td>${cell}</td>`).join("")}</tr>`).join("")
    : `<tr><td class="empty-state" colspan="${columns.length}">${escapeHtml(emptyMessage)}</td></tr>`;
  return `<div class="table-scroll"><table class="data-table"><thead><tr>${headings}</tr></thead><tbody>${body}</tbody></table></div>`;
}

function filteredRows(rows, searchText) {
  const search = currentSearch.trim().toLowerCase();
  return rows.filter((row) => {
    const matchesText = !search || JSON.stringify(row).toLowerCase().includes(search);
    const matchesStatus = currentStatus === "all" || String(row.status).toLowerCase() === currentStatus;
    return matchesText && matchesStatus;
  });
}

function renderOverview() {
  const { dashboard, items, pickup_requests: pickups } = pageData;
  const recentItems = items.filter((item) => !currentSearch || JSON.stringify(item).toLowerCase().includes(currentSearch.toLowerCase())).slice(0, 4);
  const recentPickups = pickups.slice(0, 4);
  return `
    ${heading("EcoCycle overview", "Here’s what’s happening across your e-waste network today.", "E-WASTE MANAGEMENT", true)}
    <div class="stats-grid">
      <article class="stat-card"><div class="stat-top"><span>Registered e-waste items</span><span class="stat-icon">♧</span></div><div class="stat-value">${Number(dashboard.total_registered_items || 0)}</div><div class="stat-foot"><span>All registered items</span></div></article>
      <article class="stat-card"><div class="stat-top"><span>Pending pickups</span><span class="stat-icon orange">↗</span></div><div class="stat-value">${Number(dashboard.pending_pickup_requests || 0)}</div><div class="stat-foot"><span>Requests awaiting collection</span></div></article>
      <article class="stat-card"><div class="stat-top"><span>Total shipments</span><span class="stat-icon blue">⇢</span></div><div class="stat-value">${Number(dashboard.total_shipments || 0)}</div><div class="stat-foot"><span>Recorded in the database</span></div></article>
      <article class="stat-card"><div class="stat-top"><span>Recovered material</span><span class="stat-icon purple">✳</span></div><div class="stat-value">${formatWeight(dashboard.total_recovered_material_kg)}</div><div class="stat-foot"><span class="stat-change neutral">${Number(dashboard.completed_recycling_batches || 0)} completed batches</span></div></article>
    </div>
    <div class="dashboard-grid">
      <section class="panel">
        <div class="panel-header"><div><h2 class="panel-title">Recent pickup requests</h2><p class="panel-subtitle">Latest collection schedules from MySQL</p></div><button class="text-button" type="button" data-page="pickups">View all →</button></div>
        ${renderTable(recentPickups.map(pickupRow), ["Request", "Item & contributor", "Centre", "Date", "Time slot", "Status"], "No pickup requests have been registered.")}
      </section>
      <section class="panel category-panel">
        <div class="panel-header"><div><h2 class="panel-title">Waste by category</h2><p class="panel-subtitle">Calculated from registered item weights</p></div></div>
        <div class="category-list">${categoryBreakdown(items)}</div>
      </section>
    </div>
    <section class="panel table-panel">
      <div class="panel-header"><div><h2 class="panel-title">Recent waste items</h2><p class="panel-subtitle">Latest items registered in the database</p></div><button class="text-button" type="button" data-page="waste">View all items →</button></div>
      ${renderTable(recentItems.map(wasteRow), ["Item", "Category", "Contributor", "Registered", "Weight", "Status"], "No waste items match your search.")}
      <div class="table-foot"><span>Showing <strong>${recentItems.length}</strong>${currentSearch ? "" : ` of ${items.length}`} items</span><button class="text-button" type="button" data-page="waste">View all items →</button></div>
    </section>`;
}

const tablePageConfigs = {
  waste: {
    title: "Waste items",
    subtitle: "Track registered devices from collection through recycling.",
    eyebrow: "COLLECTION",
    columns: ["Item", "Category", "Contributor", "Registered", "Weight", "Status"],
    rows: () => pageData.items,
    map: wasteRow,
  },
  pickups: {
    title: "Pickup requests",
    subtitle: "Coordinate collection schedules across your centres.",
    eyebrow: "COLLECTION",
    columns: ["Request", "Item & contributor", "Collection centre", "Scheduled date", "Time slot", "Status"],
    rows: () => pageData.pickup_requests,
    map: pickupRow,
  },
  recycling: {
    title: "Recycling",
    subtitle: "See what each batch processed and the materials recovered.",
    eyebrow: "RECOVERY",
    columns: ["Batch", "Facility", "Processed", "Recovered materials", "Status"],
    rows: () => pageData.batches,
    map: recyclingRow,
  },
};

function renderTablePage() {
  const config = tablePageConfigs[currentPage];
  const rows = config.rows();
  const visibleRows = filteredRows(rows, currentSearch);
  const statuses = [...new Set(rows.map((row) => String(row.status).toLowerCase()))];
  return `
    ${heading(config.title, config.subtitle, config.eyebrow, currentPage === "pickups")}
    <section class="panel table-panel">
      <div class="panel-header">
        <div><h2 class="panel-title">${escapeHtml(config.title)} <span class="record-count">(${visibleRows.length})</span></h2><p class="panel-subtitle">Live records from the EcoCycle database</p></div>
        <div class="table-controls"><select class="filter-select" id="status-filter" aria-label="Filter by status"><option value="all">All statuses</option>${statuses.map((status) => `<option value="${escapeHtml(status)}"${currentStatus === status ? " selected" : ""}>${escapeHtml(formatStatus(status))}</option>`).join("")}</select></div>
      </div>
      ${renderTable(visibleRows.map(config.map), config.columns, `No ${config.title.toLowerCase()} match your search or filter.`)}
      <div class="table-foot"><span>Showing <strong>${visibleRows.length}</strong> of ${rows.length} records</span><span>Loaded from MySQL</span></div>
    </section>`;
}

function renderUnavailablePage() {
  const title = pageNames[currentPage];
  return `${heading(title, `${title} management is not included in the current API endpoints.`, "OPERATIONS")}
    <section class="panel empty-feature"><span class="stat-icon blue">↗</span><h2>${escapeHtml(title)} API not connected</h2><p>The database tables exist, but this page is waiting for its API operations to be implemented.</p></section>`;
}

function renderCurrentPage() {
  if (!pageData) return;
  if (currentPage === "overview") pageContent.innerHTML = renderOverview();
  else if (tablePageConfigs[currentPage]) pageContent.innerHTML = renderTablePage();
  else pageContent.innerHTML = renderUnavailablePage();
}

async function loadCurrentPage() {
  updateNavigation();
  renderLoading();
  pageData = null;
  try {
    if (currentPage === "overview") {
      const [dashboard, waste, pickup] = await Promise.all([
        api("/api/dashboard"),
        api("/api/waste-items"),
        api("/api/pickup-requests"),
      ]);
      pageData = { dashboard, items: waste.items, pickup_requests: pickup.pickup_requests };
    } else if (currentPage === "waste") {
      const result = await api("/api/waste-items");
      pageData = { items: result.items };
    } else if (currentPage === "pickups") {
      const result = await api("/api/pickup-requests");
      pageData = { pickup_requests: result.pickup_requests };
    } else if (currentPage === "recycling") {
      const result = await api("/api/recycling");
      pageData = { batches: result.batches };
    } else {
      pageData = {};
    }
    updateNavigation();
    renderCurrentPage();
  } catch (error) {
    demoMode = true;
    if (currentPage === "overview") {
      pageData = {
        dashboard: demoData.dashboard,
        items: demoData.items,
        pickup_requests: demoData.pickup_requests,
      };
    } else if (currentPage === "waste") {
      pageData = { items: demoData.items };
    } else if (currentPage === "pickups") {
      pageData = { pickup_requests: demoData.pickup_requests };
    } else if (currentPage === "recycling") {
      pageData = { batches: demoData.batches };
    } else {
      pageData = {};
    }
    updateNavigation();
    renderCurrentPage();
  }
}

function setFormFeedback(message, kind) {
  formFeedback.textContent = message;
  formFeedback.className = `form-feedback ${kind}`;
  formFeedback.hidden = false;
}

function replaceOptions(select, entries, valueKey, labelKey, placeholder) {
  select.innerHTML = `<option value="" disabled selected>${escapeHtml(placeholder)}</option>${entries.map((entry) =>
    `<option value="${escapeHtml(entry[valueKey])}">${escapeHtml(entry[labelKey])}</option>`
  ).join("")}`;
  select.disabled = entries.length === 0;
  if (!entries.length) select.innerHTML = `<option value="" disabled selected>No options available</option>`;
}

async function openPickupForm() {
  pickupForm.reset();
  formFeedback.hidden = true;
  formFeedback.textContent = "";
  const categorySelect = pickupForm.elements.category;
  const centreSelect = pickupForm.elements.centre;
  categorySelect.disabled = true;
  centreSelect.disabled = true;
  categorySelect.innerHTML = "<option value='' selected>Loading categories...</option>";
  centreSelect.innerHTML = "<option value='' selected>Loading centres...</option>";
  pickupForm.elements.date.min = new Date().toISOString().slice(0, 10);
  pickupDialog.showModal();
  try {
    const [categoryResult, centreResult] = await Promise.all([
      api("/api/categories"),
      api("/api/centres"),
    ]);
    replaceOptions(categorySelect, categoryResult.categories, "category_id", "category_name", "Select category");
    replaceOptions(centreSelect, centreResult.centres, "centre_id", "centre_name", "Choose a centre");
  } catch (error) {
    replaceOptions(categorySelect, [
      { category_id: 1, category_name: "Computers" },
      { category_id: 2, category_name: "Mobile Devices" },
      { category_id: 3, category_name: "Home Appliances" },
      { category_id: 4, category_name: "Accessories" },
    ], "category_id", "category_name", "Select category");
    replaceOptions(centreSelect, [
      { centre_id: 1, centre_name: "Patna E-Waste Centre" },
      { centre_id: 2, centre_name: "Bihta Collection Hub" },
    ], "centre_id", "centre_name", "Choose a centre");
    setFormFeedback(`${error.message} Demo options are shown only for UI preview.`, "error");
  }
}

pickupForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (!pickupForm.reportValidity()) return;

  const submitButton = pickupForm.querySelector('button[type="submit"]');
  const formValues = new FormData(pickupForm);
  const buttonLabel = submitButton.innerHTML;
  let createdItemId = null;
  submitButton.disabled = true;
  submitButton.textContent = "Submitting…";
  formFeedback.hidden = true;

  try {
    const item = await api("/api/waste-items", {
      method: "POST",
      body: JSON.stringify({
        item_name: formValues.get("item"),
        brand: formValues.get("brand"),
        category_id: Number(formValues.get("category")),
        item_condition: formValues.get("condition"),
        weight_kg: Number(formValues.get("weight")),
        user: {
          full_name: formValues.get("name"),
          email: formValues.get("email"),
          phone: formValues.get("phone"),
        },
      }),
    });
    createdItemId = item.item_id;

    const pickup = await api("/api/pickup-requests", {
      method: "POST",
      body: JSON.stringify({
        item_id: createdItemId,
        centre_id: Number(formValues.get("centre")),
        requested_date: formValues.get("date"),
        preferred_slot: formValues.get("slot"),
      }),
    });

    setFormFeedback(`Pickup request #${pickup.request_id} was created for waste item #${createdItemId}.`, "success");
    await loadCurrentPage();
  } catch (error) {
    const message = createdItemId
      ? `Waste item #${createdItemId} was registered, but its pickup request failed: ${error.message}`
      : error.message;
    setFormFeedback(message, "error");
  } finally {
    submitButton.disabled = false;
    submitButton.innerHTML = buttonLabel;
  }
});

document.addEventListener("click", (event) => {
  const target = event.target;
  if (!(target instanceof Element)) return;

  if (target.closest("[data-open-pickup]")) {
    openPickupForm();
    return;
  }
  if (target.closest("[data-close-dialog]")) {
    pickupDialog.close();
    return;
  }
  if (target.closest("[data-retry]")) {
    loadCurrentPage();
    return;
  }

  const pageLink = target.closest("[data-page]");
  if (pageLink) {
    event.preventDefault();
    currentPage = pageLink.dataset.page;
    currentSearch = "";
    currentStatus = "all";
    searchInput.value = "";
    loadCurrentPage();
  }
  if (target.closest(".banner-dismiss")) {
    document.querySelector(".prototype-banner").remove();
  }
});

searchInput.addEventListener("input", () => {
  currentSearch = searchInput.value;
  renderCurrentPage();
});

document.addEventListener("change", (event) => {
  if (event.target.id === "status-filter") {
    currentStatus = event.target.value;
    renderCurrentPage();
  }
});

document.querySelector("#mobile-menu").addEventListener("click", () => {
  document.querySelector("#sidebar").classList.toggle("open");
});

document.addEventListener("keydown", (event) => {
  if (event.key === "/" && !["INPUT", "TEXTAREA", "SELECT"].includes(document.activeElement.tagName)) {
    event.preventDefault();
    searchInput.focus();
  }
  if (event.key === "Escape") {
    document.querySelector("#sidebar").classList.remove("open");
    searchInput.blur();
  }
});

loadCurrentPage();
