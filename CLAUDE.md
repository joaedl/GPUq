# GPU scheduler (gpuq)

This machine has one GPU. A host-wide scheduler (`gpuqd`) serialises GPU work so
parallel Claude Code sessions don't collide. **Run any command that uses GPU
compute through `gpuq submit` instead of invoking it directly.**

## When to use

- **Yes, use gpuq:** training runs, inference/generation scripts, benchmarks,
  anything that loads a model onto the GPU, anything involving `torch.cuda`,
  `tensorflow`, `jax` with a GPU device, `llama.cpp --n-gpu-layers > 0`, etc.
- **No, skip gpuq:** `nvidia-smi` / `nvidia-smi -L` metric reads, `nvcc`
  compilation, CPU-only scripts. These don't take the GPU.

If unsure whether something uses the GPU, wrap it — the overhead is tiny.

## How

```
gpuq submit [--priority N] [--label NAME] -- <command> [args...]
```

`submit` **blocks** until the job finishes. It streams stdout/stderr through in
real time and exits with the job's exit code. You do not need to poll, sleep,
or check status — the call returns when your turn is done.

```bash
# Wait-in-line and run. Blocks; returns the job's exit code.
gpuq submit -p 5 -l train-xl -- python train.py --epochs 3

# See what's ahead of you.
gpuq status

# Abort a job by id (from status).
gpuq cancel 42
```

If you hit Ctrl-C or your session dies while waiting, the daemon automatically
cancels your job (whether queued or running).

## Priority

Higher number = runs first. Default is **5**. Suggested bands:

- **8–10** — user is actively waiting (interactive inference, quick evals).
- **5**    — default background work.
- **1–3**  — long batch jobs that can wait (overnight training, sweeps).

Aging is built in: a queued job's effective priority grows by ~1 every
10 minutes of waiting, so low-priority jobs eventually run.

## Etiquette for agents

- Prefer one `gpuq submit` that runs the whole pipeline over many small submits
  — each submit re-enters the queue.
- Set `--label` to something short but recognisable (`train-llama-7b`,
  `eval-suite`, `hparam-sweep-run-3`) so humans and other agents can tell at a
  glance what's running.
- Before starting a long batch job, run `gpuq status` to see if someone's mid
  training run; if so, use a lower priority (1–3) so you queue politely behind.
- Don't bypass the scheduler by running GPU code directly — it will race with
  whatever the daemon is currently running and both jobs will be slower.
