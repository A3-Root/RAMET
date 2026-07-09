"""ramet — FlatDevil-exposed orchestration module for RAMET bulk exports.

SQF calls land as `["ramet.<submodule>.<fn>", [...]] call ramet_fnc_fdCall`.
FlatDevil routes that to ramet.<submodule>.<fn>(*args).
"""

from . import bulk, ingame, kickoff, state  # noqa: F401
