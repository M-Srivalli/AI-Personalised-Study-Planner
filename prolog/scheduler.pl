/* ==========================================================================
   AI Personalized Study Planner Using SWI-Prolog
   MODULE: scheduler.pl
   Constraint Satisfaction Problem (CSP) Engine:
   Variables, Domains, Backtracking Search, and Forward Checking (FC)
   ========================================================================== */

:- module(scheduler, [
    generate_study_plan/2,
    generate_study_plan/3,
    solve_csp/4,
    all_time_slots/1,
    get_csp_statistics/1
]).

:- use_module(knowledge_base).
:- use_module(priorities).
:- use_module(constraints).

% --------------------------------------------------------------------------
% DYNAMIC CSP METRICS TRACKER
% Tracks backtracks, domain prunings, and conflicts for lab demonstration
% --------------------------------------------------------------------------
:- dynamic csp_stat/2.

reset_csp_stats :-
    retractall(csp_stat(_, _)),
    assertz(csp_stat(backtracks, 0)),
    assertz(csp_stat(prunings, 0)),
    assertz(csp_stat(assignments, 0)),
    assertz(csp_stat(domain_wipeouts, 0)).

inc_stat(Key) :-
    retract(csp_stat(Key, Val)),
    NewVal is Val + 1,
    assertz(csp_stat(Key, NewVal)), !.
inc_stat(Key) :-
    assertz(csp_stat(Key, 1)).

get_csp_statistics(stats(VarsCount, Assignments, Backtracks, Prunings, Wipeouts)) :-
    (csp_stat(assignments, Assignments) -> true ; Assignments = 0),
    (csp_stat(backtracks, Backtracks) -> true ; Backtracks = 0),
    (csp_stat(prunings, Prunings) -> true ; Prunings = 0),
    (csp_stat(domain_wipeouts, Wipeouts) -> true ; Wipeouts = 0),
    (csp_stat(vars_count, VarsCount) -> true ; VarsCount = 0).

% --------------------------------------------------------------------------
% ALL CANDIDATE TIME SLOTS GENERATOR
% --------------------------------------------------------------------------
all_time_slots(Slots) :-
    findall(
        slot(SlotId, Day, StartTime, EndTime, Period),
        time_slot(SlotId, Day, StartTime, EndTime, Period),
        Slots
    ).

% --------------------------------------------------------------------------
% 1. VARIABLE INITIALIZATION
% Generate list of session variables needed based on priority scores.
% Heuristic: Most-Constrained Variable / Highest Priority First
% --------------------------------------------------------------------------
generate_variables(Variables) :-
    calculate_all_priorities(Priorities),
    findall(
        VarsForSubject,
        (
            member(item(Score, SubId, SubName, _, Days, _, _, _, _, Sessions), Priorities),
            generate_subject_sessions(SubId, SubName, Score, Days, Sessions, 1, VarsForSubject)
        ),
        NestedVars
    ),
    flatten(NestedVars, Variables).

generate_subject_sessions(_, _, _, _, 0, _, []) :- !.
generate_subject_sessions(SubId, SubName, Score, Days, Count, Idx, [var(SessId, SubId, SubName, Score, Days)|Rest]) :-
    Count > 0,
    atomic_list_concat([SubId, '_sess', Idx], SessId),
    NextIdx is Idx + 1,
    NextCount is Count - 1,
    generate_subject_sessions(SubId, SubName, Score, Days, NextCount, NextIdx, Rest).

% --------------------------------------------------------------------------
% 2. DOMAIN GENERATION & VALUE ORDERING HEURISTIC
% For each variable, determine initial valid domain slots.
% Slots matching student PreferredTime are ranked FIRST (Value Ordering).
% --------------------------------------------------------------------------
initial_domains([], _, []).
initial_domains([var(SessId, SubId, SubName, Score, Days)|RestVars], AllSlots, [entry(var(SessId, SubId, SubName, Score, Days), Domain)|RestDomains]) :-
    student(_, _, PreferredPeriod, _),
    filter_slots_for_subject(SubId, AllSlots, PreferredPeriod, Domain),
    initial_domains(RestVars, AllSlots, RestDomains).

filter_slots_for_subject(SubId, AllSlots, PreferredPeriod, OrderedDomain) :-
    % 1. Filter statically invalid slots (e.g., past exam day)
    findall(
        Slot,
        (member(Slot, AllSlots), slot_satisfies_domain(SubId, Slot, PreferredPeriod)),
        ValidSlots
    ),
    % 2. Order by preference: Preferred period first, then others
    partition(is_preferred_period(PreferredPeriod), ValidSlots, PreferredSlots, OtherSlots),
    append(PreferredSlots, OtherSlots, OrderedDomain).

is_preferred_period(any, _) :- !.
is_preferred_period(Target, slot(_, _, _, _, Target)).

% --------------------------------------------------------------------------
% 3. FORWARD CHECKING (FC) IMPLEMENTATION
% Given an assignment of Var to Slot:
%   - Prune Slot from all remaining variables' domains.
%   - If the assigned Day reaches DailyHoursLimit in CurrentAssignments,
%     prune ALL slots on that Day from future domains.
%   - Detect DOMAIN WIPEOUT: If any remaining variable has an empty domain,
%     forward checking FAILS immediately (avoids doomed branch search).
% --------------------------------------------------------------------------
forward_check(_, _, _, [], []).
forward_check(AssignedDay, AssignedSlotId, CurrentAssignments, [entry(Var, Domain)|RestEntries], [entry(Var, PrunedDomain)|NewRestEntries]) :-
    student(_, DailyLimit, _, _),
    prune_slot_from_domain(AssignedSlotId, Domain, TempDomain1),
    % If day limit reached, remove whole day
    ( count_sessions_on_day(AssignedDay, CurrentAssignments, DayCount), DayCount >= DailyLimit ->
        prune_day_from_domain(AssignedDay, TempDomain1, PrunedDomain)
    ;
        PrunedDomain = TempDomain1
    ),
    % Domain Wipeout check (Forward Checking Fail condition)
    ( PrunedDomain == [] ->
        inc_stat(prunings),
        inc_stat(domain_wipeouts),
        fail
    ;
        inc_stat(prunings),
        forward_check(AssignedDay, AssignedSlotId, CurrentAssignments, RestEntries, NewRestEntries)
    ).

prune_slot_from_domain(TargetSlotId, Domain, Pruned) :-
    exclude(is_slot_id(TargetSlotId), Domain, Pruned).

is_slot_id(TargetSlotId, slot(TargetSlotId, _, _, _, _)).

prune_day_from_domain(TargetDay, Domain, Pruned) :-
    exclude(is_slot_day(TargetDay), Domain, Pruned).

is_slot_day(TargetDay, slot(_, TargetDay, _, _, _)).

% --------------------------------------------------------------------------
% 4. BACKTRACKING CSP SOLVER WITH FORWARD CHECKING
% solve_csp(VariableDomainEntries, CurrentAssignments, FinalSchedule, Stats)
% --------------------------------------------------------------------------
solve_csp([], CurrentAssignments, SortedSchedule, Stats) :-
    % All variables successfully assigned
    sort_schedule(CurrentAssignments, SortedSchedule),
    get_csp_statistics(Stats).

solve_csp([entry(var(SessId, SubId, SubName, _, _), Domain)|RestEntries], CurrentAssignments, FinalSchedule, Stats) :-
    % Pick a candidate slot from the domain (Choice point for backtracking)
    member(slot(SlotId, Day, StartTime, EndTime, Period), Domain),
    
    % Test consistency against current partial assignment constraints
    satisfies_constraints(session(SubId, SubName), slot(SlotId, Day, StartTime, EndTime, Period), CurrentAssignments),
    
    NewAssignment = assigned(SessId, SubId, SubName, SlotId, Day, StartTime, EndTime, Period),
    NewAssignments = [NewAssignment|CurrentAssignments],
    inc_stat(assignments),

    % FORWARD CHECKING: Prune future domains based on this assignment
    ( forward_check(Day, SlotId, NewAssignments, RestEntries, PrunedFutureEntries) ->
        % Forward check passed: Recurse into next variable
        solve_csp(PrunedFutureEntries, NewAssignments, FinalSchedule, Stats)
    ;
        % Forward check detected domain wipeout or recursion failed: Backtrack!
        inc_stat(backtracks),
        fail
    ).

% --------------------------------------------------------------------------
% SCHEDULE SORTING & FORMATTING
% Sort chronologically by Day index, then StartTime
% --------------------------------------------------------------------------
sort_schedule(Assignments, Sorted) :-
    map_list_to_pairs(schedule_sort_key, Assignments, Pairs),
    keysort(Pairs, SortedPairs),
    pairs_values(SortedPairs, Sorted).

schedule_sort_key(assigned(_, _, _, _, Day, StartTime, _, _), key(DayNum, StartTime)) :-
    day_index(Day, DayNum).

% --------------------------------------------------------------------------
% ENTRY POINT: GENERATE STUDY PLAN
% --------------------------------------------------------------------------
generate_study_plan(Schedule, Stats) :-
    reset_csp_stats,
    generate_variables(Vars),
    length(Vars, VarsCount),
    retractall(csp_stat(vars_count, _)),
    assertz(csp_stat(vars_count, VarsCount)),
    all_time_slots(AllSlots),
    initial_domains(Vars, AllSlots, VarDomains),
    ( solve_csp(VarDomains, [], Schedule, Stats) ->
        true
    ;
        % Fallback message if constraints cannot be satisfied
        Schedule = [],
        Stats = stats(VarsCount, 0, 0, 0, 0)
    ).

generate_study_plan(Schedule, Stats, Logs) :-
    generate_study_plan(Schedule, Stats),
    format_csp_summary(Stats, Schedule, Logs).

format_csp_summary(stats(Vars, _Assgns, Backtracks, Prunes, Wipeouts), Schedule, Summary) :-
    length(Schedule, SchedCount),
    format(atom(Summary),
           'CSP Complete: ~w/~w sessions scheduled. Forward Check Prunings: ~w, Domain Wipeouts prevented: ~w, Backtracks: ~w.',
           [SchedCount, Vars, Prunes, Wipeouts, Backtracks]).
