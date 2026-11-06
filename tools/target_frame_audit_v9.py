"""Validate target cube full-frame projection and new near zoom / loose player edge.
Pure 3D perspective math; this is not a Godot runtime test.
"""
from math import sin,cos,pi,radians,tan,sqrt

WIDTH, HEIGHT = 720, 1280
F = HEIGHT / (2*tan(radians(61)/2))
PITCH = .1325
TARGET_H = 1.53
HALF = 1.0


def projection(point, yaw, radius):
    eye = (radius*sin(yaw),TARGET_H+PITCH*radius,radius*cos(yaw))
    right = (cos(yaw), 0.0, -sin(yaw))
    n = sqrt(1+PITCH**2)
    forward = (-sin(yaw)/n, -PITCH/n,-cos(yaw)/n)
    up = (-PITCH*sin(yaw)/n, 1/n,-PITCH*cos(yaw)/n)
    rel = [point[i]-eye[i] for i in range(3)]
    dot=lambda a:sum(rel[i]*a[i] for i in range(3))
    depth=dot(forward)
    if depth <= 0: return None
    return (WIDTH/2+F*dot(right)/depth, HEIGHT/2-F*dot(up)/depth)


def box_aabb(yaw, radius):
    projections=[projection((x,TARGET_H+y,z),yaw,radius)
                 for x in [-HALF,HALF] for y in [-HALF,HALF] for z in [-HALF,HALF]]
    assert all(q is not None for q in projections)
    return (min(q[0] for q in projections),max(q[0] for q in projections),
            min(q[1] for q in projections),max(q[1] for q in projections))


def desired_radius(distance):
    t=max(0.0,min(1.0,(distance-1.5)/(12.-1.5)))
    t=t*t*(3-2*t)
    return max(6.5+(16.-6.5)*t,distance+2.)


def audit():
    count=0
    near_extent=0
    for radius in [6.5,7.0,8.0,10.0,16.0,35.0]:
        for i in range(720):
            yaw=i*(2*pi/720)
            x0,x1,y0,y1=box_aabb(yaw,radius)
            assert x0 >= WIDTH*.025 and x1 <= WIDTH*.975, (yaw,radius,x0,x1)
            assert y0 >= HEIGHT*.045 and y1 <= HEIGHT*.955, (yaw,radius,y0,y1)
            count+=1
            if radius==6.5: near_extent=max(near_extent,x1-x0)
    assert abs(desired_radius(0.)-6.5)<1e-8
    assert abs(desired_radius(1.5)-6.5)<1e-8
    assert abs(desired_radius(12.)-16.)<1e-8
    assert desired_radius(2.)<desired_radius(5.)<desired_radius(8.)<16
    assert desired_radius(100.)>=102
    # A right-hand, sideways player position that stays safe for the torso but
    # can clip the arms under the new 2% / 0.38m screen edge test.
    radius,yaw=16.,0.
    x0=projection((7.0-.38,1.05,-8.0),yaw,radius)[0]
    x1=projection((7.0+.38,1.05,-8.0),yaw,radius)[0]
    arm=projection((7.0+.78,1.05,-8.0),yaw,radius)[0]
    assert x0 > WIDTH*.02 and x1 < WIDTH*.98
    assert arm > x1, (x0,x1,arm)
    print('2m target box full-frame corner projections:',count,'PASSED')
    print('near 6.5m target max screen width:',round(near_extent,1),'px')
    print('adaptive close-to-far camera radius: PASSED')
    print('loose torso-only screen edge: PASSED')
    print('Not tested in Godot engine.')

if __name__=='__main__': audit()
