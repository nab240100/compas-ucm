#!/usr/bin/env python3
"""
Transform the Ai Studio scrape (ai_studio_code.txt) into the validated
academic JSON asset used by the Compás UCM app.

Reads:  ./ai_studio_code.txt          (scrape: structure as scraped)
Writes: ./app/assets/data/academic_2026_2027.json  (app schema v1)

Run from the project root:
    python3 tools/build_academic_json.py

Fails loudly (non-zero exit) if a weekly slot cannot be resolved to a real
course, times are malformed, or core-theory classes overlap.
"""
import json
import re
import sys
from collections import defaultdict
from datetime import datetime
from difflib import SequenceMatcher
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRAPE = ROOT / "ai_studio_code.txt"
OUT_DIR = ROOT / "app" / "assets" / "data"
OUT_FILE = OUT_DIR / "academic_2026_2027.json"

DAY_ORDER = {"Monday": 1, "Tuesday": 2, "Wednesday": 3, "Thursday": 4, "Friday": 5}
# Codes that are offered to 3rd AND 4th year (from "electives_3rd_and_4th_years")
ELECTIVE_CODES = {"806001", "805992", "806000", "804604"}
# Courses with special schedule semantics (multi-date / TBD times, no weekly slots)
SPECIAL_CODES = {"804611": "internship", "804601": "tfg"}

# Abbreviations used inside the timetable PDF/scrape, mapped to course codes.
# The abbreviation set is unique per degree, so this is authoritative
# resolution (safer than fuzzy-matching full names, which collide, e.g.
# "Redes de Computadores" vs "Fundamentos de Redes de Computadores").
ABBREV_TO_CODE = {
    "tyadd": "805964", "cd": "805963", "rysdt": "805968", "adc": "805967",
    "elm1": "805971", "ef": "805972", "edc": "805973", "ssll": "805970",
    "am": "805969", "sotr": "805976", "pds": "805977", "eygdp": "805975",
    "elm2": "805974", "fdde": "805979", "tdc": "805978", "frc": "805981",
    "caf": "805980", "cds": "805984", "ea": "805982", "ccii": "805985",
    "fcem": "805983", "dsd": "804587", "edp": "804581", "rdc": "804600",
    "ie": "804583", "adsi": "804586", "bioing": "806001", "ods": "805992",
    "tfc": "806000", "rob": "804604",
}


def norm(s: str) -> str:
    """Case/accent-insensitive key for matching subject names."""
    s = s.lower()
    for a, b in (("á", "a"), ("é", "e"), ("í", "i"), ("ó", "o"), ("ú", "u"), ("ñ", "n"), ("ü", "u")):
        s = s.replace(a, b)
    return re.sub(r"[^a-z0-9]+", " ", s).strip()


def parse_hhmm(t: str) -> int:
    m = re.fullmatch(r"(\d{1,2}):(\d{2})", t.strip())
    if not m:
        raise ValueError(f"malformed time: {t!r}")
    return int(m.group(1)) * 60 + int(m.group(2))


def parse_date(d: str) -> datetime:
    return datetime.strptime(d, "%Y-%m-%d")


def main() -> int:
    scrape = json.loads(SCRAPE.read_text(encoding="utf-8"))
    errors: list[str] = []
    warnings: list[str] = []

    # ------------------------------------------------------------------ courses
    exams_by_code: dict[str, dict] = {}
    for ex in scrape["exams"]:
        code = ex["course_code"]
        if code in exams_by_code:
            warnings.append(f"duplicate exam entry for {code}")
        exams_by_code[code] = ex

    courses = []
    for code, ex in sorted(exams_by_code.items()):
        years = [3, 4] if code in ELECTIVE_CODES else [ex["year"]]
        courses.append(
            {
                "code": code,
                "name": ex["course_name"],
                "shortName": None,  # filled below from timetable abbreviations
                "years": years,
                "semesters": [ex["semester"]],
                "primarySemester": ex["semester"],  # semestre de matrícula (lista de exámenes)
                "classroom": None,  # filled below from timetable block
                "elective": code in ELECTIVE_CODES,
                "special": SPECIAL_CODES.get(code),
                "examOrdinary": ex.get("ordinary") or None,
                "examExtraordinary": ex.get("extraordinary") or None,
            }
        )

    by_norm_name: dict[str, str] = {}
    for c in courses:
        by_norm_name[norm(c["name"])] = c["code"]
    abbrev_to_code = {k: v for k, v in ABBREV_TO_CODE.items() if v in exams_by_code}

    # ------------------------------------------------------------------ timetables
    tt = scrape["weekly_timetables"]
    slot_meta = {
        "year_1": dict(year=1, scope="year"),
        "year_2": dict(year=2, scope="year"),
        "year_3": dict(year=3, scope="year"),
        "year_4": dict(year=4, scope="year"),
        "electives_3rd_and_4th_years": dict(year=None, scope="electives"),
    }

    weekly_slots: list[dict] = []

    def resolve_subject(subject: str) -> str | None:
        """Return course code for a timetable subject string."""
        m = re.search(r"\(([^)]+)\)\s*$", subject)
        abbr = m.group(1).strip() if m else None
        full = subject[: m.start()].strip() if m else subject.strip()

        if abbr and norm(abbr) in abbrev_to_code:
            return abbrev_to_code[norm(abbr)]
        if norm(full) in by_norm_name:
            return by_norm_name[norm(full)]

        exact_hits = [c for c in courses if norm(full) in norm(c["name"]) or norm(c["name"]) in norm(full)]
        if len(exact_hits) == 1:
            return exact_hits[0]["code"]

        # Fuzzy fallback: unique best match above threshold
        scored = sorted(
            (
                (SequenceMatcher(None, norm(full), norm(c["name"])).ratio(), c["code"], c["name"])
                for c in courses
            ),
            reverse=True,
        )
        if scored and scored[0][0] >= 0.8 and (len(scored) == 1 or scored[0][0] - scored[1][0] >= 0.15):
            return scored[0][1]
        return None

    def fill_short(code: str, subject: str):
        m = re.search(r"\(([^)]+)\)\s*$", subject)
        if m:
            for c in courses:
                if c["code"] == code and not c["shortName"]:
                    c["shortName"] = m.group(1).strip()

    for block_key, block in tt.items():
        meta = slot_meta[block_key]
        for sem_key in ("semester_1", "semester_2"):
            sem_block = block.get(sem_key)
            if not sem_block:
                continue
            semester = 1 if sem_key == "semester_1" else 2
            for theory in sem_block.get("theory_classes", []):
                code = resolve_subject(theory["subject"])
                if code is None:
                    errors.append(f"UNRESOLVED theory slot: {block_key}/{sem_key} {theory['subject']}")
                    continue
                fill_short(code, theory["subject"])
                for c in courses:
                    if c["code"] == code:
                        c["classroom"] = sem_block.get("classroom")
                        if semester not in c["semesters"]:
                            c["semesters"].append(semester)
                weekly_slots.append(
                    {
                        "day": DAY_ORDER[theory["day"]],
                        "start": theory["start"],
                        "end": theory["end"],
                        "courseCode": code,
                        "kind": "theory",
                        "group": None,
                        "classroom": sem_block.get("classroom"),
                        "semester": semester,
                        "scope": meta["scope"],
                    }
                )
            for lab in sem_block.get("laboratories", []):
                code = resolve_subject(lab["subject"])
                if code is None:
                    errors.append(f"UNRESOLVED lab slot: {block_key}/{sem_key} {lab['subject']}")
                    continue
                fill_short(code, lab["subject"])
                weekly_slots.append(
                    {
                        "day": DAY_ORDER[lab["day"]],
                        "start": lab["start"],
                        "end": lab["end"],
                        "courseCode": code,
                        "kind": "lab",
                        "group": lab.get("group"),
                        "classroom": None,
                        "semester": semester,
                        "scope": meta["scope"],
                    }
                )

    # ------------------------------------------------------------------ calendar
    rules = scrape["calendar_rules"]
    semesters = [
        {
            "id": 1,
            "classesStart": rules["semester_1"]["classes_start"],
            "classesEnd": rules["semester_1"]["classes_end"],
            "examPeriod": rules["semester_1"]["ordinary_exams_period"],
            "gradesDeadline": rules["semester_1"]["grades_deadline"],
            "recoveryDays": rules["semester_1"]["recovery_days"],
        },
        {
            "id": 2,
            "classesStart": rules["semester_2"]["classes_start"],
            "classesEnd": rules["semester_2"]["classes_end"],
            "examPeriod": rules["semester_2"]["ordinary_exams_period"],
            "gradesDeadline": rules["semester_2"]["grades_deadline"],
            "recoveryDays": rules["semester_2"]["recovery_days"],
        },
    ]
    extraordinary = rules["extraordinary_exams"]

    TYPE_MAP = {
        "Fiesta Nacional": "festivo",
        "Todos los Santos / Festivo": "festivo",
        "Almudena (Madrid)": "festivo",
        "Constitución / Inmaculada": "festivo",
        "Fiesta del Trabajo / Comunidad de Madrid": "festivo",
        "San Isidro": "festivo",
        "No lectivo": "noLectivo",
        "No lectivo (con posibilidad de actividad académica)": "noLectivo",
        "Vacaciones de Navidad": "vacaciones",
        "Semana Santa": "vacaciones",
        "Santo Tomás de Aquino / No lectivo": "noLectivo",
    }
    calendar_events = []
    for h in rules["holidays_and_recesses"]:
        name = h["name"]
        if "start" in h:
            calendar_events.append(
                {"name": name, "type": TYPE_MAP.get(name, "otro"), "start": h["start"], "end": h["end"]}
            )
        else:
            dates = h.get("dates") or [h["date"]]
            calendar_events.append({"name": name, "type": TYPE_MAP.get(name, "otro"), "dates": dates})

    # Derived events: welcome day (PDF "1 Acto bienvenida") + recovery "R" days
    calendar_events.append({"name": "Acto de bienvenida", "type": "welcome", "dates": ["2026-09-01"]})
    recovery = []
    for s in semesters:
        recovery.extend(s["recoveryDays"])
    calendar_events.append({"name": "Día de recuperación", "type": "recovery", "dates": sorted(set(recovery))})

    calendar_events.sort(key=lambda e: (e.get("start") or min(e.get("dates", ["9999-12-31"]))))

    # ------------------------------------------------------------------ validation
    # 1. All times parseable, start < end, sane bounds
    for s in weekly_slots:
        try:
            a, b = parse_hhmm(s["start"]), parse_hhmm(s["end"])
        except ValueError as e:
            errors.append(f"{s}: {e}")
            continue
        if a >= b:
            errors.append(f"{s}: start >= end")
        if a < 7 * 60 or b > 21 * 60:
            warnings.append(f"{s}: outside 07:00-21:00")
        s["startMinutes"] = a
        s["endMinutes"] = b

    # 2. Core theory slots must not overlap within same year+semester
    core = [s for s in weekly_slots if s["kind"] == "theory" and s["scope"] == "year"]
    by_key: dict[tuple, list[dict]] = defaultdict(list)
    for s in core:
        by_key[(s["courseCode"], s["day"])].append(s)
    for s in core:
        sc = next(c for c in courses if c["code"] == s["courseCode"])
        for t in by_key[(s["courseCode"], s["day"])]:
            if t is s:
                continue
            tc = next(c for c in courses if c["code"] == t["courseCode"])
            same_year_sem = sc["years"] == tc["years"] and sc["semesters"] == tc["semesters"]
            if same_year_sem and min(s["endMinutes"], t["endMinutes"]) > max(
                s["startMinutes"], t["startMinutes"]
            ):
                errors.append(f"OVERLAP theory: {s['courseCode']} vs {t['courseCode']} day {s['day']}")

    # 3. Lab groups sane
    for s in weekly_slots:
        if s["kind"] == "lab" and s["group"]:
            if not re.fullmatch(r"L[1-4]( y L[1-4])?", s["group"]):
                warnings.append(f"unusual lab group: {s['group']} ({s['courseCode']})")

    # 4. Every non-special course has timetable presence
    with_slots = {s["courseCode"] for s in weekly_slots}
    for c in courses:
        if c["code"] not in with_slots and not c["special"]:
            warnings.append(f"course {c['code']} ({c['name']}) has no weekly slots")

    # 5. Exams inside plausible periods (course year +/-1 tolerance not modeled)
    for c in courses:
        for call in ("examOrdinary", "examExtraordinary"):
            ex = c.get(call)
            if not ex:
                continue
            if ex.get("time") == "TBD":
                continue
            try:
                d = parse_date(ex["date"])
            except ValueError:
                errors.append(f"{c['code']} {call}: bad date {ex['date']}")
                continue
            if not (datetime(2026, 12, 16) <= d <= datetime(2027, 1, 20)) and not (
                datetime(2027, 5, 10) <= d <= datetime(2027, 5, 28)
            ) and not (datetime(2027, 6, 14) <= d <= datetime(2027, 7, 5)):
                warnings.append(f"{c['code']} {call}: exam {d.date()} outside all exam periods")

    # ------------------------------------------------------------------ output
    # Keep semester lists deterministic (e.g. Cálculo appears in 1Q and 2Q).
    for c in courses:
        c["semesters"] = sorted(set(c["semesters"]))

    out = {
        "schemaVersion": 1,
        "meta": {
            "academicYear": scrape["academic_year"],
            "degree": scrape["degree"],
            "university": "Universidad Complutense de Madrid",
            "faculty": "Facultad de Ciencias Físicas",
            "sources": [
                "calendario academico.pdf",
                "examenes.pdf",
                "document.pdf (Guía Docente 2026-27, páginas 186-190)",
            ],
            "generatedAt": "2026-09-05",
        },
        "semesters": semesters,
        "extraordinaryExamPeriod": extraordinary["period"],
        "extraordinaryGradesDeadline": extraordinary["grades_deadline"],
        "calendarEvents": calendar_events,
        "weekdays": {"1": "Lunes", "2": "Martes", "3": "Miércoles", "4": "Jueves", "5": "Viernes"},
        "courses": courses,
        "weeklySlots": [
            {k: v for k, v in s.items() if k not in ("startMinutes", "endMinutes", "scope")}
            for s in weekly_slots
        ],
    }

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    OUT_FILE.write_text(json.dumps(out, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"courses: {len(courses)} (electives: {sum(1 for c in courses if c['elective'])})")
    print(f"weekly slots: {len(out['weeklySlots'])} "
          f"(theory: {sum(1 for s in out['weeklySlots'] if s['kind'] == 'theory')}, "
          f"labs: {sum(1 for s in out['weeklySlots'] if s['kind'] == 'lab')})")
    print(f"calendar events: {len(out['calendarEvents'])}")
    for w in warnings:
        print(f"WARN  {w}")
    for e in errors:
        print(f"ERROR {e}")
    if errors:
        print(f"{len(errors)} errors — NOT writing output")
        return 1
    print(f"OK → {OUT_FILE.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
