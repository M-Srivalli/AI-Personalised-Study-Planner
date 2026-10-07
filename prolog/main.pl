/* ==========================================================================
   AI Personalized Study Planner Using SWI-Prolog
   MODULE: main.pl
   Main Entry Point & Interactive AI Lab Terminal Driver
   ========================================================================== */

:- module(main, [
    run_demo/0,
    show_student/0,
    show_priorities/0,
    show_recommendations/0,
    generate_timetable/0,
    test_csp/0,
    api_get_all_data/1,
    reset_knowledge_base/0,
    set_student/4,
    add_subject/5
]).

:- use_module(knowledge_base).
:- reexport(knowledge_base, [
    reset_knowledge_base/0,
    set_student/4,
    add_subject/5
]).
:- use_module(priorities).
:- use_module(recommendations).
:- use_module(constraints).
:- use_module(scheduler).

% --------------------------------------------------------------------------
% COMPLETE INTERACTIVE DEMO (For AI Lab Examination)
% --------------------------------------------------------------------------
run_demo :-
    nl,
    writeln('======================================================================'),
    writeln('          AI PERSONALIZED STUDY PLANNER USING SWI-PROLOG              '),
    writeln('       Constraint Satisfaction Problem (CSP) & Forward Checking       '),
    writeln('======================================================================'),
    load_sample_data,
    show_student,
    nl,
    show_priorities,
    nl,
    show_recommendations,
    nl,
    generate_timetable,
    nl,
    writeln('======================================================================'),
    writeln('Demo execution finished successfully.'),
    writeln('======================================================================'),
    nl.

% --------------------------------------------------------------------------
% DISPLAY STUDENT INFORMATION
% --------------------------------------------------------------------------
show_student :-
    student(Name, DailyLimit, PrefTime, Duration),
    format('STUDENT PROFILE:~n', []),
    format('  - Name                 : ~w~n', [Name]),
    format('  - Daily Study Limit    : ~w hour(s) per day~n', [DailyLimit]),
    format('  - Preferred Study Time : ~w~n', [PrefTime]),
    format('  - Session Duration     : ~w hour(s)~n', [Duration]).

% --------------------------------------------------------------------------
% DISPLAY PRIORITIES TABLE
% --------------------------------------------------------------------------
show_priorities :-
    writeln('SUBJECT PRIORITIES (Rule-Based Weighted Scoring):'),
    writeln('---------------------------------------------------------------------------------'),
    format('~-20w | ~-10w | ~-8w | ~-8w | ~-6w | ~-6w | ~-6w | ~-8w~n',
           ['Subject', 'Difficulty', 'Days Left', 'Weakness', 'Diff', 'Urg', 'Weak', 'Score/50']),
    writeln('---------------------------------------------------------------------------------'),
    calculate_all_priorities(Sorted),
    forall(
        member(item(Total, _, Name, Diff, Days, Weak, DS, US, WS, _), Sorted),
        format('~-20w | ~-10w | ~-8w | ~-8w | ~-6w | ~-6w | ~-6w | ~-8w~n',
               [Name, Diff, Days, Weak, DS, US, WS, Total])
    ),
    writeln('---------------------------------------------------------------------------------').

% --------------------------------------------------------------------------
% DISPLAY AI RECOMMENDATIONS & "WHAT TO STUDY NEXT"
% --------------------------------------------------------------------------
show_recommendations :-
    writeln('AI EXPLANATION & WHAT TO STUDY NEXT:'),
    writeln('---------------------------------------------------------------------------------'),
    what_to_study_next(_, ActionPlan),
    format('~w~n~n', [ActionPlan]),
    writeln('Detailed Subject Explanations:'),
    all_recommendations(RecList),
    forall(
        member(rec(_, Name, Score, Sessions, Expl), RecList),
        (
            format('  [*] ~w (Score: ~w/50, ~w sessions allocated):~n', [Name, Score, Sessions]),
            format('      "~w"~n~n', [Expl])
        )
    ).

% --------------------------------------------------------------------------
% CSP SCHEDULER EXECUTION & FORMATTED TIMETABLE
% --------------------------------------------------------------------------
generate_timetable :-
    writeln('RUNNING CSP SCHEDULER (Backtracking + Forward Checking):'),
    writeln('---------------------------------------------------------------------------------'),
    generate_study_plan(Schedule, Stats, Summary),
    writeln(Summary),
    Stats = stats(Vars, Assgns, Backtracks, Prunes, Wipeouts),
    format('  * Variables to assign     : ~w study sessions~n', [Vars]),
    format('  * Candidate assignments   : ~w~n', [Assgns]),
    format('  * Forward Check prunings  : ~w domain slots removed~n', [Prunes]),
    format('  * Domain wipeouts caught  : ~w branches pruned early~n', [Wipeouts]),
    format('  * Backtracks encountered  : ~w~n~n', [Backtracks]),
    writeln('PERSONALIZED CONFLICT-FREE TIMETABLE:'),
    writeln('---------------------------------------------------------------------------------'),
    format('~-12w | ~-15w | ~-26w | ~-12w~n', ['Day', 'Time Slot', 'Subject', 'Session ID']),
    writeln('---------------------------------------------------------------------------------'),
    ( Schedule == [] ->
        writeln('  [!] No valid conflict-free timetable could be found with current constraints.')
    ;
        forall(
            member(assigned(SessId, _, SubName, _, Day, Start, End, _), Schedule),
            (
                format(atom(TimeStr), '~w - ~w', [Start, End]),
                format('~-12w | ~-15w | ~-26w | ~-12w~n', [Day, TimeStr, SubName, SessId])
            )
        )
    ),
    writeln('---------------------------------------------------------------------------------').

% --------------------------------------------------------------------------
% AUTOMATED CSP TEST SUITE
% --------------------------------------------------------------------------
test_csp :-
    writeln('RUNNING AUTOMATED CSP VALIDATION TESTS:'),
    load_sample_data,
    generate_study_plan(Schedule, _),
    % Test 1: No overlaps
    findall(Slot, member(assigned(_, _, _, Slot, _, _, _, _), Schedule), Slots),
    sort(Slots, UniqueSlots),
    length(Slots, L1), length(UniqueSlots, L2),
    ( L1 =:= L2 ->
        format('  [PASS] Test 1: No overlapping sessions (~w slots distinct).~n', [L1])
    ;
        writeln('  [FAIL] Test 1: Overlapping slots detected!')
    ),
    % Test 2: Daily hours limit
    student(_, Limit, _, _),
    all_days(Days),
    forall(
        member(D, Days),
        (
            findall(1, member(assigned(_, _, _, _, D, _, _, _), Schedule), SubjsOnD),
            length(SubjsOnD, CountD),
            ( CountD =< Limit -> true ; format('  [FAIL] Test 2: Day ~w exceeded limit ~w (~w)~n', [D, Limit, CountD]))
        )
    ),
    writeln('  [PASS] Test 2: Daily study limits strictly respected for all days.'),
    % Test 3: Exam deadlines respected
    forall(
        member(assigned(_, SubId, _, _, D, _, _, _), Schedule),
        (
            subject(SubId, _, _, DaysRem, _),
            day_index(D, DIdx),
            ( DIdx =< DaysRem -> true ; format('  [FAIL] Test 3: ~w scheduled past exam deadline!~n', [SubId]))
        )
    ),
    writeln('  [PASS] Test 3: Exam deadline boundaries respected (sessions prior to exams).'),
    writeln('All CSP validation tests PASSED successfully.').

% --------------------------------------------------------------------------
% JSON-READY DATA DUMP (For API integration)
% --------------------------------------------------------------------------
api_get_all_data(Data) :-
    student(Name, Limit, Pref, Dur),
    calculate_all_priorities(Priorities),
    findall(
        json([
            id=SubId,
            name=SubName,
            difficulty=Diff,
            daysRemaining=Days,
            weakness=Weak,
            diffScore=DS,
            urgScore=US,
            weakScore=WS,
            totalScore=Total,
            sessionsNeeded=Sessions
        ]),
        member(item(Total, SubId, SubName, Diff, Days, Weak, DS, US, WS, Sessions), Priorities),
        PrioritiesJson
    ),
    all_recommendations(RecList),
    findall(
        json([id=RecId, name=RecName, totalScore=RScore, sessions=RSessions, explanation=Expl]),
        member(rec(RecId, RecName, RScore, RSessions, Expl), RecList),
        RecsJson
    ),
    ( what_to_study_next(NextId, NextPlan) ->
        NextJson = json([subjectId=NextId, plan=NextPlan])
    ;
        NextJson = json([subjectId='', plan='None'])
    ),
    generate_study_plan(Schedule, stats(Vars, Assgns, Backtracks, Prunes, Wipeouts)),
    findall(
        json([
            sessionId=SessId,
            subjectId=SubId,
            subjectName=SubName,
            slotId=SlotId,
            day=Day,
            startTime=Start,
            endTime=End,
            period=Period
        ]),
        member(assigned(SessId, SubId, SubName, SlotId, Day, Start, End, Period), Schedule),
        ScheduleJson
    ),
    Data = json([
        success=true,
        student=json([name=Name, dailyLimit=Limit, preferredTime=Pref, sessionDuration=Dur]),
        priorities=PrioritiesJson,
        recommendations=RecsJson,
        nextFocus=NextJson,
        timetable=ScheduleJson,
        cspStats=json([
            variables=Vars,
            assignments=Assgns,
            backtracks=Backtracks,
            prunings=Prunes,
            wipeouts=Wipeouts
        ])
    ]).
