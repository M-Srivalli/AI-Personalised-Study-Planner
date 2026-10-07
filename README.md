# AI Personalized Study Planner Using SWI-Prolog

An intelligent, rule-based study planning and timetable scheduling system powered by **SWI-Prolog** and a modern web dashboard. The system models study timetable generation as a **Constraint Satisfaction Problem (CSP)** and solves it using **Backtracking Search** enhanced with **Forward Checking (FC)**.

---

## 📌 Features & AI Lab Concepts

1. **Constraint Satisfaction Problem (CSP) Engine**:
   - **Variables**: Study sessions required for each subject (derived dynamically from rule-based priority scores).
   - **Domains**: Valid 1-hour time slots across 7 days (Morning: 09:00–12:00, Afternoon: 14:00–17:00, Evening: 18:00–21:00).
   - **Hard Constraints**:
     - *No Overlap*: A single time slot cannot be assigned to more than one subject.
     - *Daily Limit*: Total study hours per day cannot exceed the student's declared daily limit (e.g., 3 hours/day).
     - *Exam Deadline Boundary*: Sessions for a subject must be scheduled strictly on or before its exam day.
     - *Cognitive Burnout / Subject Repetition Limit*: At most 2 sessions of the same subject on any single calendar day.
   - **Soft Constraints & Heuristics**:
     - *Preferred Study Period*: Priority domain ordering places preferred slots (morning/afternoon/evening) first.
     - *Built-in Breaks*: Natural meal and rest periods (12:00–14:00 and 17:00–18:00) preserved.
2. **Backtracking Search**:
   - Systematic exploration through the search tree of possible slot assignments. Choice points are explored and undone when constraints fail.
3. **Forward Checking (FC)**:
   - Immediately prunes assigned time slots and exhausted days from the domains of all unassigned future variables.
   - Detects **Domain Wipeout** (empty domain for an unassigned variable) and backtracks immediately before descending into fruitless subtrees.
4. **Knowledge Representation (Prolog Facts & Rules)**:
   - Dynamic declarative predicates: `student/4`, `subject/5`, `time_slot/5`.
5. **Rule-Based Priority & AI Recommendation Engine**:
   - Computes weighted score based on Subject Difficulty (Scale 1–5), Exam Urgency (Scale 1–5), and Mastery/Weakness Level (Scale 1–5).
   - Generates natural language AI explanations justifying rankings and outlines strategic focus areas for the student.

---

## 📂 Project Structure

```text
ai_study_planner/
├── prolog/
│   ├── knowledge_base.pl    # Dynamic facts, student profile, time slots, days
│   ├── priorities.pl        # Weighted priority rules & session allocation
│   ├── constraints.pl       # CSP constraints (no overlap, daily limit, exam bounds)
│   ├── scheduler.pl         # CSP solver with Backtracking & Forward Checking
│   ├── recommendations.pl   # AI explanation generation & next focus recommendation
│   ├── main.pl              # Terminal CLI entry point & test suite
│   └── server.pl            # Native SWI-Prolog HTTP API server
├── frontend/
│   ├── index.html           # Modern interactive student dashboard
│   ├── style.css            # Responsive CSS theme
│   └── script.js            # Dashboard logic, API integration, and demo runner
├── backend/
│   └── app.py               # Lightweight zero-dependency HTTP server bridge
└── README.md                # Comprehensive documentation & lab manual
```

---

## 🚀 Quick Start Guide

### Step 1: Install SWI-Prolog (if not already installed)
- **Windows**: Download installer from [swi-prolog.org](https://www.swi-prolog.org/download/stable) or run:
  ```powershell
  winget install SWI-Prolog.SWI-Prolog
  ```
- **macOS**: `brew install swi-prolog`
- **Linux (Ubuntu/Debian)**: `sudo apt-get install swi-prolog`

Verify installation:
```bash
swipl --version
```
*Expected Output:*
```text
SWI-Prolog version 9.x.x for x86_64-...
```

---

### Step 2: Running in SWI-Prolog Terminal (Pure Prolog Mode)

Navigate to the `prolog/` directory:
```powershell
cd prolog
swipl main.pl
```

Inside the SWI-Prolog prompt `?-`, run:

#### 1. Run Complete End-to-End Demo:
```prolog
?- run_demo.
```

#### 2. Run Automated CSP Validation Tests:
```prolog
?- test_csp.
```

#### 3. View Priorities & Weighted Scores:
```prolog
?- show_priorities.
```

#### 4. View AI Recommendations & Explanations:
```prolog
?- show_recommendations.
```

#### 5. Generate Timetable:
```prolog
?- generate_timetable.
```

Exit SWI-Prolog:
```prolog
?- halt.
```

---

### Step 3: Running the Interactive Web Dashboard

You have **two seamless ways** to run the local web dashboard:

#### Method A: Using Python Bridge (Zero Setup, works with Python 3)
From the project root:
```powershell
python backend/app.py
```
*Output:*
```text
======================================================================
 AI PERSONALIZED STUDY PLANNER USING SWI-PROLOG
======================================================================
[OK] Dashboard URL: http://localhost:5000
======================================================================
```
Open your browser and navigate to: **`http://localhost:5000`**

#### Method B: Using Native SWI-Prolog HTTP Server
```powershell
cd prolog
swipl -g "use_module(server), start_server(8080)."
```
Open your browser and navigate to: **`http://localhost:8080`**

---

## 🧪 5 Test Cases

### Test Case 1: Urgent Exam Deadline Conflict Prevention
- **Input**: Subject *Discrete Mathematics*, Difficulty: `Hard`, Days Remaining: `2`, Weakness: `Weak`.
- **Constraint Verified**: `before_exam(sub_math, Day)`.
- **Expected Result**: All allocated sessions for *Discrete Mathematics* are strictly scheduled on **Monday** or **Tuesday**. No sessions appear on Wednesday or later.

### Test Case 2: Strict Daily Hour Limit Enforcement
- **Input**: Daily limit = `3` hours/day. Total required sessions across all subjects = `14`.
- **Constraint Verified**: `under_daily_limit(Day, 3, CurrentAssignments)`.
- **Expected Result**: No single calendar day has more than 3 sessions. Sessions are distributed across Monday (3), Tuesday (3), Wednesday (3), Thursday (3), and Friday (2).

### Test Case 3: No Overlapping Sessions (Slot Collision)
- **Input**: 14 session variables competing for time slots.
- **Constraint Verified**: `no_overlap(SlotId, CurrentAssignments)`.
- **Expected Result**: 14 distinct `SlotId` values. Exactly 0 overlapping assignments.

### Test Case 4: Cognitive Burnout Constraint (Subject Repetition)
- **Input**: Subject *Artificial Intelligence* allocated `4` sessions.
- **Constraint Verified**: `max_subject_repetition(SubjectId, Day, Assignments)`.
- **Expected Result**: No subject appears more than twice on any single day. AI is distributed across Monday (1), Tuesday (1), and Wednesday (2).

### Test Case 5: Domain Wipeout Detection & Forward Pruning
- **Input**: Highly constrained timetable where an assignment exhausts the remaining feasible slots for a 1-day urgent subject.
- **Constraint Verified**: `forward_check/4` domain wipeout detection.
- **Expected Result**: The scheduler detects an empty domain (`[]`), increments `domain_wipeouts`, immediately backtracks, and assigns an alternative valid slot without recursive failure.

---

## 🎙️ 15 AI Lab Viva Questions & Crisp Answers

1. **What is a Constraint Satisfaction Problem (CSP)?**
   - *Answer*: A CSP models a problem as a set of variables $X = \{X_1, \dots, X_n\}$, domains $D = \{D_1, \dots, D_n\}$ of allowable values, and a set of constraints $C$ specifying allowable combinations of values. The goal is to find an assignment where all variables satisfy all constraints.

2. **What are the Variables, Domains, and Constraints in this study planner?**
   - *Answer*: **Variables** are the individual study sessions needed for each subject. **Domains** are the available 1-hour time slots across the week. **Constraints** include no slot overlap, daily hour limits, exam deadline boundaries, and max 2 sessions per subject per day.

3. **What is Backtracking Search in CSP?**
   - *Answer*: A depth-first search that assigns values to one variable at a time and backs up (backtracks) whenever a variable has no legal values left to assign without violating constraints.

4. **What is Forward Checking (FC) and how does it improve standard Backtracking?**
   - *Answer*: Forward Checking looks ahead after each assignment by pruning values from the domains of unassigned variables that conflict with the current assignment. If any unassigned variable's domain becomes empty (domain wipeout), the algorithm fails and backtracks immediately, avoiding searching dead-end branches.

5. **What is Domain Wipeout in CSP?**
   - *Answer*: Domain Wipeout occurs when forward checking removes all possible values from an unassigned variable's domain. It indicates that the current partial assignment cannot lead to a valid full solution.

6. **What variable ordering heuristic is used in the scheduler?**
   - *Answer*: The **Most-Constrained Variable (MCV)** / **Minimum Remaining Values (MRV)** heuristic, prioritizing subjects with closer exam dates, higher difficulty, and greater weakness first because they have the most restricted feasible domains.

7. **What value ordering heuristic is used?**
   - *Answer*: The **Least-Constraining Value / Preference Heuristic**, testing slots that match the student's preferred study period (e.g., morning) first before exploring other periods.

8. **Why is SWI-Prolog an ideal language for CSP?**
   - *Answer*: Prolog natively provides declarative knowledge representation (facts and rules), unification, and an automatic depth-first backtracking search engine built directly into its execution model.

9. **How is subject priority calculated?**
   - *Answer*: Using weighted rules: $\text{Score} = (\text{DifficultyWeight} \times 3) + (\text{UrgencyWeight} \times 4) + (\text{WeaknessWeight} \times 3)$, yielding a score out of 50. Higher scores allocate more study sessions.

10. **How does the system ensure sessions occur before an exam?**
    - *Answer*: Through the `before_exam/2` constraint rule: `day_index(Day, DayIndex), DayIndex =< DaysRemaining`. Slots beyond the exam day are pruned from the subject's initial domain.

11. **How is the daily limit enforced in Prolog?**
    - *Answer*: The rule `under_daily_limit/3` counts existing assignments on that day using `findall/3`. If the count is equal to or exceeds `DailyLimit`, the assignment fails, and forward checking prunes all remaining slots on that day.

12. **What is the difference between Hard and Soft constraints?**
    - *Answer*: **Hard constraints** (no overlap, daily limit, exam deadline) must strictly never be violated. **Soft constraints** (preferred study time, break spacing) represent preferences to optimize satisfaction when possible.

13. **How does Prolog represent facts and dynamic knowledge?**
    - *Answer*: Static knowledge is represented as Horn clauses (`time_slot/5`, `day_index/2`). Dynamic facts that change at runtime (student profile, subjects) use `:- dynamic` declarations with `assertz/1` and `retractall/1`.

14. **How are AI explanations generated?**
    - *Answer*: The predicate `explain_subject/2` inspects the underlying score breakdown components (Urgency, Difficulty, Weakness) and constructs explanatory text outlining the exact pedagogical rationale and study strategy.

15. **What happens if no valid conflict-free timetable can be scheduled?**
    - *Answer*: If domains wipe out and all backtracking choice points are exhausted without finding a consistent assignment, Prolog returns `fail` (`Schedule = []`), and the system reports an over-constrained conflict message advising the student to increase available hours.
