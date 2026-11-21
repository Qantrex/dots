#!/usr/bin/env python3
"""Tests for bin/.local/bin/thread: the durations log, `thread durations` and the backfill, `thread send`.

Run: python3 tests/test_thread.py

Everything runs in a throwaway HOME and XDG folders. Only commands that never touch tmux are used (step,
signal, durations), or `watch` and `send` with tmux, `claude agents` and `inbox` stubbed, so the real threads and
the main chat are never typed into.
"""
import json
import time
import re
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timezone

THREAD = os.environ.get("THREAD_BIN") or os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "bin", ".local",
                                                      "bin", "thread")
T0 = datetime(2026, 1, 5, 10, 0, tzinfo=timezone.utc).timestamp()   # all test times are T0 + seconds


def iso(sec):
    return datetime.fromtimestamp(T0 + sec, timezone.utc).isoformat().replace("+00:00", "Z")


class Env:
    """A throwaway home with one thread state file and helpers to write transcripts and events."""

    def __init__(self):
        self.dir = tempfile.mkdtemp(prefix="thread-test-")
        self.env = {k: v for k, v in os.environ.items() if not k.startswith(("AGENTIC_", "CLAUDE"))}
        self.env.update(HOME=self.dir, XDG_DATA_HOME=os.path.join(self.dir, "data"),
                        XDG_STATE_HOME=os.path.join(self.dir, "state"), XDG_CACHE_HOME=os.path.join(self.dir, "cache"))
        self.threads = os.path.join(self.dir, "data", "agentic", "threads")
        self.log = os.path.join(self.dir, "data", "agentic", "durations.jsonl")
        self.projects = os.path.join(self.dir, ".claude", "projects", "-tmp-demo")
        os.makedirs(self.threads)
        os.makedirs(self.projects)

    def close(self):
        shutil.rmtree(self.dir, ignore_errors=True)

    def state(self, name, session, status="running", progress="", origin=""):
        fm = [f"name: {name}", "folder: /tmp", "model: opus", f"status: {status}"]
        fm += [f"origin: {origin}"] if origin else []
        fm += [f"session: {session}", "started: 2026-01-05 11:00", "updated: 2026-01-05 11:00"]
        fm += [f"progress: {progress}"] if progress else []
        with open(os.path.join(self.threads, name + ".md"), "w") as f:
            f.write("---\n" + "\n".join(fm) + "\n---\n\n## Goal\ndemo\n")

    def transcript(self, session, entries):
        path = os.path.join(self.projects, session + ".jsonl")
        with open(path, "w") as f:
            for e in entries:
                f.write(json.dumps(e) + "\n")
        return path

    def events(self, events):
        os.makedirs(os.path.dirname(self.log), exist_ok=True)
        with open(self.log, "w") as f:
            for e in events:
                f.write(json.dumps(dict({"model": "opus"}, **dict(e, ts=T0 + e["ts"]))) + "\n")

    def logged(self):
        try:
            with open(self.log) as f:
                return [json.loads(l) for l in f]
        except OSError:
            return []

    def run(self, *args):
        r = subprocess.run([sys.executable, THREAD, *args], capture_output=True, text=True, env=self.env)
        if r.returncode:
            raise AssertionError(f"thread {' '.join(args)} failed: {r.stderr}")
        return r.stdout

    def durations(self, *args):
        return json.loads(self.run("durations", "--json", *args))


# Transcript entries
def prompt(sec, text="do the thing"):
    return {"type": "user", "timestamp": iso(sec), "message": {"role": "user", "content": text}}


def answer(sec, text="ok"):
    return {"type": "assistant", "timestamp": iso(sec), "message": {"content": [{"type": "text", "text": text}]}}


def bash(sec, tid, command):
    return {"type": "assistant", "timestamp": iso(sec),
            "message": {"content": [{"type": "tool_use", "id": tid, "name": "Bash", "input": {"command": command}}]}}


def result(sec, tid, text):
    return {"type": "user", "timestamp": iso(sec),
            "message": {"content": [{"type": "tool_result", "tool_use_id": tid, "content": text}]}}


class LogTest(unittest.TestCase):
    def setUp(self):
        self.e = Env()
        self.e.state("demo", "s-demo")

    def tearDown(self):
        self.e.close()

    def test_step_logs_an_event(self):
        self.e.run("step", "demo", "0/3", "reading")
        self.e.run("step", "demo", "1/3", "building it")
        ev = self.e.logged()
        self.assertEqual([(x["event"], x["done"], x["total"], x["next"]) for x in ev],
                         [("step", 0, 3, "reading"), ("step", 1, 3, "building it")])
        self.assertEqual({x["thread"] for x in ev} | {x["session"] for x in ev} | {x["model"] for x in ev},
                         {"demo", "s-demo", "opus"})

    def test_signal_logs_only_for_the_stop_hook_and_keeps_its_output(self):
        self.e.run("step", "demo", "1/3", "building")
        self.assertEqual(self.e.run("signal", "demo"), "paused\t1/3\t\n")
        self.assertEqual(len(self.e.logged()), 1)               # by hand: no stop event
        tp = self.e.transcript("s-demo", [prompt(0), answer(5)])
        self.assertEqual(self.e.run("signal", "demo", "--transcript", tp), "paused\t1/3\t\n")
        self.e.run("step", "demo", "3/3", "done")
        self.assertEqual(self.e.run("signal", "demo", "--transcript", tp), "done\t3/3\t\n")
        stops = [(x["label"], x["detail"]) for x in self.e.logged() if x["event"] == "stop"]
        self.assertEqual(stops, [("paused", "1/3"), ("done", "3/3")])

    def test_misc_between_jobs_is_idle_not_paused(self):
        self.e.state("misc", "s-misc")
        self.assertEqual(self.e.run("signal", "misc"), "idle\t\t\n")           # no steps yet
        self.e.run("step", "misc", "0/1", "waiting for the first job")
        self.assertEqual(self.e.run("signal", "misc"), "idle\t\t\n")
        self.e.run("step", "misc", "2/5", "testing")
        self.assertEqual(self.e.run("signal", "misc"), "paused\t2/5\t\n")      # stopped mid-job: a pause
        self.e.run("step", "misc", "5/5", "done")
        self.assertEqual(self.e.run("signal", "misc"), "done\t5/5\t\n")
        self.e.run("step", "demo", "0/3", "reading")
        self.assertEqual(self.e.run("signal", "demo"), "paused\t0/3\t\n")      # other threads unchanged

    def test_unwritable_log_never_breaks_a_step(self):
        os.makedirs(self.e.log)                                   # a folder where the file should be
        self.assertIn("demo: 1/3", self.e.run("step", "demo", "1/3"))


class WatchBase(unittest.TestCase):
    """`thread watch` with tmux, `claude agents` and `inbox` replaced by stubs in the throwaway home."""

    def setUp(self):
        self.e = Env()
        self.bin = os.path.join(self.e.dir, "stubbin")
        local = os.path.join(self.e.dir, ".local", "bin")
        os.makedirs(self.bin)
        os.makedirs(local)
        self.agents = os.path.join(self.e.dir, "agents.json")
        self.added = os.path.join(self.e.dir, "inbox-added")
        self.wins = os.path.join(self.e.dir, "windows")
        stubs = {
            # capture-pane -p -t %<n>: the screen file of pane n if the test wrote one, else a still screen
            os.path.join(self.bin, "tmux"): f'[ "$1" = list-windows ] && cat {self.wins}\n'
                                            f'[ "$1" = capture-pane ] && screen={self.e.dir}/screen-"${{4#%}}" && '
                                            'if [ -f "$screen" ]; then cat "$screen"; else echo "nothing happens"; fi\n'
                                            'exit 0',
            os.path.join(local, "claude"): f"cat {self.agents}",
            os.path.join(local, "inbox"): f'echo "$*" >> {self.added}',
        }
        for path, body in stubs.items():
            with open(path, "w") as f:
                f.write("#!/bin/sh\n" + body + "\n")
            os.chmod(path, 0o755)
        self.e.env["PATH"] = self.bin + os.pathsep + self.e.env["PATH"]

    def tearDown(self):
        self.e.close()

    def threads(self, rows):
        """rows: (name, progress, claude state); every one has its own tmux window."""
        with open(self.wins, "w") as f:
            f.writelines(f"{n}\t{i + 2}\t{100 + i}\t%{i}\t0\n" for i, (n, _, _) in enumerate(rows))
        with open(self.agents, "w") as f:
            json.dump([{"sessionId": "s-" + n, "state": st} for n, _, st in rows], f)
        for n, prog, _ in rows:
            self.e.state(n, "s-" + n, progress=prog)

    def stalled_after_ten_minutes(self):
        self.e.run("watch")
        watch = os.path.join(self.e.dir, "state", "agentic", "watch")
        for f in os.listdir(watch):                                  # pretend the screens stayed 11 min
            with open(os.path.join(watch, f)) as fh:
                w = json.load(fh)
            w["fp_at"] -= 660
            with open(os.path.join(watch, f), "w") as fh:
                json.dump(w, fh)
        self.e.run("watch")
        try:
            with open(self.added) as fh:
                return sorted(l.split("'")[1] for l in fh)
        except OSError:
            return []


class WatchTest(WatchBase):
    def test_misc_idle_never_stalls_but_stuck_work_does(self):
        self.threads([("misc", "0/1 waiting for the first job", "idle"), ("demo", "0/3 reading", "idle")])
        self.assertEqual(self.stalled_after_ten_minutes(), ["demo"])

    def test_background_work_is_waiting_not_stalled(self):
        # cabinet-renders on 2026-11-20: its turn ended with a render-queue watcher running in a background shell
        rows = [("renders", "4/6 queued", "idle"), ("agents", "2/5 sweeping", "busy"), ("said", "1/3 x", "idle"),
                ("stuck", "1/3 x", "busy")]
        self.threads(rows)
        with open(os.path.join(self.e.dir, "screen-0"), "w") as f:
            f.write("✻ Worked for 43s · 1 shell still running\n❯\n  ⏵⏵ auto mode on · 1 shell · ↓ to manage\n")
        with open(os.path.join(self.e.dir, "screen-1"), "w") as f:
            f.write("✻ Sweeping\n❯\n  ⏵⏵ auto mode on · 2 background agents\n")
        progress = os.path.join(self.e.dir, "state", "agentic", "progress")
        os.makedirs(progress)
        with open(os.path.join(progress, "said.json"), "w") as f:
            json.dump({"name": "said", "state": "working", "detail": "in the background: 1 shell"}, f)
        self.assertEqual(self.stalled_after_ten_minutes(), ["stuck"])

    def test_misc_stuck_working_or_stopped_mid_job_still_stalls(self):
        self.threads([("misc", "0/1 waiting", "busy")])
        self.assertEqual(self.stalled_after_ten_minutes(), ["misc"])
        os.remove(self.added)
        self.threads([("misc", "2/5 testing", "idle")])
        self.assertEqual(self.stalled_after_ten_minutes(), ["misc"])


class RetireTest(WatchBase):
    """`thread watch` stops and archives a finished thread: done, card written, idle 30 min."""

    def setUp(self):
        super().setUp()
        tm = os.path.join(self.bin, "tmux")
        with open(tm, "w") as f:                    # /exit closes the window; list-clients: panes on screen
            f.write("#!/bin/sh\n"
                    f'[ "$1" = list-windows ] && cat {self.wins}\n'
                    f'[ "$1" = list-clients ] && cat {self.e.dir}/clients 2>/dev/null\n'
                    f'[ "$1" = send-keys ] && grep -v "\t$3\t" {self.wins} > {self.wins}.n; '
                    f'[ "$1" = send-keys ] && mv {self.wins}.n {self.wins}\n'
                    f'[ "$1" = capture-pane ] && echo "done." && echo "❯ "\n'
                    "exit 0\n")
        self.cards = os.path.join(self.e.dir, "Notes", "Results")
        os.makedirs(self.cards)

    def finished(self, name, stop_ts=0, card=True, label="done", progress="3/3 done"):
        self.e.state(name, "s-" + name, progress=progress)
        if card:
            with open(os.path.join(self.cards, f"2026-01-05-{name}.md"), "w") as f:
                f.write(f"---\ntype: result\nthread: {name}\nsession: s-{name}\n---\n")
        return {"ts": stop_ts, "thread": name, "session": "s-" + name, "event": "stop", "label": label}

    def status(self, name):
        return re.search(r"^status: (\S+)", open(os.path.join(self.e.threads, name + ".md")).read(), re.M).group(1)

    def test_only_a_finished_thread_with_a_card_idle_30_min_is_archived(self):
        names = ["old", "nocard", "paused", "misc", "fixes", "recent", "shown", "working"]
        self.threads([(n, "3/3 done", "busy" if n == "working" else "idle") for n in names])
        ev = [self.finished("old"), self.finished("nocard", card=False),
              self.finished("paused", label="paused", progress="2/3 x"), self.finished("misc"),
              self.finished("fixes"), self.finished("shown"), self.finished("working")]
        self.e.events(ev)
        with open(self.e.log, "a") as f:                                  # done 5 min ago
            f.write(json.dumps(dict(self.finished("recent"), ts=time.time() - 300)) + "\n")
        with open(os.path.join(self.e.dir, "clients"), "w") as f:
            f.write("%6\n")                                              # the owner looks at 'shown'
        self.e.run("watch")
        self.assertEqual([n for n in names if self.status(n) == "archived"], ["old"])
        self.assertEqual(open(self.added).read().count("archived thread 'old': finished"), 1)
        listed = [l.split()[0] for l in self.e.run("list").splitlines()]
        self.assertNotIn("old", listed)
        self.assertIn("old", [l.split()[0] for l in self.e.run("list", "--all").splitlines()])

    def test_a_finished_thread_left_open_is_archived_without_a_stop(self):
        self.threads([("live", "1/3 x", "busy")])
        self.e.events([self.finished("gone"), self.finished("gonepaused", label="paused", progress="1/3 x")])
        self.e.run("watch")                                               # 'gone' has no window and no session
        self.assertEqual((self.status("gone"), self.status("gonepaused")), ("archived", "running"))

    def test_a_later_event_after_done_keeps_it(self):
        self.threads([("again", "3/3 done", "idle")])
        self.e.events([self.finished("again"), {"ts": 50, "thread": "again", "session": "s-again", "event": "resume"}])
        self.e.run("watch")
        self.assertEqual(self.status("again"), "running")


class DurationsTest(unittest.TestCase):
    def setUp(self):
        self.e = Env()

    def tearDown(self):
        self.e.close()

    def test_work_leaves_out_waiting_and_counts_compaction_and_background_work(self):
        self.e.state("demo", "s1", status="stopped")
        self.e.transcript("s1", [
            prompt(0), answer(60),                                # 60 s work
            bash(70, "t1", "make"), result(370, "t1", "built"),   # 300 s tool run
            answer(400),                                          # turn ends, waits for the owner
            prompt(4000, "Answers from the owner: yes"),          # 3600 s waiting: left out
            answer(4030),
            {"type": "api-request", "timestamp": iso(9000)},      # bookkeeping written ahead: ignored
            {"type": "system", "subtype": "compact_boundary", "timestamp": iso(4150)},   # 120 s compacting
            {"type": "user", "isCompactSummary": True, "timestamp": iso(4100), "message": {"content": "summary"}},
            answer(4160),
            prompt(4400, "<task-notification> <task-id>a1</task-id> done"),   # background work: 240 s counted
            answer(4410),
        ])
        self.e.events([
            {"thread": "demo", "session": "s1", "event": "start", "ts": 0},
            {"thread": "demo", "session": "s1", "event": "step", "done": 0, "total": 4, "next": "a", "ts": 1},
            {"thread": "demo", "session": "s1", "event": "step", "done": 2, "total": 4, "next": "b", "ts": 380},
            {"thread": "demo", "session": "s1", "event": "stop", "label": "questions", "ts": 401},
            {"thread": "demo", "session": "s1", "event": "step", "done": 4, "total": 4, "next": "c", "ts": 4405},
            {"thread": "demo", "session": "s1", "event": "stop", "label": "done", "ts": 4410},
        ])
        d = self.e.durations()
        self.assertEqual(len(d["finished"]), 1)
        r = d["finished"][0]
        self.assertEqual(r["wall"], 4410)
        self.assertAlmostEqual(r["work"], 60 + 10 + 300 + 30 + 30 + 120 + 10 + 240 + 10, delta=0.01)
        self.assertEqual(r["n_steps"], 4)
        self.assertAlmostEqual(r["per_step"], r["work"] / 4 / 60)
        self.assertEqual(d["median"]["runs"], 1)
        # the step list: work since the line before
        self.assertEqual([round(s["work"]) for s in r["step_list"]], [0, 369, 420])

    def test_follow_up_run_starts_at_the_next_message_and_partial_runs_stay_out_of_medians(self):
        self.e.state("demo", "s1", status="running", progress="1/2 more")
        self.e.state("old", "s2", status="stopped")
        self.e.transcript("s1", [prompt(0), answer(100), prompt(1000, "one more thing"), answer(1300)])
        self.e.events([
            {"thread": "demo", "session": "s1", "event": "start", "ts": 0},
            {"thread": "demo", "session": "s1", "event": "step", "done": 3, "total": 3, "ts": 90},
            {"thread": "demo", "session": "s1", "event": "stop", "label": "done", "ts": 100},
            {"thread": "demo", "session": "s1", "event": "step", "done": 3, "total": 3, "ts": 200},   # again: ignored
            {"thread": "demo", "session": "s1", "event": "step", "done": 1, "total": 2, "ts": 1200},
            {"thread": "old", "session": "s2", "event": "step", "done": 1, "total": 2, "ts": 50},
            {"thread": "old", "session": "s2", "event": "step", "done": 2, "total": 2, "ts": 80},
        ])
        d = self.e.durations()
        fin = {(r["thread"], r["follow_up"], r["partial"]): r for r in d["finished"]}
        self.assertEqual(set(fin), {("demo", False, False), ("old", False, True)})
        self.assertEqual(fin[("demo", False, False)]["wall"], 100)
        self.assertEqual(d["median"]["runs"], 1)
        self.assertEqual(d["median"]["work"], 100)
        self.assertEqual(len(d["open"]), 1)
        op = d["open"][0]
        self.assertTrue(op["follow_up"])
        self.assertEqual(op["start"], T0 + 1000)                  # the message after the done, not the step
        self.assertEqual((op["done"], op["total"], op["n_steps"]), (1, 2, 2))   # a new plan: all its steps

    def test_a_follow_up_that_extends_the_plan_counts_only_the_new_steps(self):
        self.e.state("demo", "s1", status="stopped")
        self.e.events([
            {"thread": "demo", "session": "s1", "event": "start", "ts": 0},
            {"thread": "demo", "session": "s1", "event": "step", "done": 12, "total": 12, "ts": 50},
            {"thread": "demo", "session": "s1", "event": "step", "done": 13, "total": 14, "ts": 500},
            {"thread": "demo", "session": "s1", "event": "step", "done": 14, "total": 14, "ts": 600},
        ])
        runs = self.e.durations()["finished"]
        self.assertEqual([(r["follow_up"], r["n_steps"]) for r in runs], [(False, 12), (True, 2)])

    def test_text_output_and_a_name(self):
        self.e.state("demo", "s1", status="stopped")
        self.e.transcript("s1", [prompt(0), answer(600)])
        self.e.events([
            {"thread": "demo", "session": "s1", "event": "start", "ts": 0},
            {"thread": "demo", "session": "s1", "event": "step", "done": 0, "total": 2, "next": "reading", "ts": 1},
            {"thread": "demo", "session": "s1", "event": "step", "done": 2, "total": 2, "next": "done", "ts": 600},
        ])
        out = self.e.run("durations")
        self.assertIn("Medians over 1 finished run: work 10 min, wall 10 min, 2 steps, 5.0 min of work per step", out)
        out = self.e.run("durations", "demo")
        self.assertIn(" 2/2  work   10 min", out)
        self.assertIn("No thread events for nothing-here yet", self.e.run("durations", "nothing-here"))


class BackfillTest(unittest.TestCase):
    def setUp(self):
        self.e = Env()

    def tearDown(self):
        self.e.close()

    def test_backfill_from_transcript_once(self):
        self.e.state("demo", "s1", status="stopped", progress="2/2 done")
        self.e.state("mine", "s3", status="stopped", origin="adopted")
        self.e.transcript("s3", [prompt(0), bash(5, "x", "thread step 1/1"), result(6, "x", "mine: 1/1")])
        self.e.transcript("s1", [
            prompt(0, "Goal: ... (record with `thread step 0/6 reading the repo`)"),   # the brief's example
            bash(10, "a", "thread step 0/2 reading 2>&1 | tail -1"), result(11, "a", "demo: 0/2 reading"),
            bash(20, "b", "echo 'thread step 1/2 quoted'"), result(21, "b", "thread step 1/2 quoted"),
            bash(30, "c", "cd /x; thread step 1/2 building"), result(31, "c", "demo: 1/2 building"),
            bash(35, "e", "thread step demo 1/2 'named form'"), result(36, "e", "demo: 1/2 named form"),
            bash(40, "d", "thread step 2/2 done"), result(41, "d", "demo: 2/2 done"),
            answer(50, "Summary: built it"),
            prompt(500, "thanks"), answer(510),
        ])
        out = self.e.run("durations", "--backfill")
        self.assertIn("Added 6 events", out)
        ev = [(x["event"], x.get("done"), x.get("label"), round(x["ts"] - T0)) for x in self.e.logged()]
        self.assertEqual(ev, [("start", None, None, 0), ("step", 0, None, 10), ("step", 1, None, 30),
                              ("step", 1, None, 35), ("step", 2, None, 40), ("stop", None, "done", 50)])
        self.assertTrue(all(x["src"] == "backfill" for x in self.e.logged()))
        self.assertIn("Added 0 events", self.e.run("durations", "--backfill"))
        r = self.e.durations()["finished"][0]
        self.assertEqual((r["thread"], r["wall"], r["n_steps"]), ("demo", 50, 2))

    def test_backfill_stops_at_the_first_live_event(self):
        self.e.state("demo", "s1", status="running", progress="1/3")
        self.e.transcript("s1", [prompt(0), bash(10, "a", "thread step 0/3 a"), result(11, "a", "demo: 0/3 a"),
                                 bash(20, "b", "thread step 1/3 b"), result(21, "b", "demo: 1/3 b")])
        self.e.events([{"thread": "demo", "session": "s1", "event": "step", "done": 1, "total": 3, "ts": 20}])
        self.assertIn("Would add 2 events", self.e.run("durations", "--backfill", "--dry-run"))
        self.assertEqual(len(self.e.logged()), 1)
        self.e.run("durations", "--backfill")
        d = self.e.durations()
        self.assertEqual(len(d["open"]), 1)
        self.assertFalse(d["open"][0]["partial"])
        self.assertEqual(d["open"][0]["start"], T0)


# A stand-in tmux for `thread send`: the pane is a file with what is typed in its input line.
# NOSHOW: the screen never shows the typed text. DRAFT: something is typed there already.
# FAIL_AT=n: the n-th send-keys call fails. DIALOG_AFTER=n: from the n-th send-keys call on a dialog
# is on the screen instead of the input.
SEND_TMUX = r'''#!/usr/bin/env python3
import json, os, sys
d = os.environ["HOME"]; st = os.path.join(d, "pane.json")
s = json.load(open(st)) if os.path.exists(st) else {"typed": "", "sent": [], "keys": 0, "pieces": []}
a = sys.argv[1:]; rc = 0
if a[0] == "list-windows":
    print("demo\t2\t100\t%0\t0")
elif a[0] == "capture-pane":
    shown = "" if os.environ.get("NOSHOW") else s["typed"].replace("\n", "\n  ")
    if os.environ.get("DRAFT") and not s["keys"]:
        shown = "a draft"
    if s["keys"] >= int(os.environ.get("DIALOG_AFTER") or 10**9):
        print("Do you want to proceed?\n\u276f 1. Yes\n  2. No\n\nEsc to cancel")
    else:
        print("some output\n\u276f " + shown + "\n  status line")
elif a[0] == "send-keys":
    s["keys"] += 1
    if str(s["keys"]) == os.environ.get("FAIL_AT"):
        rc = 1
    elif "-l" in a:
        s["typed"] += a[-1]; s["pieces"].append(len(a[-1]))
    elif a[-1] == "Enter":
        s["sent"].append(s["typed"]); s["typed"] = ""
json.dump(s, open(st, "w")); sys.exit(rc)
'''


class SendTest(unittest.TestCase):
    """`thread send` against the stand-in tmux: what is typed, in which pieces, and what each failure leaves."""

    def setUp(self):
        self.e = Env()
        self.e.state("demo", "s-demo")
        stubbin = os.path.join(self.e.dir, "stubbin")
        os.makedirs(stubbin)
        with open(os.path.join(stubbin, "tmux"), "w") as f:
            f.write(SEND_TMUX)
        os.chmod(os.path.join(stubbin, "tmux"), 0o755)
        self.e.env["PATH"] = stubbin + os.pathsep + self.e.env["PATH"]

    def tearDown(self):
        self.e.close()

    def send(self, text, **env):
        """(exit code, the pane afterwards, stderr) of one `thread send demo <text>` on a fresh pane."""
        pane = os.path.join(self.e.dir, "pane.json")
        if os.path.exists(pane):
            os.remove(pane)
        r = subprocess.run([sys.executable, THREAD, "send", "demo", text], capture_output=True, text=True,
                           env=dict(self.e.env, **{k: str(v) for k, v in env.items()}))
        try:
            with open(pane) as f:
                state = json.load(f)
        except OSError:
            state = {"typed": "", "sent": [], "keys": 0, "pieces": []}
        return r.returncode, state, r.stderr

    def test_a_short_line_is_one_piece_then_enter(self):
        code, p, _ = self.send("  hello   there ")
        self.assertEqual((code, p["sent"], p["pieces"], p["keys"]), (0, ["hello there"], [11], 2))
        code, p, _ = self.send("-x starts with a dash")
        self.assertEqual((code, p["sent"]), (0, ["-x starts with a dash"]))
        code, p, _ = self.send("x" * 300)
        self.assertEqual((code, p["pieces"]), (0, [300]))

    def test_a_long_text_is_typed_in_pieces_and_arrives_whole(self):
        long = "".join(chr(97 + i % 26) for i in range(2000))
        code, p, _ = self.send(long)
        self.assertEqual((code, p["sent"], p["pieces"]), (0, [long], [300] * 6 + [200]))
        code, p, _ = self.send("x" * 301)
        self.assertEqual((code, p["pieces"], p["sent"]), (0, [300, 1], ["x" * 301]))
        umlauts = "äöü € " * 150
        code, p, _ = self.send(umlauts)
        self.assertEqual((code, p["sent"]), (0, [" ".join(umlauts.split())]))

    def test_several_lines_stay_one_message_and_no_key_but_the_line_feed_gets_through(self):
        code, p, _ = self.send("\n\none\r\ntwo\rthree\n  four\n\n")
        self.assertEqual((code, p["sent"]), (0, ["one\ntwo\nthree\n  four"]))   # a carriage return would be Enter
        code, p, _ = self.send("a\tb\x1bc\x03d\x7fe\nf")
        self.assertEqual((code, p["sent"]), (0, ["a    bcde\nf"]))                # a tab completes, an escape clears

    def test_a_draft_or_dialog_is_never_typed_over(self):
        code, p, err = self.send("hello", DRAFT=1)
        self.assertEqual((code, p["keys"]), (3, 0))
        self.assertIn("has text typed already", err)

    def test_a_failure_says_whether_the_text_is_in_the_input(self):
        code, p, _ = self.send("hello", FAIL_AT=1)                  # nothing typed: a plain failure
        self.assertEqual((code, p["typed"], p["sent"]), (1, "", []))
        long = "y" * 1000
        code, p, err = self.send(long, FAIL_AT=3)                   # half typed
        self.assertEqual((code, p["typed"], p["sent"]), (4, long[:600], []))
        self.assertIn("typed in the input of 'demo' but was not sent", err)
        code, p, _ = self.send("hello", FAIL_AT=2)                  # typed, Enter failed
        self.assertEqual((code, p["typed"], p["sent"]), (4, "hello", []))
        code, p, _ = self.send(long, NOSHOW=1)                      # never showed: no more keys, no blind Enter
        self.assertEqual((code, p["typed"], p["sent"]), (4, long[:300], []))

    def test_a_dialog_that_comes_up_while_typing_gets_no_more_keys_and_no_enter(self):
        long = "z" * 1500
        code, p, err = self.send(long, DIALOG_AFTER=2)
        self.assertEqual((code, p["keys"], p["sent"]), (4, 2, []))
        self.assertIn("but was not sent", err)
        code, p, _ = self.send("one\ntwo", DIALOG_AFTER=1)
        self.assertEqual((code, p["keys"], p["sent"]), (4, 1, []))

    def test_only_a_running_session_gets_text(self):
        code, p, err = self.send("hello")
        self.assertEqual(code, 0)
        r = subprocess.run([sys.executable, THREAD, "send", "nosuch", "hello"], capture_output=True, text=True,
                           env=self.e.env)
        self.assertEqual(r.returncode, 2)


ROUND = {"questions": [
    {"question": "Which start?", "header": "Start", "options": [{"label": "A", "description": "a"},
                                                                {"label": "B", "description": "b"}]},
    {"question": "How much?", "header": "Budget", "options": [{"label": "Low", "description": "l"},
                                                              {"label": "High", "description": "h"}]}]}


class AskTest(unittest.TestCase):
    """`thread ask` tells the main chat itself, so a thread that keeps working after asking is heard."""

    def setUp(self):
        self.e = Env()
        self.e.state("demo", "s-demo", progress="1/3 asking")
        self.bin = os.path.join(self.e.dir, ".local", "bin")
        self.calls = os.path.join(self.e.dir, "inbox.calls")
        os.makedirs(self.bin)

    def tearDown(self):
        self.e.close()

    def inbox(self, code=0):
        with open(os.path.join(self.bin, "inbox"), "w") as f:
            f.write(f'#!/bin/sh\nprintf "%s\\t" "$@" >> "{self.calls}"; echo >> "{self.calls}"; exit {code}\n')
        os.chmod(os.path.join(self.bin, "inbox"), 0o755)

    def ask(self):
        r = subprocess.run([sys.executable, THREAD, "ask", "demo"], input=json.dumps(ROUND), capture_output=True,
                           text=True, env=self.e.env)
        self.assertEqual(r.returncode, 0, r.stderr)
        return r.stdout, json.load(open(os.path.join(self.e.threads, "demo.questions.json")))

    def sent(self):
        try:
            return [l.rstrip("\t").split("\t") for l in open(self.calls).read().splitlines()]
        except OSError:
            return []

    def test_asking_sends_one_questions_line_and_the_stop_sends_none(self):
        self.inbox()
        out, rnd = self.ask()
        self.assertIn("the main chat is told", out)
        self.assertEqual(self.sent(), [["add", "--wake", "questions", "thread",
                                        f"'demo': 2 questions (Start, Budget), round {rnd['round']}"]])
        self.assertIn("notified", rnd)
        tp = self.e.transcript("s-demo", [prompt(0), answer(5)])
        self.assertEqual(self.e.run("signal", "demo", "--transcript", tp), "questions\t2 questions\tnotified\n")

    def test_without_an_inbox_or_when_it_fails_the_stop_still_sends_it(self):
        out, rnd = self.ask()                                           # no inbox at all
        self.assertNotIn("told", out)
        self.assertNotIn("notified", rnd)
        self.assertEqual(self.e.run("signal", "demo"), "questions\t2 questions\t\n")
        os.remove(os.path.join(self.e.threads, "demo.questions.json"))
        self.inbox(code=1)                                              # an inbox that fails
        out, rnd = self.ask()
        self.assertEqual(len(self.sent()), 1)
        self.assertNotIn("notified", rnd)
        self.assertEqual(self.e.run("signal", "demo"), "questions\t2 questions\t\n")


RESULTS_BIN = os.path.join(os.path.dirname(THREAD), "results")


def write_tool(sec, tid, path):
    return {"type": "assistant", "timestamp": iso(sec),
            "message": {"id": f"m-{tid}", "content": [{"type": "tool_use", "id": tid, "name": "Write",
                                                        "input": {"file_path": path, "content": "x"}}]}}


class ResultCardTest(unittest.TestCase):
    """Result cards in <HOME>/Notes/Results: written at a done stop, one per thread session."""

    def setUp(self):
        self.e = Env()
        self.e.state("demo", "s-demo", progress="3/3 done")
        self.vault = os.path.join(self.e.dir, "Notes")
        self.results_dir = os.path.join(self.vault, "Results")
        self.scratch = tempfile.mkdtemp(prefix="thread-scratch-")      # under /tmp: short-lived
        self.pdf = os.path.join(self.scratch, "report.pdf")
        with open(self.pdf, "wb") as f:
            f.write(b"%PDF-1.4 demo")

    def tearDown(self):
        self.e.close()
        shutil.rmtree(self.scratch, ignore_errors=True)

    def card(self, name=None):
        d = self.results_dir
        cards = sorted(f for f in os.listdir(d) if f.endswith(".md")) if os.path.isdir(d) else []
        if name:
            cards = [f for f in cards if name in f]
        self.assertLessEqual(len(cards), 1)
        return open(os.path.join(d, cards[0])).read() if cards else None

    def results(self, *args):
        r = subprocess.run([sys.executable, RESULTS_BIN, *args], capture_output=True, text=True, env=self.e.env)
        return r.stdout

    def test_a_done_stop_writes_the_card_with_the_answer_and_copies_scratch_files(self):
        text = f"**Done:** the report is ready.\n`{self.pdf}`\n\nDetails: [the PDF]({self.pdf}), tool at {THREAD}."
        tp = self.e.transcript("s-demo", [prompt(0), answer(5, "working on it"), answer(60, text)])
        self.assertEqual(self.e.run("signal", "demo", "--transcript", tp), "done\t3/3\t\n")   # output unchanged
        c = self.card()
        self.assertIn("type: result\nthread: demo\n", c)
        self.assertIn("read: false", c)
        self.assertIn('summary: "Done: the report is ready."', c)
        self.assertIn("**Done:** the report is ready.", c)
        self.assertNotIn("working on it", c)
        sub = os.listdir(os.path.join(self.results_dir, "files"))[0]
        copied = os.path.join(self.results_dir, "files", sub, "report.pdf")
        self.assertEqual(open(copied, "rb").read(), b"%PDF-1.4 demo")
        rel = os.path.relpath(copied, self.vault)
        self.assertIn(f"[[{rel}|report.pdf]]\n", c)                     # the path in backticks became a link
        self.assertIn(f"[the PDF]({rel})", c)                             # a markdown link target too
        self.assertNotIn(f"`{self.pdf}`\n", c.split("## Files")[0])
        self.assertIn(f"(file://{os.path.abspath(THREAD)})", c)           # durable, outside the vault: linked
        self.assertEqual(self.results("count").strip(), "1")

    def test_a_pause_or_a_look_by_hand_writes_no_card(self):
        tp = self.e.transcript("s-demo", [prompt(0), answer(5, "half way")])
        self.e.run("step", "demo", "1/3", "building")
        self.e.run("signal", "demo", "--transcript", tp)
        self.e.run("step", "demo", "3/3", "done")
        self.e.run("signal", "demo")
        self.assertIsNone(self.card())

    def test_same_answer_changes_nothing_and_a_new_one_goes_on_top_unread(self):
        tp = self.e.transcript("s-demo", [prompt(0), answer(5, "First result.")])
        self.e.run("signal", "demo", "--transcript", tp)
        self.results("read", "demo")
        before = self.card()
        self.assertIn("read: true", before)
        self.e.run("signal", "demo", "--transcript", tp)                  # the same stop again
        self.assertEqual(self.card(), before)
        tp = self.e.transcript("s-demo", [prompt(0), answer(5, "First result."), prompt(100),
                                          answer(105, "Second result.")])
        self.e.run("signal", "demo", "--transcript", tp)
        c = self.card()
        self.assertIn("read: false", c)
        self.assertLess(c.index("Second result."), c.index("## Earlier results"))
        self.assertLess(c.index("## Earlier results"), c.index("> First result."))
        self.assertIn('summary: "Second result."', c)

    def test_a_short_follow_up_keeps_the_files_and_links_of_the_first_answer(self):
        first = f"Report ready.\n`{self.pdf}`"
        tp = self.e.transcript("s-demo", [prompt(0), answer(5, first)])
        self.e.run("signal", "demo", "--transcript", tp)
        tp = self.e.transcript("s-demo", [prompt(0), answer(5, first), prompt(100, "thanks"), answer(105, "Yes.")])
        self.e.run("signal", "demo", "--transcript", tp)
        c = self.card()
        self.assertIn('summary: "Yes."', c)
        self.assertIn("report.pdf|report.pdf]]", c.split("## Files")[1])           # still listed
        self.assertIn("> [[Results/files/", c.split("## Earlier results")[1])      # earlier text keeps its link

    def test_files_are_vault_notes_it_wrote_not_code_or_claude_md(self):
        note = os.path.join(self.vault, "Area", "Plan.md")
        code = os.path.join(self.vault, "Homelab", "deploy", "x", "run.md")
        rules = os.path.join(self.vault, "Area", "CLAUDE.md")
        for p in (note, code, rules):
            os.makedirs(os.path.dirname(p), exist_ok=True)
            open(p, "w").write("x")
        tp = self.e.transcript("s-demo", [prompt(0), write_tool(2, "w1", note), write_tool(3, "w2", code),
                                          write_tool(4, "w3", rules), answer(5, "Wrote the plan.")])
        self.e.run("signal", "demo", "--transcript", tp)
        files = self.card().split("## Files")[1].split("## Thread")[0]
        self.assertEqual(files.strip(), "- [[Area/Plan|Plan]]")

    def test_backfill_writes_one_card_per_session_from_its_last_done(self):
        tp = self.e.transcript("s-demo", [prompt(0), answer(5, "Round one."), prompt(50), answer(55, "Round two."),
                                          prompt(200), answer(205, "Later talk, not a result.")])
        self.e.events([{"ts": 9, "at": iso(9), "thread": "demo", "session": "s-demo", "event": "stop", "label": "done"},
                       {"ts": 59, "at": iso(59), "thread": "demo", "session": "s-demo", "event": "stop", "label": "done"}])
        out = self.e.run("result", "--backfill", "--since", "2026-01-01")
        self.assertIn("new card", out)
        c = self.card()
        self.assertIn("Round two.", c)
        self.assertNotIn("Later talk", c)
        self.assertIn("read: true", c)                                    # not from today
        self.assertIn("has a card", self.e.run("result", "--backfill", "--since", "2026-01-01"))

    def test_results_lists_unread_first_and_marks_read(self):
        self.e.state("other", "s-other", progress="1/1 done")
        self.e.run("signal", "demo", "--transcript", self.e.transcript("s-demo", [prompt(0), answer(5, "Demo out.")]))
        self.e.run("signal", "other", "--transcript", self.e.transcript("s-other", [prompt(0), answer(9, "Other out.")]))
        lines = self.results().splitlines()
        self.assertIn("2 unread results", lines[0])
        self.assertIn("Other out.", lines[1])                             # newest first
        self.results("read", "1")
        self.assertEqual(self.results("count").strip(), "1")
        self.assertIn("(read)", self.results("--all").splitlines()[-1])
        self.assertEqual(json.loads(self.results("--json"))[0]["thread"], "demo")


if __name__ == "__main__":
    unittest.main(verbosity=2)
