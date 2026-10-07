/* ==========================================================================
   AI Personalized Study Planner Using SWI-Prolog
   MODULE: server.pl
   Native SWI-Prolog HTTP API & Static File Web Server
   ========================================================================== */

:- module(server, [
    start_server/1,
    start_server/0,
    stop_server/0
]).

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_cors)).
:- use_module(library(http/http_files)).
:- use_module(library(http/http_parameters)).

:- use_module(knowledge_base).
:- use_module(priorities).
:- use_module(recommendations).
:- use_module(constraints).
:- use_module(scheduler).

% Enable CORS for local API access
:- set_setting(http:cors, [*]).

% --------------------------------------------------------------------------
% HTTP ROUTE DEFINITIONS
% --------------------------------------------------------------------------
:- http_handler(root(api/data), api_data_handler, [methods([get, options])]).
:- http_handler(root(api/student), api_student_handler, [methods([post, options])]).
:- http_handler(root(api/subjects), api_subjects_handler, [methods([post, options])]).
:- http_handler(root(api/reset), api_reset_handler, [methods([post, options])]).
:- http_handler(root(.), serve_frontend, [prefix]).

serve_frontend(Request) :-
    http_reply_from_files('../frontend', [], Request).

% Handle CORS Preflight OPTIONS requests
reply_cors :-
    format('Access-Control-Allow-Origin: *~n'),
    format('Access-Control-Allow-Methods: GET, POST, OPTIONS~n'),
    format('Access-Control-Allow-Headers: Content-Type~n~n').

% --------------------------------------------------------------------------
% API: GET /api/data
% Returns student profile, priorities, recommendations, timetable, & CSP stats
% --------------------------------------------------------------------------
api_data_handler(Request) :-
    member(method(options), Request), !,
    reply_cors.

api_data_handler(_Request) :-
    cors_enable,
    ( student(Name, DailyLimit, PrefTime, Duration) ->
        true
    ;
        load_sample_data,
        student(Name, DailyLimit, PrefTime, Duration)
    ),
    
    % Fetch Subjects
    findall(
        json([id=SubId, name=SubName, difficulty=Diff, daysRemaining=Days, weakness=Weak]),
        subject(SubId, SubName, Diff, Days, Weak),
        SubjectsList
    ),

    % Calculate Priorities
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

    % AI Recommendations
    all_recommendations(RecList),
    findall(
        json([id=RecId, name=RecName, totalScore=RScore, sessions=RSessions, explanation=Expl]),
        member(rec(RecId, RecName, RScore, RSessions, Expl), RecList),
        RecsJson
    ),

    % "What to Study Next"
    ( what_to_study_next(NextId, NextPlan) ->
        NextJson = json([subjectId=NextId, plan=NextPlan])
    ;
        NextJson = json([subjectId='', plan='No active subjects available.'])
    ),

    % CSP Schedule & Stats
    generate_study_plan(Schedule, stats(VarsCount, Assgns, Backtracks, Prunings, Wipeouts)),
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

    Response = json([
        success=true,
        student=json([
            name=Name,
            dailyLimit=DailyLimit,
            preferredTime=PrefTime,
            sessionDuration=Duration
        ]),
        subjects=SubjectsList,
        priorities=PrioritiesJson,
        recommendations=RecsJson,
        nextFocus=NextJson,
        timetable=ScheduleJson,
        cspStats=json([
            variables=VarsCount,
            assignments=Assgns,
            backtracks=Backtracks,
            prunings=Prunings,
            wipeouts=Wipeouts
        ])
    ]),
    reply_json(Response).

% --------------------------------------------------------------------------
% API: POST /api/student
% Update student profile
% --------------------------------------------------------------------------
api_student_handler(Request) :-
    member(method(options), Request), !,
    reply_cors.

api_student_handler(Request) :-
    cors_enable,
    http_read_json_dict(Request, Dict),
    atom_string(Name, Dict.get(name)),
    Limit = Dict.get(dailyLimit),
    atom_string(PrefTime, Dict.get(preferredTime)),
    Duration = Dict.get(sessionDuration),
    set_student(Name, Limit, PrefTime, Duration),
    reply_json(json([success=true, message='Student profile updated successfully.'])).

% --------------------------------------------------------------------------
% API: POST /api/subjects
% Add or replace subjects list
% --------------------------------------------------------------------------
api_subjects_handler(Request) :-
    member(method(options), Request), !,
    reply_cors.

api_subjects_handler(Request) :-
    cors_enable,
    http_read_json_dict(Request, Dict),
    Subjects = Dict.get(subjects),
    retractall(knowledge_base:subject(_, _, _, _, _)),
    forall(
        member(Sub, Subjects),
        (
            atom_string(Id, Sub.get(id)),
            atom_string(Name, Sub.get(name)),
            atom_string(Diff, Sub.get(difficulty)),
            Days = Sub.get(daysRemaining),
            atom_string(Weak, Sub.get(weakness)),
            add_subject(Id, Name, Diff, Days, Weak)
        )
    ),
    reply_json(json([success=true, message='Subjects updated successfully.'])).

% --------------------------------------------------------------------------
% API: POST /api/reset
% Reset knowledge base to default sample data
% --------------------------------------------------------------------------
api_reset_handler(Request) :-
    member(method(options), Request), !,
    reply_cors.

api_reset_handler(_Request) :-
    cors_enable,
    load_sample_data,
    reply_json(json([success=true, message='Reset to default sample student data.'])).

% --------------------------------------------------------------------------
% SERVER LIFECYCLE MANAGEMENT
% --------------------------------------------------------------------------
:- dynamic server_port/1.

start_server(Port) :-
    stop_server,
    http_server(http_dispatch, [port(Port)]),
    assertz(server_port(Port)),
    format('~n>>> SWI-Prolog Study Planner Server running at: http://localhost:~w/~n~n', [Port]).

start_server :-
    start_server(8080).

stop_server :-
    server_port(P),
    retractall(server_port(_)),
    http_stop_server(P, []),
    format('Server on port ~w stopped.~n', [P]), !.
stop_server.

% Auto-start when loaded as script
% :- initialization(start_server, main).
