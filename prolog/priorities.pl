/* ==========================================================================
   AI Personalized Study Planner Using SWI-Prolog
   MODULE: priorities.pl
   Rule-Based Subject Priority Calculation & Session Allocation
   ========================================================================== */

:- module(priorities, [
    subject_priority/10,
    calculate_all_priorities/1,
    priority_order/2,
    sessions_needed/2
]).

:- use_module(knowledge_base).

% --------------------------------------------------------------------------
% RULE-BASED SCORING WEIGHTS
% --------------------------------------------------------------------------
% Difficulty weights (Scale 1 - 5)
difficulty_weight(hard, 5).
difficulty_weight(medium, 3).
difficulty_weight(easy, 1).

% Urgency weights based on days remaining until exam
urgency_weight(Days, 5) :- Days =< 2, !.
urgency_weight(Days, 4) :- Days =< 5, !.
urgency_weight(Days, 2) :- Days =< 7, !.
urgency_weight(_, 1).

% Performance / Weakness level weights
weakness_weight(weak, 5).
weakness_weight(average, 3).
weakness_weight(strong, 1).

% --------------------------------------------------------------------------
% PRIORITY FORMULA:
% Score = (DiffWeight * 3) + (UrgWeight * 4) + (WeakWeight * 3)
% Total possible score: 50
% --------------------------------------------------------------------------
calculate_score(Difficulty, DaysRemaining, WeaknessLevel, DiffScore, UrgScore, WeakScore, TotalScore) :-
    difficulty_weight(Difficulty, DiffWeight),
    urgency_weight(DaysRemaining, UrgWeight),
    weakness_weight(WeaknessLevel, WeakWeight),
    DiffScore is DiffWeight * 3,
    UrgScore  is UrgWeight  * 4,
    WeakScore is WeakWeight * 3,
    TotalScore is DiffScore + UrgScore + WeakScore.

% --------------------------------------------------------------------------
% ALLOCATION OF STUDY SESSIONS BASED ON PRIORITY SCORE
% --------------------------------------------------------------------------
sessions_needed(TotalScore, 4) :- TotalScore >= 38, !.
sessions_needed(TotalScore, 3) :- TotalScore >= 30, !.
sessions_needed(TotalScore, 2) :- TotalScore >= 20, !.
sessions_needed(_, 1).

% --------------------------------------------------------------------------
% SUBJECT PRIORITY PREDICATE
% subject_priority(Id, Name, Diff, Days, Weakness, DiffScore, UrgScore, WeakScore, TotalScore, Sessions)
% --------------------------------------------------------------------------
subject_priority(Id, Name, Difficulty, DaysRemaining, WeaknessLevel,
                 DiffScore, UrgScore, WeakScore, TotalScore, Sessions) :-
    subject(Id, Name, Difficulty, DaysRemaining, WeaknessLevel),
    calculate_score(Difficulty, DaysRemaining, WeaknessLevel, DiffScore, UrgScore, WeakScore, TotalScore),
    sessions_needed(TotalScore, Sessions).

% --------------------------------------------------------------------------
% CALCULATE AND SORT ALL PRIORITIES DESCENDING
% Returns list of items:
% item(Score, Id, Name, Diff, Days, Weak, DiffScore, UrgScore, WeakScore, Sessions)
% --------------------------------------------------------------------------
calculate_all_priorities(SortedPriorities) :-
    findall(
        item(TotalScore, Id, Name, Diff, Days, Weak, DiffScore, UrgScore, WeakScore, Sessions),
        subject_priority(Id, Name, Diff, Days, Weak, DiffScore, UrgScore, WeakScore, TotalScore, Sessions),
        AllPriorities
    ),
    sort(1, @>=, AllPriorities, SortedPriorities).

% Priority ordering for scheduler (Highest priority first)
priority_order(IdList, OrderedList) :-
    calculate_all_priorities(Sorted),
    findall(Id, (member(item(_, Id, _, _, _, _, _, _, _, _), Sorted), member(Id, IdList)), OrderedList).
