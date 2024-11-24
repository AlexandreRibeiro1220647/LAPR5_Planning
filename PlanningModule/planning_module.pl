    :- use_module(library(http/thread_httpd)).
    :- use_module(library(http/http_dispatch)).
    :- use_module(library(http/http_json)).
    :- use_module(library(http/http_parameters)).
    :- use_module(library(lists)).
    :- use_module(library(http/http_cors)).
    :- use_module(library(http/json_convert)).
    :- use_module(library(http/json)).

    :- set_prolog_flag(encoding, utf8).
    
    % Cors: Permitir requisições de qualquer origem
    :- set_setting(http:cors, [*]).
    
    % Rota para /obtain_better_solution
    :- http_handler(root(obtain_better_solution), handle_obtain_better_sol, []).
    
    % Rota para outras requisições, se necessário
    :- http_handler(root(sort_surgeries), handle_sort_surgeries, [method(get)]).
    
    % Servidor HTTP na porta 8080
    server(Port) :-
        http_server(http_dispatch, [port(Port)]).
    
    % Inicia o servidor automaticamente
    :- initialization(start_server).
    
    start_server :-
        server(8080),
        writeln('Servidor HTTP rodando na porta 8080').
    
    %--------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    handle_obtain_better_sol(Request) :-
        % Enable CORS
        cors_enable,
    
        % Extract parameters from the request
        http_parameters(Request, [
            or(Op, [atom]),          % Extract 'or' as an atom
            date(Date, [number])    % Extract 'date' as a number
        ]),
    
        % Call obtain_better_sol/4 to calculate the solution
        (   obtain_better_sol(Op, Date, AgOpRoomBetter, LAgDoctorsBetter, _)
        ),
    
        % Log the terms
        format('AgOpRoomBetter: ~w~n', [AgOpRoomBetter]),
        format('LAgDoctorsBetter: ~w~n', [LAgDoctorsBetter]),
    
        % Convert Prolog terms into JSON-compatible structures
        convert_to_json(AgOpRoomBetter, AgOpRoomBetterJSON),
        convert_to_json(LAgDoctorsBetter, LAgDoctorsBetterJSON),
    
        % Create a JSON object containing both AgOpRoomBetter and LAgDoctorsBetter
        JsonResponse = json([ag_op_room_better = AgOpRoomBetterJSON, lag_doctors_better = LAgDoctorsBetterJSON]),
    
        % Reply with the combined JSON response
        reply_json(JsonResponse, [json_object(dict)]).
    
    % Helper to convert Prolog terms into JSON-compatible structures
    convert_to_json(Term, JSON) :-
        is_list(Term),               % If it's a list, map each element
        maplist(convert_to_json, Term, JSON).
    
    convert_to_json((A, B, C), [A, B, C]). % Convert tuple to list
    
    convert_to_json(Other, Other) :-       % Leave atomic values (e.g., numbers, strings) unchanged
        atomic(Other).
    
    convert_to_json(Term, JSON) :-         % Convert compound term to list (ignoring Functor)
        compound(Term),
        Term =.. [_Functor | Args],        % Convert compound term to list of arguments, ignore Functor
        maplist(convert_to_json, Args, JSON).
    






    :- use_module(library(http/http_open)).
    
    % Define surgery/4 and surgery_id/2 as dynamic predicates
    :- dynamic surgery/4.
    :- dynamic surgery_id/2.
    :- dynamic assignment_surgery/2.
    :- dynamic staff/4.
    :- dynamic timetable/3.
    :- dynamic agenda_staff/3.


    % Fetch JSON from a backend URL
    fetch_json(URL, JSON) :-
        setup_call_cleanup(
            http_open(URL, In, []),
            json_read_dict(In, JSON),
            close(In)
        ).
    
    % Convert time in "HH:MM:SS" format to minutes
    time_to_minutes(TimeString, Minutes) :-
        split_string(TimeString, ":", "", [HStr, MStr, SStr]),
        number_string(Hours, HStr),
        number_string(MinutesPart, MStr),
        number_string(_, SStr),  % Seconds are ignored
        Minutes is Hours * 60 + MinutesPart.
    
        % Convert the schedule to (start, end) format in minutes
    convert_schedule(Schedule, ScheduleInMinutes) :-
        maplist(convert_time, Schedule, ScheduleInMinutes).

    convert_time(TimeString, Minutes) :-
        time_to_minutes(TimeString, Minutes).

    % Process surgeries JSON
    process_surgeries(SurgeriesJSON) :-
        maplist(assert_surgery, SurgeriesJSON).
    
    assert_surgery(Surgery) :-
        time_to_minutes(Surgery.anesthesia, AnesthesiaMinutes),
        time_to_minutes(Surgery.surgery, SurgeryMinutes),
        time_to_minutes(Surgery.cleaning, CleaningMinutes),
        assertz(surgery(Surgery.id, AnesthesiaMinutes, SurgeryMinutes, CleaningMinutes)).
    
    % Process surgery_id JSON
    process_surgery_ids(SurgeryIDsJSON) :-
        maplist(assert_surgery_id, SurgeryIDsJSON).

    assert_surgery_id(SurgeryID) :-
        assertz(surgery_id(SurgeryID.id, SurgeryID.type)).

    % Process surgery assignments JSON
    process_assignments(AssignmentsJSON) :-
        maplist(assert_assignment, AssignmentsJSON).

    % Assert a single assignment
    assert_assignment(Assignment) :-
        assertz(assignment_surgery(Assignment.id, Assignment.staffid)).
    
    % Process staff operations JSON
    process_staff_operations(StaffsJSON) :-
        maplist(assert_staff, StaffsJSON).

    % Assert a single staff
    assert_staff(Staff) :-
        % Extract relevant information from the JSON object
        StaffId = Staff.id,
        StaffPosition = Staff.role,
        StaffSpeciality = Staff.specialization,
        SurgeryTypes = Staff.operationTypes,
    
        % Assert the staff facts
        assertz(staff(StaffId, StaffPosition, StaffSpeciality, SurgeryTypes)).

    % Process timetable data from JSON
    process_timetable_data(TimetableJSON) :-
        maplist(assert_timetable, TimetableJSON).

    assert_timetable(ScheduleData) :-
        DoctorId = ScheduleData.doctorId,
        ScheduleList = ScheduleData.schedule,
    
        % For each day, convert schedule and appointments
        maplist(assert_schedule_day(DoctorId), ScheduleList).

        convert_schedule_to_tuple([X, Y], (X, Y)).

    assert_schedule_day(DoctorId, DaySchedule) :-
        Day = DaySchedule.day,
        Schedule = DaySchedule.schedule,
    
        % Convert the schedule to minutes
        convert_schedule(Schedule, ScheduleInMinutes),
    
        convert_schedule_to_tuple(ScheduleInMinutes, ScheduleTup),

        % Assert timetable
        assertz(timetable(DoctorId, Day, ScheduleTup)),
    
        % Process appointments
        process_appointments(DoctorId, Day, DaySchedule.appointments).

    % Process agenda data from JSON
    process_appointments(DoctorId, Day, Appointments) :-
        maplist(assert_appointment(DoctorId, Day), Appointments).

    assert_appointment(DoctorId, Day, Appointment) :-
        StartTime = Appointment.start,
        EndTime = Appointment.end,
        AppointmentName = Appointment.name,
    
        % Convert the appointment times to minutes
        time_to_minutes(StartTime, StartTimeMinutes),
        time_to_minutes(EndTime, EndTimeMinutes),
    
        % Assert agenda_staff fact
        assertz(agenda_staff(DoctorId, Day, [(StartTimeMinutes, EndTimeMinutes, AppointmentName)])).

    % Load data from backend and save as Prolog facts
    load_data_opTypeDuration :-
        % Replace these URLs with your backend endpoints
        fetch_json('http://localhost:5012/api/Planning/opTypeDuration', SurgeriesJSON),
        process_surgeries(SurgeriesJSON).

    load_data_opRequestType :-
        fetch_json('http://localhost:5012/api/Planning/opRequestType', SurgeryIDsJSON),
        process_surgery_ids(SurgeryIDsJSON).
    
    load_data_opRequestDoctor :-
        fetch_json('http://localhost:5012/api/Planning/opRequestDoctor', AssignmentsJSON),
        process_assignments(AssignmentsJSON).
    
    load_data_staffOpTypes :-
        fetch_json('http://localhost:5012/api/Planning/staffOpTypes', StaffsJSON),
        process_staff_operations(StaffsJSON).

    load_data_timetable :-
        fetch_json('http://localhost:5012/api/Planning/staffSchedules', StaffSchedulesJSON),
        process_timetable_data(StaffSchedulesJSON).
        
    load_data :-
        load_data_opTypeDuration, 
        load_data_opRequestType,
        load_data_opRequestDoctor,
        load_data_staffOpTypes,
        load_data_timetable.
    

        % To Remove duplicate facts
    remove_duplicates(Predicate/Arity) :-
        functor(Fact, Predicate, Arity),
        findall(Fact, Fact, Facts),
        list_to_set(Facts, UniqueFacts),
        retractall(Fact),
        maplist(assertz, UniqueFacts).

    clear_all_data :-
        retractall(surgery(_, _, _, _)),
        retractall(surgery_id(_, _)),
        retractall(assignment_surgery(_, _)),
        retractall(staff(_, _, _, _)),
        retractall(timetable(_, _, _)),
        retractall(agenda_staff(_, _, _)),
        write('All data cleared from the knowledge base.').
        




:- dynamic availability/3.
:- dynamic agenda_staff/3.
:- dynamic agenda_staff1/3.
:-dynamic agenda_operation_room/3.
:-dynamic agenda_operation_room1/3.
:-dynamic better_sol/5.

/* +- */
/* agenda_staff(staffId,date,scheduledAppointments) */
/* Este predicado ira definir uma agenda diaria de um membro do staff do hospital
   (doutor por exemplo), incluindo trabalhos ou marcações já existentes. */

agenda_staff(d001,20241028,[(720,790,m01),(1080,1140,c01)]).
agenda_staff(d002,20241028,[(850,900,m02),(901,960,m02),(1380,1440,c02)]).
agenda_staff(d003,20241028,[(720,790,m01),(910,980,m02)]).

/* +- */
/* timetable(staffId,date,staffSchedule) */
/* Este predicado irá definir o horário de trabalho diário de um membro do staff do hospital. */

timetable(d001,20241028,(480,1200)).
timetable(d002,20241028,(500,1440)).
timetable(d003,20241028,(520,1320)).


/* --- IMPLEMENTADO DOMINIO */
/* staff(staffId,staffPosition,staffSpeciality,surgeryTypes) */
/* Este predicado vai definir o id, a profissão que desempenha dentro do hospital, 
   a especialidade e os tipos de cirurgia que pode realizar. */

staff(d001,doctor,orthopaedist,[so2,so3,so4]).
staff(d002,doctor,orthopaedist,[so2,so3,so4]).
staff(d003,doctor,orthopaedist,[so2,so3,so4]).

/* --- IMPLEMENTADO */
/* surgery(surgeryType,timeAnesthesia,timeSurgery,timeCleaning) */
/* Este predicado vai definir quanto tempo demora a anestesia, o tempo de cirurgia 
   e o tempo para limpeza, para cada tipo de cirurgia. */
%surgery(SurgeryType,TAnesthesia,TSurgery,TCleaning).

surgery(so2,45,60,45). 
surgery(so3,45,90,45).
surgery(so4,45,75,45).

/* --- IMPLEMENTADO */
/* surgery_id(surgeryId,surgeryType) */
/* Este predicado vai definir o id de cada cirurgia e o seu tipo.  */

surgery_id(so100001,so2).
surgery_id(so100002,so3).
surgery_id(so100003,so4).
surgery_id(so100004,so2).
surgery_id(so100005,so4).

/* --- IMPLEMENTADO */
/* assignmentSurgery(surgeryId,staffId) */
/* Este predicado vai definir qual(quais) serão os membros do staff responsáveis por cada cirurgia.  */

assignment_surgery(so100001,d001). 
assignment_surgery(so100002,d002).
assignment_surgery(so100003,d003).
assignment_surgery(so100004,d001).
assignment_surgery(so100004,d002).
assignment_surgery(so100005,d002).
assignment_surgery(so100005,d003).



/* agenda_operation_room(operationRoomId, operacoes) */
/* Este predicado vai definir a agenda diária de cada sala de operações(todas as cirurgias marcadas para esse dia).  */
agenda_operation_room(or1,20241028,[]).
agenda_operation_room(or1,20241122,[]).
agenda_operation_room(or1,20241123,[]).

/* free_agenda0/2 e free_agenda1/2 têm como objetivo encontrar intervalos de tempo livres numa agenda diária preenchida. */
/* Se o intervalo da agenda for vazio como na primeira situação, então o intervalo livre da agenda será (0,1440), que corresponde a 24 horas. */
/* Se o intervalo da agenda começar no minuto 0, irá automaticamente chamar o predicado free_agenda1/2. */
/* Para qualquer outra situação em que seja chamado o predicado free_agenda0/2, será chamado o predicado free_agenda1/2, sendo que o primeiro intervalo de tempo livre começa a contar a partir do minuto zero até um minuto antes do tempo de início da agenda.  */
/* Na primeira situação do predicado free_agenda1/2, se a agenda apenas tiver um intervalo já preenchido, o intervalo livre será entre um minuto depois do tempo de fim do intervalo preenchido e 1440 minutos(24 horas).  */
/* Na terceira situação do predicado free_agenda1/2, se dois intervalos de tempo preenchido forem consecutivos, ou seja, o tempo de fim do primeiro será um minuto antes do tempo de início do seguinte, não será criado nenhum intervalo de tempo livre. */
/* Na quarta situação do predicado free_agenda1/2, se dois intervalos de tempo preenchido não forem consecutivos, ou seja, o tempo de fim do primeiro será mais de um minuto antes do tempo de início do seguinte, será criado um intervalo de tempo livre adicional. */
free_agenda0([],[(0,1440)]).
free_agenda0([(0,Tfin,_)|LT],LT1):-!,free_agenda1([(0,Tfin,_)|LT],LT1).
free_agenda0([(Tin,Tfin,_)|LT],[(0,T1)|LT1]):- T1 is Tin-1,
    free_agenda1([(Tin,Tfin,_)|LT],LT1).

free_agenda1([(_,Tfin,_)],[(T1,1440)]):-Tfin\==1440,!,T1 is Tfin+1.
free_agenda1([(_,_,_)],[]).
free_agenda1([(_,T,_),(T1,Tfin2,_)|LT],LT1):-Tx is T+1,T1==Tx,!,
    free_agenda1([(T1,Tfin2,_)|LT],LT1).
free_agenda1([(_,Tfin1,_),(Tin2,Tfin2,_)|LT],[(T1,T2)|LT1]):-T1 is Tfin1+1,T2 is Tin2-1,
    free_agenda1([(Tin2,Tfin2,_)|LT],LT1).

/* adapt_timetable(staffId,Date,IntervalosTempoFornecidos,NovosIntervalosTempo) */
/* Este algoritmo irá ajustar os tempos de início e fim dos intervalos de tempo fornecidos com base na agenda diária de um membro do staff específico.  */
adapt_timetable(D,Date,LFA,LFA2):-timetable(D,Date,(InTime,FinTime)),treatin(InTime,LFA,LFA1),treatfin(FinTime,LFA1,LFA2).

/* O predicado treatin/3 tem como objetivo ajustar o tempo inicial de um ou mais intervalos de tempo fornecidos, com base na agenda de um membro do staff específico. */
/* Na primeira situação se o tempo de início do intervalo fornecido for maior ou igual ao tempo de início da agenda, então o tempo de início do intervalo fornecido será o mesmo.  */
/* Na segunda situação se o tempo final do primeiro intervalo fornecido for menor que o tempo de início da agenda, então este primeiro intervalo será ignorado e o algoritmo prossegue com o resto da lista. */
/* Na terceira situação, se as anteriores não forem respeitadas, então significa que o tempo inicial da agenda estará dentro do intervalo de tempo fornecido, o que significa que o tempo inicial deste intervalo passará a ser o tempo inicial da agenda. */
/* Na quarta situação, se não for fornecido nenhum intervalo, então termina. */
treatin(InTime,[(In,Fin)|LFA],[(In,Fin)|LFA]):-InTime=<In,!.
treatin(InTime,[(_,Fin)|LFA],LFA1):-InTime>Fin,!,treatin(InTime,LFA,LFA1).
treatin(InTime,[(_,Fin)|LFA],[(InTime,Fin)|LFA]).
treatin(_,[],[]).

/* O predicado treatfin/3 tem como objetivo ajustar o tempo final de um ou mais intervalos de tempo fornecidos, com base na agenda de um membro do staff específico. */
/* Na primeira situação se o tempo de fim do intervalo fornecido for menor que o tempo final da agenda, então o tempo de fim do intervalo fornecido será o mesmo.  */
/* Na segunda situação se o tempo inicial do primeiro intervalo fornecido for menor ou igual que o tempo final da agenda, então o algoritmo irá ignorar todos os restantes intervalos de tempo na lista, terminando o algoritmo.  */
/* Na terceira situação, se as anteriores não forem respeitadas, então significa que o tempo final da agenda estará dentro do intervalo de tempo fornecido, o que significa que o tempo final deste intervalo passará a ser o tempo final da agenda. */
/* Na quarta situação, se não for fornecido nenhum intervalo, então termina. */
treatfin(FinTime,[(In,Fin)|LFA],[(In,Fin)|LFA1]):-FinTime>=Fin,!,treatfin(FinTime,LFA,LFA1).
treatfin(FinTime,[(In,_)|_],[]):-FinTime=<In,!.
treatfin(FinTime,[(In,_)|_],[(In,FinTime)]).
treatfin(_,[],[]).

/* O predicado intersect_all_agendas/3 tem como finalidade "juntar" todas as agendas diárias de cada membro do staff.  */
/* Na primeira situação, se a lista de nomes apenas conter um nome, então a sua disponibilidade diária será igual á fornecida. */
/* Na segunda situação, se a lista de nomes conter mais que um nome, então a disponibilidade será calculada chamando o predicado intersect_2_agendas/3. */
intersect_all_agendas([Name],Date,LA):-!,availability(Name,Date,LA).
intersect_all_agendas([Name|LNames],Date,LI):-
    availability(Name,Date,LA),
    intersect_all_agendas(LNames,Date,LI1),
    intersect_2_agendas(LA,LI1,LI).

/* O predicado intersect_2_agendas/3 tem como finalidade "juntar" o horário de duas agendas diárias para uma mesma pessoa.  */
/* Na primeira situação, se a primeira agenda fornecida for "vazia", então a interseção das duas agendas também será "vazia", não interessando */
/* Na segunda situação, para os restantes casos, este predicado irá "chamar" o predicado intersect_availability/4 para "juntar" intervalos de tempo. O append irá "juntar" os resultados da interseção atual(LI) aos da interseção recursiva(LID). */
intersect_2_agendas([],_,[]).
intersect_2_agendas([D|LD],LA,LIT):-	intersect_availability(D,LA,LI,LA1),
					intersect_2_agendas(LD,LA1,LID),
					append(LI,LID,LIT).

/* O predicado intersect_availability/4 tem como finalidade "juntar" dois intervalos de tempo.  */
/* Na primeira situação, se a lista de intervalos de tempo for "vazia", então a interseção também será vazia e LA(resto) também vazio. */
/* Na segunda situação, se o intervalo de tempo acaba antes do intervalo de tempo da lista começar, então não existe interseção e toda a lista de intervalos de tempo será o resto. */
/* Na terceira situação, se o intervalo de tempo começa depois do fim do intervalo de tempo da lista, então o intervalo de tempo da lista é ignorado e o algoritmo continua recursivamente. */
/* Na quarta situação, se o intervalo de tempo termina antes do intervalo de tempo da lista, então a interseção será um intervalo de tempo entre o valor máximo de tempo de início e o valor mínimo de tempo de fim destes dois intervalos, sendo que o resto irá conter o intervalo de tempo entre o valor mínimo e o valor máximo dos tempos de fim + a restantes lista. */
/* Na quinta situação, se o intervalo de tempo termina ao mesmo tempo ou depois do intervalo de tempo da lista, então a interseção será um intervalo de tempo entre o valor máximo de tempo de início e o valor mínimo de tempo de fim destes dois intervalos, com o algoritmo a continuar de forma recursiva, para determinar o resto e toda a restante interseção. */
intersect_availability((_,_),[],[],[]).

intersect_availability((_,Fim),[(Ini1,Fim1)|LD],[],[(Ini1,Fim1)|LD]):-
		Fim<Ini1,!.

intersect_availability((Ini,Fim),[(_,Fim1)|LD],LI,LA):-
		Ini>Fim1,!,
		intersect_availability((Ini,Fim),LD,LI,LA).

intersect_availability((Ini,Fim),[(Ini1,Fim1)|LD],[(Imax,Fmin)],[(Fim,Fim1)|LD]):-
		Fim1>Fim,!,
		min_max(Ini,Ini1,_,Imax),
		min_max(Fim,Fim1,Fmin,_).

intersect_availability((Ini,Fim),[(Ini1,Fim1)|LD],[(Imax,Fmin)|LI],LA):-
		Fim>=Fim1,!,
		min_max(Ini,Ini1,_,Imax),
		min_max(Fim,Fim1,Fmin,_),
		intersect_availability((Fim1,Fim),LD,LI,LA).

/* Este predicado irá calcular o valor mínimo e o valor máximo entre dois valores. */
min_max(I,I1,I,I1):- I<I1,!.
min_max(I,I1,I1,I).



/* Este predicado tem como finalidade fazer a marcação de todas as cirurgias de uma sala específica para um dia específico. */
/* Os predicados retractall/1 têm como finalidade remover todos os dados guardados nos predicados dinâmicos. */
/* O primeiro predicado findall irá fazer uma cópia de todos os dados do predicado agenda_staff, para o predicado agenda_staff1/3 e faz a mesma coisa do predicado agenda_operation_room/3 para agenda_operation_room1/3. */
/* O segundo predicado findall, irá determinar a disponibilidade de cada membro do staff, guardando o resultado no predicado availability/3. */
/* O terceiro predicado findall, irá criar uma lista(LOpCode) que contém todos os id's de cirurgias. */
/* Em último lugar é chamado o predicado availability_all_surgeries/3. */
schedule_all_surgeries(Room,Day):-
    retractall(agenda_staff1(_,_,_)),
    retractall(agenda_operation_room1(_,_,_)),
    retractall(availability(_,_,_)),
    findall(_,(agenda_staff(D,Day,Agenda),assertz(agenda_staff1(D,Day,Agenda))),_),
    agenda_operation_room(Or,Date,Agenda),assert(agenda_operation_room1(Or,Date,Agenda)),
    findall(_,(agenda_staff1(D,Date,L),free_agenda0(L,LFA),adapt_timetable(D,Date,LFA,LFA2),assertz(availability(D,Date,LFA2))),_),
    findall(OpCode,surgery_id(OpCode,_),LOpCode),

    availability_all_surgeries(LOpCode,Room,Day),!.

/* Este predicado tem como finalidade fazer a marcação de cirurgias uma a uma para uma sala específica num dia específico. */
/* Na primeira situação, se não existir mais nenhum surgeryId no intervalo fornecido, então termina este algoritmo recursivo. */
/* Na segunda situação, o algoritmo começa por ir buscar o tipo de cirurgia através do predicado surgery_id/2 e todos os detalhes deste tipo de cirurgia através do predicado surgery/4. */
/* É chamado o predicado  availability_operation/5. */
/* É chamado o predicado  schedule_first_interval/3. */
/* De seguida, o predicado retract/2, será responsável por obter a agenda atual para aquele dia naquela sala de operações. */
/* É chamado o predicado insert_agenda/3. */
/* De seguida, o predicado assertz, será responsável por "atualizar" a agenda que já existia. */
/* É chamado o predicado insert_agenda_doctors/3. */
/* O algoritmo irá continuar de forma recursiva. */
availability_all_surgeries([],_,_).
availability_all_surgeries([OpCode|LOpCode],Room,Day):-
    surgery_id(OpCode,OpType),surgery(OpType,_,TSurgery,_),
    availability_operation(OpCode,Room,Day,LPossibilities,LDoctors),
    schedule_first_interval(TSurgery,LPossibilities,(TinS,TfinS)),
    retract(agenda_operation_room1(Room,Day,Agenda)),
    insert_agenda((TinS,TfinS,OpCode),Agenda,Agenda1),
    assertz(agenda_operation_room1(Room,Day,Agenda1)),
    insert_agenda_doctors((TinS,TfinS,OpCode),Day,LDoctors),
    availability_all_surgeries(LOpCode,Room,Day).


/* Este predicado tem como finalidade "descobrir" os tempos(horários) e os doutores disponíveis para uma determinada cirurgia numa sala específica num dia específico.  */
/* Em primeiro lugar, o algoritmo vai buscar o tipo de cirurgia através do predicado surgery_id/2 e todos os detalhes deste tipo de cirurgia através do predicado surgery/4. */
/* O predicado findall/3 irá obter todos os doutores que realizam este tipo de cirurgias, colocando-os numa lista(LDoctors). */
/* É chamado o predicado intersect_all_agendas/3. */
/* O predicado agenda_operation_room1/3, será utilizado para obter a agenda de uma sala de operações num determinado dia. */
/* É chamado o predicado free_agenda0/2. */
/* É chamado o predicado intersect_2_agendas/3. */
/* É chamado o predicado remove_unf_intervals/3. */
availability_operation(OpCode,Room,Day,LPossibilities,LDoctors):-
    surgery_id(OpCode,OpType),surgery(OpType,_,TSurgery,_),
    findall(Doctor,assignment_surgery(OpCode,Doctor),LDoctors),
    intersect_all_agendas(LDoctors,Day,LA),
    agenda_operation_room1(Room,Day,LAgenda),
    free_agenda0(LAgenda,LFAgRoom),
    intersect_2_agendas(LA,LFAgRoom,LIntAgDoctorsRoom),
    remove_unf_intervals(TSurgery,LIntAgDoctorsRoom,LPossibilities).

/* Este predicado será responsável por filtrar os intervalos de tempo de forma a que respeitem os tempos definidos para as cirurgias. */
/* A primeira situação, é responsável por parar o algoritmo recursivo. */
/* Na segunda situação, o intervalo de tempo irá fazer parte da lista final de intervalos de tempo caso a diferença de tempo deste intervalo seja igual ou maior que o tempo necessário para realizar a cirurgia.  */
/* Na terceira situação, o intervalo de tempo não irá fazer parte do resultado final, caso a sua diferença de tempo seja inferior ao tempo necessário para realizar a cirurgia.  */
remove_unf_intervals(_,[],[]).
remove_unf_intervals(TSurgery,[(Tin,Tfin)|LA],[(Tin,Tfin)|LA1]):-DT is Tfin-Tin+1,TSurgery=<DT,!,
    remove_unf_intervals(TSurgery,LA,LA1).
remove_unf_intervals(TSurgery,[_|LA],LA1):- remove_unf_intervals(TSurgery,LA,LA1).

/* Este predicado é utilizado para selecionar o primeiro intervalo de tempo disponível para a cirurgia, calcular o tempo final da cirurgia e apresenta o intervalo final como resultado. */
schedule_first_interval(TSurgery,[(Tin,_)|_],(Tin,TfinS)):-
    TfinS is Tin + TSurgery - 1.

/* Este predicado vai inserir uma nova cirurgia numa agenda, mantendo a sua ordem cronológica. */
/* Na primeira situação, se a agenda não contém nenhum intervalo de tempo, então será constituída apenas pelo intervalo de tempo que vai ser inserido. */
/* Na segunda situação, se o tempo inicial do intervalo de tempo na "head" da agenda for superior ao tempo final do intervalo de tempo a ser inserido, então este intervalo de tempo será colocado na posição anterior. */
/* Na terceira situação, se as outras não se verificarem, então o algoritmo irá continuar de forma recursiva, até encontrar a posição na agenda onde o intervalo de tempo será inserido. */
insert_agenda((TinS,TfinS,OpCode),[],[(TinS,TfinS,OpCode)]).
insert_agenda((TinS,TfinS,OpCode),[(Tin,Tfin,OpCode1)|LA],[(TinS,TfinS,OpCode),(Tin,Tfin,OpCode1)|LA]):-TfinS<Tin,!.
insert_agenda((TinS,TfinS,OpCode),[(Tin,Tfin,OpCode1)|LA],[(Tin,Tfin,OpCode1)|LA1]):-insert_agenda((TinS,TfinS,OpCode),LA,LA1).

/* Este predicado irá atualizar a agenda de vários médicos para incluir uma nova cirurgia. */
/* A primeira situação é responsável por terminar o algoritmo recursivo. */
/* Na segunda situação, em primeiro lugar, através do predicado agenda_staff1/3, será removida a atual agenda do médico da base de dados dinâmica. */
/* Em segundo lugar, será chamado o predicado insert_agenda/3, que irá atualizar a atual agenda. */
/* Em terceiro lugar, será chamado o predicado assert/1, que irá inserir a nova agenda na base de dados dinâmica. */
/* Em último lugar, o algoritmo irá continuar de forma recursiva pela restante lista de médicos. */
insert_agenda_doctors(_,_,[]).
insert_agenda_doctors((TinS,TfinS,OpCode),Day,[Doctor|LDoctors]):-
    retract(agenda_staff1(Doctor,Day,Agenda)),
    insert_agenda((TinS,TfinS,OpCode),Agenda,Agenda1),
    assert(agenda_staff1(Doctor,Day,Agenda1)),
    insert_agenda_doctors((TinS,TfinS,OpCode),Day,LDoctors).


/* Este predicado é responsável por calcular a melhor solução possível para a marcação de cirurgias para uma determinada sala de operações num determinado dia. */
/* O predicado get_time/1 irá obter o tempo atual do sistema. */
/* De seguida, é chamado o predicado  obtain_better_sol1/2. */
/* O predicado retract irá obter a solução desejada a partir de uma base de dados dinâmica. */
/* Os outputs serão obtidos através do write. */
/* Os outputs são uma agenda otimizada para uma sala de operações, uma agenda otimizada para os médicos, o tempo em que terminam todas as cirurgias na sala de operações e a duração desta computação. */
obtain_better_sol(Room,Day,AgOpRoomBetter,LAgDoctorsBetter,TFinOp):-
%		get_time(Ti),
		(obtain_better_sol1(Room,Day);true),
		retract(better_sol(Day,Room,AgOpRoomBetter,LAgDoctorsBetter,TFinOp)).%,
%            write('Final Result: AgOpRoomBetter='),write(AgOpRoomBetter),nl,
%            write('LAgDoctorsBetter='),write(LAgDoctorsBetter),nl,
%            write('TFinOp='),write(TFinOp),nl.
%		get_time(Tf),
%		T is Tf-Ti,
%		write('Tempo de geracao da solucao:'),write(T),nl.

/* Este predicado é responsável por continuar de forma iterativa a gerar a melhor solução possível. */
/* O predicado asserta/1 vai criar um worst-case scenario na base de dados dinâmica de forma a que a solução encontrada esteja dentro dos limites de tempo. */
/* O primeiro predicado findall e o predicado permutation, vão gerar as permutações das cirurgias através do seu id. */
/* Os predicados retractall vão "limpar" as bases de dados dinâmicas. */
/* O segundo predicado findall vai recriar as bases de dados dinâmicas da agenda_staff1/3 e agenda_operation_room1/3. */
/* O terceiro predicado findall será responsável por obter e guardar a disponibilidade do staff guardando o resultado em availability/3.  */
/* De seguida serão chamados os predicados  availability_all_surgeries/3 e update_better_sol/4, sendo que a instrução "fail" fará com que o algoritmo continue de forma recursiva até que todas as permutações tenham sido "avaliadas".  */
obtain_better_sol1(Room,Day):-
    asserta(better_sol(Day,Room,_,_,1441)),
    findall(OpCode,surgery_id(OpCode,_),LOC),!,
    permutation(LOC,LOpCode),
    retractall(agenda_staff1(_,_,_)),
    retractall(agenda_operation_room1(_,_,_)),
    retractall(availability(_,_,_)),
    findall(_,(agenda_staff(D,Day,Agenda),assertz(agenda_staff1(D,Day,Agenda))),_),
    agenda_operation_room(Room,Day,Agenda),assert(agenda_operation_room1(Room,Day,Agenda)),
    findall(_,(agenda_staff1(D,Day,L),free_agenda0(L,LFA),adapt_timetable(D,Day,LFA,LFA2),assertz(availability(D,Day,LFA2))),_),
    availability_all_surgeries(LOpCode,Room,Day),
    agenda_operation_room1(Room,Day,AgendaR),
		update_better_sol(Day,Room,AgendaR,LOpCode),
		fail.

/* Este predicado é responsável por atualizar as cirurgias se forem encontradas melhores soluções para otimização.   */
update_better_sol(Day,Room,Agenda,LOpCode):-
                better_sol(Day,Room,_,_,FinTime),
                reverse(Agenda,AgendaR),
                evaluate_final_time(AgendaR,LOpCode,FinTime1),
%             write('Analysing for LOpCode='),write(LOpCode),nl,
%             write('now: FinTime1='),write(FinTime1),write(' Agenda='),write(Agenda),nl,
		FinTime1<FinTime,
%             write('best solution updated'),nl,
                retract(better_sol(_,_,_,_,_)),
                findall(Doctor,assignment_surgery(_,Doctor),LDoctors1),
                remove_equals(LDoctors1,LDoctors),
                list_doctors_agenda(Day,LDoctors,LDAgendas),
		asserta(better_sol(Day,Room,Agenda,LDAgendas,FinTime1)).

/* Este predicado é responsável por calcular o tempo final de uma agenda com base na lista de id's das cirurgias. */
evaluate_final_time([],_,1441).
evaluate_final_time([(_,Tfin,OpCode)|_],LOpCode,Tfin):-member(OpCode,LOpCode),!.
evaluate_final_time([_|AgR],LOpCode,Tfin):-evaluate_final_time(AgR,LOpCode,Tfin).

/* Este predicado vai ser usado para organizar as agendas diárias de um doutor. */
/* Na primeira situação, se não existir nenhum doutor, também não irá existir uma lista de agendas. */
/* Na segunda situação, o predicado vai buscar a lista de agendas de um doutor para um dia específico(utilizando o predicado agenda_staff1/3). */
list_doctors_agenda(_,[],[]).
list_doctors_agenda(Day,[D|LD],[(D,AgD)|LAgD]):-agenda_staff1(D,Day,AgD),list_doctors_agenda(Day,LD,LAgD).

/* Este predicado é responsável por remover elementos duplicados numa lista. */
/* Na primeira situação, se a lista não tiver nenhum elemento, então a nova lista não terá nenhum elemento. */
/* Na segunda situação, se a lista tiver um elemento duplicado então significa que a nova lista não irá incluir este elemento. */
/* Na terceira situação, se a lista não tiver um elemento duplicado então significa que será adicionado à nova lista */
remove_equals([],[]).
remove_equals([X|L],L1):-member(X,L),!,remove_equals(L,L1).
remove_equals([X|L],[X|L1]):-remove_equals(L,L1).