"""Demonstrate intent fitting on an opt-in design copy; source and game models unchanged."""
import copy
import json
import sys
from pathlib import Path
from hard_surface import compile_design

def main(root):
    source=json.loads((root/"design.json").read_text())
    spec=copy.deepcopy(source)
    armor=next(p for p in spec["parts"] if p["name"]=="Armor")
    fit=armor["dimension_fit"]["x"]
    fit.update({"target_m":.9,"bounds_m":[.7,1.0],"intent_weight":3.,
                "tolerance_m":.025,"reason":"Retain the broad armor silhouette while allowing reference disagreement.",
                "observations":[{"source":"synthetic front","value_m":.88,"weight":1.},
                                {"source":"synthetic rear","value_m":.92,"weight":.8},
                                {"source":"synthetic inconsistent illustration","value_m":1.18,"weight":.35}]})
    compiled,plan=compile_design(spec)
    report=plan["parts"]["Armor"]["dimension_fit"]["x"]["intent_fit"]
    if not .7<=report["after_m"]<=1.0 or report["objective_after"]>report["objective_before"]+1e-12:
        raise ValueError("intent fit violates bounds or worsens objective")
    if not report["observations"][-1]["outlier"]:
        raise ValueError("inconsistent observation not recorded")
    out=root/"structure_analysis"/"intent"
    out.mkdir(exist_ok=False)
    for filename,data in (("design.json",spec),("compiled_design.json",compiled),("plan.json",plan),
                          ("evaluation.json",{"format":"SERA_INTENT_FIT_REVIEW_V1","result":report,
                           "limits":"Synthetic conflicting dimension observations; no new model rendered or aesthetic quality measured."})):
        (out/filename).write_text(json.dumps(data,indent=2),encoding="utf-8")
if __name__=="__main__":
    main(Path(sys.argv[1]).resolve())
