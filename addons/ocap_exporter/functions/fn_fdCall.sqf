/*
	Calls a Python function through the FlatDevil extension, hiding the wire
	protocol and multipart paging from callers.

	Parameters:
		0: STRING - "module.function" (or a "#builtin" like "#version")
		1: ARRAY  - arguments (optional; each element may be any SQF value)

	Returns:
		[true,  value]          on success
		[false, kind, message]  on error (kind: "python", "dispatch",
		                        "decode", "init", "internal")

	Usage:
		private _r = ["ramet.bulk.next_world", ["ocap"]] call ocap_renderterrain_fnc_fdCall;
*/

params [["_function", "", [""]], ["_args", [], [[]]]];

private _raw = "flatdevil" callExtension [_function, _args apply {str _x}];
_raw params ["_response", "_returnCode", "_errorCode"];

if (_errorCode != 0) exitWith {
	[false, "internal", format ["callExtension engine error %1", _errorCode]]
};
if (_response isEqualTo "") exitWith {
	[false, "internal", "empty response - flatdevil extension not loaded"]
};

private _parsed = parseSimpleArray _response;

// Multipart: ["pg", id, count] - fetch and concatenate the raw pages.
if ((_parsed select 0) isEqualTo "pg") then {
	_parsed params ["", "_id", "_count"];
	private _buffer = "";
	for "_i" from 1 to _count do {
		private _page = "flatdevil" callExtension ["#page", [str _id, str _i]];
		_buffer = _buffer + (_page select 0);
	};
	_parsed = parseSimpleArray _buffer;
};

if ((_parsed select 0) isEqualTo "ok") exitWith {
	[true, _parsed select 1]
};

// ["err", kind, message, (traceback)]
[false, _parsed param [1, "internal"], _parsed param [2, "unknown error"]]
