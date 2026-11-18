"""Thin client for the CATA R engine.

Runs Rscript as a subprocess and reads the results folder it writes.
This module does NO statistics: all analysis happens in R.
"""
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path


class EngineError(Exception):
    """An error from the engine, with a code and a message safe to show to a user."""

    def __init__(self, code, message, check="", detail=""):
        super().__init__(message)
        self.code = code
        self.message = message
        self.check = check
        self.detail = detail


def find_rscript():
    """Locate Rscript.exe: env var, bundled copy, PATH, then Program Files."""
    env = os.environ.get("CATA_RSCRIPT")
    if env and Path(env).is_file():
        return env

    bundled = Path(__file__).resolve().parent.parent / "r" / "bin" / "Rscript.exe"
    if bundled.is_file():
        return str(bundled)

    on_path = shutil.which("Rscript")
    if on_path:
        return on_path

    root = Path(os.environ.get("ProgramFiles", r"C:\Program Files")) / "R"
    if root.is_dir():
        found = sorted(root.glob("R-*/bin/Rscript.exe"), reverse=True)
        if found:
            return str(found[0])

    raise EngineError(
        "R_NOT_FOUND",
        "R could not be found on this computer. Please reinstall the application.",
        "rscript",
    )


def find_run_script():
    """Locate the engine's command-line script (inst/run.R in the repo)."""
    script = Path(__file__).resolve().parent.parent / "inst" / "run.R"
    if not script.is_file():
        raise EngineError(
            "ENGINE_SCRIPT_MISSING",
            "The analysis engine files are missing. Please reinstall the application.",
            "run_script",
        )
    return script


def run_analysis(input_csv, settings=None, out_dir=None, timeout=300):
    """Run the R engine on a long-format CSV.

    Returns {"out_dir": Path, "results": dict}.
    Raises EngineError with a user-readable message on any failure.
    """
    input_csv = Path(input_csv).resolve()
    if not input_csv.is_file():
        raise EngineError(
            "INPUT_NOT_FOUND", "The data file could not be found: " + str(input_csv), "input_file"
        )

    out = Path(out_dir) if out_dir else Path(tempfile.mkdtemp(prefix="cata_"))
    out.mkdir(parents=True, exist_ok=True)

    settings_path = out / "settings_used.json"
    settings_path.write_text(json.dumps(settings or {}, indent=2), encoding="utf-8")

    cmd = [
        find_rscript(),
        str(find_run_script()),
        "--input", str(input_csv),
        "--settings", str(settings_path),
        "--out", str(out),
    ]

    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
    except subprocess.TimeoutExpired:
        raise EngineError(
            "TIMEOUT", "The analysis took too long and was stopped.", "timeout"
        )

    if proc.returncode != 0:
        err_file = out / "error.json"
        if err_file.is_file():
            e = json.loads(err_file.read_text(encoding="utf-8"))
            raise EngineError(
                e.get("code", "ERROR"), e.get("message", "Analysis failed."), e.get("check", "")
            )
        raise EngineError(
            "ENGINE_CRASH",
            "The analysis engine stopped unexpectedly.",
            "process",
            detail=(proc.stderr or "")[-2000:],
        )

    results_file = out / "results.json"
    if not results_file.is_file():
        raise EngineError(
            "NO_RESULTS", "The analysis finished but produced no results file.", "results_file"
        )

    results = json.loads(results_file.read_text(encoding="utf-8"))
    return {"out_dir": out, "results": results}