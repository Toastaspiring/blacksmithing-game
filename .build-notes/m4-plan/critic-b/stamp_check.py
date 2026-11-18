# M4 plan critic B: does the Recorder's stamp formula (seconds in, ms out) equal the prototype bot's ms formula?
# Recorder (plan [3.6], goClockS = 0, clockS = f/1000, frameDtS = dt/1000):
#   button: floor((f/1000 - 0) * 1000 - (dt/1000) * 1000 / 2)      prototype stamp(): floor(f - dt/2)
#   trace:  floor((f/1000 - 0) * 1000)                               prototype ptHuman: floor(f)
# and D7's claim about integers: (t/1000)*1000 can fall one ulp below t.
import math, random, sys
out = []
def P(*a):
    s = " ".join(str(x) for x in a); print(s); out.append(s)

below = [t for t in range(0, 60001) if (t / 1000) * 1000 < t]
above = [t for t in range(0, 60001) if (t / 1000) * 1000 > t]
P("integers t in 0..60000 with (t/1000)*1000 < t:", len(below), "e.g.", below[:8], "; > t:", len(above))
bad_half = [t for t in range(0, 60001) if math.floor(((t + 0.5) / 1000) * 1000) != t]
P("D7 fix floor(((t+0.5)/1000)*1000) != t:", len(bad_half))
# exact-time button bots: with frameDtS = 0 the stamp is t; with a real frame dt it is t - dt/2
P("button stamp with clockS=(t+0.5)/1000 and frameDtS=10/1000 for t=1000:", math.floor(((1000 + 0.5) / 1000) * 1000 - (10 / 1000) * 1000 / 2))

rnd = random.Random(7)
def frames(endMs, fps, hitch):
    f = []; dt = 1000 / fps; t = rnd.uniform(0, dt)
    while t <= endMs + 2 * dt + 130:
        f.append(t); step = dt + (rnd.random() - 0.5) * 2
        if rnd.random() < hitch: step += rnd.uniform(30, 120)
        t += step
    return f
nb = nt = mb = mt = 0
for run in range(4000):
    fps = rnd.choice([30, 60, 144, 240])
    fr = frames(31000, fps, 0.003)
    for k in range(len(fr)):
        f = fr[k]; dt = fr[k] - fr[k - 1] if k > 0 else fr[k]
        a = math.floor(f - dt / 2); b = math.floor((f / 1000 - 0) * 1000 - (dt / 1000) * 1000 / 2)
        nb += 1; mb += a != b
        c = math.floor(f); d = math.floor((f / 1000 - 0) * 1000)
        nt += 1; mt += c != d
P("random frames (Bots.frames model, 30-240 fps): button stamps", nb, "mismatches", mb, "; trace stamps", nt, "mismatches", mt)
open(sys.argv[1], "w").write("\n".join(out) + "\n")
