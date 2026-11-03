# Contributing

Thanks for looking. Right now this repository is a **showroom**, not a codebase: it explains how Navi is built,
and there is nothing here to run yet.

**Most useful right now:**

- **Questions** about anything in the docs. Open an issue.
- **"Have you tried X?"**, especially native OpenClaw features or maintained open-source projects that would replace
  something we built by hand. We'd rather use a good existing project than maintain our own.
- **Local-model experience** on AMD Strix Halo (Vulkan, llama.cpp), speech models on CPU, or agent tool calling with
  open-weights models.

**Not yet useful:** pull requests with code. The code will arrive with the clean rebuild.

**Privacy.** Navi handles one person's private life. Please don't post anything about the owner or people around him,
and don't ask for transcripts, memory contents or logs. They are never published.

**Before anything is committed here**, `tools/scan-public.sh` must pass. It checks for secrets, private network
addresses, e-mail addresses, home paths, device serials and a private list of personal terms that is kept outside
the repository.
