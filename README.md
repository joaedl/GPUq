# gpu_scheduler

A tiny single-host GPU job scheduler. One daemon (`gpuqd`), one client (`gpuq`),
a Unix socket, stdlib-only Python. Built so multiple Claude Code agents on the
same box can share one (or several) GPUs without stepping on each other.

## Behaviour

- **Multi-slot execution** — runs up to N jobs concurrently, one per GPU.
  Slot count is `GPUQ_GPUS` if set, else `nvidia-smi -L` count, else 1.
  The daemon sets `CUDA_VISIBLE_DEVICES=<slot>` on each job so they land on
  separate GPUs.
- **Priority queue** — higher `--priority` runs first; FIFO within a priority.
- **Aging** — every 10 min of queue time adds ~1 effective priority point, so
  low-priority jobs don't starve.
- **Blocking client** — `gpuq submit` blocks until the job finishes, streams
  stdout/stderr in real time, and exits with the job's exit code. No polling.
- **Auto-cancel on disconnect** — Ctrl-C or a dead parent removes the job
  (queued) or kills its process group (running).
- **Persistent queue** — queued jobs are written to
  `STATE_DIR/jobs/<id>/meta.json` and survive daemon restarts and reboots.
  On restart, resumed queued jobs have no live client, so they run detached
  with output written to `jobs/<id>/stdout.log` and `stderr.log`. Use
  `gpuq logs <id>` to view. Running jobs at the moment of a daemon crash
  are reaped on restart (we can't `waitpid()` a non-child) and marked
  `crashed`.
- **GPU-relevant env passthrough** — `CUDA_*` (except `CUDA_VISIBLE_DEVICES`,
  which the scheduler owns), `NVIDIA_*`, `HF_*`, `TORCH_*`, `XLA_*`, `JAX_*`,
  `TF_*`, `PYTORCH_*`, plus `PATH`, `VIRTUAL_ENV`, `CONDA_PREFIX`,
  `LD_LIBRARY_PATH`.

## Install

```bash
./install.sh
```

This symlinks `gpuq` and `gpuqd` into `~/.local/bin`, installs a user systemd
unit, and adds an `@import` of `CLAUDE.md` to `~/.claude/CLAUDE.md` so every
Claude Code session on this box learns the etiquette.

Confirm:

```bash
systemctl --user status gpuqd
gpuq status
gpuq submit -p 5 -- nvidia-smi -L
```

To run with a specific number of GPU slots, set `GPUQ_GPUS` in the systemd
environment (e.g. `systemctl --user edit gpuqd` and add
`Environment=GPUQ_GPUS=2`), or export it before launching `gpuqd` manually.

## CLI

```
gpuq submit [-p N] [-l LABEL] [-q] -- <cmd> [args...]
gpuq status
gpuq cancel <id>
gpuq logs   <id>
```

Exit codes: the job's own status; `130` for cancellation; `2` for a daemon
that can't be reached or malformed args.

## State

- Socket: `${XDG_STATE_HOME:-$HOME/.local/state}/gpu-scheduler/sock`
- Log:    `${XDG_STATE_HOME:-$HOME/.local/state}/gpu-scheduler/daemon.log`
- Jobs:   `${XDG_STATE_HOME:-$HOME/.local/state}/gpu-scheduler/jobs/<id>/`
  - `meta.json` — status, cmd, env, timings, exit code, GPU slot
  - `stdout.log` / `stderr.log` — captured output
  - `seq` (in parent dir) — persistent job id counter
- Override the whole dir via `GPUQ_DIR`.

## What it is not

- Not multi-host. One machine, one daemon.
- Not aware of per-GPU memory. It pins one job per GPU slot. If you want
  multiple small jobs sharing a GPU, this is the wrong tool.
- Running jobs do not survive a daemon crash (their output pipes break).
  Only the queue is guaranteed to be preserved.
