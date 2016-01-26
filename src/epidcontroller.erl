-module(epidcontroller).
-author("Patrick Begley").


-behaviour(gen_server).

%% gen_server callbacks
-export([
  init/1,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  terminate/2,
  code_change/3
]).

%% API exports
-export([
  start_link/0,
  update/2,
  setTarget/2,
  setPID/5,
  setMinIntegral/2,
  setMaxIntegral/2
]).

-record(pid_config, {
  p = 1     :: pos_integer(),
  i = 0     :: float(),
  d = 0     :: float(),
  t = 3     :: pos_integer(),
  i_min = -10000000  :: integer(),
  i_max =  10000000  :: integer()
}).

-type pid_config() :: #pid_config{}.

-record(state, {
  config            :: pid_config(),
  error             :: float(),
  integral          :: pos_integer(),
  derivative        :: pos_integer(),
  target            :: float()
}).


%%====================================================================
%% API functions
%%====================================================================
-spec(start_link() ->
  {ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link() ->
  StartingPIDValues = #pid_config{},
  gen_server:start_link(?MODULE, [StartingPIDValues], []).

-spec( update(Pid :: pid(), Value :: (integer() | float() ) ) ->
  Adj :: float() ).
update(Pid, Value)
  when is_pid(Pid),
       is_integer(Value) ->
  update( Pid, float(Value));
update( Pid, Value )
  when is_pid(Pid),
       is_float(Value) ->
  gen_server:call(Pid, {update, [Value]}).

-spec(setTarget(Pid :: pid(), Target :: (integer() | float() ) ) ->
  ok).
setTarget( Pid, Target )
  when is_pid(Pid),
  is_integer(Target) ->
  setTarget(Pid, float(Target));
setTarget( Pid, Target )
  when is_pid(Pid),
       is_float(Target) ->
  gen_server:call(Pid, {setTarget, [Target]}).

-spec(setPID(Pid :: pid(), P :: integer(), I :: float, D :: float(), T :: pos_integer()) ->
  ok).
setPID( Pid, P, I, D, T )
  when is_pid(Pid),
       is_integer(P),
       is_float(I),
       is_float(D),
       is_integer(T) ->
  gen_server:call(Pid, {setPID, [P,I,D,T]}).

-spec(setMinIntegral( Pid :: pid(), Min :: integer() ) ->
  ok).
setMinIntegral( Pid, Min )
  when is_pid(Pid),
  is_integer(Min) ->
  gen_server:call(Pid, {setMin, [Min]}).

-spec(setMaxIntegral( Pid :: pid(), Min :: integer() ) ->
  ok).
setMaxIntegral( Pid, Max )
  when is_pid(Pid),
  is_integer(Max) ->
  gen_server:call(Pid, {setMax, [Max]}).

%%====================================================================
%% Internal functions
%%====================================================================

-spec(init(Args :: term()) ->
  {ok, State :: #state{}} | {ok, State :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term()} | ignore).
init([Config = #pid_config{}]) ->
  {ok, #state{config = Config, integral = 0, derivative = 0, error = 0.0, target = 0.0}}.


-spec(handle_call(atom(), From :: {pid(), Tag :: term()},
    State :: #state{}) ->
  {reply, Reply :: term(), NewState :: #state{}} |
  {reply, Reply :: term(), NewState :: #state{}, timeout() | hibernate} |
  {noreply, NewState :: #state{}} |
  {noreply, NewState :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term(), Reply :: term(), NewState :: #state{}} |
  {stop, Reason :: term(), NewState :: #state{}}).
handle_call( {Request, Params}, _From, State)
  when is_atom(Request), is_list(Params) ->
  handle_pid_request(Request, Params, State);
handle_call(_Request, _From, State) ->
  {reply, ok, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_cast(Request :: term(), State :: #state{}) ->
  {noreply, NewState :: #state{}} |
  {noreply, NewState :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term(), NewState :: #state{}}).
handle_cast(_Request, State) ->
  {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
-spec(handle_info(Info :: timeout() | term(), State :: #state{}) ->
  {noreply, NewState :: #state{}} |
  {noreply, NewState :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term(), NewState :: #state{}}).
handle_info(_Info, State) ->
  {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
-spec(terminate(Reason :: (normal | shutdown | {shutdown, term()} | term()),
    State :: #state{}) -> term()).
terminate(_Reason, _State) ->
  ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
-spec(code_change(OldVsn :: term() | {down, term()}, State :: #state{},
    Extra :: term()) ->
  {ok, NewState :: #state{}} | {error, Reason :: term()}).
code_change(_OldVsn, State, _Extra) ->
  {ok, State}.


handle_pid_request( Request, Params, State )
  when Request =:= update ->
  [Value|_] = Params,
  handle_update(Value, State);
handle_pid_request( Request, Params, State )
  when Request =:= setTarget ->
  [Target|_] = Params,
  handle_targetSet(Target, State);
handle_pid_request( Request, Params, State )
  when Request =:= setPID ->
  handle_setPID(Params, State);
handle_pid_request( Request, Params, State )
  when Request =:= setMin ->
  [Target|_] = Params,
  handle_setMin(Target, State);
handle_pid_request( Request, Params, State )
  when Request =:= setMax ->
  [Target|_] = Params,
  handle_setMax(Target, State).


handle_update( UpdatedValue, State ) ->
  PIDConfig = State#state.config,
  Error = State#state.target - UpdatedValue,

  %Prevent the integral term from accumulating above or below pre-determined bounds
  IntegralDecider = ( State#state.error + Error ) * State#state.integral,
  NewStateIntegral = State#state{ integral = calculateIntegral( IntegralDecider, Error, State#state.integral, PIDConfig#pid_config.t, PIDConfig#pid_config.i_min, PIDConfig#pid_config.i_max) },

  NewStateDerivative = NewStateIntegral#state{ derivative = (Error - NewStateIntegral#state.error) / PIDConfig#pid_config.t },
  Output = PIDConfig#pid_config.p * Error + PIDConfig#pid_config.i * NewStateDerivative#state.integral + PIDConfig#pid_config.d * NewStateDerivative#state.derivative,
  FinalState = NewStateDerivative#state{ error = Error },
  {reply, Output, FinalState }.

handle_targetSet( Target, State ) ->
  {reply, ok, State#state{target = Target} }.

handle_setPID( Params, State ) ->
  [P|NewList] = Params,
  [I|NewList2] = NewList,
  [D|NewList3] = NewList2,
  [T|_] = NewList3,
  PidConfigRecord = #pid_config{ p = P, i = I, d = D, t = T},
  {reply, ok, State#state{config = PidConfigRecord} }.


handle_setMin( Target, State ) ->
  Config = State#state.config,
  NewConfig = Config#pid_config{i_min = Target},
  {reply, ok, State#state{config = NewConfig} }.

handle_setMax( Target, State ) ->
  Config = State#state.config,
  NewConfig = Config#pid_config{i_max = Target},
  {reply, ok, State#state{config = NewConfig} }.

calculateIntegral( IntegralDecider, Error, PrevIntegral, T, Min, Max)
  when Error =/= 0,
       IntegralDecider > Min,
       IntegralDecider < Max ->
  PrevIntegral + (Error * T );
calculateIntegral( _IntegralDecider, _Error, _PrevIntegral, _T, _Min, _Max) ->
  0.