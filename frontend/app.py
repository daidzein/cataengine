"""CATA Analysis window. Collects a data file and displays results; no statistics here."""
from pathlib import Path

import webview

from data_import import inspect_file, prepare_input
from engine_client import EngineError, run_analysis

HERE = Path(__file__).resolve().parent
OUT_DIR = HERE.parent / "out"

SETTINGS = {
    "schema_version": "1.0",
    "alpha": 0.05,
    "correction": "bonferroni",
    "analyses": ["contingency", "cochran_q", "chisq"],
    "ideal_product_name": "Ideal",
    "exclude_ideal_from_q": True,
}


class Api:
    def choose_file(self):
        dialog_enum = getattr(webview, "FileDialog", None)
        open_type = dialog_enum.OPEN if dialog_enum else webview.OPEN_DIALOG
        result = webview.windows[0].create_file_dialog(
            open_type,
            allow_multiple=False,
            file_types=("Excel or CSV files (*.xlsx;*.csv)",),
        )
        return result[0] if result else None

    def inspect(self, path):
        try:
            return dict(ok=True, **inspect_file(path))
        except EngineError as e:
            return {"ok": False, "message": e.message}

    def run(self, path, sheet=None):
        try:
            prepared = prepare_input(path, sheet, OUT_DIR)
            res = run_analysis(prepared["path"], SETTINGS, out_dir=OUT_DIR)
        except EngineError as e:
            return {"ok": False, "code": e.code, "message": e.message}
        return {
            "ok": True,
            "doc": res["results"],
            "out_dir": str(res["out_dir"]),
            "converted": str(prepared["path"]),
            "reshaped": prepared["reshaped"],
        }


if __name__ == "__main__":
    webview.create_window(
        "CATA Analysis",
        url=str(HERE / "ui.html"),
        js_api=Api(),
        width=1100,
        height=800,
    )
    webview.start()