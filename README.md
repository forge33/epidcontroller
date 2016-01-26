epidcontroller
=====

epidcontroller is a controller libary for the PID(proportional–integral–derivative) algorithm in Erlang.
The library is originally built for the home brewing software I'm writing.

> See https://en.wikipedia.org/wiki/PID_controller

Standard PID algorithm, with built in integral limits(defaults min:-10000000, max:10000000)

Usage
-----
    Once you start the gen server, set your PID values
    epidcontroller::setPID( Pid, 100, 19.2, 195, 3).
    
    Then set your target
    epidcontroller::setTarget( Pid, 171.1 ).
    
    Now start updating the loop
    epidcontroller::update( Pid, 75.6 ).
    
    Set the integral limits if needed
    epidcontroller::setMinIntegral(Pid, 0).
    epidcontroller::setMaxIntegral(Pid, 100).

Build
-----

    $ rebar3 compile
