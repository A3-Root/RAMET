// interceptEvent is a custom command registered by the Intercept host DLL at runtime —
// wrapped in a compiled string so HEMTT's static SQF parser doesn't choke on it.
_this call compile "(_this select 0) interceptEvent (_this select 1); nil";
