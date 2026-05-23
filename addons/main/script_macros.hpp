/*
 * Author: Root
 * Description: Macro definitions for Root's AMET addon
 *              Provides constants, utility macros, and CBA integration
 *
 * Notes:
 * - Common CBA macros (QUOTE, QGVAR, GVAR, DOUBLES, TRIPLES, FUNC) are imported from CBA via script_mod.hpp
 * - PREFIX is defined in script_mod.hpp
 * - Debug macros are conditionally compiled based on DEBUG_MODE_FULL
 *
 * Public: No
 */


// ============================================================================
// Debug Logging Macros
// ============================================================================
// Runtime debug logging controlled by CBA setting ROOT_AMET_DEBUG_MODE
// Logs to RPT file with file name and formatted message

// Check if debug mode is enabled (runtime check)
#ifndef DEBUG_MODE
    #define DEBUG_MODE (missionNamespace getVariable ["ROOT_AMET_DEBUG_MODE", false])
#endif

// Debug logging macros - only log if DEBUG_MODE is enabled
#ifndef DEBUG_LOG
    #define DEBUG_LOG(msg) \
        if (DEBUG_MODE) then { \
            diag_log format ["[ROOT_AMET] %1 | %2", __FILE__, msg]; \
        }
#endif

#ifndef DEBUG_LOG_1
    #define DEBUG_LOG_1(msg,arg1) \
        if (DEBUG_MODE) then { \
            diag_log ("[ROOT_AMET] " + __FILE__ + " | " + format [msg, arg1]); \
        }
#endif

#ifndef DEBUG_LOG_2
    #define DEBUG_LOG_2(msg,arg1,arg2) \
        if (DEBUG_MODE) then { \
            diag_log ("[ROOT_AMET] " + __FILE__ + " | " + format [msg, arg1, arg2]); \
        }
#endif

#ifndef DEBUG_LOG_3
    #define DEBUG_LOG_3(msg,arg1,arg2,arg3) \
        if (DEBUG_MODE) then { \
            diag_log ("[ROOT_AMET] " + __FILE__ + " | " + format [msg, arg1, arg2, arg3]); \
        }
#endif

#ifndef DEBUG_LOG_4
    #define DEBUG_LOG_4(msg,arg1,arg2,arg3,arg4) \
        if (DEBUG_MODE) then { \
            diag_log ("[ROOT_AMET] " + __FILE__ + " | " + format [msg, arg1, arg2, arg3, arg4]); \
        }
#endif

#ifndef DEBUG_LOG_5
    #define DEBUG_LOG_5(msg,arg1,arg2,arg3,arg4,arg5) \
        if (DEBUG_MODE) then { \
            diag_log ("[ROOT_AMET] " + __FILE__ + " | " + format [msg, arg1, arg2, arg3, arg4, arg5]); \
        }
#endif

#ifndef DEBUG_LOG_6
    #define DEBUG_LOG_6(msg,arg1,arg2,arg3,arg4,arg5,arg6) \
        if (DEBUG_MODE) then { \
            diag_log ("[ROOT_AMET] " + __FILE__ + " | " + format [msg, arg1, arg2, arg3, arg4, arg5, arg6]); \
        }
#endif

#ifndef DEBUG_LOG_7
    #define DEBUG_LOG_7(msg,arg1,arg2,arg3,arg4,arg5,arg6,arg7) \
        if (DEBUG_MODE) then { \
            diag_log ("[ROOT_AMET] " + __FILE__ + " | " + format [msg, arg1, arg2, arg3, arg4, arg5, arg6, arg7]); \
        }
#endif

#ifndef DEBUG_LOG_8
    #define DEBUG_LOG_8(msg,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8) \
        if (DEBUG_MODE) then { \
            diag_log ("[ROOT_AMET] " + __FILE__ + " | " + format [msg, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8]); \
        }
#endif

#ifndef DEBUG_LOG_9
    #define DEBUG_LOG_9(msg,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9) \
        if (DEBUG_MODE) then { \
            diag_log ("[ROOT_AMET] " + __FILE__ + " | " + format [msg, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9]); \
        }
#endif

#ifndef DEBUG_LOG_10
    #define DEBUG_LOG_10(msg,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10) \
        if (DEBUG_MODE) then { \
            diag_log ("[ROOT_AMET] " + __FILE__ + " | " + format [msg, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10]); \
        }
#endif

#ifndef DEBUG_LOG_11
    #define DEBUG_LOG_11(msg,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11) \
        if (DEBUG_MODE) then { \
            diag_log ("[ROOT_AMET] " + __FILE__ + " | " + format [msg, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11]); \
        }
#endif

#ifndef DEBUG_LOG_12
    #define DEBUG_LOG_12(msg,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12) \
        if (DEBUG_MODE) then { \
            diag_log ("[ROOT_AMET] " + __FILE__ + " | " + format [msg, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12]); \
        }
#endif

#ifndef DEBUG_LOG_13
    #define DEBUG_LOG_13(msg,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13) \
        if (DEBUG_MODE) then { \
            diag_log ("[ROOT_AMET] " + __FILE__ + " | " + format [msg, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13]); \
        }
#endif

#ifndef DEBUG_LOG_14
    #define DEBUG_LOG_14(msg,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13,arg14) \
        if (DEBUG_MODE) then { \
            diag_log ("[ROOT_AMET] " + __FILE__ + " | " + format [msg, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14]); \
        }
#endif

#ifndef DEBUG_LOG_15
    #define DEBUG_LOG_15(msg,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13,arg14,arg15) \
        if (DEBUG_MODE) then { \
            diag_log ("[ROOT_AMET] " + __FILE__ + " | " + format [msg, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15]); \
        }
#endif

#ifndef DEBUG_LOG_16
    #define DEBUG_LOG_16(msg,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13,arg14,arg15,arg16) \
        if (DEBUG_MODE) then { \
            diag_log ("[ROOT_AMET] " + __FILE__ + " | " + format [msg, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16]); \
        }
#endif

#ifndef DEBUG_LOG_17
    #define DEBUG_LOG_17(msg,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11,arg12,arg13,arg14,arg15,arg16,arg17) \
        if (DEBUG_MODE) then { \
            diag_log ("[ROOT_AMET] " + __FILE__ + " | " + format [msg, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17]); \
        }
#endif

// Legacy debug macros (kept for compatibility, but deprecated)
#ifdef DEBUG_MODE_FULL
    #ifndef ROOT_AMET_LOG_DEBUG
        #define ROOT_AMET_LOG_DEBUG(msg) diag_log text format ["[ROOT_AMET DEBUG] %1", msg]
    #endif
    #ifndef ROOT_AMET_LOG_DEBUG_1
        #define ROOT_AMET_LOG_DEBUG_1(msg,arg1) diag_log text format ["[ROOT_AMET DEBUG] " + msg, arg1]
    #endif
    #ifndef ROOT_AMET_LOG_DEBUG_2
        #define ROOT_AMET_LOG_DEBUG_2(msg,arg1,arg2) diag_log text format ["[ROOT_AMET DEBUG] " + msg, arg1, arg2]
    #endif
    #ifndef ROOT_AMET_LOG_DEBUG_3
        #define ROOT_AMET_LOG_DEBUG_3(msg,arg1,arg2,arg3) diag_log text format ["[ROOT_AMET DEBUG] " + msg, arg1, arg2, arg3]
    #endif
#else
    // No-op when debug disabled
    #ifndef ROOT_AMET_LOG_DEBUG
        #define ROOT_AMET_LOG_DEBUG(msg)
    #endif
    #ifndef ROOT_AMET_LOG_DEBUG_1
        #define ROOT_AMET_LOG_DEBUG_1(msg,arg1)
    #endif
    #ifndef ROOT_AMET_LOG_DEBUG_2
        #define ROOT_AMET_LOG_DEBUG_2(msg,arg1,arg2)
    #endif
    #ifndef ROOT_AMET_LOG_DEBUG_3
        #define ROOT_AMET_LOG_DEBUG_3(msg,arg1,arg2,arg3)
    #endif
#endif

// Error and info logging (always enabled)
#ifndef ROOT_AMET_LOG_ERROR
    #define ROOT_AMET_LOG_ERROR(msg) diag_log text format ["[ROOT_AMET ERROR] %1", msg]
#endif
#ifndef ROOT_AMET_LOG_ERROR_1
    #define ROOT_AMET_LOG_ERROR_1(msg,arg1) diag_log text format ["[ROOT_AMET ERROR] " + msg, arg1]
#endif
#ifndef ROOT_AMET_LOG_ERROR_2
    #define ROOT_AMET_LOG_ERROR_2(msg,arg1,arg2) diag_log text format ["[ROOT_AMET ERROR] " + msg, arg1, arg2]
#endif

#ifndef ROOT_AMET_LOG_INFO
    #define ROOT_AMET_LOG_INFO(msg) diag_log text format ["[ROOT_AMET INFO] %1", msg]
#endif
#ifndef ROOT_AMET_LOG_INFO_1
    #define ROOT_AMET_LOG_INFO_1(msg,arg1) diag_log text format ["[ROOT_AMET INFO] " + msg, arg1]
#endif
#ifndef ROOT_AMET_LOG_INFO_2
    #define ROOT_AMET_LOG_INFO_2(msg,arg1,arg2) diag_log text format ["[ROOT_AMET INFO] " + msg, arg1, arg2]
#endif
#ifndef ROOT_AMET_LOG_INFO_3
    #define ROOT_AMET_LOG_INFO_3(msg,arg1,arg2,arg3) diag_log text format ["[ROOT_AMET INFO] " + msg, arg1, arg2, arg3]
#endif

// ============================================================================
// Color Codes
// ============================================================================
// HTML color codes for output formatting

#ifndef ROOT_AMET_COLOR_SUCCESS
    #define ROOT_AMET_COLOR_SUCCESS "#8ce10b"     // Green - success messages
#endif
#ifndef ROOT_AMET_COLOR_ERROR
    #define ROOT_AMET_COLOR_ERROR "#fa4c58"       // Red - error messages
#endif
#ifndef ROOT_AMET_COLOR_WARNING
    #define ROOT_AMET_COLOR_WARNING "#FFD966"     // Yellow - warning messages
#endif
#ifndef ROOT_AMET_COLOR_INFO
    #define ROOT_AMET_COLOR_INFO "#008DF8"        // Blue - informational messages
#endif
#ifndef ROOT_AMET_COLOR_NEUTRAL
    #define ROOT_AMET_COLOR_NEUTRAL "#BCBCBC"     // Gray - neutral text
#endif

// Side-specific colors
#ifndef ROOT_AMET_COLOR_SIDE_WEST
    #define ROOT_AMET_COLOR_SIDE_WEST "#008DF8"   // Blue - BLUFOR/NATO
#endif
#ifndef ROOT_AMET_COLOR_SIDE_EAST
    #define ROOT_AMET_COLOR_SIDE_EAST "#FA4C58"   // Red - OPFOR/CSAT
#endif
#ifndef ROOT_AMET_COLOR_SIDE_GUER
    #define ROOT_AMET_COLOR_SIDE_GUER "#8CE10B"   // Green - Independent/AAF
#endif
#ifndef ROOT_AMET_COLOR_SIDE_CIV
    #define ROOT_AMET_COLOR_SIDE_CIV "#FFD966"    // Yellow - Civilian
#endif
