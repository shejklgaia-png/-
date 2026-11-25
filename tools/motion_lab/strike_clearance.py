"""Conservative oriented mesh-local bounding box overlap proxy.
Not exact surface penetration: adjacent joint housings are reported separately.
Fifteen SAT axes; report the minimum interval translation along tested axes.
"""
from itertools import combinations
from mathutils import Vector

class StrikeClearance:
    def __init__(self,meshes,strike):
        self.bounds={}
        self.pairs=[]
        for m in meshes:
            coords=[v.co for v in m.data.vertices]
            if not coords:continue
            lo=Vector(tuple(min(v[i] for v in coords) for i in range(3)))
            hi=Vector(tuple(max(v[i] for v in coords) for i in range(3)))
            self.bounds[m]=((lo+hi)*.5,(hi-lo)*.5)
        for a,b in combinations(self.bounds,2):
            if a.parent==b.parent or not (a.parent in strike or b.parent in strike):continue
            adjacent=a.parent.parent==b.parent or b.parent.parent==a.parent
            self.pairs.append((a,b,adjacent))

    @staticmethod
    def overlap(a,b):
        ca,A,ha=a;cb,B,hb=b
        delta=cb-ca
        axes=[*A,*B,*[u.cross(v) for u in A for v in B]]
        minimum=float("inf")
        for axis in axes:
            if axis.length<1e-7:continue
            n=axis.normalized()
            radius=sum(abs(n.dot(v))*h for v,h in zip(A,ha))+sum(abs(n.dot(v))*h for v,h in zip(B,hb))
            ov=radius-abs(delta.dot(n))
            if ov<=0:return 0.
            minimum=min(minimum,ov)
        return minimum

    def measure(self):
        boxes={}
        for m,(center,half) in self.bounds.items():
            mat=m.matrix_world
            axes=[mat.to_3x3().col[i].copy() for i in range(3)]
            scale=[a.length for a in axes]
            if min(scale)<1e-8:raise ValueError("degenerate OBB axis")
            axes=[a.normalized() for a in axes]
            if any(abs(axes[i].dot(axes[j]))>1e-5 for i,j in ((0,1),(0,2),(1,2))):
                raise ValueError("sheared OBB transform")
            boxes[m]=(mat@center,axes,[half[i]*scale[i] for i in range(3)])
        report={"nonadjacent_m":0.,"nonadjacent_pair":None,"adjacent_m":0.,"adjacent_pair":None}
        for a,b,adj in self.pairs:
            v=self.overlap(boxes[a],boxes[b])
            key="adjacent" if adj else "nonadjacent"
            if v>report[key+"_m"]:
                report[key+"_m"]=v;report[key+"_pair"]=[a.name,b.name]
        report["nonadjacent_review_required"]=report["nonadjacent_m"]>.05
        return report
