import math, sys
V=[(-167,-16,175.60129464500446,13.038404810405298,-106.69924423399362,41.7612260356422),
(-116,-103,171.0273733851036,38.47076812334269,-16.389540334034784,17.72004514666935),
(-64,-92,-141.84277341263095,17.804493814764857,-74.53878225955809,48.76474136094644),
(44,-160,-175.6839724801344,53.150729063673246,1.6365770416167182,70.02856560004639),
(154,-33,-82.5685920288275,69.58448102845921,25.942295489871672,41.14608122288197),
(193,53,-73.14160123226172,34.48187929913333,104.03624346792648,37.107950630558946),
(113,111,-4.513988458001263,38.118237105091836,130.76360520094119,38.28837943815329),
(2,150,3.122130462115708,55.08175741568164,-178.60281897270363,41.012193308819754),
(-90,125,35.53767779197438,25.80697580112788,164.40718906073366,44.64302857109943),
(-202,101,47.202598161765806,36.796738985948195,-130.91438322002512,39.698866482558415),
(-202,2,133.7811247648687,33.24154027718932,-50.71059313749964,14.212670403551895)]
H=[(-38,-100,-51.340191745909905,25.612496949731394,-71.56505117707799,25.298221281347036),
(30,-138,180.0,34.0,161.56505117707798,25.298221281347036)]
def ctl(v,which):
    x,y,ir,idist,orr,od=v
    r,d=(ir,idist) if which=='in' else (orr,od)
    a=math.radians(r); return (x+math.cos(a)*d, y+math.sin(a)*d)
def path(vs):
    f=lambda p:f"{p[0]:.2f} {p[1]:.2f}"
    s=f"M{f(vs[0][:2])}"
    n=len(vs)
    for i in range(n):
        a=vs[i]; b=vs[(i+1)%n]
        s+=f" C{f(ctl(a,'out'))} {f(ctl(b,'in'))} {f(b[:2])}"
    return s+" Z"
body=path(V); hl=path(H)
def inner(id,dx,dy,strength,color,op):
    s=strength/2.2
    return f'''<filter id="{id}" x="-20%" y="-20%" width="140%" height="140%">
  <feGaussianBlur in="SourceAlpha" stdDeviation="{s:.1f}" result="b"/>
  <feOffset in="b" dx="{dx}" dy="{dy}" result="o"/>
  <feComposite in="SourceAlpha" in2="o" operator="out" result="e"/>
  <feFlood flood-color="{color}" flood-opacity="{op}"/>
  <feComposite in2="e" operator="in"/>
</filter>'''
def inky(prefix=""):
    defs=f'''<radialGradient id="{prefix}g" gradientUnits="userSpaceOnUse" cx="-30" cy="-95" r="280">
  <stop offset="0" stop-color="#3a3a3a"/><stop offset=".55" stop-color="#1c1c1c"/><stop offset="1" stop-color="#101010"/>
</radialGradient>
{inner(prefix+"bs",0,-26,42,"#000000",0.65)}
{inner(prefix+"bl",9,13,14,"#ffffff",0.28)}
{inner(prefix+"es",-2,-7,7,"#243248",0.25)}
<filter id="{prefix}hb" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="2"/></filter>'''
    eyes="".join(f'''<rect x="{cx-15}" y="{28-38.5}" width="30" height="77" rx="15" fill="#fff"/>
<rect x="{cx-15}" y="{28-38.5}" width="30" height="77" rx="15" fill="#fff" filter="url(#{prefix}es)"/>''' for cx in (-34,41))
    shapes=f'''<path d="{body}" fill="url(#{prefix}g)"/>
<path d="{body}" fill="#000" filter="url(#{prefix}bs)"/>
<path d="{body}" fill="#000" filter="url(#{prefix}bl)"/>
<path d="{hl}" fill="#fff" fill-opacity=".3" filter="url(#{prefix}hb)"/>
{eyes}'''
    return defs, shapes
d,s=inky()
# mascot alone, tight box around body (-215..215, -175..165)
open(sys.argv[1]+"/inky-idle.svg","w").write(f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-230 -185 460 360" width="920" height="720">
<defs>{d}</defs>
{s}
</svg>
''')
bg=sys.argv[2] if len(sys.argv)>2 else "#FFFFFF"
# app icon 1024: Inky ~68% wide, centered optically
scale=700/440
open(sys.argv[1]+"/app-icon.svg","w").write(f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
<defs>{d}</defs>
<rect width="1024" height="1024" fill="{bg}"/>
<g transform="translate(512 {512+20}) scale({scale:.4f})">
{s}
</g>
</svg>
''')
