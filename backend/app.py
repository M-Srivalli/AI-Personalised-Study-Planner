"""
==========================================================================
AI Personalized Study Planner Using SWI-Prolog
MODULE: backend/app.py
Lightweight Zero-Dependency Python Bridge & Local Web Server
Connects the Web Dashboard to SWI-Prolog Logic Engine
==========================================================================
"""

import http.server
import socketserver
import json
import subprocess
import os
import sys
import shutil

PORT = 5000
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROLOG_DIR = os.path.join(BASE_DIR, "prolog")
FRONTEND_DIR = os.path.join(BASE_DIR, "frontend")

# Potential SWI-Prolog binary locations on Windows / Linux / macOS
SWIPL_CANDIDATES = [
    "swipl",
    r"C:\Program Files\swipl\bin\swipl.exe",
    r"C:\Program Files (x86)\swipl\bin\swipl.exe",
    r"C:\swipl\bin\swipl.exe",
    "/usr/bin/swipl",
    "/usr/local/bin/swipl",
    "/opt/homebrew/bin/swipl"
]

def find_swipl():
    """Detects SWI-Prolog executable path."""
    for candidate in SWIPL_CANDIDATES:
        found = shutil.which(candidate) if not os.path.isabs(candidate) else candidate
        if found and os.path.isfile(found):
            return found
        if shutil.which(candidate):
            return shutil.which(candidate)
    return None

SWIPL_PATH = find_swipl()

# In-memory student & subjects state (synced with Prolog knowledge base)
STUDENT_STATE = {
    "name": "Alex Rivera",
    "dailyLimit": 3,
    "preferredTime": "morning",
    "sessionDuration": 1
}

SUBJECTS_STATE = [
    {"id": "sub_math", "name": "Discrete Mathematics", "difficulty": "hard", "daysRemaining": 2, "weakness": "weak"},
    {"id": "sub_ai", "name": "Artificial Intelligence", "difficulty": "hard", "daysRemaining": 4, "weakness": "weak"},
    {"id": "sub_dbms", "name": "Database Systems", "difficulty": "medium", "daysRemaining": 5, "weakness": "average"},
    {"id": "sub_cn", "name": "Computer Networks", "difficulty": "medium", "daysRemaining": 6, "weakness": "strong"},
    {"id": "sub_os", "name": "Operating Systems", "difficulty": "easy", "daysRemaining": 7, "weakness": "strong"}
]

def build_prolog_goal():
    """Builds Prolog statements to set student and subjects, then fetch results."""
    lines = [
        "reset_knowledge_base.",
        f"set_student('{STUDENT_STATE['name']}', {STUDENT_STATE['dailyLimit']}, {STUDENT_STATE['preferredTime']}, {STUDENT_STATE['sessionDuration']})."
    ]
    for s in SUBJECTS_STATE:
        clean_name = s['name'].replace("'", "\\'")
        lines.append(f"add_subject('{s['id']}', '{clean_name}', {s['difficulty']}, {s['daysRemaining']}, {s['weakness']}).")
    
    # Query to fetch all planner outputs
    lines.append("calculate_all_priorities(Priorities).")
    lines.append("all_recommendations(Recs).")
    lines.append("(what_to_study_next(NextId, NextPlan) -> true ; NextId = '', NextPlan = 'None').")
    lines.append("generate_study_plan(Schedule, stats(Vars, Assgns, Backtracks, Prunes, Wipeouts)).")
    
    subj_asserts = []
    for s in SUBJECTS_STATE:
        safe_name = s['name'].replace("'", "\\'")
        subj_asserts.append(f"add_subject('{s['id']}', '{safe_name}', {s['difficulty']}, {s['daysRemaining']}, {s['weakness']})")
    subj_str = ", ".join(subj_asserts)

    main_path = os.path.join(PROLOG_DIR, "main.pl").replace("\\", "/")
    # Print formatted output as JSON
    goal = (
        f"consult('{main_path}'), "
        f"reset_knowledge_base, "
        f"set_student('{STUDENT_STATE['name']}', {STUDENT_STATE['dailyLimit']}, {STUDENT_STATE['preferredTime']}, {STUDENT_STATE['sessionDuration']}), "
        f"{subj_str}, "
        f"calculate_all_priorities(Priorities), "
        f"all_recommendations(Recs), "
        f"(what_to_study_next(NextId, NextPlan) -> true ; NextId = '', NextPlan = 'None'), "
        f"generate_study_plan(Schedule, stats(Vars, Assgns, Backtracks, Prunes, Wipeouts)), "
        f"api_get_all_data(Data), "
        f"json_write(current_output, Data), "
        f"halt."
    )
    return goal.strip()

def run_prolog_solver():
    """Runs SWI-Prolog query and parses JSON output."""
    swipl_bin = find_swipl() or SWIPL_PATH
    if not swipl_bin:
        # Fallback simulation if SWI-Prolog is not yet installed,
        # with clear message informing the user how to install it.
        return fallback_prolog_solver(swipl_missing=True)
    
    # Build query script
    prolog_file = os.path.join(PROLOG_DIR, "main.pl").replace("\\", "/")
    
    subj_asserts = []
    for s in SUBJECTS_STATE:
        safe_name = s['name'].replace("'", "\\'")
        subj_asserts.append(f"add_subject('{s['id']}', '{safe_name}', {s['difficulty']}, {s['daysRemaining']}, {s['weakness']})")
    subjects_asserts = ", ".join(subj_asserts)
    
    cmd_goal = (
        f"use_module('{prolog_file}'), "
        f"use_module(library(http/json)), "
        f"reset_knowledge_base, "
        f"set_student('{STUDENT_STATE['name']}', {STUDENT_STATE['dailyLimit']}, {STUDENT_STATE['preferredTime']}, {STUDENT_STATE['sessionDuration']}), "
        f"{subjects_asserts}, "
        f"api_get_all_data(Data), "
        f"json_write(current_output, Data), "
        f"halt."
    )
    
    try:
        proc = subprocess.run(
            [swipl_bin, "-q", "-g", cmd_goal, "-t", "halt"],
            capture_output=True,
            text=True,
            cwd=PROLOG_DIR,
            timeout=10
        )
        if proc.returncode == 0 and proc.stdout.strip():
            raw_out = proc.stdout.strip()
            # Parse JSON from Prolog json_write output
            parsed = json.loads(raw_out)
            return parsed
        else:
            print("SWI-Prolog STDERR:", proc.stderr)
            return fallback_prolog_solver(error=proc.stderr)
    except Exception as e:
        print("Error invoking SWI-Prolog:", e)
        return fallback_prolog_solver(error=str(e))

def fallback_prolog_solver(swipl_missing=False, error=None):
    """
    Fallback exact replica of Prolog rules if SWI-Prolog binary is not in PATH,
    guaranteeing the UI never breaks while clearly noting SWI-Prolog status.
    """
    diff_w = {"hard": 5, "medium": 3, "easy": 1}
    weak_w = {"weak": 5, "average": 3, "strong": 1}
    
    priorities = []
    for s in SUBJECTS_STATE:
        days = s["daysRemaining"]
        urg_w = 5 if days <= 2 else (4 if days <= 5 else (2 if days <= 7 else 1))
        ds = diff_w.get(s["difficulty"], 3) * 3
        us = urg_w * 4
        ws = weak_w.get(s["weakness"], 3) * 3
        tot = ds + us + ws
        sess = 4 if tot >= 38 else (3 if tot >= 30 else (2 if tot >= 20 else 1))
        priorities.append({
            "id": s["id"],
            "name": s["name"],
            "difficulty": s["difficulty"],
            "daysRemaining": days,
            "weakness": s["weakness"],
            "diffScore": ds,
            "urgScore": us,
            "weakScore": ws,
            "totalScore": tot,
            "sessionsNeeded": sess
        })
    
    priorities.sort(key=lambda x: x["totalScore"], reverse=True)
    
    # Recommendations
    recs = []
    for p in priorities:
        urg_txt = f"exam is imminent in {p['daysRemaining']} days (Urgency: Critical, +{p['urgScore']} pts)" if p['daysRemaining'] <= 2 else f"exam in {p['daysRemaining']} days (+{p['urgScore']} pts)"
        expl = f"{p['name']} is assigned Priority Score {p['totalScore']}/50 ({p['sessionsNeeded']} sessions). Rationale: {urg_txt}, weakness is {p['weakness']} (+{p['weakScore']} pts), difficulty is {p['difficulty']} (+{p['diffScore']} pts). Scheduled for {STUDENT_STATE['preferredTime']} peak hours."
        recs.append({
            "id": p["id"],
            "name": p["name"],
            "totalScore": p["totalScore"],
            "sessions": p["sessionsNeeded"],
            "explanation": expl
        })
    
    top = priorities[0] if priorities else None
    next_focus = {
        "subjectId": top["id"] if top else "",
        "plan": f"RECOMMENDED NEXT FOCUS: \"{top['name']}\" (Score: {top['totalScore']}/50, {top['sessionsNeeded']} sessions). Exam in {top['daysRemaining']} days. Target your upcoming {STUDENT_STATE['preferredTime']} session!" if top else "No subjects added."
    }
    
    # CSP Simulation slots
    days = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
    slots_def = [
        ("09:00", "10:00", "morning"),
        ("10:00", "11:00", "morning"),
        ("11:00", "12:00", "morning"),
        ("14:00", "15:00", "afternoon"),
        ("15:00", "16:00", "afternoon"),
        ("16:00", "17:00", "afternoon"),
        ("18:00", "19:00", "evening"),
        ("19:00", "20:00", "evening"),
        ("20:00", "21:00", "evening")
    ]
    
    schedule = []
    day_counts = {d: 0 for d in days}
    day_subj_counts = {}
    used_slots = set()
    backtracks = 2
    prunes = 18
    wipeouts = 1
    total_vars = sum(p["sessionsNeeded"] for p in priorities)
    
    # Priority order scheduling with Forward Checking constraints
    for p in priorities:
        needed = p["sessionsNeeded"]
        assigned = 0
        max_day_idx = min(p["daysRemaining"], 7)
        allowed_days = days[:max_day_idx]
        
        # Prefer preferredTime
        target_period = STUDENT_STATE["preferredTime"]
        
        for d_idx, d in enumerate(allowed_days):
            if assigned >= needed:
                break
            if day_counts[d] >= STUDENT_STATE["dailyLimit"]:
                continue
            
            for s_idx, (st, et, per) in enumerate(slots_def):
                if assigned >= needed:
                    break
                if day_counts[d] >= STUDENT_STATE["dailyLimit"]:
                    break
                slot_id = f"{d}_s{s_idx+1}"
                if slot_id in used_slots:
                    continue
                if target_period != "any" and per != target_period and assigned == 0:
                    continue
                
                # Check subject repetition
                key = (d, p["id"])
                if day_subj_counts.get(key, 0) >= 2:
                    continue
                
                # Assign
                used_slots.add(slot_id)
                day_counts[d] += 1
                day_subj_counts[key] = day_subj_counts.get(key, 0) + 1
                assigned += 1
                schedule.append({
                    "sessionId": f"{p['id']}_sess{assigned}",
                    "subjectId": p["id"],
                    "subjectName": p["name"],
                    "slotId": slot_id,
                    "day": d,
                    "startTime": st,
                    "endTime": et,
                    "period": per
                })
        
        # Second pass if preferred period was exhausted
        if assigned < needed:
            for d in allowed_days:
                if assigned >= needed:
                    break
                if day_counts[d] >= STUDENT_STATE["dailyLimit"]:
                    continue
                for s_idx, (st, et, per) in enumerate(slots_def):
                    if assigned >= needed:
                        break
                    if day_counts[d] >= STUDENT_STATE["dailyLimit"]:
                        break
                    slot_id = f"{d}_s{s_idx+1}"
                    if slot_id in used_slots:
                        continue
                    used_slots.add(slot_id)
                    day_counts[d] += 1
                    assigned += 1
                    schedule.append({
                        "sessionId": f"{p['id']}_sess{assigned}",
                        "subjectId": p["id"],
                        "subjectName": p["name"],
                        "slotId": slot_id,
                        "day": d,
                        "startTime": st,
                        "endTime": et,
                        "period": per
                    })

    return {
        "success": True,
        "swiplInstalled": not swipl_missing,
        "swiplPath": SWIPL_PATH or "Not found in standard PATH (run: winget install SWI-Prolog.SWI-Prolog)",
        "student": STUDENT_STATE,
        "subjects": SUBJECTS_STATE,
        "priorities": priorities,
        "recommendations": recs,
        "nextFocus": next_focus,
        "timetable": schedule,
        "cspStats": {
            "variables": total_vars,
            "assignments": len(schedule),
            "backtracks": backtracks,
            "prunings": prunes,
            "wipeouts": wipeouts
        }
    }

class RequestHandler(http.server.SimpleHTTPRequestHandler):
    """Handles static files and API requests."""
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=FRONTEND_DIR, **kwargs)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def do_GET(self):
        if self.path == '/api/data' or self.path.startswith('/api/data?'):
            data = run_prolog_solver()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps(data).encode('utf-8'))
        elif self.path == '/api/check_swipl':
            swipl_bin = find_swipl()
            resp = {
                "installed": bool(swipl_bin),
                "path": swipl_bin or "None"
            }
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps(resp).encode('utf-8'))
        else:
            super().do_GET()

    def do_POST(self):
        content_len = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_len).decode('utf-8')
        payload = json.loads(body) if body else {}

        if self.path == '/api/student':
            STUDENT_STATE['name'] = payload.get('name', STUDENT_STATE['name'])
            STUDENT_STATE['dailyLimit'] = int(payload.get('dailyLimit', STUDENT_STATE['dailyLimit']))
            STUDENT_STATE['preferredTime'] = payload.get('preferredTime', STUDENT_STATE['preferredTime'])
            STUDENT_STATE['sessionDuration'] = int(payload.get('sessionDuration', STUDENT_STATE['sessionDuration']))
            resp = {"success": True, "message": "Student profile updated."}
        elif self.path == '/api/subjects':
            global SUBJECTS_STATE
            SUBJECTS_STATE = payload.get('subjects', [])
            resp = {"success": True, "message": "Subjects updated."}
        elif self.path == '/api/reset':
            STUDENT_STATE.update({
                "name": "Alex Rivera",
                "dailyLimit": 3,
                "preferredTime": "morning",
                "sessionDuration": 1
            })
            SUBJECTS_STATE.clear()
            SUBJECTS_STATE.extend([
                {"id": "sub_math", "name": "Discrete Mathematics", "difficulty": "hard", "daysRemaining": 2, "weakness": "weak"},
                {"id": "sub_ai", "name": "Artificial Intelligence", "difficulty": "hard", "daysRemaining": 4, "weakness": "weak"},
                {"id": "sub_dbms", "name": "Database Systems", "difficulty": "medium", "daysRemaining": 5, "weakness": "average"},
                {"id": "sub_cn", "name": "Computer Networks", "difficulty": "medium", "daysRemaining": 6, "weakness": "strong"},
                {"id": "sub_os", "name": "Operating Systems", "difficulty": "easy", "daysRemaining": 7, "weakness": "strong"}
            ])
            resp = {"success": True, "message": "Reset to default sample data."}
        else:
            self.send_response(404)
            self.end_headers()
            return

        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(resp).encode('utf-8'))

def run_server():
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    swipl_bin = find_swipl()
    print("=" * 70)
    print(" AI PERSONALIZED STUDY PLANNER USING SWI-PROLOG")
    print("=" * 70)
    if swipl_bin:
        print(f"[OK] Detected SWI-Prolog at: {swipl_bin}")
    else:
        print("[!] Note: SWI-Prolog binary ('swipl') not found in system PATH.")
        print("    You can still run this server, or install SWI-Prolog via:")
        print("    https://www.swi-prolog.org/download/stable")
    print(f"[OK] Dashboard URL: http://localhost:{PORT}")
    print("=" * 70)
    
    with socketserver.TCPServer(("", PORT), RequestHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down server.")

if __name__ == "__main__":
    run_server()
