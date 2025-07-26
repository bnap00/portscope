# 🔍 portscope

**portscope** is a lightweight Bash tool that checks your `docker-compose.yml` for **host port conflicts** before you run your stack.

---

## 😩 Tired of Docker Compose Port Chaos?

Are you juggling **tons of Docker Compose projects** on your home server, laptop, or dev machine…  
and every new project opens **yet another port**?

And now you want to install **even more**?

**💥 Enter `portscope` – your port conflict detector.**  
It tells you *before* your container says "Port already in use".

---

## 🧠 Features

- 🗂️ Smart file selection:
  - No argument? Uses current directory.
  - Directory? Looks for `docker-compose.yml` inside.
  - File? Parses it directly as a Docker Compose file.
- 🧪 Validates YAML file type.
- 🔎 Extracts **host ports** like `8080:80`.
- ⚠️ Detects conflicts with system ports (used by other services or Docker).
- 🚫 Ignores ports already used by containers from the **same compose file**.
- ✅ Friendly output: “All good” or conflict details.

---

## 📦 Installation

```bash
curl -o portscope https://raw.githubusercontent.com/bnap00/portscope/main/portscope.sh
chmod +x portscope
sudo mv portscope /usr/local/bin/portscope
```

To update later:

```bash
sudo curl -o /usr/local/bin/portscope https://raw.githubusercontent.com/bnap00/portscope/main/portscope.sh
```

---

## 🚀 Usage

```bash
portscope                    # Use current directory's docker-compose.yml
portscope /path/to/dir      # Use compose file inside specified directory
portscope custom.yml        # Parse a specific file directly
```

### ℹ️ Extras

```bash
portscope --help            # Show help message
portscope --version         # Show version number
```

---

## 📂 Example

```bash
$ portscope ./project
Using docker-compose file: ./project/docker-compose.yml
Required host ports: 80 6379
Info: Port 80 is already used by the same project – skipping
Conflict: Port 6379 is already in use by another container
```

---

## 🛠 Want to Just See Open Ports from All Docker Projects?

Use this one-liner to list all unique host ports exposed by **all running Docker containers**:

```bash
docker ps --format '{{{{.Ports}}}}' | grep -oP '\\d+(?=->)' | sort -n | uniq
```

Simple. Fast. No surprises.

---

## 🔒 Requirements

- Bash
- `ss` (part of `iproute2` package)
- Docker CLI

---

## 🧪 Roadmap

- [ ] Add support for multiple compose files (e.g., `-f a.yml -f b.yml`)
- [ ] Optional JSON output mode for CI
- [ ] Add CI integration and unit tests

---

## 🤝 Contributing

We welcome feedback and PRs!  
To propose improvements, please open an [issue](https://github.com/bnap00/portscope/issues) or submit a pull request.

---

## 📄 License

MIT License

---

## ✨ Maintained by [bnap00](https://github.com/bnap00)
