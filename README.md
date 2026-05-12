## Lightweight Linux Fleet Reporting & Telemetry Platform

![alt text](docs/lastcontrol_logo.png "LastControl Logo")

---

LastControl, a lightweight, TLS-enabled Linux fleet reporting and telemetry platform, is designed for small and medium-sized infrastructures, laboratories, test environments, and self-hosted enterprise-style deployments.

![LastControl](https://img.shields.io/badge/LastControl-Linux%20System%20Reporter-1e3a8a?style=for-the-badge&logo=linux&logoColor=green&labelColor=0f172a&color=darkblue) <br>

---

#### Project Focuses
- Simple deployment
- Minimal dependencies
- Bash-first architecture
- Secure telemetry transport
- Centralized reporting
- Lightweight operational visibility

Unlike large-scale enterprise monitoring stacks, LastControl aims to provide a minimal and understandable infrastructure that can be deployed quickly on Debian-based systems while remaining extensible for future orchestration and task execution capabilities.

#### Project Goals
LastControl was designed with the following ideas in mind:
- Keep the agent lightweight
- Avoid daemon-heavy architectures
- Use standard Linux tools
- Use encrypted communication
- Make deployments reproducible
- Allow future orchestration capabilities
- Remain understandable and maintainable by system administrators

#### The current version focuses:
- Inventory collection
- System telemetry
- Centralized reporting
- Web-based visibility
- Secure agent-server communication

#### Features
- Secure Agent Communication
- TLS-encrypted communication using socat
- Certificate-based client authentication
- Lightweight transport layer
- Flask-based lightweight web UI
- Historical telemetry views
- Bash-based agents
- systemd integration
- Randomized reporting timers

#### Installation
```
git clone https://github.com/eesmer/LastControl.git
cd LastControl
```
