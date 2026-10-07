/* ==========================================================================
   AI Personalized Study Planner Using SWI-Prolog
   MODULE: recommendations.pl
   AI Explanation & "What to Study Next" Recommendation Engine
   ========================================================================== */

:- module(recommendations, [
    generate_recommendation/2,
    explain_subject/2,
    what_to_study_next/2,
    all_recommendations/1
]).

:- use_module(knowledge_base).
:- use_module(priorities).

% --------------------------------------------------------------------------
% GENERATE DETAILED EXPLANATION FOR A SUBJECT
% --------------------------------------------------------------------------
explain_subject(SubjectId, Explanation) :-
    subject_priority(SubjectId, Name, Diff, Days, Weakness,
                     DiffScore, UrgScore, WeakScore, TotalScore, Sessions),
    student(_, _, PreferredTime, _),
    explain_urgency(Days, UrgScore, UrgText),
    explain_difficulty(Diff, DiffScore, DiffText),
    explain_weakness(Weakness, WeakScore, WeakText),
    study_strategy(Diff, Weakness, StrategyText),
    format(atom(Explanation),
           '~w is assigned Priority Score ~w/50 (~w sessions allocated). Rationale: ~w, ~w, and ~w. Strategy: ~w Best scheduled during ~w periods.',
           [Name, TotalScore, Sessions, UrgText, WeakText, DiffText, StrategyText, PreferredTime]).

explain_urgency(Days, Score, Text) :-
    Days =< 2, !,
    format(atom(Text), 'exam is imminent in ~w days (Urgency: Critical, +~w pts)', [Days, Score]).
explain_urgency(Days, Score, Text) :-
    Days =< 5, !,
    format(atom(Text), 'exam is approaching in ~w days (Urgency: High, +~w pts)', [Days, Score]).
explain_urgency(Days, Score, Text) :-
    Days =< 7, !,
    format(atom(Text), 'exam in ~w days (Urgency: Moderate, +~w pts)', [Days, Score]).
explain_urgency(Days, Score, Text) :-
    format(atom(Text), 'exam is ~w days away (Urgency: Low, +~w pts)', [Days, Score]).

explain_difficulty(hard, Score, Text) :-
    format(atom(Text), 'difficulty is Hard (+~w pts - requires deep conceptual focus)', [Score]).
explain_difficulty(medium, Score, Text) :-
    format(atom(Text), 'difficulty is Medium (+~w pts - standard practice needed)', [Score]).
explain_difficulty(easy, Score, Text) :-
    format(atom(Text), 'difficulty is Easy (+~w pts - quick revision sufficient)', [Score]).

explain_weakness(weak, Score, Text) :-
    format(atom(Text), 'student reports Weak mastery (+~w pts - high remedial focus)', [Score]).
explain_weakness(average, Score, Text) :-
    format(atom(Text), 'student reports Average mastery (+~w pts - consolidation needed)', [Score]).
explain_weakness(strong, Score, Text) :-
    format(atom(Text), 'student reports Strong mastery (+~w pts - reinforcement only)', [Score]).

study_strategy(hard, weak, 'Prioritize foundational theory and guided numericals. Break into small intensive chunks.').
study_strategy(hard, average, 'Tackle challenging problem sets and practice past-year papers.').
study_strategy(hard, strong, 'High-level synthesis, edge cases, and timed mock tests.').
study_strategy(medium, weak, 'Review core textbook examples and clear fundamental doubts.').
study_strategy(medium, average, 'Standard practice questions and active recall summaries.').
study_strategy(medium, strong, 'Quick flashcard drills and rapid problem revisions.').
study_strategy(easy, weak, 'Address minor conceptual blind spots and review summary notes.').
study_strategy(easy, average, 'Quick skim of key definitions and essential formulas.').
study_strategy(easy, strong, 'Brief maintenance review to preserve confidence.').

% --------------------------------------------------------------------------
% RECOMMEND WHAT TO STUDY NEXT
% Identifies the top-priority subject and immediate action plan
% --------------------------------------------------------------------------
what_to_study_next(TopSubjectId, ActionPlan) :-
    calculate_all_priorities([item(Score, TopSubjectId, Name, Diff, Days, Weakness, _, _, _, Sessions)|_]),
    student(_, DailyLimit, PrefTime, _),
    explain_subject(TopSubjectId, DetailedReason),
    study_strategy(Diff, Weakness, Strategy),
    format(atom(ActionPlan),
           'RECOMMENDED NEXT FOCUS: "~w" (Score: ~w/50, ~w sessions needed). Exam in ~w day(s). Strategy: ~w Target your upcoming ~w session (Daily target: ~w hrs). Reasoning: ~w',
           [Name, Score, Sessions, Days, Strategy, PrefTime, DailyLimit, DetailedReason]).

% --------------------------------------------------------------------------
% GENERATE ALL RECOMMENDATIONS
% Returns list of structured recommendation records
% --------------------------------------------------------------------------
generate_recommendation(SubjectId, rec(SubjectId, Name, TotalScore, Sessions, Explanation)) :-
    subject_priority(SubjectId, Name, _, _, _, _, _, _, TotalScore, Sessions),
    explain_subject(SubjectId, Explanation).

all_recommendations(RecList) :-
    calculate_all_priorities(Sorted),
    findall(
        rec(Id, Name, Score, Sessions, Explanation),
        (
            member(item(Score, Id, Name, _, _, _, _, _, _, Sessions), Sorted),
            explain_subject(Id, Explanation)
        ),
        RecList
    ).
