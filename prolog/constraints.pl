/* ==========================================================================
   AI Personalized Study Planner Using SWI-Prolog
   MODULE: constraints.pl
   Constraint Satisfaction Problem (CSP) Constraints Definitions
   ========================================================================== */

:- module(constraints, [
    satisfies_constraints/3,
    no_overlap/2,
    under_daily_limit/3,
    count_sessions_on_day/3,
    before_exam/2,
    max_subject_repetition/3,
    slot_satisfies_domain/3
]).

:- use_module(knowledge_base).

% --------------------------------------------------------------------------
% CONSTRAINT 1: NO OVERLAP
% Slot cannot already be assigned to another session.
% Assigned term structure:
% assigned(SessionId, SubjectId, SubjectName, SlotId, Day, StartTime, EndTime, Period)
% --------------------------------------------------------------------------
no_overlap(SlotId, CurrentAssignments) :-
    \+ member(assigned(_, _, _, SlotId, _, _, _, _), CurrentAssignments).

% --------------------------------------------------------------------------
% CONSTRAINT 2: DAILY STUDY HOUR LIMIT
% A student cannot study more than their declared DailyHoursLimit in one day.
% --------------------------------------------------------------------------
count_sessions_on_day(Day, Assignments, Count) :-
    findall(1, member(assigned(_, _, _, _, Day, _, _, _), Assignments), L),
    length(L, Count).

under_daily_limit(Day, DailyLimit, CurrentAssignments) :-
    count_sessions_on_day(Day, CurrentAssignments, CurrentCount),
    CurrentCount < DailyLimit.

% --------------------------------------------------------------------------
% CONSTRAINT 3: EXAM DATE BOUNDARY
% Study session must occur on or before the exam day.
% If exam is in 2 days, sessions must be placed on Day 1 or Day 2.
% --------------------------------------------------------------------------
before_exam(SubjectId, Day) :-
    subject(SubjectId, _, _, DaysRemaining, _),
    day_index(Day, DayIndex),
    DayIndex =< DaysRemaining.

% --------------------------------------------------------------------------
% CONSTRAINT 4: SUBJECT REPETITION LIMIT (AVOID BURNOUT)
% Do not allocate more than 2 sessions of the same subject on a single day.
% --------------------------------------------------------------------------
max_subject_repetition(SubjectId, Day, CurrentAssignments) :-
    findall(1, member(assigned(_, SubjectId, _, _, Day, _, _, _), CurrentAssignments), L),
    length(L, Count),
    Count < 2.

% --------------------------------------------------------------------------
% COMBINED HARD CONSTRAINT CHECKER
% Checks if assigning Variable to Slot is consistent with CurrentAssignments
% --------------------------------------------------------------------------
satisfies_constraints(session(SubjectId, _), slot(SlotId, Day, _, _, _), CurrentAssignments) :-
    student(_, DailyLimit, _, _),
    no_overlap(SlotId, CurrentAssignments),
    under_daily_limit(Day, DailyLimit, CurrentAssignments),
    before_exam(SubjectId, Day),
    max_subject_repetition(SubjectId, Day, CurrentAssignments).

% --------------------------------------------------------------------------
% INITIAL DOMAIN FILTER FOR A SUBJECT
% Checks if a slot fundamentally violates static constraints (e.g., exam date)
% --------------------------------------------------------------------------
slot_satisfies_domain(SubjectId, slot(_, Day, _, _, _), _PreferredPeriod) :-
    before_exam(SubjectId, Day).
