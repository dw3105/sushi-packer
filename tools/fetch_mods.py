#!/usr/bin/env python3
"""Third-party mods for v9 mod-set tests (integrator only; never in release).

  tools/fetch_mods.py lock                 resolve every mod set -> tests/mods.lock.json (portal API, no login)
  tools/fetch_mods.py fetch FV [MODSET]    download locked zips for FV into ~/.cache/sushi-packer-mods/FV, sha1 checked
  tools/fetch_mods.py list FV MODSET       print mod names of set (incl. deps), one per line

Download needs ~/.factorio-portal (username=..., token=...), chmod 600, never in repo.
"""
import hashlib, json, os, sys, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SETS = json.load(open(os.path.join(ROOT, "tools", "modsets.json")))
LOCK = os.path.join(ROOT, "tests", "mods.lock.json")
CACHE = os.path.expanduser("~/.cache/sushi-packer-mods")
BUILTIN = {"base", "space-age", "quality", "elevated-rails", "recycler", "core"}
API = "https://mods.factorio.com/api/mods/%s/full"


def api(name, memo={}):
    if name not in memo:
        with urllib.request.urlopen(API % name, timeout=60) as r:
            memo[name] = json.load(r)
    return memo[name]


def dep_name(dep):
    dep = dep.strip()
    if dep[:1] in "?!" or dep.startswith("(?)"):
        return None  # optional, hidden optional, incompatible
    dep = dep.lstrip("~+ ").strip()
    return dep.split()[0]


def newest(name, fv):
    rel = [r for r in api(name)["releases"] if r["info_json"]["factorio_version"] == fv]
    if not rel:
        raise SystemExit(f"fetch_mods: {name} has no release for {fv}")
    return max(rel, key=lambda r: r["released_at"])


def resolve(fv, mods, pinned=None):
    # v10: mods already in the lock keep their pin (old sets never move); only new mods take newest release.
    pinned = pinned or {}
    out, todo = {}, list(mods)
    while todo:
        m = todo.pop()
        if m in out or m in BUILTIN:
            continue
        if m in pinned:
            out[m] = pinned[m]
            r = [x for x in api(m)["releases"] if x["version"] == pinned[m]["version"]][0]
        else:
            r = newest(m, fv)
            out[m] = {"version": r["version"], "file": r["file_name"], "sha1": r["sha1"], "url": r["download_url"]}
        todo += [d for d in (dep_name(x) for x in r["info_json"].get("dependencies", [])) if d]
    return out


def cmd_lock():
    lock, old = {}, (json.load(open(LOCK)) if os.path.exists(LOCK) else {})
    for fv in ("2.0", "2.1"):
        allm = sorted({m for k, s in SETS.items() if not k.startswith("_") and fv in s["fv"] for m in s["mods"]})
        lock[fv] = resolve(fv, allm, old.get(fv))
    json.dump(lock, open(LOCK, "w"), indent=2, sort_keys=True)
    for fv, mods in lock.items():
        print(fv, len(mods), "mods")


def members(fv, modset):
    s = SETS[modset]
    if fv not in s["fv"]:
        raise SystemExit(f"fetch_mods: set {modset} not on {fv}")
    lock = json.load(open(LOCK))[fv]
    out, todo = [], list(s["mods"])
    while todo:
        m = todo.pop()
        if m in out or m in BUILTIN:
            continue
        out.append(m)
        info = [r for r in api(m)["releases"] if r["version"] == lock[m]["version"]][0]["info_json"]
        todo += [d for d in (dep_name(x) for x in info.get("dependencies", [])) if d]
    return sorted(out)


def creds():
    p = os.path.expanduser("~/.factorio-portal")
    kv = dict(l.strip().split("=", 1) for l in open(p) if "=" in l)
    return kv["username"], kv["token"]


def sha1(p):
    h = hashlib.sha1()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def cmd_fetch(fv, modset=None):
    lock = json.load(open(LOCK))[fv]
    names = members(fv, modset) if modset else sorted(lock)
    d = os.path.join(CACHE, fv)
    os.makedirs(d, exist_ok=True)
    user = token = None
    for m in names:
        e = lock[m]
        p = os.path.join(d, e["file"])
        if os.path.exists(p) and sha1(p) == e["sha1"]:
            continue
        if user is None:
            user, token = creds()
        url = "https://mods.factorio.com%s?username=%s&token=%s" % (e["url"], user, token)
        tmp = p + ".part"
        req = urllib.request.Request(url, headers={"User-Agent": "sushi-packer-fetch/1"})  # default urllib UA gets 403
        with urllib.request.urlopen(req, timeout=600) as r, open(tmp, "wb") as f:
            while True:
                b = r.read(1 << 20)
                if not b:
                    break
                f.write(b)
        got = sha1(tmp)
        if got != e["sha1"]:
            os.remove(tmp)
            raise SystemExit(f"fetch_mods: sha1 mismatch {e['file']}: {got} != {e['sha1']}")
        os.replace(tmp, p)
        print("fetched", e["file"], os.path.getsize(p))
    print(f"fetch-{fv}-{modset or 'all'}-ok")


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["lock"]:
        cmd_lock()
    elif a[:1] == ["fetch"] and len(a) in (2, 3):
        cmd_fetch(*a[1:])
    elif a[:1] == ["list"] and len(a) == 3:
        print("\n".join(members(a[1], a[2])))
    else:
        raise SystemExit(__doc__)
