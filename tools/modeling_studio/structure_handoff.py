"""Explicitly reviewed candidates -> hard_surface.lines. Never auto-approve."""
import json
import sys
from pathlib import Path
from hard_surface import LINE_TYPES

def handoff(report,selection,design):
    if report.get("format")!="SERA_STRUCTURE_ANALYSIS_V1":
        raise ValueError("unsupported analysis format")
    candidates={x["id"]:x for x in report["lines"]}
    parts={p["name"] for p in design["parts"]}
    view=selection["view"]
    if view not in ("front","back","left","right","top","bottom","front_3q","back_3q"):
        raise ValueError("unknown reference view")
    result=[]
    seen=set()
    for row in selection["lines"]:
        key=row["id"]
        if key in seen or key not in candidates:
            raise ValueError("duplicate or missing candidate")
        seen.add(key)
        if row.get("approved") is not True or not str(row.get("reason","")).strip():
            raise ValueError("explicit approval and reason required")
        if row["part"] not in parts or row["kind"] not in LINE_TYPES or row["kind"]=="unknown":
            raise ValueError("approved part and semantic kind required")
        result.append({"part":row["part"],"view":view,"kind":row["kind"],
                       "pixels":candidates[key]["pixels"],"source_candidate":key,
                       "review_reason":row["reason"]})
    return result

if __name__=="__main__":
    if len(sys.argv)!=5:
        raise SystemExit("usage: structure_handoff.py structure.json selection.json design.json output.json")
    report,selection,design=[json.loads(Path(p).read_text()) for p in sys.argv[1:4]]
    lines=handoff(report,selection,design)
    with Path(sys.argv[4]).open("x",encoding="utf-8") as f:
        json.dump({"format":"SERA_REVIEWED_STRUCTURE_LINES_V1","lines":lines},f,indent=2)
