"""ramet — Archangel-exposed orchestration module for RAMET bulk exports.

SQF calls land as `"archangel" callExtension ["ramet.<submodule>.<fn>", [...]]`.
Archangel routes that to ramet.<submodule>.<fn>(*args) and serialises the
return value back to SQF.
"""

from . import bulk, stage, kickoff  # noqa: F401
