# gpu_scheduler

A tiny single-host GPU job scheduler. One daemon (`gpuqd`), one client (`gpuq`),
a Unix socket, stdlib-only Python. Built so multiple Claude Code agents on the
same box can share one GPU without stepping on each other.

## Behaviour

- **Serial execution** — at most one job runs at a time.
- **Priority queue** — higher `--priority` runs first; FIFO within a priority.
- **Aging** — every 10 min of queue time adds ~1 effective priority point, so
  low-priority jobs don't starve.
- **Blocking client** — `gpuq submit` blocks until the job finishes, streams
  stdout/stderr in real time, and exits with the job's exit code. No polling.
- **Auto-cancel on disconnect** — Ctrl-C or a dead parent removes the job
  (queued) or kills its process group (running).
- **GPU-relevant env passthrough** — `CUDA_*`, `NVIDIA_*`, `HF_*`, `TORCH_*`,
  `XLA_*`, `JAX_*`, `TF_*`, `PYTORCH_*`, plus `PATH`, `VIRTUAL_ENV`,
  `CONDA_PREFIX`, `LD_LIBRARY_PATH`.

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

## CLI

```
gpuq submit [-p N] [-l LABEL] [-q] -- <cmd> [args...]
gpuq status
gpuq cancel <id>
```

Exit codes: the job's own status; `130` for cancellation; `2` for a daemon
that can't be reached or malformed args.

## State

- Socket: `${XDG_STATE_HOME:-$HOME/.local/state}/gpu-scheduler/sock`
- Log:    `${XDG_STATE_HOME:-$HOME/.local/state}/gpu-scheduler/daemon.log`
- Override both via `GPUQ_DIR`.

## What it is not

- Not multi-host. One machine, one daemon.
- Not GPU-aware — it enforces mutual exclusion at the process level. If you
  have two GPUs and want one job per GPU concurrently, this is the wrong tool.
- No persistence across daemon restarts. The queue is in memory.
