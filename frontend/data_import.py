"""Turns the user's file (.xlsx or .csv) into the long-format CSV the R engine expects.

This is data reshaping only. No statistics happen here.
Accepted layouts:
  wide: column 1 = panelist, column 2 = product, then one 0/1 column per attribute
  long: columns panelist, product, attribute, checked
"""
import csv
import io
from pathlib import Path

from engine_client import EngineError

LONG_COLUMNS = ["panelist", "product", "attribute", "checked"]
UNREADABLE = (
    "This file could not be read. Check that it is a valid .xlsx or .csv file "
    "and that it is not open in another program."
)
UNSUPPORTED = (
    "Please choose an Excel (.xlsx) or CSV (.csv) file. "
    "Older .xls files should be saved as .xlsx first."
)


def _cell(v):
    if v is None:
        return ""
    if isinstance(v, float) and v.is_integer():
        return str(int(v))
    return str(v).strip()


def _split_header(rows):
    rows = [r for r in rows if any(_cell(c) for c in r)]
    if not rows:
        raise EngineError("EMPTY_FILE", "The file has no data.", "empty_file")
    header = [_cell(c) for c in rows[0]]
    n = len(header)
    while n and not header[n - 1]:
        n -= 1
    header = header[:n]
    body = []
    for r in rows[1:]:
        cells = [_cell(c) for c in r[:n]]
        cells += [""] * (n - len(cells))
        body.append(cells)
    return header, body


def _looks_like_data(rows):
    try:
        header, body = _split_header(rows)
    except EngineError:
        return False
    if len(header) < 3 or not body:
        return False
    lower = {h.lower() for h in header}
    if set(LONG_COLUMNS) <= lower:
        return True
    return all(c in ("", "0", "1") for r in body for c in r[2:])


def _read_xlsx(path, sheet):
    import openpyxl

    wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
    try:
        return [list(r) for r in wb[sheet].iter_rows(values_only=True)]
    finally:
        wb.close()


def _read_csv(path):
    raw = Path(path).read_bytes()
    try:
        text = raw.decode("utf-8-sig")
    except UnicodeDecodeError:
        text = raw.decode("cp1252")
    first = text.splitlines()[0] if text.strip() else ""
    delim = ";" if first.count(";") > first.count(",") else ","
    return list(csv.reader(io.StringIO(text), delimiter=delim))


def inspect_file(path):
    """Say what kind of file this is and, for Excel, which sheets it has."""
    ext = Path(path).suffix.lower()
    if ext == ".csv":
        return {"kind": "csv", "sheets": [], "default_sheet": None}
    if ext != ".xlsx":
        raise EngineError("UNSUPPORTED_FILE", UNSUPPORTED, "file_type")
    try:
        import openpyxl

        wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
        try:
            sheets, default = [], None
            for ws in wb.worksheets:
                if ws.sheet_state != "visible":
                    continue
                sheets.append(ws.title)
                if default is None:
                    rows = []
                    for i, r in enumerate(ws.iter_rows(values_only=True)):
                        if i >= 30:
                            break
                        rows.append(list(r))
                    if _looks_like_data(rows):
                        default = ws.title
        finally:
            wb.close()
    except Exception:
        raise EngineError("UNREADABLE_FILE", UNREADABLE, "read_file")
    if not sheets:
        raise EngineError("NO_SHEETS", "This workbook has no visible sheets.", "sheets")
    return {"kind": "xlsx", "sheets": sheets, "default_sheet": default or sheets[0]}


def _wide_to_long(header, body):
    if len(header) < 3:
        raise EngineError(
            "TOO_FEW_COLUMNS",
            "The data needs at least 3 columns: panelist, product, and one 0/1 column for each attribute.",
            "columns",
        )
    attrs = header[2:]
    for i, a in enumerate(attrs):
        if not a:
            raise EngineError(
                "UNNAMED_COLUMN",
                "Column %d has no name. Every attribute column needs a header." % (i + 3),
                "header",
            )
    dup = sorted({a for a in attrs if attrs.count(a) > 1})
    if dup:
        raise EngineError(
            "DUPLICATE_ATTRIBUTE_NAMES",
            "These attribute names appear more than once: " + ", ".join(dup) + ".",
            "header",
        )
    out = []
    for r in body:
        for a, v in zip(attrs, r[2:]):
            out.append([r[0], r[1], a, v])
    return out


def prepare_input(path, sheet, out_dir):
    """Read the user's file and write out_dir/data_long.csv. Returns info about it."""
    ext = Path(path).suffix.lower()
    try:
        if ext == ".xlsx":
            if not sheet:
                sheet = inspect_file(path)["default_sheet"]
            raw = _read_xlsx(path, sheet)
        elif ext == ".csv":
            raw = _read_csv(path)
        else:
            raise EngineError("UNSUPPORTED_FILE", UNSUPPORTED, "file_type")
        header, body = _split_header(raw)
    except EngineError:
        raise
    except Exception:
        raise EngineError("UNREADABLE_FILE", UNREADABLE, "read_file")

    lower = [h.lower() for h in header]
    reshaped = not all(c in lower for c in LONG_COLUMNS)
    if reshaped:
        long_rows = _wide_to_long(header, body)
    else:
        idx = [lower.index(c) for c in LONG_COLUMNS]
        long_rows = [[r[i] for i in idx] for r in body]

    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    target = out_dir / "data_long.csv"
    with open(target, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(LONG_COLUMNS)
        w.writerows(long_rows)
    return {"path": target, "n_rows": len(long_rows), "reshaped": reshaped}