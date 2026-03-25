"""
cortical_mgd/utils/logging_config.py

Structured logging setup for the MGD Text Agent.
Monitors STORE/UPDATE/IGNORE decisions per type (API_DEF, PATTERN, EPISODE).
"""

import logging
import sys

# Action/Type counter for observability
_decision_counters: dict = {}


def get_counters() -> dict:
    return dict(_decision_counters)


def reset_counters():
    _decision_counters.clear()


class MemoryDecisionFilter(logging.Filter):
    """Intercetta i log di policy e aggiorna i contatori per tipo."""
    def filter(self, record: logging.LogRecord) -> bool:
        msg = record.getMessage()
        if "Policy →" in msg:
            for action in ("STORE", "UPDATE", "IGNORE"):
                for m_type in ("API_DEF", "PATTERN", "EPISODE"):
                    if action in msg and m_type in msg:
                        key = f"{action}/{m_type}"
                        _decision_counters[key] = _decision_counters.get(key, 0) + 1
        return True


def setup_logging(level: int = logging.INFO, log_file: str = None):
    """
    Configure root logger with optional file output.
    Adds structured filter to track memory decisions by action/type.
    """
    handlers = [logging.StreamHandler(sys.stdout)]
    if log_file:
        handlers.append(logging.FileHandler(log_file, encoding="utf-8"))

    fmt = "%(asctime)s [%(levelname)s] %(name)s: %(message)s"
    logging.basicConfig(format=fmt, level=level, handlers=handlers)

    # Attach decision counter to MemoryManager logger
    mgr_logger = logging.getLogger("cortical_mgd.memory.memory_manager")
    mgr_logger.addFilter(MemoryDecisionFilter())
