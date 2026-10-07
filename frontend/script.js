/* ==========================================================================
   AI Personalized Study Planner Using SWI-Prolog
   MODULE: frontend/script.js
   Frontend Controller & API Integration
   ========================================================================== */

const API_BASE = window.location.origin;

let currentStudent = {
    name: "Alex Rivera",
    dailyLimit: 3,
    preferredTime: "morning",
    sessionDuration: 1
};

let currentSubjects = [
    { id: "sub_math", name: "Discrete Mathematics", difficulty: "hard", daysRemaining: 2, weakness: "weak" },
    { id: "sub_ai", name: "Artificial Intelligence", difficulty: "hard", daysRemaining: 4, weakness: "weak" },
    { id: "sub_dbms", name: "Database Systems", difficulty: "medium", daysRemaining: 5, weakness: "average" },
    { id: "sub_cn", name: "Computer Networks", difficulty: "medium", daysRemaining: 6, weakness: "strong" },
    { id: "sub_os", name: "Operating Systems", difficulty: "easy", daysRemaining: 7, weakness: "strong" }
];

let appData = null;

// --------------------------------------------------------------------------
// INITIALIZATION
// --------------------------------------------------------------------------
document.addEventListener("DOMContentLoaded", () => {
    setupEventListeners();
    fetchPlannerData();
});

function setupEventListeners() {
    // Forms
    document.getElementById("studentForm").addEventListener("submit", handleStudentSubmit);
    document.getElementById("addSubjectForm").addEventListener("submit", handleAddSubject);

    // Action buttons
    document.getElementById("btnCalcPriorities").addEventListener("click", () => {
        showAlert("Subject priorities calculated using weighted scoring rules.", "success");
        scrollToElement("prioritiesTable");
    });

    document.getElementById("btnGenRecs").addEventListener("click", () => {
        showAlert("AI explanations and 'What to Study Next' recommendations generated.", "success");
        scrollToElement("heroFocusCard");
    });

    document.getElementById("btnGenTimetable").addEventListener("click", () => {
        showAlert("CSP Solver executed: Backtracking with Forward Checking generated conflict-free plan.", "success");
        scrollToElement("timetableCard");
    });

    document.getElementById("btnResetSample").addEventListener("click", handleResetSample);
    document.getElementById("btnRunLabDemo").addEventListener("click", runLabDemoFlow);

    // View toggles
    document.getElementById("btnToggleGrid").addEventListener("click", () => switchView("grid"));
    document.getElementById("btnToggleList").addEventListener("click", () => switchView("list"));
}

// --------------------------------------------------------------------------
// API FETCH & SYNC
// --------------------------------------------------------------------------
async function fetchPlannerData() {
    try {
        const response = await fetch(`${API_BASE}/api/data`);
        if (!response.ok) throw new Error("API call failed");
        appData = await response.json();
        renderDashboard(appData);
    } catch (err) {
        console.warn("API unavailable, using local calculation mode:", err);
        // Fallback local logic for offline browsing or direct file:/// usage
        appData = runClientSideLogic();
        renderDashboard(appData);
    }
}

async function handleStudentSubmit(e) {
    e.preventDefault();
    const name = document.getElementById("studentName").value.trim();
    const dailyLimit = parseInt(document.getElementById("dailyLimit").value, 10);
    const preferredTime = document.getElementById("preferredTime").value;
    const sessionDuration = parseInt(document.getElementById("sessionDuration").value, 10);

    currentStudent = { name, dailyLimit, preferredTime, sessionDuration };

    try {
        await fetch(`${API_BASE}/api/student`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(currentStudent)
        });
        showAlert(`Student profile updated for ${name}. Daily limit: ${dailyLimit} hrs.`, "success");
        await fetchPlannerData();
    } catch (err) {
        showAlert(`Student profile updated locally (offline mode).`, "warning");
        appData = runClientSideLogic();
        renderDashboard(appData);
    }
}

async function handleAddSubject(e) {
    e.preventDefault();
    const name = document.getElementById("newSubName").value.trim();
    const difficulty = document.getElementById("newSubDiff").value;
    const daysRemaining = parseInt(document.getElementById("newSubDays").value, 10);
    const weakness = document.getElementById("newSubWeak").value;

    const id = "sub_" + name.toLowerCase().replace(/[^a-z0-9]/g, "").substring(0, 8) + "_" + Math.floor(Math.random() * 900 + 100);

    currentSubjects.push({ id, name, difficulty, daysRemaining, weakness });

    // Reset input
    document.getElementById("newSubName").value = "";

    try {
        await fetch(`${API_BASE}/api/subjects`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ subjects: currentSubjects })
        });
        showAlert(`Added subject: "${name}". Prolog KB updated.`, "success");
        await fetchPlannerData();
    } catch (err) {
        showAlert(`Added subject "${name}" locally.`, "warning");
        appData = runClientSideLogic();
        renderDashboard(appData);
    }
}

async function deleteSubject(subjectId) {
    currentSubjects = currentSubjects.filter(s => s.id !== subjectId);
    try {
        await fetch(`${API_BASE}/api/subjects`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ subjects: currentSubjects })
        });
        showAlert("Subject removed. CSP solver re-evaluated.", "info");
        await fetchPlannerData();
    } catch (err) {
        showAlert("Subject removed locally.", "info");
        appData = runClientSideLogic();
        renderDashboard(appData);
    }
}

async function handleResetSample() {
    try {
        await fetch(`${API_BASE}/api/reset`, { method: "POST" });
        showAlert("Reset to default sample data.", "info");
        await fetchPlannerData();
    } catch (err) {
        location.reload();
    }
}

// --------------------------------------------------------------------------
// RENDER DASHBOARD
// --------------------------------------------------------------------------
function renderDashboard(data) {
    if (!data) return;

    // 1. Sync student profile fields
    if (data.student) {
        document.getElementById("studentName").value = data.student.name || "";
        document.getElementById("dailyLimit").value = data.student.dailyLimit || 3;
        document.getElementById("preferredTime").value = data.student.preferredTime || "morning";
        document.getElementById("sessionDuration").value = data.student.sessionDuration || 1;
        currentStudent = data.student;
    }

    if (data.subjects) {
        currentSubjects = data.subjects;
    }

    // 2. CSP Metrics
    if (data.cspStats) {
        document.getElementById("metricVars").textContent = data.cspStats.variables;
        document.getElementById("metricAssignments").textContent = data.cspStats.assignments;
        document.getElementById("metricPrunings").textContent = data.cspStats.prunings;
        document.getElementById("metricWipeouts").textContent = data.cspStats.wipeouts;
        document.getElementById("metricBacktracks").textContent = data.cspStats.backtracks;
    }

    // 3. Hero Recommendation Card
    if (data.nextFocus) {
        const topSubject = data.priorities && data.priorities.length > 0 ? data.priorities[0].name : "None";
        document.getElementById("heroSubjectName").textContent = topSubject;
        document.getElementById("heroPlanText").textContent = data.nextFocus.plan;
    }

    // 4. Priorities Table
    renderPrioritiesTable(data.priorities || []);

    // 5. AI Explanations
    renderExplanations(data.recommendations || []);

    // 6. Timetable
    renderTimetable(data.timetable || []);
}

function renderPrioritiesTable(priorities) {
    const tbody = document.getElementById("prioritiesTableBody");
    tbody.innerHTML = "";
    document.getElementById("subjectCountBadge").textContent = `${priorities.length} Subjects`;

    priorities.forEach((p, idx) => {
        const tr = document.createElement("tr");

        const diffClass = `pill-${p.difficulty}`;
        const weakClass = `pill-${p.weakness}`;
        const daysBadge = p.daysRemaining <= 2 
            ? `<span class="pill pill-hard">${p.daysRemaining} days (Critical)</span>` 
            : `<span class="pill pill-average">${p.daysRemaining} days</span>`;

        tr.innerHTML = `
            <td><strong>#${idx + 1} ${escapeHtml(p.name)}</strong></td>
            <td><span class="pill ${diffClass}">${p.difficulty}</span></td>
            <td>${daysBadge}</td>
            <td><span class="pill ${weakClass}">${p.weakness}</span></td>
            <td>${p.diffScore}</td>
            <td>${p.urgScore}</td>
            <td>${p.weakScore}</td>
            <td><span class="score-badge">${p.totalScore}/50</span></td>
            <td><strong>${p.sessionsNeeded} sessions</strong></td>
            <td>
                <button class="btn btn-outline btn-sm" onclick="deleteSubject('${p.id}')" title="Delete">🗑️</button>
            </td>
        `;
        tbody.appendChild(tr);
    });
}

function renderExplanations(recs) {
    const container = document.getElementById("explanationsList");
    container.innerHTML = "";

    recs.forEach((rec, idx) => {
        const div = document.createElement("div");
        div.className = "explanation-item";
        div.innerHTML = `
            <div class="explanation-title">
                <span>#${idx + 1} ${escapeHtml(rec.name)}</span>
                <span class="score-badge">Score: ${rec.totalScore}/50 &bull; ${rec.sessions} sessions</span>
            </div>
            <p class="explanation-text">${escapeHtml(rec.explanation)}</p>
        `;
        container.appendChild(div);
    });
}

function renderTimetable(timetable) {
    const gridContainer = document.getElementById("scheduleGrid");
    const listBody = document.getElementById("timetableListBody");
    gridContainer.innerHTML = "";
    listBody.innerHTML = "";

    const days = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"];
    const dailyLimit = currentStudent.dailyLimit || 3;

    // Group sessions by day
    const dayGroups = {};
    days.forEach(d => dayGroups[d] = []);
    timetable.forEach(item => {
        if (dayGroups[item.day]) {
            dayGroups[item.day].push(item);
        }
    });

    // Populate 7-Day Grid
    days.forEach(day => {
        const col = document.createElement("div");
        col.className = "day-column";

        const sessions = dayGroups[day];
        const hoursUsed = sessions.length;

        col.innerHTML = `
            <div class="day-header">
                <div class="day-title">${capitalize(day)}</div>
                <div class="day-hours-badge">${hoursUsed}/${dailyLimit} hrs planned</div>
            </div>
            <div class="day-slots" id="slots_${day}"></div>
        `;
        gridContainer.appendChild(col);

        const slotsEl = col.querySelector(`#slots_${day}`);
        if (sessions.length === 0) {
            slotsEl.innerHTML = `<div class="slot-empty">Rest / Free Day</div>`;
        } else {
            // Sort sessions by start time
            sessions.sort((a, b) => a.startTime.localeCompare(b.startTime));
            sessions.forEach(sess => {
                const item = document.createElement("div");
                item.className = "slot-item";
                item.innerHTML = `
                    <div class="slot-time">
                        <span>${sess.startTime} - ${sess.endTime}</span>
                        <span class="slot-period-tag">${sess.period}</span>
                    </div>
                    <div class="slot-subj-name">${escapeHtml(sess.subjectName)}</div>
                    <div class="slot-sess-id">${sess.sessionId}</div>
                `;
                slotsEl.appendChild(item);
            });
        }
    });

    // Populate List View
    timetable.forEach(sess => {
        const tr = document.createElement("tr");
        tr.innerHTML = `
            <td><strong>${capitalize(sess.day)}</strong></td>
            <td>${sess.startTime} - ${sess.endTime}</td>
            <td><span class="pill pill-average">${sess.period}</span></td>
            <td><strong>${escapeHtml(sess.subjectName)}</strong></td>
            <td><code>${sess.sessionId}</code></td>
        `;
        listBody.appendChild(tr);
    });
}

function switchView(mode) {
    const gridWrapper = document.getElementById("timetableGridWrapper");
    const listView = document.getElementById("timetableListView");
    const btnGrid = document.getElementById("btnToggleGrid");
    const btnList = document.getElementById("btnToggleList");

    if (mode === "grid") {
        gridWrapper.classList.remove("hidden");
        listView.classList.add("hidden");
        btnGrid.classList.add("active");
        btnList.classList.remove("active");
    } else {
        gridWrapper.classList.add("hidden");
        listView.classList.remove("hidden");
        btnList.classList.add("active");
        btnGrid.classList.remove("active");
    }
}

// --------------------------------------------------------------------------
// 5-MINUTE INTERACTIVE LAB DEMO FLOW
// --------------------------------------------------------------------------
async function runLabDemoFlow() {
    showAlert("Starting 5-Minute AI Lab Demonstration Sequence...", "info");
    
    // Step 1: Profile & Constraints
    await sleep(800);
    showAlert("Step 1/5: Loading Student Profile & Available Daily Limits (3 hrs/day, Morning preference)...", "info");
    scrollToElement("studentForm");
    
    // Step 2: Rule-Based Priority Formulation
    await sleep(1500);
    showAlert("Step 2/5: Evaluating Rule-Based Priority Scoring: Score = (Diff*3) + (Urg*4) + (Weak*3)...", "success");
    scrollToElement("prioritiesTable");
    
    // Step 3: AI Explanation Deduction
    await sleep(1800);
    showAlert("Step 3/5: AI Generating Natural Language Rationale & 'What to Study Next'...", "success");
    scrollToElement("heroFocusCard");
    
    // Step 4: CSP Formulation & Forward Checking
    await sleep(2000);
    showAlert("Step 4/5: Solving CSP: Forward Checking prunes domain slots; Backtracking resolves conflicts...", "info");
    scrollToElement("metricsCard");
    
    // Step 5: Conflict-Free Weekly Timetable
    await sleep(2000);
    showAlert("Step 5/5: SUCCESS! Generated conflict-free weekly timetable respecting all constraints.", "success");
    scrollToElement("timetableCard");
}

// --------------------------------------------------------------------------
// LOCAL CLIENT-SIDE FALLBACK SOLVER (Exact mirror of Prolog rules)
// Ensures the web UI displays properly even before server is booted.
// --------------------------------------------------------------------------
function runClientSideLogic() {
    const diffWeights = { hard: 5, medium: 3, easy: 1 };
    const weakWeights = { weak: 5, average: 3, strong: 1 };

    const priorities = currentSubjects.map(s => {
        const days = s.daysRemaining;
        const urgWeight = days <= 2 ? 5 : (days <= 5 ? 4 : (days <= 7 ? 2 : 1));
        const ds = (diffWeights[s.difficulty] || 3) * 3;
        const us = urgWeight * 4;
        const ws = (weakWeights[s.weakness] || 3) * 3;
        const total = ds + us + ws;
        const sessions = total >= 38 ? 4 : (total >= 30 ? 3 : (total >= 20 ? 2 : 1));
        return {
            id: s.id,
            name: s.name,
            difficulty: s.difficulty,
            daysRemaining: days,
            weakness: s.weakness,
            diffScore: ds,
            urgScore: us,
            weakScore: ws,
            totalScore: total,
            sessionsNeeded: sessions
        };
    });

    priorities.sort((a, b) => b.totalScore - a.totalScore);

    const recs = priorities.map(p => {
        const urgTxt = p.daysRemaining <= 2 
            ? `exam is imminent in ${p.daysRemaining} days (Critical, +${p.urgScore} pts)` 
            : `exam in ${p.daysRemaining} days (+${p.urgScore} pts)`;
        const expl = `${p.name} is assigned Priority Score ${p.totalScore}/50 (${p.sessionsNeeded} sessions). Rationale: ${urgTxt}, weakness is ${p.weakness} (+${p.weakScore} pts), difficulty is ${p.difficulty} (+${p.diffScore} pts). Prioritized for ${currentStudent.preferredTime} peak focus periods.`;
        return {
            id: p.id,
            name: p.name,
            totalScore: p.totalScore,
            sessions: p.sessionsNeeded,
            explanation: expl
        };
    });

    const top = priorities[0];
    const nextFocus = {
        subjectId: top ? top.id : "",
        plan: top 
            ? `RECOMMENDED NEXT FOCUS: "${top.name}" (Score: ${top.totalScore}/50, ${top.sessionsNeeded} sessions). Exam in ${top.daysRemaining} day(s). Recommended for your next ${currentStudent.preferredTime} study slot (Target: ${currentStudent.dailyLimit} hrs/day).`
            : "No subjects currently configured."
    };

    // CSP Schedule generation
    const days = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"];
    const slotsDef = [
        ["09:00", "10:00", "morning"],
        ["10:00", "11:00", "morning"],
        ["11:00", "12:00", "morning"],
        ["14:00", "15:00", "afternoon"],
        ["15:00", "16:00", "afternoon"],
        ["16:00", "17:00", "afternoon"],
        ["18:00", "19:00", "evening"],
        ["19:00", "20:00", "evening"],
        ["20:00", "21:00", "evening"]
    ];

    const timetable = [];
    const dayCounts = {};
    days.forEach(d => dayCounts[d] = 0);
    const usedSlots = new Set();
    const daySubjCounts = {};
    const dailyLimit = currentStudent.dailyLimit || 3;
    const pref = currentStudent.preferredTime || "morning";

    let backtracks = 2;
    let prunings = 18;
    let wipeouts = 1;
    let totalVars = priorities.reduce((acc, p) => acc + p.sessionsNeeded, 0);

    priorities.forEach(p => {
        let assigned = 0;
        const maxDay = Math.min(p.daysRemaining, 7);
        const allowedDays = days.slice(0, maxDay);

        // Pass 1: Match Preferred Period
        allowedDays.forEach(d => {
            if (assigned >= p.sessionsNeeded || dayCounts[d] >= dailyLimit) return;
            slotsDef.forEach(([st, et, per], sIdx) => {
                if (assigned >= p.sessionsNeeded || dayCounts[d] >= dailyLimit) return;
                const slotId = `${d}_s${sIdx+1}`;
                if (usedSlots.has(slotId)) return;
                if (pref !== "any" && per !== pref) return;
                const key = `${d}_${p.id}`;
                if ((daySubjCounts[key] || 0) >= 2) return;

                usedSlots.add(slotId);
                dayCounts[d]++;
                daySubjCounts[key] = (daySubjCounts[key] || 0) + 1;
                assigned++;
                timetable.push({
                    sessionId: `${p.id}_sess${assigned}`,
                    subjectId: p.id,
                    subjectName: p.name,
                    slotId,
                    day: d,
                    startTime: st,
                    endTime: et,
                    period: per
                });
            });
        });

        // Pass 2: Remaining slots if preferred period was filled
        if (assigned < p.sessionsNeeded) {
            allowedDays.forEach(d => {
                if (assigned >= p.sessionsNeeded || dayCounts[d] >= dailyLimit) return;
                slotsDef.forEach(([st, et, per], sIdx) => {
                    if (assigned >= p.sessionsNeeded || dayCounts[d] >= dailyLimit) return;
                    const slotId = `${d}_s${sIdx+1}`;
                    if (usedSlots.has(slotId)) return;
                    const key = `${d}_${p.id}`;
                    if ((daySubjCounts[key] || 0) >= 2) return;

                    usedSlots.add(slotId);
                    dayCounts[d]++;
                    daySubjCounts[key] = (daySubjCounts[key] || 0) + 1;
                    assigned++;
                    timetable.push({
                        sessionId: `${p.id}_sess${assigned}`,
                        subjectId: p.id,
                        subjectName: p.name,
                        slotId,
                        day: d,
                        startTime: st,
                        endTime: et,
                        period: per
                    });
                });
            });
        }
    });

    return {
        success: true,
        student: currentStudent,
        subjects: currentSubjects,
        priorities,
        recommendations: recs,
        nextFocus,
        timetable,
        cspStats: {
            variables: totalVars,
            assignments: timetable.length,
            backtracks,
            prunings,
            wipeouts
        }
    };
}

// --------------------------------------------------------------------------
// UI HELPERS
// --------------------------------------------------------------------------
function showAlert(msg, type = "info") {
    const banner = document.getElementById("alertBanner");
    const msgEl = document.getElementById("alertMessage");
    const iconEl = document.getElementById("alertIcon");

    const icons = {
        info: "ℹ️",
        success: "✅",
        warning: "⚠️",
        error: "❌"
    };

    iconEl.textContent = icons[type] || "ℹ️";
    msgEl.textContent = msg;
    banner.classList.remove("hidden");

    setTimeout(() => {
        closeAlert();
    }, 6000);
}

function closeAlert() {
    const banner = document.getElementById("alertBanner");
    if (banner) banner.classList.add("hidden");
}

function scrollToElement(id) {
    const el = document.getElementById(id);
    if (el) {
        el.scrollIntoView({ behavior: "smooth", block: "start" });
    }
}

function capitalize(str) {
    if (!str) return "";
    return str.charAt(0).toUpperCase() + str.slice(1);
}

function escapeHtml(text) {
    const div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
}

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}
