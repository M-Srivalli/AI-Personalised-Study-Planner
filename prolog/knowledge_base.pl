/* ==========================================================================
   AI Personalized Study Planner Using SWI-Prolog
   MODULE: knowledge_base.pl
   Knowledge Representation: Facts, Dynamic predicates, and Time slots
   ========================================================================== */

:- module(knowledge_base, [
    student/4,
    subject/5,
    time_slot/5,
    day_index/2,
    all_days/1,
    reset_knowledge_base/0,
    set_student/4,
    add_subject/5,
    load_sample_data/0
]).

% --------------------------------------------------------------------------
% DYNAMIC PREDICATES
% --------------------------------------------------------------------------
% student(Name, DailyHoursLimit, PreferredTime, SessionDuration)
%   - Name: Atom or String
%   - DailyHoursLimit: Integer (e.g., 3 hours/day)
%   - PreferredTime: morning | afternoon | evening | any
%   - SessionDuration: Integer (e.g., 1 hour per session)
:- dynamic student/4.

% subject(Id, Name, Difficulty, DaysRemaining, WeaknessLevel)
%   - Id: Atom (e.g., sub_math)
%   - Name: String or Atom (e.g., 'Discrete Mathematics')
%   - Difficulty: easy | medium | hard
%   - DaysRemaining: Integer (e.g., 2 days until exam)
%   - WeaknessLevel: weak | average | strong
:- dynamic subject/5.

% --------------------------------------------------------------------------
% DAY MAPPING
% Day indices 1..7 allow checking exam urgency and scheduling bounds.
% --------------------------------------------------------------------------
day_index(monday, 1).
day_index(tuesday, 2).
day_index(wednesday, 3).
day_index(thursday, 4).
day_index(friday, 5).
day_index(saturday, 6).
day_index(sunday, 7).

all_days([monday, tuesday, wednesday, thursday, friday, saturday, sunday]).

% --------------------------------------------------------------------------
% TIME SLOTS DEFINITION
% time_slot(SlotId, Day, StartTime, EndTime, Period)
% Each day has 3 Morning slots, 3 Afternoon slots, and 3 Evening slots.
% Built-in breaks:
%   - 12:00 to 14:00 (Lunch & relaxation break)
%   - 17:00 to 18:00 (Evening snack / exercise break)
% --------------------------------------------------------------------------
slot_template(1, '09:00', '10:00', morning).
slot_template(2, '10:00', '11:00', morning).
slot_template(3, '11:00', '12:00', morning).
slot_template(4, '14:00', '15:00', afternoon).
slot_template(5, '15:00', '16:00', afternoon).
slot_template(6, '16:00', '17:00', afternoon).
slot_template(7, '18:00', '19:00', evening).
slot_template(8, '19:00', '20:00', evening).
slot_template(9, '20:00', '21:00', evening).

% Generates time_slot/5 dynamically for all days
time_slot(SlotId, Day, StartTime, EndTime, Period) :-
    day_index(Day, _),
    slot_template(Num, StartTime, EndTime, Period),
    atomic_list_concat([Day, '_s', Num], SlotId).

% --------------------------------------------------------------------------
% KNOWLEDGE BASE MANAGEMENT
% --------------------------------------------------------------------------
reset_knowledge_base :-
    retractall(student(_, _, _, _)),
    retractall(subject(_, _, _, _, _)).

set_student(Name, DailyHoursLimit, PreferredTime, SessionDuration) :-
    retractall(student(_, _, _, _)),
    assertz(student(Name, DailyHoursLimit, PreferredTime, SessionDuration)).

add_subject(Id, Name, Difficulty, DaysRemaining, WeaknessLevel) :-
    retractall(subject(Id, _, _, _, _)),
    assertz(subject(Id, Name, Difficulty, DaysRemaining, WeaknessLevel)).

% --------------------------------------------------------------------------
% SAMPLE STUDENT PROFILE FOR TESTING & DEMO
% --------------------------------------------------------------------------
load_sample_data :-
    reset_knowledge_base,
    set_student('Alex Rivera', 3, morning, 1),
    add_subject(sub_math, 'Discrete Mathematics', hard, 2, weak),
    add_subject(sub_ai,   'Artificial Intelligence', hard, 4, weak),
    add_subject(sub_dbms, 'Database Systems', medium, 5, average),
    add_subject(sub_cn,   'Computer Networks', medium, 6, strong),
    add_subject(sub_os,   'Operating Systems', easy, 7, strong).
