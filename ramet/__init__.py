"""ramet — Archangel-exposed orchestration module for RAMET bulk exports.

SQF calls land as `"archangel" callExtension ["ramet.<submodule>.<fn>", [...]]`.
Archangel routes that to ramet.<submodule>.<fn>(*args).
"""

from . import bulk, kickoff  # noqa: F401
