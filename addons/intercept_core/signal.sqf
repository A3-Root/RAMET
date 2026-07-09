/*
 * Author: esteldunedain
 * Sends a signal to an Intercept extension
 *
 * Arguments:
 * 0: extension name <STRING>
 * 1: Signal name <SRING>
 * 2: Parameters <ANY>
 *
 * Return value:
 * Success <BOOL>
 *
 * Example:
 * ["z\intercept\build\win32\example_frag\RelWithDebInfo\example_frag.dll", "enableFrag", myParameters] call intercept_fnc_signal
 *
 * Public: No
 *
 */
params ["_extensionName", "_signalName", "_parameters"];

if !(intercept_invoker_ok) exitWith {false};

// interceptSignal is a custom command registered by the Intercept host DLL at runtime —
// HEMTT's static SQF parser doesn't know it, so the call is wrapped in a compiled string
// (same workaround grad_meh uses for gradMehExportMap) instead of raw top-level syntax.
[[_extensionName,_signalName], _parameters] call compile "(_this select 0) interceptSignal (_this select 1);";

//intercept_signal_var set[0, _parameters];
//"intercept" callExtension format ["signal:%1,%2",_extensionName,_signalName];
