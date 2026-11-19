#!/usr/bin/env python3
"""Tests for bin/.local/bin/thread: the durations log, `thread durations` and the backfill.

Run: python3 tests/test_thread.py

Everything runs in a throwaway HOME and XDG folders. Only commands that never touch tmux are used (step,
signal, durations), so the real threads and the main chat are never typed into.
"""
import json
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

    def test_unwritable_log_never_breaks_a_step(self):
        os.makedirs(self.e.log)                                   # a folder where the file should be
        self.assertIn("demo: 1/3", self.e.run("step", "demo", "1/3"))


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
        self.assertEqual((op["done"], op["total"], op["n_steps"]), (1, 2, 2))

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
            bash(40, "d", "thread step 2/2 done"), result(41, "d", "demo: 2/2 done"),
            answer(50, "Summary: built it"),
            prompt(500, "thanks"), answer(510),
        ])
        out = self.e.run("durations", "--backfill")
        self.assertIn("Added 5 events", out)
        ev = [(x["event"], x.get("done"), x.get("label"), round(x["ts"] - T0)) for x in self.e.logged()]
        self.assertEqual(ev, [("start", None, None, 0), ("step", 0, None, 10), ("step", 1, None, 30),
                              ("step", 2, None, 40), ("stop", None, "done", 50)])
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


if __name__ == "__main__":
    unittest.main(verbosity=2)
